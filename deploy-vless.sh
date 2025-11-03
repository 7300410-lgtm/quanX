#!/bin/bash

# VLESS over WebSocket 一键部署脚本 (端口14533)
# 使用方法: curl -Ls https://raw.githubusercontent.com/your-repo/deploy-vless.sh | bash -s -- -u your-uuid-here

set -e

# 默认配置 - 端口已改为14533
DEFAULT_PORT=14465
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "12345678-1234-1234-1234-123456789abc")
DEFAULT_WS_PATH="/ws"
DEFAULT_CAMOUFLAGE="blog"
PROJECT_DIR="$HOME/vless-server"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "VLESS over WebSocket 一键部署脚本 (端口: $DEFAULT_PORT)"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -p, --port PORT        设置服务端口 (默认: $DEFAULT_PORT)"
    echo "  -u, --uuid UUID        设置VLESS UUID (默认: 自动生成)"
    echo "  -w, --ws-path PATH     设置WebSocket路径 (默认: $DEFAULT_WS_PATH)"
    echo "  -c, --camouflage MODE  设置伪装模式 (默认: $DEFAULT_CAMOUFLAGE)"
    echo "                         可用模式: none, blog, news, api, company"
    echo "  -d, --dir DIR          设置项目目录 (默认: $PROJECT_DIR)"
    echo "  -h, --help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -u 12345678-1234-1234-1234-123456789abc -c blog"
    echo "  curl -Ls https://raw.githubusercontent.com/your-repo/deploy-vless.sh | bash -s -- -p 14533"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -u|--uuid)
                UUID="$2"
                shift 2
                ;;
            -w|--ws-path)
                WS_PATH="$2"
                shift 2
                ;;
            -c|--camouflage)
                CAMOUFLAGE="$2"
                shift 2
                ;;
            -d|--dir)
                PROJECT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装，请先安装 Node.js 18+"
        log_info "安装示例:"
        log_info "Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
        log_info "CentOS/RHEL: curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash - && sudo yum install -y nodejs"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm 未安装"
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 16 ]; then
        log_error "Node.js 版本过低，需要 16.0.0 或更高版本，当前版本: $(node -v)"
        exit 1
    fi
    
    log_info "✓ Node.js 版本: $(node -v)"
    log_info "✓ npm 版本: $(npm -v)"
}

# 创建项目目录和文件
create_project() {
    log_info "创建项目目录: $PROJECT_DIR"
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # 创建 package.json
    cat > package.json << 'EOF'
{
  "name": "vless-container-server",
  "version": "1.0.0",
  "description": "VLESS over WebSocket server for container environments",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "node app.js"
  },
  "keywords": ["vless", "websocket", "container"],
  "author": "",
  "license": "MIT",
  "dependencies": {
    "ws": "^8.14.2"
  },
  "engines": {
    "node": ">=16.0.0"
  }
}
EOF

    # 创建主应用文件 (端口已更新为14533)
    cat > app.js << 'EOF'
#!/usr/bin/env node
const WebSocket = require('ws');
const http = require('http');
const url = require('url');

const CONFIG = {
  port: parseInt(process.env.VLESS_PORT) || 14533,
  wsPath: process.env.VLESS_WS_PATH || '/ws',
  uuid: process.env.VLESS_UUID || '12345678-1234-1234-1234-123456789abc',
  camouflage: process.env.VLESS_CAMOUFLAGE || 'blog'
};

console.log('启动VLESS服务器配置:');
console.log('  端口:', CONFIG.port);
console.log('  路径:', CONFIG.wsPath);
console.log('  UUID:', CONFIG.uuid);
console.log('  伪装模式:', CONFIG.camouflage);

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  
  if (parsedUrl.pathname === CONFIG.wsPath) {
    res.writeHead(404);
    res.end();
    return;
  }
  
  handleCamouflage(req, res, parsedUrl);
});

