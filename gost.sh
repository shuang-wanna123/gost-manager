#!/bin/bash
#===============================================
# GOST 一键管理脚本
# 支持: 安装/卸载/状态/修改配置
#===============================================

GOST_PATH="/usr/local/bin/gost"
GOST_SERVICE="/etc/systemd/system/gost.service"
GOST_CONFIG="/etc/gost/config.json"
GOST_VERSION="2.11.5"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 打印 Logo
print_logo() {
    clear
    echo -e "${CYAN}"
    echo "  ██████╗  ██████╗ ███████╗████████╗"
    echo " ██╔════╝ ██╔═══██╗██╔════╝╚══██╔══╝"
    echo " ██║  ███╗██║   ██║███████╗   ██║   "
    echo " ██║   ██║██║   ██║╚════██║   ██║   "
    echo " ╚██████╔╝╚██████╔╝███████║   ██║   "
    echo "  ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝   "
    echo -e "${NC}"
    echo -e "${YELLOW}      GOST 一键管理脚本 v1.0${NC}"
    echo ""
}

# 检查是否安装
check_installed() {
    if [ -f "$GOST_PATH" ] && [ -f "$GOST_SERVICE" ]; then
        return 0
    else
        return 1
    fi
}

# 获取当前配置
get_current_config() {
    if [ -f "$GOST_SERVICE" ]; then
        CURRENT_CMD=$(grep "ExecStart=" "$GOST_SERVICE" | sed 's/ExecStart=//')
        echo "$CURRENT_CMD"
    fi
}

# 下载安装 gost
install_gost_binary() {
    if [ -f "$GOST_PATH" ]; then
        print_info "gost 已存在: $("$GOST_PATH" -V 2>&1 | head -n1)"
        return 0
    fi
    
    print_info "开始下载 gost..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l)  ARCH="armv7" ;;
        i386|i686) ARCH="386" ;;
        *)       print_error "不支持的架构: $ARCH"; return 1 ;;
    esac
    
    DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${ARCH}-${GOST_VERSION}.gz"
    print_info "下载地址: $DOWNLOAD_URL"
    
    cd /tmp
    rm -f gost.gz gost
    
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O gost.gz "$DOWNLOAD_URL"
    elif command -v curl &>/dev/null; then
        curl -L -o gost.gz "$DOWNLOAD_URL"
    else
        print_error "请先安装 wget 或 curl"
        return 1
    fi
    
    if [ $? -ne 0 ] || [ ! -f gost.gz ]; then
        print_error "下载失败"
        return 1
    fi
    
    gunzip -f gost.gz
    chmod +x gost
    mv gost "$GOST_PATH"
    
    print_info "gost 安装成功: $("$GOST_PATH" -V 2>&1 | head -n1)"
    return 0
}

# 清理端口占用
clean_port() {
    local PORT=$1
    print_info "清理端口 ${PORT}..."
    
    # 停止 gost 服务
    systemctl stop gost 2>/dev/null
    
    # 杀掉 gost 进程
    for PID in $(pgrep -x gost 2>/dev/null); do
        kill -9 $PID 2>/dev/null
    done
    
    # 清理端口
    if command -v fuser &>/dev/null; then
        fuser -k ${PORT}/tcp 2>/dev/null
        fuser -k ${PORT}/udp 2>/dev/null
    fi
    
    sleep 1
}

# 创建 systemd 服务
create_service() {
    local EXEC_CMD=$1
    
    mkdir -p /etc/gost
    
    cat > "$GOST_SERVICE" << EOF
[Unit]
Description=GOST Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=${EXEC_CMD}
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable gost 2>/dev/null
}

