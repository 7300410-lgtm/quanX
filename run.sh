#!/bin/bash
# ============================================================
# 🌀 VLESS over WebSocket (固定 UUID + 自动保存)
# 作者: afd riu
# 用法: curl -Ls https://raw.githubusercontent.com/afdriu/vless/main/vless-fixed.sh | bash
# ============================================================

set -e

# ==== 默认参数 ====
IP=${IP:-85.215.137.163}
PORT=${PORT:-14549}
UUID="2c1a7a59-6241-4114-a26c-1da2e73444dc"   # 固定 UUID
WS_PATH=${WS_PATH:-/ws}
CAMOUFLAGE=${CAMOUFLAGE:-blog}
PROJECT_DIR=${PROJECT_DIR:-$HOME/vless-server}
UUID_FILE="${PROJECT_DIR}/UUID.txt"

# ==== 日志函数 ====
log() { echo -e "\033[1;32m[+] $1\033[0m"; }

# ==== 环境检测 ====
check_env() {
  if ! command -v node &>/dev/null; then
    log "检测到未安装 Node.js，正在安装..."
    if command -v apt &>/dev/null; then
      apt update -y && apt install -y nodejs npm
    elif command -v yum &>/dev/null; then
      yum install -y nodejs npm
    elif command -v apk &>/dev/null; then
      apk add --no-cache nodejs npm
    else
      echo "无法自动安装 Node.js，请手动安装后重试。"
      exit 1
    fi
  fi
}

# ==== 创建服务项目 ====
setup_project() {
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  # 保存 UUID（固定）
  echo "$UUID" > "$UUID_FILE"

  cat > package.json <<EOF
{
  "name": "vless-lite",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": { "ws": "^8.14.2" },
  "scripts": { "start": "node app.js" }
}
EOF

  cat > app.js <<'EOF'
#!/usr/bin/env node
const WebSocket = require('ws');
const http = require('http');
const url = require('url');
const fs = require('fs');

const CONFIG = {
  port: parseInt(process.env.VLESS_PORT) || 14549,
  wsPath: process.env.VLESS_WS_PATH || '/ws',
  uuid: process.env.VLESS_UUID || fs.existsSync('./UUID.txt') ? fs.readFileSync('./UUID.txt','utf8').trim() : '2c1a7a59-6241-4114-a26c-1da2e73444dc',
  camouflage: process.env.VLESS_CAMOUFLAGE || 'blog'
};

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  if (parsedUrl.pathname === CONFIG.wsPath) {
    res.writeHead(404);
    return res.end();
  }
  switch (CONFIG.camouflage) {
    case 'blog':
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end('<h1>技术博客</h1><p>记录开发与运维笔记</p>');
      break;
    case 'news':
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end('<h1>今日新闻</h1><p>科技创新推动行业发展</p>');
      break;
    case 'api':
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', time: new Date().toISOString() }));
      break;
    default:
      res.writeHead(200);
      res.end('Service is running');
  }
});

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
  console.log('New connection from:', req.socket.remoteAddress);
  ws.on('message', msg => ws.send(msg));
});

server.listen(CONFIG.port, '0.0.0.0', () =>
  console.log(`✅ VLESS WS running on port ${CONFIG.port} path=${CONFIG.wsPath}`)
);
EOF
}

# ==== 安装依赖 ====
install_deps() {
  cd "$PROJECT_DIR"
  npm install --silent
}

# ==== 启动脚本 ====
create_runner() {
  cat > start.sh <<EOF
#!/bin/bash
export VLESS_PORT=${PORT}
export VLESS_UUID="\$(cat ${UUID_FILE})"
export VLESS_WS_PATH="${WS_PATH}"
export VLESS_CAMOUFLAGE="${CAMOUFLAGE}"
cd "${PROJECT_DIR}"
npm start
EOF
  chmod +x start.sh
}

# ==== 输出信息 ====
print_link() {
  VLESS_LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&security=none&type=ws&host=${IP}&path=${WS_PATH}#${IP}"
  
  echo
  log "✅ 部署完成！"
  echo "运行命令启动："
  echo "cd $PROJECT_DIR && ./start.sh"
  echo
  log "🌀 你的 VLESS 节点信息如下："
  echo "$VLESS_LINK"
  echo
  log "📌 UUID 已保存到 $UUID_FILE，可随时查看："
  echo "cat $UUID_FILE"
}

# ==== 主流程 ====
main() {
  log "开始部署 VLESS WS 服务..."
  log "IP: $IP"
  log "端口: $PORT"
  log "路径: $WS_PATH"
  log "伪装: $CAMOUFLAGE"

  check_env
  setup_project
  install_deps
  create_runner
  print_link
}

main "$@"
