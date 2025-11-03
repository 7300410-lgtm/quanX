#!/bin/bash
# =========================================
# Xray VLESS over WS+TLS 自动部署脚本（免 root）
# 固定端口：14549
# 固定 UUID：2c1a7a59-6241-4114-a26c-1da2e73444dc
# SNI：www.bing.com
# =========================================
set -euo pipefail
export LC_ALL=C
IFS=$'\n\t'

MASQ_DOMAIN="www.bing.com"
VLESS_PORT=14549
VLESS_UUID="2c1a7a59-6241-4114-a26c-1da2e73444dc"
VLESS_PATH="/vless"
SERVER_JSON="vless-server.json"
LINK_TXT="vless_link.txt"
XRAY_BIN="./xray"
CERT_PEM="vless-cert.pem"
KEY_PEM="vless-key.pem"

# ========== 生成自签证书 ==========
generate_cert() {
  if [[ -f "$CERT_PEM" && -f "$KEY_PEM" ]]; then
    echo "🔐 Certificate exists, skipping."
    return
  fi
  echo "🔐 Generating self-signed certificate for ${MASQ_DOMAIN}..."
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout "$KEY_PEM" -out "$CERT_PEM" -subj "/CN=${MASQ_DOMAIN}" -days 365 -nodes >/dev/null 2>&1
  chmod 600 "$KEY_PEM"
  chmod 644 "$CERT_PEM"
}

# ========== 下载 Xray 核心 ==========
check_xray() {
  if [[ -x "$XRAY_BIN" ]]; then
    echo "✅ Xray already exists."
    return
  fi
  echo "📥 Downloading Xray core..."
  ARCH=$(uname -m)
  if [[ "$ARCH" == "x86_64" ]]; then
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
  elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip"
  else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
  fi
  curl -L -o xray.zip "$XRAY_URL"
  unzip -o xray.zip -d xray_tmp
  mv xray_tmp/xray "$XRAY_BIN"
  chmod +x "$XRAY_BIN"
  rm -rf xray_tmp xray.zip
}

# ========== 生成 Xray 配置 ==========
generate_config() {
cat > "$SERVER_JSON" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": ${VLESS_PORT},
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "${VLESS_UUID}",
          "flow": "xtls-rprx-vision",
          "level": 0
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "${VLESS_PATH}",
        "headers": {
          "Host": "${MASQ_DOMAIN}"
        }
      },
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "${CERT_PEM}",
            "keyFile": "${KEY_PEM}"
          }
        ]
      }
    }
  }],
  "outbounds": [
    { "protocol": "freedom", "settings": {} }
  ]
}
EOF
}

# ========== 获取公网 IP ==========
get_server_ip() {
  curl -s --connect-timeout 3 https://api64.ipify.org || echo "127.0.0.1"
}

# ========== 生成 VLESS 链接 ==========
generate_link() {
  local ip="$1"
  cat > "$LINK_TXT" <<EOF
vless://${VLESS_UUID}@${ip}:${VLESS_PORT}?encryption=none&security=tls&type=ws&host=${MASQ_DOMAIN}&path=${VLESS_PATH}#VLESS-${ip}
EOF
  echo "🔗 VLESS link generated successfully:"
  cat "$LINK_TXT"
}

# ========== 启动 Xray ==========
run_server() {
  echo "🚀 Starting Xray VLESS server..."
  "$XRAY_BIN" -config "$SERVER_JSON"
}

# ========== 主流程 ==========
main() {
  generate_cert
  check_xray
  generate_config
  ip=$(get_server_ip)
  generate_link "$ip"
  run_server
}

main
