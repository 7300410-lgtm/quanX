#!/bin/bash

# 非 Root 权限 VLESS 部署脚本
# 端口: 14549
# 无需 root 权限，使用用户空间安装

set -e

# 配置变量
USER_HOME="$HOME"
V2RAY_DIR="$USER_HOME/v2ray"
CONFIG_FILE="$V2RAY_DIR/config.json"
BIN_DIR="$V2RAY_DIR/bin"
LOG_DIR="$V2RAY_DIR/logs"
PORT="14549"
UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "$(date +%s)-$RANDOM")

# 如果无法生成标准 UUID，使用替代方法
if [ "$UUID" = "" ]; then
    UUID="$(date +%s%N)-$RANDOM-$RANDOM-$RANDOM"
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查系统架构
get_architecture() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="64" ;;
        aarch64) ARCH="arm64-v8a" ;;
        armv7l) ARCH="arm32-v7a" ;;
        *) error "不支持的架构: $ARCH"; exit 1 ;;
    esac
    info "系统架构: $ARCH"
}

# 创建目录结构
create_directories() {
    info "创建目录结构..."
    mkdir -p "$BIN_DIR" "$LOG_DIR"
}

# 下载 V2Ray
download_v2ray() {
    info "下载 V2Ray..."
    local V2RAY_URL="https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-$ARCH.zip"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$V2RAY_DIR/v2ray.zip" "$V2RAY_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$V2RAY_DIR/v2ray.zip" "$V2RAY_URL"
    else
        error "需要 curl 或 wget 来下载文件"
        exit 1
    fi
    
    if [ ! -f "$V2RAY_DIR/v2ray.zip" ]; then
        error "下载 V2Ray 失败"
        exit 1
    fi
    
    info "解压 V2Ray..."
    unzip -q "$V2RAY_DIR/v2ray.zip" -d "$V2RAY_DIR/"
    mv "$V2RAY_DIR/v2ray" "$BIN_DIR/"
    mv "$V2RAY_DIR/v2ctl" "$BIN_DIR/"
    chmod +x "$BIN_DIR/v2ray" "$BIN_DIR/v2ctl"
    rm -f "$V2RAY_DIR/v2ray.zip" "$V2RAY_DIR/"*.json
}

# 生成配置文件
generate_config() {
    info "生成 V2Ray 配置文件..."
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log"
  },
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [
        {
          "id": "$UUID",
          "level": 0,
          "email": "user@v2ray.com"
        }
      ],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/v2ray"
      },
      "security": "none"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    info "配置文件已生成: $CONFIG_FILE"
}

# 生成启动脚本
generate_start_script() {
    info "生成启动脚本..."
    
    cat > "$V2RAY_DIR/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./bin/v2ray run -config config.json
EOF

    cat > "$V2RAY_DIR/stop.sh" << 'EOF'
#!/bin/bash
pkill -f "v2ray run -config config.json"
EOF

    chmod +x "$V2RAY_DIR/start.sh" "$V2RAY_DIR/stop.sh"
}

# 获取公网IP
get_public_ip() {
    info "获取服务器公网IP..."
    PUBLIC_IP=$(curl -s -4 ip.sb 2>/dev/null || curl -s -4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    if [ "$PUBLIC_IP" = "YOUR_SERVER_IP" ]; then
        warn "无法自动获取公网IP，请手动替换连接中的 YOUR_SERVER_IP"
    else
        info "服务器公网IP: $PUBLIC_IP"
    fi
}

# 生成客户端连接信息
generate_client_info() {
    info "生成 VLESS 客户端连接信息..."
    
    cat << EOF

================================ VLESS 配置信息 ================================
服务器地址: $PUBLIC_IP
端口: $PORT
UUID: $UUID
传输协议: ws
路径: /v2ray
安全: none

VLESS 链接:
vless://$UUID@$PUBLIC_IP:$PORT?type=ws&security=none&path=%2Fv2ray#$PUBLIC_IP

Clash 配置:
  - name: "VLESS-$PUBLIC_IP"
    type: vless
    server: $PUBLIC_IP
    port: $PORT
    uuid: $UUID
    network: ws
    ws-opts:
      path: /v2ray
    udp: true

===============================================================================
EOF

    # 保存配置到文件
    cat > "$V2RAY_DIR/client-info.txt" << EOF
服务器地址: $PUBLIC_IP
端口: $PORT
UUID: $UUID
传输协议: ws
路径: /v2ray

VLESS 链接:
vless://$UUID@$PUBLIC_IP:$PORT?type=ws&security=none&path=%2Fv2ray#$PUBLIC_IP
EOF
    
    info "客户端配置已保存到: $V2RAY_DIR/client-info.txt"
}

# 测试端口是否可用
test_port() {
    info "测试端口 $PORT 是否可用..."
    
    if command -v nc >/dev/null 2>&1; then
        if nc -z localhost $PORT 2>/dev/null; then
            error "端口 $PORT 已被占用，请更换端口或关闭占用程序"
            exit 1
        else
            info "端口 $PORT 可用"
        fi
    else
        warn "无法检查端口占用情况 (netcat 未安装)，请确保端口 $PORT 未被占用"
    fi
}

# 启动服务
start_service() {
    info "启动 V2Ray 服务..."
    
    # 检查是否已在运行
    if pgrep -f "v2ray run -config config.json" >/dev/null; then
        warn "V2Ray 服务已在运行，正在停止..."
        pkill -f "v2ray run -config config.json"
        sleep 2
    fi
    
    # 启动服务
    cd "$V2RAY_DIR"
    nohup ./bin/v2ray run -config config.json > "$LOG_DIR/run.log" 2>&1 &
    local PID=$!
    
    sleep 3
    
    if ps -p $PID >/dev/null 2>&1; then
        info "V2Ray 服务启动成功 (PID: $PID)"
        
        # 检查端口监听
        if command -v ss >/dev/null 2>&1 && ss -tuln | grep -q ":$PORT "; then
            info "端口 $PORT 监听正常"
        else
            warn "端口 $PORT 可能未正常监听，请检查日志: $LOG_DIR/run.log"
        fi
    else
        error "V2Ray 服务启动失败，请检查日志: $LOG_DIR/run.log"
        exit 1
    fi
}

# 显示使用说明
show_usage() {
    cat << EOF

使用说明:
启动服务: $V2RAY_DIR/start.sh
停止服务: $V2RAY_DIR/stop.sh
查看日志: tail -f $LOG_DIR/run.log
配置文件: $CONFIG_FILE
客户端配置: $V2RAY_DIR/client-info.txt

管理命令:
启动: cd $V2RAY_DIR && ./start.sh
停止: cd $V2RAY_DIR && ./stop.sh
重启: 先运行 stop.sh 再运行 start.sh

EOF
}

# 主函数
main() {
    clear
    echo "=========================================="
    echo "   非 Root VLESS 部署脚本 (端口: $PORT)   "
    echo "=========================================="
    
    get_architecture
    test_port
    create_directories
    download_v2ray
    generate_config
    generate_start_script
    get_public_ip
    start_service
    generate_client_info
    show_usage
    
    info "部署完成！所有文件安装在: $V2RAY_DIR"
}

# 执行主函数
main "$@"
