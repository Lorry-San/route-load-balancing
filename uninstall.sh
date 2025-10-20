#!/bin/bash

#=============================================================================
# 拼好线 (PinHaoXian) 卸载脚本
# Multi-Line Load Balancer Uninstallation Script
# Author: Lorry-San
# GitHub: https://github.com/Lorry-San/route-load-balancing
#=============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 打印函数
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

# 打印banner
print_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              拼好线 (PinHaoXian) 卸载程序                      ║
║                  Uninstallation Script                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检查root权限
check_root() {
    if [ "$EUID" -eq 0 ]; then 
        USE_SUDO=true
        INSTALL_DIR="/usr/local/bin"
    else
        print_warning "当前不是root用户，将卸载用户安装的版本"
        USE_SUDO=false
        INSTALL_DIR="$HOME/bin"
    fi
}

# 确认卸载
confirm_uninstall() {
    echo ""
    print_warning "即将卸载拼好线负载均衡器"
    echo ""
    read -p "$(echo -e ${YELLOW}"确认要卸载吗？(y/N): "${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "取消卸载"
        exit 0
    fi
}

# 停止所有运行的实例
stop_all_instances() {
    print_info "正在停止所有运行的实例..."
    
    local stopped_count=0
    
    # 查找所有PID文件
    for pid_file in /tmp/loadbalancer_*.pid; do
        if [ -f "$pid_file" ]; then
            port=$(basename "$pid_file" | sed 's/loadbalancer_\([0-9]*\)\.pid/\1/')
            print_info "停止端口 $port 的服务..."
            
            if command -v bs2 &> /dev/null; then
                bs2 --stop -l "$port" 2>/dev/null || true
            else
                # 手动停止
                if [ -r "$pid_file" ]; then
                    pid=$(cat "$pid_file")
                    kill -TERM "$pid" 2>/dev/null || true
                    sleep 0.5
                    # 强制杀死
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
            
            stopped_count=$((stopped_count + 1))
        fi
    done
    
    if [ $stopped_count -gt 0 ]; then
        print_success "已停止 $stopped_count 个实例"
    else
        print_info "没有运行中的实例"
    fi
}

# 停止systemd服务
stop_systemd_services() {
    if [ "$USE_SUDO" = false ]; then
        return
    fi
    
    print_info "正在停止systemd服务..."
    
    local service_count=0
    
    # 查找所有loadbalancer服务
    for service in $(systemctl list-units --type=service --all | grep loadbalancer@ | awk '{print $1}'); do
        print_info "停止服务: $service"
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        service_count=$((service_count + 1))
    done
    
    if [ $service_count -gt 0 ]; then
        print_success "已停止 $service_count 个systemd服务"
    else
        print_info "没有systemd服务需要停止"
    fi
}

# 删除主程序
remove_main_program() {
    print_info "删除主程序..."
    
    if [ -f "$INSTALL_DIR/bs2" ]; then
        rm -f "$INSTALL_DIR/bs2"
        print_success "已删除: $INSTALL_DIR/bs2"
    else
        print_warning "主程序不存在: $INSTALL_DIR/bs2"
    fi
}

# 删除systemd服务文件
remove_systemd_files() {
    if [ "$USE_SUDO" = false ]; then
        return
    fi
    
    print_info "删除systemd服务文件..."
    
    if [ -f /etc/systemd/system/loadbalancer@.service ]; then
        rm -f /etc/systemd/system/loadbalancer@.service
        systemctl daemon-reload
        print_success "已删除systemd服务文件"
    else
        print_info "systemd服务文件不存在"
    fi
}

# 删除配置示例
remove_example_config() {
    print_info "删除示例配置..."
    
    if [ -d "$HOME/.pinhaoxian" ]; then
        rm -rf "$HOME/.pinhaoxian"
        print_success "已删除示例配置目录"
    fi
}

# 清理PID文件
clean_pid_files() {
    print_info "清理PID文件..."
    
    local cleaned=0
    for pid_file in /tmp/loadbalancer_*.pid; do
        if [ -f "$pid_file" ]; then
            rm -f "$pid_file"
            cleaned=$((cleaned + 1))
        fi
    done
    
    if [ $cleaned -gt 0 ]; then
        print_success "已清理 $cleaned 个PID文件"
    fi
}

# 询问是否删除日志
remove_logs() {
    echo ""
    read -p "$(echo -e ${YELLOW}"是否删除所有日志文件？(y/N): "${NC})" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "删除日志文件..."
        
        local log_count=0
        
        # 删除系统日志
        if [ "$USE_SUDO" = true ]; then
            for log_file in /var/log/loadbalancer_*.log*; do
                if [ -f "$log_file" ]; then
                    rm -f "$log_file"
                    log_count=$((log_count + 1))
                fi
            done
        fi
        
        # 删除用户日志
        if [ -d "$HOME/.local/log" ]; then
            for log_file in "$HOME/.local/log/loadbalancer"*.log*; do
                if [ -f "$log_file" ]; then
                    rm -f "$log_file"
                    log_count=$((log_count + 1))
                fi
            done
        fi
        
        if [ $log_count -gt 0 ]; then
            print_success "已删除 $log_count 个日志文件"
        else
            print_info "没有找到日志文件"
        fi
    else
        print_info "保留日志文件"
    fi
}

# 清理PATH配置
clean_path_config() {
    if [ "$USE_SUDO" = true ]; then
        return
    fi
    
    print_info "清理PATH配置..."
    
    # 检查常用的shell配置文件
    for rc_file in ~/.bashrc ~/.zshrc ~/.profile; do
        if [ -f "$rc_file" ]; then
            if grep -q "$INSTALL_DIR" "$rc_file"; then
                print_warning "检测到 $rc_file 中包含PATH配置"
                read -p "$(echo -e ${YELLOW}"是否删除？(y/N): "${NC})" -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    # 备份原文件
                    cp "$rc_file" "${rc_file}.bak.$(date +%Y%m%d%H%M%S)"
                    # 删除包含INSTALL_DIR的行
                    sed -i "\|$INSTALL_DIR|d" "$rc_file"
                    print_success "已从 $rc_file 中删除PATH配置（已备份）"
                fi
            fi
        fi
    done
}

# 显示卸载总结
show_summary() {
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                               ║${NC}"
    echo -e "${PURPLE}║   ${GREEN}拼好线已成功卸载！PinHaoXian Uninstalled!${PURPLE}              ║${NC}"
    echo -e "${PURPLE}║                                                               ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_info "已完成以下操作:"
    echo "  ✓ 停止所有运行的实例"
    echo "  ✓ 删除主程序"
    echo "  ✓ 清理PID文件"
    
    if [ "$USE_SUDO" = true ]; then
        echo "  ✓ 停止systemd服务"
        echo "  ✓ 删除systemd服务文件"
    fi
    
    echo ""
    print_info "感谢您使用拼好线！"
    print_info "如有问题或建议，欢迎访问："
    print_info "  https://github.com/Lorry-San/route-load-balancing"
    echo ""
}

# 主卸载流程
main() {
    print_banner
    check_root
    confirm_uninstall
    
    echo ""
    stop_all_instances
    stop_systemd_services
    remove_main_program
    remove_systemd_files
    remove_example_config
    clean_pid_files
    remove_logs
    clean_path_config
    
    show_summary
}

# 运行主程序
main "$@"
