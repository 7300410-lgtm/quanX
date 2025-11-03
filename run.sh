#!/bin/bash
# ============================================================
# 🌀 VLESS + WebSocket + Node伪装 一键部署脚本 (兼容无iptables系统)
# 作者: afd riu
# 用法: curl -Ls https://raw.githubusercontent.com/afdriu/vless/main/vless-full-lite.sh | bash
# ============================================================

set -e

# ==== 参数 ====
PORT=${PORT:-14549}
UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}
WS_PATH=${WS_PATH:-/ws}
CAMOUFLAGE=${CAMOUFLAGE:-blog}
PROJECT_DIR=${PROJECT_DIR:-$HOME/vless-server}
SERVER_IP=${SERVER_IP:-85.215.137.163}

# ==== 简单输出 ====
log() { echo -e "\033[1;32m[+] $1\033[0m"; }
warn() { echo -e "\033[1;33m[!] $1\033[0m"; }

# ==== 防火墙（自动检测是否可用）====
firewall() {
  log "配置防火墙规则（若不可用将自动跳过）..."
  if command -v ufw &>/dev/null; then
    ufw allow ${PORT}/tcp || true
    ufw allow 80/tcp || true
  fi
  if command -v iptables &>/dev/null; then
    iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT || true
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT || true
  else
    warn "系统未安装 iptables，跳过端口放行步骤。"
  fi
}

# ==== 安装 Node ====
install_node() {
  if ! command -v node &>/dev/null; then
    log "安装 Node.js 环境..."
    if command -v apt &>/dev/null; then
      apt update -y && apt install -y curl
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt install -y nodejs
    elif command -v yum &>/dev/null; then
      yum install -y curl
      curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
      yum install -y nodejs
    else
      echo "无法自动安装 Node.js，请手动安装后再运行。"
      exit 1
    fi
  fi
}

# ==== 安装 Xray ====
install_xray() {
  log "安装 Xray-core..."
  bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh) >/dev/null 2>&1
  mkdir -p /usr/local/etc/xray
  cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [{
    "port": ${PORT},
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "${UUID}", "level": 0 }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": { "path": "${WS_PATH}" }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
  systemctl enable xray >/dev/null 2>&1
  systemctl restart xray
}

# ==== Node伪装站点 ====
setup_node() {
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  cat > package.json <<EOF
{
  "name": "vless-mask",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": { "express": "^4.18.2" },
  "scripts": { "start": "node app.js" }
}
EOF

  cat > app.js <<EOF
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  switch ('${CAMOUFLAGE}') {
    case 'blog':
      res.send('<h1>技术博客</h1><p>记录开发与运维笔记</p>');
      break;
    case 'news':
      res.send('<h1>今日新闻</h1><p>科技创新推动行业发展</p>');
      break;
    case 'api':
      res.json({ status: 'ok', time: new Date().toISOString() });
      break;
    default:
      res.send('Service is running');
  }
});

app.listen(80, () => console.log('🟢 Node伪装站点运行在 80 端口'));
EOF

  npm install --silent
  nohup npm start >/dev/null 2>&1 &
}

# ==== 输出信息 ====
print_link() {
  local link="vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&type=ws&host=${SERVER_IP}&path=${WS_PATH}&security=none#VLESS_${SERVER_IP}"
  echo
  log "✅ 部署完成！"
  echo "-------------------------------------------"
  echo " VLESS 连接地址："
  echo -e "\033[1;34m${link}\033[0m"
  echo "-------------------------------------------"
  echo "访问伪装站点: http://${SERVER_IP}/"
  echo "启动服务: systemctl restart xray"
  echo
}

# ==== 主流程 ====
main() {
  log "开始部署 VLESS + Node 伪装..."
  firewall
  install_node
  install_xray
  setup_node
  print_link
}

main "$@"