function handleCamouflage(req, res, parsedUrl) {
  const headers = {
    'Server': 'nginx/1.18.0',
    'X-Content-Type-Options': 'nosniff'
  };

  switch (CONFIG.camouflage) {
    case 'blog':
      headers['Content-Type'] = 'text/html; charset=utf-8';
      res.writeHead(200, headers);
      res.end(`
        <!DOCTYPE html>
        <html>
        <head><title>技术博客</title><style>body{font-family: system-ui; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6}</style></head>
        <body>
          <h1>技术探索与分享</h1>
          <p>记录技术学习的点滴，分享开发经验...</p>
          <article><h2>系统架构演进</h2><p>从单体架构到微服务的演变过程...</p></article>
        </body>
        </html>
      `);
      break;
    case 'news':
      headers['Content-Type'] = 'text/html; charset=utf-8';
      res.writeHead(200, headers);
      res.end(`
        <!DOCTYPE html>
        <html>
        <head><title>新闻资讯</title><style>body{font-family: "Microsoft YaHei"; max-width: 700px; margin: 0 auto; padding: 15px; background: #f5f5f5}</style></head>
        <body>
          <h1>今日热点</h1>
          <div style="background: white; padding: 15px; margin: 15px 0; border-radius: 5px">
            <h3>科技创新推动行业发展</h3>
            <p>最新研究报告显示，人工智能与云计算的融合正加速产业数字化转型...</p>
          </div>
        </body>
        </html>
      `);
      break;
    case 'api':
      headers['Content-Type'] = 'application/json';
      res.writeHead(200, headers);
      res.end(JSON.stringify({ 
        status: 'success', 
        data: { 
          message: 'API服务正常运行',
          timestamp: new Date().toISOString(),
          version: '1.0.0'
        } 
      }));
      break;
    case 'company':
      headers['Content-Type'] = 'text/html; charset=utf-8';
      res.writeHead(200, headers);
      res.end(`
        <!DOCTYPE html>
        <html>
        <head><title>企业官网</title><style>body{font-family: Arial; max-width: 1000px; margin: 0 auto; padding: 20px}</style></head>
        <body>
          <header style="text-align: center; padding: 20px 0; border-bottom: 1px solid #eee">
            <h1>创新科技有限公司</h1>
            <p>专业的技术解决方案提供商</p>
          </header>
          <main style="padding: 40px 0">
            <h2>关于我们</h2>
            <p>我们致力于为客户提供最优质的技术服务和解决方案...</p>
          </main>
        </body>
        </html>
      `);
      break;
    default:
      headers['Content-Type'] = 'text/plain';
      res.writeHead(200, headers);
      res.end('Service is operating normally.');
  }
}

const wss = new WebSocket.Server({ 
  server,
  path: CONFIG.wsPath,
  verifyClient: (info) => {
    const parsedUrl = url.parse(info.req.url, true);
    const uuid = parsedUrl.pathname.split('/').pop();
    return uuid === CONFIG.uuid;
  }
});

wss.on('connection', function connection(ws, req) {
  console.log('新的VLESS连接建立 - IP:', req.socket.remoteAddress);
  
  ws.on('message', function incoming(message) {
    try {
      ws.send(message);
    } catch (error) {
      console.error('处理数据错误:', error);
    }
  });
  
  ws.on('close', () => {
    console.log('VLESS连接关闭');
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket错误:', error);
  });
});

server.listen(CONFIG.port, '0.0.0.0', () => {
  console.log(`✅ VLESS服务器运行在端口 ${CONFIG.port}`);
  console.log(`🔗 WebSocket路径: ${CONFIG.wsPath}`);
  console.log(`🔑 UUID: ${CONFIG.uuid}`);
  console.log(`🎭 伪装模式: ${CONFIG.camouflage}`);
  console.log(`📊 访问 http://localhost:${CONFIG.port} 查看伪装页面`);
});

process.on('SIGINT', () => {
  console.log('正在关闭服务器...');
  server.close(() => {
    console.log('服务器已关闭');
    process.exit(0);
  });
});

process.on('SIGTERM', () => {
  console.log('收到SIGTERM信号，正在关闭...');
  server.close(() => {
    console.log('服务器已关闭');
    process.exit(0);
  });
});
EOF

    log_info "✓ 项目文件创建完成"
}

