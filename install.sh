#!/bin/bash

#=============================================================================
# 拼好线 (PinHaoXian) 一键安装脚本
# Multi-Line Load Balancer One-Click Installation Script
# Author: Lorry-San
# GitHub: https://github.com/Lorry-San/route-load-balancing
# License: MIT
#=============================================================================

set -e

# 版本信息
VERSION="1.0.0"
SCRIPT_NAME="bs2"
INSTALL_DIR="/usr/local/bin"
GITHUB_REPO="Lorry-San/route-load-balancing"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/main"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 打印 banner
print_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██████╗ ██╗███╗   ██╗██╗  ██╗ █████╗  ██████╗ ██╗  ██╗    ║
║   ██╔══██╗██║████╗  ██║██║  ██║██╔══██╗██╔═══██╗╚██╗██╔╝   ║
║   ██████╔╝██║██╔██╗ ██║███████║███████║██║   ██║ ╚███╔╝    ║
║   ██╔═══╝ ██║██║╚██╗██║██╔══██║██╔══██║██║   ██║ ██╔██╗    ║
║   ██║     ██║██║ ╚████║██║  ██║██║  ██║╚██████╔╝██╔╝ ██╗   ║
║   ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ║
║                                                               ║
║              拼好线 - 多线路负载均衡器                         ║
║          Multi-Line Load Balancer Installer                  ║
║                     Version: 1.0.0                            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查操作系统
check_os() {
    print_step "检测操作系统..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        print_info "操作系统: $PRETTY_NAME"
    else
        print_error "无法识别的操作系统"
        exit 1
    fi
}

# 检查是否为root用户
check_root() {
    print_step "检查用户权限..."
    
    if [ "$EUID" -ne 0 ]; then 
        print_warning "当前不是root用户"
        print_info "将尝试使用sudo安装到用户目录..."
        USE_SUDO=false
        INSTALL_DIR="$HOME/bin"
        mkdir -p "$INSTALL_DIR"
    else
        print_info "以root权限运行"
        USE_SUDO=true
    fi
}

# 检查Python版本
check_python() {
    print_step "检查Python环境..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
        
        print_info "发现Python版本: $PYTHON_VERSION"
        
        if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 6 ]); then
            print_error "需要Python 3.6或更高版本"
            print_info "正在尝试安装Python3..."
            install_python
        else
            print_success "Python版本满足要求"
        fi
    else
        print_warning "未找到Python3"
        install_python
    fi
}

# 安装Python
install_python() {
    print_step "安装Python3..."
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        if [ "$USE_SUDO" = true ]; then
            apt-get update
            apt-get install -y python3 python3-pip
        else
            print_error "需要root权限安装Python3"
            print_info "请运行: sudo apt-get install python3"
            exit 1
        fi
    elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
        if [ "$USE_SUDO" = true ]; then
            yum install -y python3 python3-pip
        else
            print_error "需要root权限安装Python3"
            print_info "请运行: sudo yum install python3"
            exit 1
        fi
    else
        print_error "不支持的系统类型: $OS"
        print_info "请手动安装Python 3.6+"
        exit 1
    fi
    
    print_success "Python3安装完成"
}

# 下载主程序
download_script() {
    print_step "下载拼好线主程序..."
    
    TEMP_FILE=$(mktemp)
    
    # 尝试从GitHub下载
    if curl -fsSL -o "$TEMP_FILE" "${GITHUB_RAW}/bs2.py"; then
        print_success "下载成功"
    elif wget -q -O "$TEMP_FILE" "${GITHUB_RAW}/bs2.py"; then
        print_success "下载成功"
    else
        print_error "下载失败"
        print_info "请检查网络连接或手动下载："
        print_info "  ${GITHUB_RAW}/bs2.py"
        rm -f "$TEMP_FILE"
        exit 1
    fi
    
    # 安装到目标目录
    if [ "$USE_SUDO" = true ]; then
        mv "$TEMP_FILE" "$INSTALL_DIR/$SCRIPT_NAME"
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    else
        mv "$TEMP_FILE" "$INSTALL_DIR/$SCRIPT_NAME"
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
        
        # 添加到PATH
        if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
            print_info "添加到PATH..."
            
            # 判断使用的shell
            if [ -n "$BASH_VERSION" ]; then
                SHELL_RC="$HOME/.bashrc"
            elif [ -n "$ZSH_VERSION" ]; then
                SHELL_RC="$HOME/.zshrc"
            else
                SHELL_RC="$HOME/.profile"
            fi
            
            if ! grep -q "export PATH.*$INSTALL_DIR" "$SHELL_RC" 2>/dev/null; then
                echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
                print_info "已添加到 $SHELL_RC"
                print_warning "请运行以下命令使PATH生效："
                print_warning "  source $SHELL_RC"
            fi
        fi
    fi
    
    print_success "程序已安装到: $INSTALL_DIR/$SCRIPT_NAME"
}

