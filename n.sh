#!/bin/bash
# =========================================
# VLESS over WS/TLS 自动部署脚本（免 root）
# 固定 SNI：www.bing.com
# 固定端口：14549
# 固定 UUID：2c1a7a59-6241-4114-a26c-1da2e73444dc
# =========================================
set -euo pipefail
export LC_ALL=C
IFS=$'\n\t'

MASQ_DOMAIN="www.bing.com"
SERVER_JSON="vless-server.json"
LINK_TXT="vless_link.txt"
VLESS_BIN="./v2ray"   # 假设使用 v2ray-core
VLESS_PORT=14549
VLESS_UUID="2c1a7a59-6241-4114-a26c-1da2e73444dc"

# ========== 生成证书 ==========
generate_cert() {
  if [[ -f "vless-cert.pem" && -f "vless-key.pem" ]]; then
    echo "🔐 Certificate exists, skipping."
    return
  fi
  echo "🔐 Generating self-signed certificate for ${MASQ_DOMAIN}..."
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout "vless-key.pem" -out "vless-cert.pem" -subj "/CN=${MASQ_DOMAIN}" -days 365 -nodes >/dev/null 2>&1
  chmod 600 "vless-key.pem"
  chmod 644 "vless-cert.pem"
}

# ========== 下载 v2ray-core ==========
check_vless_server() {
  if [[ -x "$VLESS_BIN" ]]; then
    echo "✅ v2ray-core already exists."
    return
  fi
  echo "📥 Downloading v2ray-core..."
  curl -L -o "v2ray-linux-64.zip" "https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip"
  unzip -o "v2ray-linux-64.zip" -d ./v2ray_tmp
  mv ./v2ray_tmp/v2ray "$VLESS_BIN"
  chmod +x "$VLESS_BIN"
  rm -rf ./v2ray_tmp v2ray-linux-64.zip
}

# ========== 生成配置 ==========
generate_config() {
cat > "$SERVER_JSON" <<EOF
{
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
        "path": "/vless",
        "headers": {
          "Host": "${MASQ_DOMAIN}"
        }
      },
      "security": "tls",
      "tlsSettings": {
        "certificates": [
          {
            "certificateFile": "vless-cert.pem",
            "keyFile": "vless-key.pem"
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

# ========== 生成 VLESS 链接 ==========
generate_link() {
  local ip="$1"
  cat > "$LINK_TXT" <<EOF
vless://${VLESS_UUID}@${ip}:${VLESS_PORT}?encryption=none&security=tls&type=ws&host=${MASQ_DOMAIN}&path=/vless#VLESS-${ip}
EOF
  echo "🔗 VLESS link generated successfully:"
  cat "$LINK_TXT"
}

# ========== 获取公网IP ==========
get_server_ip() {
  curl -s --connect-timeout 3 https://api64.ipify.org || echo "127.0.0.1"
}

# ========== 守护进程 ==========
run_background_loop() {
  echo "🚀 Starting VLESS server..."
  while true; do
    "$VLESS_BIN" -config "$SERVER_JSON" >/dev/null 2>&1 || true
    echo "⚠️ VLESS crashed. Restarting in 5s..."
    sleep 5
  done
}

# ========== 主流程 ==========
main() {
  generate_cert
  check_vless_server
  generate_config

  ip="$(get_server_ip)"
  generate_link "$ip"
  run_background_loop
}

main