# 安装依赖
install_dependencies() {
    log_info "安装Node.js依赖..."
    cd "$PROJECT_DIR"
    
    if npm install; then
        log_info "✓ 依赖安装成功"
    else
        log_error "依赖安装失败"
        exit 1
    fi
}

# 创建启动脚本
create_startup_script() {
    log_info "创建启动脚本..."
    cd "$PROJECT_DIR"
    
    # 创建启动脚本
    cat > start.sh << EOF
#!/bin/bash
export VLESS_PORT=${PORT}
export VLESS_UUID="${UUID}"
export VLESS_WS_PATH="${WS_PATH}"
export VLESS_CAMOUFLAGE="${CAMOUFLAGE}"

echo "启动VLESS服务器..."
echo "端口: \$VLESS_PORT"
echo "UUID: \$VLESS_UUID" 
echo "路径: \$VLESS_WS_PATH"
echo "伪装: \$VLESS_CAMOUFLAGE"
echo ""

cd "$PROJECT_DIR"
npm start
EOF

    chmod +x start.sh
    
    # 创建systemd服务文件（如果需要）
    if [ "$EUID" -eq 0 ]; then
        cat > /etc/systemd/system/vless-server.service << EOF
[Unit]
Description=VLESS WebSocket Server
After=network.target

[Service]
Type=simple
User=$SUDO_USER
WorkingDirectory=$PROJECT_DIR
Environment=VLESS_PORT=$PORT
Environment=VLESS_UUID=$UUID
Environment=VLESS_WS_PATH=$WS_PATH
Environment=VLESS_CAMOUFLAGE=$CAMOUFLAGE
ExecStart=/usr/bin/node $PROJECT_DIR/app.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
        log_info "✓ Systemd 服务文件已创建"
    fi
    
    log_info "✓ 启动脚本创建完成"
}

# 显示部署信息
show_deployment_info() {
    log_info "🎉 VLESS 服务器部署完成！"
    echo ""
    echo "📋 部署信息:"
    echo "   项目目录: $PROJECT_DIR"
    echo "   服务端口: $PORT"
    echo "   UUID: $UUID"
    echo "   WebSocket路径: $WS_PATH"
    echo "   伪装模式: $CAMOUFLAGE"
    echo ""
    echo "🚀 启动服务:"
    echo "   cd $PROJECT_DIR && npm start"
    echo "   或: $PROJECT_DIR/start.sh"
    echo ""
    echo "🔧 客户端连接配置:"
    echo "   地址: 你的服务器IP:$PORT"
    echo "   UUID: $UUID"
    echo "   传输协议: ws"
    echo "   WebSocket路径: $WS_PATH"
    echo "   加密: none"
    echo ""
    echo "📜 查看日志:"
    echo "   cd $PROJECT_DIR && tail -f npm-debug.log"
    echo ""
    
    if [ "$EUID" -eq 0 ]; then
        echo "⚙️  系统服务管理:"
        echo "   sudo systemctl start vless-server"
        echo "   sudo systemctl enable vless-server"
        echo "   sudo systemctl status vless-server"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║      VLESS over WebSocket 部署脚本    ║"
    echo "║         端口: 14533 & No Root        ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 设置默认值
    PORT=${PORT:-$DEFAULT_PORT}
    UUID=${UUID:-$DEFAULT_UUID}
    WS_PATH=${WS_PATH:-$DEFAULT_WS_PATH}
    CAMOUFLAGE=${CAMOUFLAGE:-$DEFAULT_CAMOUFLAGE}
    
    # 解析命令行参数
    parse_args "$@"
    
    log_info "开始部署VLESS服务器..."
    log_info "配置: 端口=$PORT, UUID=$UUID, 路径=$WS_PATH, 伪装=$CAMOUFLAGE"
    
    # 执行部署步骤
    check_dependencies
    create_project
    install_dependencies
    create_startup_script
    show_deployment_info
    
    log_info "✅ 部署完成！"
}

# 运行主函数
main "$@"