# 安装落地鸡
install_landing() {
    print_logo
    echo -e "${GREEN}========== 安装落地鸡（SS服务端）==========${NC}"
    echo ""
    
    # 交互输入
    read -p "请输入监听端口 [默认: 8443]: " INPUT_PORT
    SS_PORT=${INPUT_PORT:-8443}
    
    read -p "请输入加密方式 [默认: chacha20-ietf-poly1305]: " INPUT_METHOD
    SS_METHOD=${INPUT_METHOD:-chacha20-ietf-poly1305}
    
    read -p "请输入密码 [默认: Qwert1470]: " INPUT_PASS
    SS_PASSWORD=${INPUT_PASS:-Qwert1470}
    
    echo ""
    echo -e "${YELLOW}配置确认:${NC}"
    echo "  端口: $SS_PORT"
    echo "  加密: $SS_METHOD"
    echo "  密码: $SS_PASSWORD"
    echo ""
    read -p "确认安装? [Y/n]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        print_warn "已取消安装"
        return
    fi
    
    echo ""
    
    # 安装 gost
    install_gost_binary || return 1
    
    # 清理端口
    clean_port $SS_PORT
    
    # 创建服务
    EXEC_CMD="${GOST_PATH} -L=ss://${SS_METHOD}:${SS_PASSWORD}@:${SS_PORT}"
    create_service "$EXEC_CMD"
    
    # 保存配置信息
    cat > "$GOST_CONFIG" << EOF
{
    "mode": "landing",
    "port": "${SS_PORT}",
    "method": "${SS_METHOD}",
    "password": "${SS_PASSWORD}"
}
EOF
    
    # 启动服务
    print_info "启动服务..."
    systemctl start gost
    sleep 2
    
    # 检查状态
    if systemctl is-active --quiet gost; then
        echo ""
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}          ✓ 落地鸡安装成功!${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        echo -e "  模式: ${CYAN}落地鸡 (SS服务端)${NC}"
        echo -e "  端口: ${CYAN}${SS_PORT}${NC}"
        echo -e "  加密: ${CYAN}${SS_METHOD}${NC}"
        echo -e "  密码: ${CYAN}${SS_PASSWORD}${NC}"
        echo ""
        echo -e "  管理命令: ${YELLOW}gost${NC}"
        echo ""
        echo -e "${GREEN}============================================${NC}"
    else
        echo ""
        echo -e "${RED}============================================${NC}"
        echo -e "${RED}          ✗ 安装失败!${NC}"
        echo -e "${RED}============================================${NC}"
        systemctl status gost --no-pager -l
    fi
}

# 安装中转鸡
install_relay() {
    print_logo
    echo -e "${GREEN}========== 安装中转鸡（端口转发）==========${NC}"
    echo ""
    
    # 交互输入
    read -p "请输入落地鸡IP [必填]: " REMOTE_IP
    if [ -z "$REMOTE_IP" ]; then
        print_error "落地鸡IP不能为空!"
        return 1
    fi
    
    read -p "请输入落地鸡端口 [默认: 8443]: " INPUT_REMOTE_PORT
    REMOTE_PORT=${INPUT_REMOTE_PORT:-8443}
    
    read -p "请输入本地监听端口 [默认: 51520]: " INPUT_LOCAL_PORT
    LOCAL_PORT=${INPUT_LOCAL_PORT:-51520}
    
    echo ""
    echo -e "${YELLOW}配置确认:${NC}"
    echo "  本地监听端口: $LOCAL_PORT"
    echo "  落地鸡地址: $REMOTE_IP:$REMOTE_PORT"
    echo ""
    read -p "确认安装? [Y/n]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        print_warn "已取消安装"
        return
    fi
    
    echo ""
    
    # 安装 gost
    install_gost_binary || return 1
    
    # 测试落地鸡连通性
    print_info "测试落地鸡连通性..."
    if timeout 3 bash -c "echo >/dev/tcp/${REMOTE_IP}/${REMOTE_PORT}" 2>/dev/null; then
        print_info "落地鸡连接正常"
    else
        print_warn "无法连接落地鸡，请确认落地鸡已启动"
    fi
    
    # 清理端口
    clean_port $LOCAL_PORT
    
    # 创建服务
    EXEC_CMD="${GOST_PATH} -L=tcp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT} -L=udp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT}"
    create_service "$EXEC_CMD"
    
    # 保存配置信息
    cat > "$GOST_CONFIG" << EOF
{
    "mode": "relay",
    "local_port": "${LOCAL_PORT}",
    "remote_ip": "${REMOTE_IP}",
    "remote_port": "${REMOTE_PORT}"
}
EOF
    
    # 启动服务
    print_info "启动服务..."
    systemctl start gost
    sleep 2
    
    # 检查状态
    if systemctl is-active --quiet gost; then
        echo ""
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}          ✓ 中转鸡安装成功!${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        echo -e "  模式: ${CYAN}中转鸡 (端口转发)${NC}"
        echo -e "  本地监听: ${CYAN}0.0.0.0:${LOCAL_PORT}${NC} (TCP+UDP)"
        echo -e "  转发目标: ${CYAN}${REMOTE_IP}:${REMOTE_PORT}${NC}"
        echo ""
        echo -e "  管理命令: ${YELLOW}gost${NC}"
        echo ""
        echo -e "${GREEN}============================================${NC}"
    else
        echo ""
        echo -e "${RED}============================================${NC}"
        echo -e "${RED}          ✗ 安装失败!${NC}"
        echo -e "${RED}============================================${NC}"
        systemctl status gost --no-pager -l
    fi
}

