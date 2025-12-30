#!/bin/bash
# VPS Monitor 一键安装脚本
# 适用于 Debian 11 系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        log_info "使用命令: sudo bash $0"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "debian" ]]; then
            log_warning "此脚本专为 Debian 11 设计，当前系统: $PRETTY_NAME"
            read -p "是否继续安装？(y/n): " continue_install
            if [[ "$continue_install" != "y" ]]; then
                exit 0
            fi
        fi
    fi
}

# 安装依赖
install_dependencies() {
    log_info "正在更新软件包列表..."
    apt update -qq
    
    log_info "正在安装依赖包..."
    apt install -y curl bc procps coreutils grep gawk > /dev/null 2>&1
    
    log_success "依赖安装完成"
}

# 下载监控脚本
download_script() {
    local install_dir="/opt/vps-monitor"
    
    log_info "创建安装目录: $install_dir"
    mkdir -p "$install_dir"
    
    log_info "下载监控脚本..."
    cat > "$install_dir/monitor.sh" << 'MONITOR_SCRIPT_EOF'
#!/bin/bash
# VPS Monitor Client - Shell Script Version
# 此处应包含完整的监控脚本内容
# 由于篇幅限制，安装时需要从上一个 artifact 复制完整脚本

# 请将上面的 "Shell 客户端监控脚本" 的完整内容粘贴到这里
MONITOR_SCRIPT_EOF
    
    chmod +x "$install_dir/monitor.sh"
    log_success "监控脚本已下载到 $install_dir/monitor.sh"
}

# 配置监控脚本
configure_script() {
    local install_dir="/opt/vps-monitor"
    local config_file="$install_dir/monitor.sh"
    
    echo ""
    echo "===================================================="
    echo "配置监控客户端"
    echo "===================================================="
    
    # 获取 API URL
    read -p "请输入 Cloudflare Workers API 地址: " api_url
    while [[ -z "$api_url" ]]; do
        log_error "API 地址不能为空"
        read -p "请输入 Cloudflare Workers API 地址: " api_url
    done
    
    # 获取服务器 ID
    local default_id="debian-vps-$(date +%s | tail -c 4)"
    read -p "请输入服务器唯一 ID [$default_id]: " server_id
    server_id=${server_id:-$default_id}
    
    # 获取服务器名称
    local hostname=$(hostname)
    read -p "请输入服务器名称 [$hostname]: " server_name
    server_name=${server_name:-$hostname}
    
    # 获取服务器位置
    read -p "请输入服务器位置 (如: Tokyo, Japan): " server_location
    server_location=${server_location:-"Unknown Location"}
    
    # 获取上报间隔
    read -p "请输入上报间隔（秒）[10]: " report_interval
    report_interval=${report_interval:-10}
    
    # 修改配置
    sed -i "s|API_URL=\".*\"|API_URL=\"$api_url\"|g" "$config_file"
    sed -i "s|SERVER_ID=\".*\"|SERVER_ID=\"$server_id\"|g" "$config_file"
    sed -i "s|SERVER_NAME=\".*\"|SERVER_NAME=\"$server_name\"|g" "$config_file"
    sed -i "s|SERVER_LOCATION=\".*\"|SERVER_LOCATION=\"$server_location\"|g" "$config_file"
    sed -i "s|REPORT_INTERVAL=.*|REPORT_INTERVAL=$report_interval|g" "$config_file"
    
    echo ""
    log_success "配置完成！"
    echo "服务器 ID: $server_id"
    echo "服务器名称: $server_name"
    echo "服务器位置: $server_location"
    echo "API 地址: $api_url"
    echo "上报间隔: $report_interval 秒"
}

# 创建 systemd 服务
create_service() {
    log_info "创建 systemd 服务..."
    
    cat > /etc/systemd/system/vps-monitor.service << 'EOF'
[Unit]
Description=VPS Monitor Client
Documentation=https://github.com/your-repo/vps-monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/vps-monitor
ExecStart=/bin/bash /opt/vps-monitor/monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_success "systemd 服务已创建"
}

# 启动服务
start_service() {
    echo ""
    read -p "是否立即启动监控服务？(y/n): " start_now
    
    if [[ "$start_now" == "y" ]]; then
        log_info "启动监控服务..."
        systemctl enable vps-monitor
        systemctl start vps-monitor
        
        sleep 2
        
        if systemctl is-active --quiet vps-monitor; then
            log_success "监控服务已成功启动！"
            echo ""
            log_info "查看服务状态: systemctl status vps-monitor"
            log_info "查看实时日志: journalctl -u vps-monitor -f"
            log_info "停止服务: systemctl stop vps-monitor"
            log_info "重启服务: systemctl restart vps-monitor"
        else
            log_error "服务启动失败，请检查日志: journalctl -u vps-monitor -n 50"
        fi
    else
        log_info "稍后可以使用以下命令启动服务:"
        echo "  systemctl enable vps-monitor"
        echo "  systemctl start vps-monitor"
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo "===================================================="
    echo "安装完成！"
    echo "===================================================="
    echo ""
    echo "📁 安装目录: /opt/vps-monitor"
    echo "📝 配置文件: /opt/vps-monitor/monitor.sh"
    echo "🔧 服务文件: /etc/systemd/system/vps-monitor.service"
    echo ""
    echo "常用命令:"
    echo "  启动服务: systemctl start vps-monitor"
    echo "  停止服务: systemctl stop vps-monitor"
    echo "  重启服务: systemctl restart vps-monitor"
    echo "  查看状态: systemctl status vps-monitor"
    echo "  查看日志: journalctl -u vps-monitor -f"
    echo "  编辑配置: nano /opt/vps-monitor/monitor.sh"
    echo ""
    echo "如需修改配置，请编辑脚本后重启服务:"
    echo "  nano /opt/vps-monitor/monitor.sh"
    echo "  systemctl restart vps-monitor"
    echo ""
    log_success "感谢使用 VPS Monitor！"
}

# 主函数
main() {
    echo "===================================================="
    echo "VPS Monitor 一键安装脚本"
    echo "适用于 Debian 11 系统"
    echo "===================================================="
    echo ""
    
    check_root
    check_system
    install_dependencies
    download_script
    configure_script
    create_service
    start_service
    show_completion
}

# 运行主函数
main