# 创建日志目录
create_log_dir() {
    print_step "创建日志目录..."
    
    if [ "$USE_SUDO" = true ]; then
        mkdir -p /var/log
        chmod 755 /var/log
        print_success "日志目录: /var/log/"
    else
        mkdir -p "$HOME/.local/log"
        print_success "日志目录: $HOME/.local/log/"
        print_warning "使用--log-file参数指定日志路径，例如："
        print_warning "  bs2 -l 40001 -t 40002 40003 -d --log-file ~/.local/log/lb.log"
    fi
}

# 创建systemd服务模板
create_systemd_template() {
    if [ "$USE_SUDO" = false ]; then
        print_warning "非root用户，跳过systemd服务创建"
        return
    fi
    
    print_step "创建systemd服务模板..."
    
    cat > /etc/systemd/system/loadbalancer@.service << 'EOF'
[Unit]
Description=PinHaoXian Load Balancer on port %i
After=network.target
Documentation=https://github.com/Lorry-San/route-load-balancing

[Service]
Type=forking
User=root
Group=root
ExecStart=/usr/local/bin/bs2 -l %i -t 40002 40003 40004 -d
ExecStop=/usr/local/bin/bs2 --stop -l %i
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/tmp/loadbalancer_%i.pid
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_success "systemd服务模板已创建"
}

# 创建示例配置
create_example_config() {
    print_step "创建示例配置..."
    
    EXAMPLE_DIR="$HOME/.pinhaoxian"
    mkdir -p "$EXAMPLE_DIR"
    
    cat > "$EXAMPLE_DIR/example.sh" << 'EOF'
#!/bin/bash
# 拼好线配置示例

# 示例1: 基础2线路配置
# bs2 -l 40001 -t 40002 40003 -d

# 示例2: 3线路，指定主线路
# bs2 -l 40001 -t 40002 40003 40004 --primary 2 -d

# 示例3: 6线路最大配置
# bs2 -l 40001 -t 40002 40003 40004 40005 40006 40007 -d

# 示例4: 只转发TCP
# bs2 -l 40001 -t 40002 40003 -p tcp -d

# 示例5: 按包大小分流
# bs2 -l 40001 -t 40002 40003 -m size -s 1024 -d

# 示例6: 完整地址配置
# bs2 -l 40001 -t 192.168.1.10:40002 192.168.1.11:40003 -d

# 示例7: 游戏服务器负载均衡
# bs2 -l 25565 -t game1.example.com:25565 game2.example.com:25565 -d

# 示例8: DNS负载均衡
# bs2 -l 53 -t 8.8.8.8:53 1.1.1.1:53 223.5.5.5:53 -p udp -d
EOF
    
    chmod +x "$EXAMPLE_DIR/example.sh"
    print_success "示例配置已创建: $EXAMPLE_DIR/example.sh"
}

