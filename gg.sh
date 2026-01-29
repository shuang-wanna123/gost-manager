#!/bin/bash
#===============================================
# GOST 一键管理脚本 v1.0
# 快捷命令: gg
#===============================================

GOST_PATH="/usr/local/bin/gost"
GOST_SERVICE="/etc/systemd/system/gost.service"
GOST_CONFIG="/etc/gost/config.json"
GOST_VERSION="2.11.5"
MANAGER_PATH="/usr/local/bin/gg"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo -e "${YELLOW}      GOST 一键管理脚本 v1.1${NC}"
    echo -e "${YELLOW}      快捷命令: gg${NC}"
    echo ""
}

# 检查是否已安装
check_installed() {
    if [ -f "$GOST_SERVICE" ] && systemctl list-unit-files | grep -q "gost.service"; then
        return 0
    else
        return 1
    fi
}

# 获取当前模式
get_current_mode() {
    if [ -f "$GOST_CONFIG" ]; then
        grep '"mode"' "$GOST_CONFIG" 2>/dev/null | sed 's/.*: *"\(.*\)".*/\1/'
    fi
}

# 下载安装 gost
install_gost_binary() {
    if [ -f "$GOST_PATH" ]; then
        echo -e "${GREEN}[INFO]${NC} gost 已存在: $("$GOST_PATH" -V 2>&1 | head -n1)"
        return 0
    fi
    
    echo -e "${GREEN}[INFO]${NC} 开始下载 gost..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l)  ARCH="armv7" ;;
        i386|i686) ARCH="386" ;;
        *)       echo -e "${RED}[ERROR]${NC} 不支持的架构: $ARCH"; return 1 ;;
    esac
    
    DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${ARCH}-${GOST_VERSION}.gz"
    echo -e "${GREEN}[INFO]${NC} 下载地址: $DOWNLOAD_URL"
    
    cd /tmp
    rm -f gost.gz gost 2>/dev/null
    
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O gost.gz "$DOWNLOAD_URL"
    elif command -v curl &>/dev/null; then
        curl -L -o gost.gz "$DOWNLOAD_URL"
    else
        echo -e "${RED}[ERROR]${NC} 请先安装 wget 或 curl"
        return 1
    fi
    
    if [ $? -ne 0 ] || [ ! -f gost.gz ]; then
        echo -e "${RED}[ERROR]${NC} 下载失败"
        return 1
    fi
    
    gunzip -f gost.gz
    chmod +x gost
    mv gost "$GOST_PATH"
    
    echo -e "${GREEN}[INFO]${NC} gost 安装成功: $("$GOST_PATH" -V 2>&1 | head -n1)"
    return 0
}

# 清理端口
clean_port() {
    local PORT=$1
    echo -e "${GREEN}[INFO]${NC} 清理端口 ${PORT}..."
    
    systemctl stop gost 2>/dev/null
    
    for PID in $(pgrep -x gost 2>/dev/null); do
        kill -9 $PID 2>/dev/null
    done
    
    if command -v fuser &>/dev/null; then
        fuser -k ${PORT}/tcp 2>/dev/null
        fuser -k ${PORT}/udp 2>/dev/null
    fi
    
    sleep 1
}

# 创建服务
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

# 安装快捷命令
install_shortcut() {
    cp -f "$(readlink -f "$0")" "$MANAGER_PATH" 2>/dev/null || cat "$(readlink -f "$0")" > "$MANAGER_PATH"
    chmod +x "$MANAGER_PATH"
    echo -e "${GREEN}[INFO]${NC} 快捷命令已安装: ${YELLOW}gg${NC}"
}

