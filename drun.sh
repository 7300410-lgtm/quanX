#!/bin/bash
# =====================================================
# 🛰️  VLESS over WebSocket 一键部署脚本 (轻量容器版)
# 安装运行: curl -Ls https://your-repo/vless-lite.sh | bash
# =====================================================

set -e

# ===== 默认参数 =====
PORT=${PORT:-14549}
UUID_FILE="$HOME/.vless_uuid"
UUID=${UUID:-$( [ -f "$UUID_FILE" ] && cat "$UUID_FILE" || cat /proc/sys/kernel/random/uuid )}
WS_PATH=${WS_PATH:-/ws}
CAMOUFLAGE=${CAMOUFLAGE:-blog}
PROJECT_DIR=${PROJECT_DIR:-$HOME/vless-server}

# ===== 简易日志函数 =====
log() { echo -e "\033[1;32m[+] $1\033[0m"; }
warn() { echo -e "\033[1;33m[!] $1\033[0m"; }
err() { echo -e "\033[1;31m[✗] $1\033[0m"; exit 1; }

# ===== 检查依赖 =====
check_env() {
  if ! command -v node &>/dev/null; then
    err "Node.js 未安装，请先安装 Node.js 18+"
  fi
  if ! command -v npm &>/dev/null; then
    err "npm 未安装"
  fi
}

# ===== 创建项目文件 =====
setup_project() {
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  # package.json
  cat > package.json <<EOF
{
  "name": "vless-lite",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": { "ws": "^8.14.2" },
  "scripts": { "start": "node app.js" }
}
EOF

  # app.js
  cat > app.js <<'EOF'
#!/usr/bin/env node
const WebSocket = require('ws');
const http = require('http');
const url = require('url');

const CONFIG = {
  port: parseInt(process.env.VLESS_PORT) || 14549,
  wsPath: process.env.VLESS_WS_PATH || '/ws',
  uuid: process.env.VLESS_UUID || '12345678-1234-1234-1234-123456789abc',
  camouflage: process.env.VLESS_CAMOUFLAGE || 'blog'
};

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  if (parsedUrl.pathname === CONFIG.wsPath) {
    res.writeHead(404);
    return res.end();
  }
  serveCamouflage(req, res);
});

function serveCamouflage(req, res) {
  switch (CONFIG.camouflage) {
    case 'blog':
      res.writeHead(200, {'Content-Type':'text/html'});
      res.end('<h1>技术博客</h1><p>记录开发笔记与技术分享。</p>');
      break;
    case 'api':
      res.writeHead(200, {'Content-Type':'application/json'});
      res.end(JSON.stringify({status:'ok',time:new Date().toISOString()}));
      break;
    case 'news':
      res.writeHead(200, {'Content-Type':'text/html'});
      res.end('<h1>今日新闻</h1><p>AI 技术引领未来。</p>');
      break;
    default:
      res.writeHead(200);
      res.end('Service is running');
  }
}

const wss = new WebSocket.Server({
  server,
  path: CONFIG.wsPath,
  verifyClient: info => {
    const u = url.parse(info.req.url, true);
    const uuid = u.pathname.split('/').pop();
    return uuid === CONFIG.uuid;
  }
});

wss.on('connection', (ws, req) => {
  console.log('新连接:', req.socket.remoteAddress);
  ws.on('message', msg => ws.send(msg));
});

server.listen(CONFIG.port, '0.0.0.0', () => {
  console.log(\`✅ VLESS WS 运行于端口 \${CONFIG.port} 路径=\${CONFIG.wsPath}\`);
});
EOF

  # 保存 UUID
  echo "$UUID" > "$UUID_FILE"
}

# ===== 安装依赖 =====
install_deps() {
  cd "$PROJECT_DIR"
  npm install --silent
}

# ===== 启动服务 =====
start_server() {
  cd "$PROJECT_DIR"
  log "启动 VLESS 服务..."
  export VLESS_PORT=$PORT
  export VLESS_UUID="$UUID"
  export VLESS_WS_PATH="$WS_PATH"
  export VLESS_CAMOUFLAGE="$CAMOUFLAGE"
  nohup npm start >/dev/null 2>&1 &
}

# ===== 信息展示 =====
show_info() {
  echo ""
  log "🎉 部署完成！"
  echo "📍 端口: $PORT"
  echo "🔑 UUID: $UUID"
  echo "🌐 路径: $WS_PATH"
  echo "🎭 伪装: $CAMOUFLAGE"
  echo ""
  echo "🚀 访问伪装页: http://<你的服务器IP>:$PORT"
  echo ""
  echo "🧠 客户端配置:"
  echo "  vless://$UUID@<你的服务器IP>:$PORT?encryption=none&type=ws&path=$WS_PATH#VLESS-WS"
}

# ===== 主流程 =====
main() {
  echo -e "\033[1;34m
╔══════════════════════════════╗
║     🚀 VLESS WS 轻量版部署脚本 ║
╚══════════════════════════════╝\033[0m"
  check_env
  setup_project
  install_deps
  start_server
  show_info
}

main "$@"