# 查看状态
show_status() {
    print_logo
    echo -e "${GREEN}========== GOST 运行状态 ==========${NC}"
    echo ""
    
    if ! check_installed; then
        print_warn "GOST 未安装"
        return
    fi
    
    # 服务状态
    if systemctl is-active --quiet gost; then
        echo -e "  服务状态: ${GREEN}● 运行中${NC}"
    else
        echo -e "  服务状态: ${RED}● 已停止${NC}"
    fi
    
    # 版本信息
    echo -e "  GOST版本: ${CYAN}$("$GOST_PATH" -V 2>&1 | head -n1)${NC}"
    
    # 当前配置
    echo ""
    echo -e "${YELLOW}当前配置:${NC}"
    if [ -f "$GOST_CONFIG" ]; then
        cat "$GOST_CONFIG" | grep -v "^[{}]" | sed 's/[",]//g' | sed 's/^/  /'
    fi
    
    # 启动命令
    echo ""
    echo -e "${YELLOW}启动命令:${NC}"
    get_current_config | sed 's/^/  /'
    
    # 监听端口
    echo ""
    echo -e "${YELLOW}监听端口:${NC}"
    ss -tlnp 2>/dev/null | grep gost | awk '{print "  " $4}' || echo "  (无)"
    
    echo ""
    echo -e "${GREEN}====================================${NC}"
}