# 测试安装
test_installation() {
    print_step "测试安装..."
    
    # 临时添加到PATH（如果未root）
    if [ "$USE_SUDO" = false ]; then
        export PATH="$INSTALL_DIR:$PATH"
    fi
    
    if command -v bs2 &> /dev/null; then
        VERSION_OUTPUT=$(bs2 -v 2>&1 || bs2 --version 2>&1)
        print_success "安装测试成功"
        print_info "版本信息: $VERSION_OUTPUT"
    else
        print_error "安装测试失败"
        print_info "请尝试重新运行安装脚本"
        exit 1
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                               ║${NC}"
    echo -e "${PURPLE}║   ${GREEN}拼好线安装成功！PinHaoXian Installed Successfully!${PURPLE}       ║${NC}"
    echo -e "${PURPLE}║                                                               ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$USE_SUDO" = false ]; then
        echo -e "${YELLOW}⚠️  注意: 请先运行以下命令使PATH生效:${NC}"
        if [ -n "$BASH_VERSION" ]; then
            echo -e "${CYAN}   source ~/.bashrc${NC}"
        elif [ -n "$ZSH_VERSION" ]; then
            echo -e "${CYAN}   source ~/.zshrc${NC}"
        else
            echo -e "${CYAN}   source ~/.profile${NC}"
        fi
        echo ""
    fi
    
    cat << 'EOF'
📚 快速开始 / Quick Start:

  1️⃣  查看帮助
      bs2 -h

  2️⃣  前台运行 (Foreground)
      bs2 -l 40001 -t 40002 40003

  3️⃣  后台运行 (Background)
      bs2 -l 40001 -t 40002 40003 -d

  4️⃣  查看状态 (Check Status)
      bs2 --status -l 40001

  5️⃣  停止服务 (Stop Service)
      bs2 --stop -l 40001

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 进阶使用 / Advanced Usage:

  • 3线路配置
    bs2 -l 40001 -t 40002 40003 40004 -d

  • 指定主线路（从第2条开始）
    bs2 -l 40001 -t 40002 40003 40004 --primary 2 -d

  • 只转发TCP
    bs2 -l 40001 -t 40002 40003 -p tcp -d

  • 按包大小分流
    bs2 -l 40001 -t 40002 40003 -m size -s 1024 -d

  • 不同主机配置
    bs2 -l 40001 -t 192.168.1.10:40002 192.168.1.11:40003 -d

EOF

    if [ "$USE_SUDO" = true ]; then
        cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 Systemd服务 / Systemd Service:

  • 启动服务 (Start)
    sudo systemctl start loadbalancer@40001

  • 停止服务 (Stop)
    sudo systemctl stop loadbalancer@40001

  • 开机自启 (Enable)
    sudo systemctl enable loadbalancer@40001

  • 查看状态 (Status)
    sudo systemctl status loadbalancer@40001

  • 查看日志 (Logs)
    sudo journalctl -u loadbalancer@40001 -f

EOF
    fi
    
    cat << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 日志位置 / Log Location:
EOF

    if [ "$USE_SUDO" = true ]; then
        echo "   /var/log/loadbalancer_<PORT>.log"
    else
        echo "   使用 --log-file 参数指定"
        echo "   例如: --log-file ~/.local/log/loadbalancer.log"
    fi

    cat << EOF

📖 完整文档 / Full Documentation:
   https://github.com/Lorry-San/route-load-balancing

🐛 问题反馈 / Issues:
   https://github.com/Lorry-San/route-load-balancing/issues

💬 讨论交流 / Discussions:
   https://github.com/Lorry-San/route-load-balancing/discussions

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

    echo -e "${GREEN}✅ 感谢使用拼好线！Thank you for using PinHaoXian!${NC}"
    echo ""
}

# 清理函数
cleanup() {
    print_info "清理临时文件..."
    # 清理可能存在的临时文件
    rm -f /tmp/bs2_install_*.tmp
}

# 错误处理
error_handler() {
    print_error "安装过程中发生错误"
    cleanup
    exit 1
}

# 设置错误处理
trap error_handler ERR
trap cleanup EXIT

# 主安装流程
main() {
    print_banner
    
    echo -e "${CYAN}开始安装拼好线 v${VERSION}...${NC}"
    echo ""
    
    check_os
    check_root
    check_python
    create_log_dir
    download_script
    create_systemd_template
    create_example_config
    test_installation
    
    echo ""
    print_success "安装完成！Installation Complete!"
    echo ""
    
    show_usage
}

# 运行主程序
main "$@"