# 安装落地鸡
install_landing() {
    print_logo
    echo -e "${GREEN}========== 安装落地鸡（SS服务端）==========${NC}"
    echo ""
    
    # 检查是否已安装
    if check_installed; then
        CURRENT_MODE=$(get_current_mode)
        echo -e "${YELLOW}[警告]${NC} 检测到已安装 GOST 服务"
        echo -e "       当前模式: ${CYAN}${CURRENT_MODE}${NC}"
        echo ""
        read -p "是否覆盖安装? [y/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[INFO]${NC} 已取消安装"
            return
        fi
        echo ""
    fi
    
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
        echo -e "${YELLOW}[INFO]${NC} 已取消安装"
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
    
    # 保存配置
    cat > "$GOST_CONFIG" << EOF
{
    "mode": "landing",
    "port": "${SS_PORT}",
    "method": "${SS_METHOD}",
    "password": "${SS_PASSWORD}"
}
EOF
    
    # 启动服务
    echo -e "${GREEN}[INFO]${NC} 启动服务..."
    systemctl start gost
    sleep 2
    
    # 安装快捷命令
    install_shortcut
    
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
        echo -e "  快捷命令: ${YELLOW}gg${NC}"
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
    
    # 检查是否已安装
    if check_installed; then
        CURRENT_MODE=$(get_current_mode)
        echo -e "${YELLOW}[警告]${NC} 检测到已安装 GOST 服务"
        echo -e "       当前模式: ${CYAN}${CURRENT_MODE}${NC}"
        echo ""
        read -p "是否覆盖安装? [y/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[INFO]${NC} 已取消安装"
            return
        fi
        echo ""
    fi
    
    # 交互输入
    read -p "请输入落地鸡IP [必填]: " REMOTE_IP
    if [ -z "$REMOTE_IP" ]; then
        echo -e "${RED}[ERROR]${NC} 落地鸡IP不能为空!"
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
        echo -e "${YELLOW}[INFO]${NC} 已取消安装"
        return
    fi
    
    echo ""
    
    # 安装 gost
    install_gost_binary || return 1
    
    # 测试落地鸡
    echo -e "${GREEN}[INFO]${NC} 测试落地鸡连通性..."
    if timeout 3 bash -c "echo >/dev/tcp/${REMOTE_IP}/${REMOTE_PORT}" 2>/dev/null; then
        echo -e "${GREEN}[INFO]${NC} 落地鸡连接正常"
    else
        echo -e "${YELLOW}[WARN]${NC} 无法连接落地鸡，请确认落地鸡已启动"
    fi
    
    # 清理端口
    clean_port $LOCAL_PORT
    
    # 创建服务
    EXEC_CMD="${GOST_PATH} -L=tcp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT} -L=udp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT}"
    create_service "$EXEC_CMD"
    
    # 保存配置
    cat > "$GOST_CONFIG" << EOF
{
    "mode": "relay",
    "local_port": "${LOCAL_PORT}",
    "remote_ip": "${REMOTE_IP}",
    "remote_port": "${REMOTE_PORT}"
}
EOF
    
    # 启动服务
    echo -e "${GREEN}[INFO]${NC} 启动服务..."
    systemctl start gost
    sleep 2
    
    # 安装快捷命令
    install_shortcut
    
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
        echo -e "  快捷命令: ${YELLOW}gg${NC}"
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
        echo -e "  安装状态: ${YELLOW}● 未安装${NC}"
        echo ""
        return
    fi
    
    # 服务状态
    if systemctl is-active --quiet gost; then
        echo -e "  服务状态: ${GREEN}● 运行中${NC}"
    else
        echo -e "  服务状态: ${RED}● 已停止${NC}"
    fi
    
    # 版本
    if [ -f "$GOST_PATH" ]; then
        echo -e "  GOST版本: ${CYAN}$("$GOST_PATH" -V 2>&1 | head -n1)${NC}"
    fi
    
    # 当前模式
    MODE=$(get_current_mode)
    echo -e "  当前模式: ${CYAN}${MODE:-未知}${NC}"
    
    # 配置详情
    echo ""
    echo -e "${YELLOW}配置详情:${NC}"
    if [ -f "$GOST_CONFIG" ]; then
        if [ "$MODE" = "landing" ]; then
            PORT=$(grep '"port"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
            METHOD=$(grep '"method"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
            PASS=$(grep '"password"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
            echo -e "  端口: ${CYAN}${PORT}${NC}"
            echo -e "  加密: ${CYAN}${METHOD}${NC}"
            echo -e "  密码: ${CYAN}${PASS}${NC}"
        elif [ "$MODE" = "relay" ]; then
            LOCAL=$(grep '"local_port"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
            REMOTE_IP=$(grep '"remote_ip"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
            REMOTE_PORT=$(grep '"remote_port"' "$GOST_CONFIG" | sed 's/.*: *"\(.*\)".*/\1/')
            echo -e "  本地端口: ${CYAN}${LOCAL}${NC}"
            echo -e "  落地鸡: ${CYAN}${REMOTE_IP}:${REMOTE_PORT}${NC}"
        fi
    fi
    
    # 监听端口
    echo ""
    echo -e "${YELLOW}监听端口:${NC}"
    PORTS=$(ss -tlnp 2>/dev/null | grep gost | awk '{print $4}')
    if [ -n "$PORTS" ]; then
        echo "$PORTS" | while read line; do
            echo -e "  ${CYAN}${line}${NC}"
        done
    else
        echo "  (无)"
    fi
    
    echo ""
    echo -e "${GREEN}====================================${NC}"
}

# 修改配置
modify_config() {
    print_logo
    echo -e "${GREEN}========== 修改 GOST 配置 ==========${NC}"
    echo ""
    
    if ! check_installed; then
        echo -e "${YELLOW}[WARN]${NC} GOST 未安装，请先安装"
        return
    fi
    
    MODE=$(get_current_mode)
    echo -e "当前模式: ${CYAN}${MODE}${NC}"
    echo ""
    
    if [ "$MODE" = "landing" ]; then
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
    else
        echo -e "${RED}[ERROR]${NC} 无法识别当前配置，请重新安装"
        return
    fi
    
    systemctl restart gost
    sleep 2
    
    if systemctl is-active --quiet gost; then
        echo ""
        echo -e "${GREEN}[INFO]${NC} 配置修改成功，服务已重启"
    else
        echo ""
        echo -e "${RED}[ERROR]${NC} 服务启动失败"
        systemctl status gost --no-pager
    fi
}

# 启动服务
start_service() {
    echo -e "${GREEN}[INFO]${NC} 启动 GOST 服务..."
    systemctl start gost
    sleep 2
    if systemctl is-active --quiet gost; then
        echo -e "${GREEN}[INFO]${NC} 启动成功"
    else
        echo -e "${RED}[ERROR]${NC} 启动失败"
        systemctl status gost --no-pager
    fi
}

# 停止服务
stop_service() {
    echo -e "${GREEN}[INFO]${NC} 停止 GOST 服务..."
    systemctl stop gost
    echo -e "${GREEN}[INFO]${NC} 服务已停止"
}

# 重启服务
restart_service() {
    echo -e "${GREEN}[INFO]${NC} 重启 GOST 服务..."
    systemctl restart gost
    sleep 2
    if systemctl is-active --quiet gost; then
        echo -e "${GREEN}[INFO]${NC} 重启成功"
    else
        echo -e "${RED}[ERROR]${NC} 重启失败"
        systemctl status gost --no-pager
    fi
}

# 查看日志
show_logs() {
    echo -e "${GREEN}[INFO]${NC} 显示实时日志 (Ctrl+C 退出)..."
    echo ""
    journalctl -u gost -f
}

# 卸载
uninstall() {
    print_logo
    echo -e "${RED}========== 卸载 GOST ==========${NC}"
    echo ""
    
    read -p "确认完全卸载 GOST? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[INFO]${NC} 已取消"
        return
    fi
    
    echo ""
    echo -e "${GREEN}[INFO]${NC} 停止服务..."
    systemctl stop gost 2>/dev/null
    systemctl disable gost 2>/dev/null
    
    echo -e "${GREEN}[INFO]${NC} 删除文件..."
    rm -f "$GOST_PATH"
    rm -f "$GOST_SERVICE"
    rm -rf /etc/gost
    rm -f "$MANAGER_PATH"
    
    systemctl daemon-reload
    
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}          ✓ GOST 已完全卸载${NC}"
    echo -e "${GREEN}============================================${NC}"
}

# 主菜单
main_menu() {
    while true; do
        print_logo
        
        # 状态显示
        if check_installed; then
            if systemctl is-active --quiet gost; then
                STATUS="${GREEN}● 运行中${NC}"
            else
                STATUS="${RED}● 已停止${NC}"
            fi
            MODE=$(get_current_mode)
            MODE_TEXT="(${MODE})"
        else
            STATUS="${YELLOW}● 未安装${NC}"
            MODE_TEXT=""
        fi
        
        echo -e "  当前状态: $STATUS ${CYAN}${MODE_TEXT}${NC}"
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
            0) echo ""; echo "再见!"; exit 0 ;;
            *) echo -e "${RED}[ERROR]${NC} 无效选项" ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# 入口
main_menu