# 修改配置
modify_config() {
    print_logo
    echo -e "${GREEN}========== 修改 GOST 配置 ==========${NC}"
    echo ""
    
    if ! check_installed; then
        print_warn "GOST 未安装，请先安装"
        return
    fi
    
    # 读取当前配置
    if [ -f "$GOST_CONFIG" ]; then
        MODE=$(grep '"mode"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
    else
        print_warn "配置文件不存在，请重新安装"
        return
    fi
    
    echo -e "当前模式: ${CYAN}${MODE}${NC}"
    echo ""
    
    if [ "$MODE" = "landing" ]; then
        # 落地鸡配置修改
        CURRENT_PORT=$(grep '"port"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
        CURRENT_METHOD=$(grep '"method"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
        CURRENT_PASS=$(grep '"password"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
        
        echo "当前端口: $CURRENT_PORT"
        echo "当前加密: $CURRENT_METHOD"
        echo "当前密码: $CURRENT_PASS"
        echo ""
        
        read -p "新端口 [回车保持不变]: " NEW_PORT
        read -p "新加密 [回车保持不变]: " NEW_METHOD
        read -p "新密码 [回车保持不变]: " NEW_PASS
        
        SS_PORT=${NEW_PORT:-$CURRENT_PORT}
        SS_METHOD=${NEW_METHOD:-$CURRENT_METHOD}
        SS_PASSWORD=${NEW_PASS:-$CURRENT_PASS}
        
        clean_port $SS_PORT
        
        EXEC_CMD="${GOST_PATH} -L=ss://${SS_METHOD}:${SS_PASSWORD}@:${SS_PORT}"
        create_service "$EXEC_CMD"
        
        cat > "$GOST_CONFIG" << EOF
{
    "mode": "landing",
    "port": "${SS_PORT}",
    "method": "${SS_METHOD}",
    "password": "${SS_PASSWORD}"
}
EOF
        
    elif [ "$MODE" = "relay" ]; then
        # 中转鸡配置修改
        CURRENT_LOCAL=$(grep '"local_port"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
        CURRENT_REMOTE_IP=$(grep '"remote_ip"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
        CURRENT_REMOTE_PORT=$(grep '"remote_port"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
        
        echo "当前本地端口: $CURRENT_LOCAL"
        echo "当前落地鸡IP: $CURRENT_REMOTE_IP"
        echo "当前落地鸡端口: $CURRENT_REMOTE_PORT"
        echo ""
        
        read -p "新本地端口 [回车保持不变]: " NEW_LOCAL
        read -p "新落地鸡IP [回车保持不变]: " NEW_REMOTE_IP
        read -p "新落地鸡端口 [回车保持不变]: " NEW_REMOTE_PORT
        
        LOCAL_PORT=${NEW_LOCAL:-$CURRENT_LOCAL}
        REMOTE_IP=${NEW_REMOTE_IP:-$CURRENT_REMOTE_IP}
        REMOTE_PORT=${NEW_REMOTE_PORT:-$CURRENT_REMOTE_PORT}
        
        clean_port $LOCAL_PORT
        
        EXEC_CMD="${GOST_PATH} -L=tcp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT} -L=udp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT}"
        create_service "$EXEC_CMD"
        
        cat > "$GOST_CONFIG" << EOF
{
    "mode": "relay",
    "local_port": "${LOCAL_PORT}",
    "remote_ip": "${REMOTE_IP}",
    "remote_port": "${REMOTE_PORT}"
}
EOF
    fi
    
    systemctl restart gost
    sleep 2
    
    if systemctl is-active --quiet gost; then
        print_info "配置修改成功，服务已重启"
    else
        print_error "服务启动失败"
        systemctl status gost --no-pager
    fi
}

# 重启服务
restart_service() {
    print_info "重启 GOST 服务..."
    systemctl restart gost
    sleep 2
    if systemctl is-active --quiet gost; then
        print_info "重启成功"
    else
        print_error "重启失败"
        systemctl status gost --no-pager
    fi
}

# 停止服务
stop_service() {
    print_info "停止 GOST 服务..."
    systemctl stop gost
    print_info "服务已停止"
}

# 启动服务
start_service() {
    print_info "启动 GOST 服务..."
    systemctl start gost
    sleep 2
    if systemctl is-active --quiet gost; then
        print_info "启动成功"
    else
        print_error "启动失败"
        systemctl status gost --no-pager
    fi
}

# 查看日志
show_logs() {
    echo -e "${GREEN}[INFO]${NC} 显示最近日志 (Ctrl+C 退出)..."
    journalctl -u gost -f
}

# 卸载
uninstall() {
    print_logo
    echo -e "${RED}========== 卸载 GOST ==========${NC}"
    echo ""
    
    read -p "确认卸载 GOST? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        print_warn "已取消"
        return
    fi
    
    print_info "停止服务..."
    systemctl stop gost 2>/dev/null
    systemctl disable gost 2>/dev/null
    
    print_info "删除文件..."
    rm -f "$GOST_PATH"
    rm -f "$GOST_SERVICE"
    rm -rf /etc/gost
    rm -f /usr/local/bin/gost-manager
    
    systemctl daemon-reload
    
    # 删除快捷命令
    sed -i '/alias gost=/d' ~/.bashrc 2>/dev/null
    
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}          ✓ GOST 已完全卸载${NC}"
    echo -e "${GREEN}============================================${NC}"
}

# 安装快捷命令
install_shortcut() {
    # 保存当前脚本到系统目录
    SCRIPT_PATH="/usr/local/bin/gost-manager"
    
    # 如果当前脚本不在系统目录，复制过去
    if [ "$(readlink -f "$0")" != "$SCRIPT_PATH" ]; then
        cp -f "$0" "$SCRIPT_PATH" 2>/dev/null || cat "$0" > "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
    fi
    
    # 创建 gost 快捷命令
    ln -sf "$SCRIPT_PATH" /usr/local/bin/g 2>/dev/null
    
    # 添加别名
    if ! grep -q "alias gost=" ~/.bashrc 2>/dev/null; then
        echo "alias gost='$SCRIPT_PATH'" >> ~/.bashrc
    fi
}

# 主菜单
main_menu() {
    while true; do
        print_logo
        
        # 检查状态
        if check_installed; then
            if systemctl is-active --quiet gost; then
                STATUS="${GREEN}● 运行中${NC}"
            else
                STATUS="${RED}● 已停止${NC}"
            fi
        else
            STATUS="${YELLOW}● 未安装${NC}"
        fi
        
        echo -e "  当前状态: $STATUS"
        echo ""
        echo -e "${CYAN}==================== 菜单 ====================${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 安装 - 落地鸡 (SS服务端)"
        echo -e "  ${GREEN}2.${NC} 安装 - 中转鸡 (端口转发)"
        echo ""
        echo -e "  ${BLUE}3.${NC} 查看状态"
        echo -e "  ${BLUE}4.${NC} 修改配置"
        echo -e "  ${BLUE}5.${NC} 查看日志"
        echo ""
        echo -e "  ${YELLOW}6.${NC} 启动服务"
        echo -e "  ${YELLOW}7.${NC} 停止服务"
        echo -e "  ${YELLOW}8.${NC} 重启服务"
        echo ""
        echo -e "  ${RED}9.${NC} 卸载 GOST"
        echo ""
        echo -e "  ${NC}0.${NC} 退出"
        echo ""
        echo -e "${CYAN}===============================================${NC}"
        echo ""
        read -p "请选择 [0-9]: " CHOICE
        
        case $CHOICE in
            1) install_landing ;;
            2) install_relay ;;
            3) show_status ;;
            4) modify_config ;;
            5) show_logs ;;
            6) start_service ;;
            7) stop_service ;;
            8) restart_service ;;
            9) uninstall ;;
            0) echo "再见!"; exit 0 ;;
            *) print_error "无效选项" ;;
        esac
        
        echo ""
        read -p "按回车键继续..." 
    done
}

# 命令行参数处理
case "$1" in
    status|s)
        show_status
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart|r)
        restart_service
        ;;
    log|logs|l)
        show_logs
        ;;
    uninstall)
        uninstall
        ;;
    landing)
        install_landing
        install_shortcut
        ;;
    relay)
        install_relay
        install_shortcut
        ;;
    *)
        install_shortcut
        main_menu
        ;;
esac
