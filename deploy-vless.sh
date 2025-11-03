#!/bin/bash

# 优化版 VLESS 部署脚本
# 端口: 14549
# 作者: 基于社区最佳实践优化

set -e

# 配置变量
CONFIG_FILE="/etc/v2ray/config.json"
SERVICE_NAME="v2ray"
PORT="14549"
UUID=$(cat /proc/sys/kernel/random/uuid)
WEBSITE_URL="https://github.com/v2fly/v2ray-core"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "需要root权限运行此脚本"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        SYSTEM="centos"
    elif grep -q "Ubuntu" /etc/issue; then
        SYSTEM="ubuntu"
    elif grep -q "Debian" /etc/issue; then
        SYSTEM="debian"
    else
        error "不支持的操作系统"
        exit 1
    fi
    info "检测到系统: $SYSTEM"
}

# 安装依赖
install_dependencies() {
    info "安装系统依赖..."
    if [[ $SYSTEM == "centos" ]]; then
        yum update -y
        yum install -y curl unzip wget
    else
        apt update -y
        apt install -y curl unzip wget
    fi
}

# 安装V2Ray
install_v2ray() {
    info "安装 V2Ray..."
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        error "V2Ray 安装失败"
        exit 1
    fi
    info "V2Ray 安装成功"
}

# 生成配置文件
generate_config() {
    info "生成 V2Ray 配置文件..."
    
    cat > $CONFIG_FILE << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log"
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

# 配置防火墙
setup_firewall() {
    info "配置防火墙..."
    if command -v ufw >/dev/null 2>&1; then
        ufw allow $PORT/tcp
        ufw reload
        info "UFW 防火墙已配置"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=$PORT/tcp
        firewall-cmd --reload
        info "FirewallD 已配置"
    elif command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
        info "iptables 规则已添加"
    else
        warn "未找到支持的防火墙工具，请手动开放端口 $PORT"
    fi
}

# 获取公网IP
get_public_ip() {
    info "获取服务器公网IP..."
    PUBLIC_IP=$(curl -s -4 ip.sb)
    if [[ -z "$PUBLIC_IP" ]]; then
        PUBLIC_IP=$(curl -s -4 ifconfig.me)
    fi
    if [[ -z "$PUBLIC_IP" ]]; then
        error "无法获取公网IP，请手动检查"
        PUBLIC_IP="你的服务器IP"
    fi
    info "服务器公网IP: $PUBLIC_IP"
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
}

# 启动服务
start_service() {
    info "启动 V2Ray 服务..."
    systemctl enable $SERVICE_NAME
    systemctl restart $SERVICE_NAME
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        info "V2Ray 服务启动成功"
        
        # 检查端口监听
        if ss -tuln | grep -q ":$PORT "; then
            info "端口 $PORT 监听正常"
        else
            warn "端口 $PORT 未监听，请检查服务状态"
        fi
    else
        error "V2Ray 服务启动失败"
        journalctl -u $SERVICE_NAME -n 10 --no-pager
        exit 1
    fi
}

# 显示服务状态
show_status() {
    info "服务状态检查..."
    systemctl status $SERVICE_NAME --no-pager -l
    
    echo
    info "最近日志:"
    journalctl -u $SERVICE_NAME -n 5 --no-pager
}

# 主函数
main() {
    clear
    echo "=========================================="
    echo "    VLESS 服务部署脚本 (端口: $PORT)     "
    echo "=========================================="
    
    check_root
    check_system
    install_dependencies
    install_v2ray
    generate_config
    setup_firewall
    start_service
    get_public_ip
    generate_client_info
    show_status
    
    info "部署完成！"
    info "配置文件位置: $CONFIG_FILE"
    info "管理命令: systemctl [start|stop|restart|status] $SERVICE_NAME"
}

# 执行主函数
main "$@"
