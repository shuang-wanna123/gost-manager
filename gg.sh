#!/bin/bash
#===============================================
# GOST 多隧道管理脚本 v2.0
# 快捷命令: gg
#===============================================

GOST_PATH="/usr/local/bin/gost"
GOST_CONF_DIR="/etc/gost"
GOST_TUNNEL_DIR="/etc/gost/tunnels"
GOST_VERSION="2.11.5"
MANAGER_PATH="/usr/local/bin/gg"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

#===============================================
# 基础函数
#===============================================

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
    echo -e "${YELLOW}    GOST 多隧道管理脚本 v2.0${NC}"
    echo -e "${YELLOW}    快捷命令: ${GREEN}gg${NC}"
    echo ""
}

press_any_key() {
    echo ""
    read -p "按回车键继续..."
}

# 检查 gost 是否安装
check_gost_installed() {
    [ -f "$GOST_PATH" ]
}

# 下载安装 gost
install_gost_binary() {
    if check_gost_installed; then
        echo -e "${GREEN}[✓]${NC} GOST 已安装: $("$GOST_PATH" -V 2>&1 | head -n1)"
        return 0
    fi
    
    echo -e "${GREEN}[*]${NC} 开始下载 GOST..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l)  ARCH="armv7" ;;
        i386|i686) ARCH="386" ;;
        *)       echo -e "${RED}[✗]${NC} 不支持的架构: $ARCH"; return 1 ;;
    esac
    
    DOWNLOAD_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${ARCH}-${GOST_VERSION}.gz"
    
    cd /tmp
    rm -f gost.gz gost 2>/dev/null
    
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O gost.gz "$DOWNLOAD_URL" || { echo -e "${RED}[✗]${NC} 下载失败"; return 1; }
    elif command -v curl &>/dev/null; then
        curl -L -o gost.gz "$DOWNLOAD_URL" || { echo -e "${RED}[✗]${NC} 下载失败"; return 1; }
    else
        echo -e "${RED}[✗]${NC} 请先安装 wget 或 curl"
        return 1
    fi
    
    gunzip -f gost.gz
    chmod +x gost
    mv gost "$GOST_PATH"
    
    echo -e "${GREEN}[✓]${NC} GOST 安装成功: $("$GOST_PATH" -V 2>&1 | head -n1)"
    return 0
}

# 初始化目录
init_dirs() {
    mkdir -p "$GOST_TUNNEL_DIR"
}

# 安装快捷命令
install_shortcut() {
    # 获取当前脚本的完整内容并写入
    if [ -f "$0" ]; then
        cat "$0" > "$MANAGER_PATH"
    else
        # 如果是通过管道执行的，从stdin读取
        return 1
    fi
    chmod +x "$MANAGER_PATH"
    
    # 创建软链接备用
    ln -sf "$MANAGER_PATH" /usr/bin/gg 2>/dev/null
    
    hash -r 2>/dev/null
}

#===============================================
# 隧道管理函数
#===============================================

# 获取所有隧道
get_all_tunnels() {
    ls "$GOST_TUNNEL_DIR"/*.json 2>/dev/null | xargs -I{} basename {} .json
}

# 获取隧道数量
get_tunnel_count() {
    ls "$GOST_TUNNEL_DIR"/*.json 2>/dev/null | wc -l
}

# 检查隧道是否存在
tunnel_exists() {
    [ -f "$GOST_TUNNEL_DIR/$1.json" ]
}

# 获取隧道服务名
get_service_name() {
    echo "gost-$1"
}

# 检查隧道服务状态
get_tunnel_status() {
    local name=$1
    local service=$(get_service_name "$name")
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
}

# 读取隧道配置
read_tunnel_config() {
    local name=$1
    local config_file="$GOST_TUNNEL_DIR/$name.json"
    if [ -f "$config_file" ]; then
        cat "$config_file"
    fi
}

# 创建隧道服务
create_tunnel_service() {
    local name=$1
    local exec_cmd=$2
    local service=$(get_service_name "$name")
    
    cat > "/etc/systemd/system/${service}.service" << EOF
[Unit]
Description=GOST Tunnel - $name
After=network.target

[Service]
Type=simple
ExecStart=$exec_cmd
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$service" 2>/dev/null
}

# 删除隧道服务
remove_tunnel_service() {
    local name=$1
    local service=$(get_service_name "$name")
    
    systemctl stop "$service" 2>/dev/null
    systemctl disable "$service" 2>/dev/null
    rm -f "/etc/systemd/system/${service}.service"
    systemctl daemon-reload
}

# 启动隧道
start_tunnel() {
    local name=$1
    local service=$(get_service_name "$name")
    systemctl start "$service"
}

# 停止隧道
stop_tunnel() {
    local name=$1
    local service=$(get_service_name "$name")
    systemctl stop "$service"
}

# 重启隧道
restart_tunnel() {
    local name=$1
    local service=$(get_service_name "$name")
    systemctl restart "$service"
}

# 清理端口占用
clean_port() {
    local port=$1
    if command -v fuser &>/dev/null; then
        fuser -k ${port}/tcp 2>/dev/null
        fuser -k ${port}/udp 2>/dev/null
    fi
    sleep 1
}

#===============================================
# 新增隧道
#===============================================

add_tunnel() {
    print_logo
    echo -e "${GREEN}============ 新增隧道 ============${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 落地隧道 (SS服务端)"
    echo -e "  ${GREEN}2.${NC} 中转隧道 (端口转发)"
    echo ""
    echo -e "  ${NC}0.${NC} 返回上级"
    echo ""
    read -p "请选择隧道类型 [0-2]: " TYPE
    
    case $TYPE in
        1) add_landing_tunnel ;;
        2) add_relay_tunnel ;;
        0) return ;;
        *) echo -e "${RED}[✗]${NC} 无效选项" ;;
    esac
}

# 新增落地隧道
add_landing_tunnel() {
    echo ""
    echo -e "${CYAN}>>> 新增落地隧道 (SS服务端)${NC}"
    echo ""
    
    # 输入隧道名称
    read -p "请输入隧道名称 [默认: landing1]: " TUNNEL_NAME
    TUNNEL_NAME=${TUNNEL_NAME:-landing1}
    
    # 检查是否已存在
    if tunnel_exists "$TUNNEL_NAME"; then
        echo -e "${YELLOW}[!]${NC} 隧道 '$TUNNEL_NAME' 已存在"
        read -p "是否覆盖? [y/N]: " CONFIRM
        [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && return
    fi
    
    read -p "请输入监听端口 [默认: 8443]: " SS_PORT
    SS_PORT=${SS_PORT:-8443}
    
    read -p "请输入加密方式 [默认: chacha20-ietf-poly1305]: " SS_METHOD
    SS_METHOD=${SS_METHOD:-chacha20-ietf-poly1305}
    
    read -p "请输入密码 [默认: Qwert1470]: " SS_PASSWORD
    SS_PASSWORD=${SS_PASSWORD:-Qwert1470}
    
    echo ""
    echo -e "${YELLOW}配置确认:${NC}"
    echo "  名称: $TUNNEL_NAME"
    echo "  类型: 落地隧道"
    echo "  端口: $SS_PORT"
    echo "  加密: $SS_METHOD"
    echo "  密码: $SS_PASSWORD"
    echo ""
    read -p "确认创建? [Y/n]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Nn]$ ]] && return
    
    # 安装 GOST
    install_gost_binary || return 1
    init_dirs
    
    # 清理端口
    clean_port $SS_PORT
    
    # 保存配置
    cat > "$GOST_TUNNEL_DIR/$TUNNEL_NAME.json" << EOF
{
    "name": "${TUNNEL_NAME}",
    "type": "landing",
    "port": "${SS_PORT}",
    "method": "${SS_METHOD}",
    "password": "${SS_PASSWORD}"
}
EOF
    
    # 创建服务
    EXEC_CMD="${GOST_PATH} -L=ss://${SS_METHOD}:${SS_PASSWORD}@:${SS_PORT}"
    create_tunnel_service "$TUNNEL_NAME" "$EXEC_CMD"
    
    # 启动服务
    start_tunnel "$TUNNEL_NAME"
    sleep 2
    
    # 安装快捷命令
    install_shortcut
    
    # 检查状态
    if systemctl is-active --quiet "$(get_service_name "$TUNNEL_NAME")"; then
        echo ""
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}          ✓ 落地隧道创建成功!${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        echo -e "  名称: ${CYAN}${TUNNEL_NAME}${NC}"
        echo -e "  端口: ${CYAN}${SS_PORT}${NC}"
        echo -e "  加密: ${CYAN}${SS_METHOD}${NC}"
        echo -e "  密码: ${CYAN}${SS_PASSWORD}${NC}"
        echo ""
        echo -e "${GREEN}============================================${NC}"
    else
        echo -e "${RED}[✗]${NC} 隧道启动失败"
        systemctl status "$(get_service_name "$TUNNEL_NAME")" --no-pager
    fi
}

# 新增中转隧道
add_relay_tunnel() {
    echo ""
    echo -e "${CYAN}>>> 新增中转隧道 (端口转发)${NC}"
    echo ""
    
    read -p "请输入隧道名称 [默认: relay1]: " TUNNEL_NAME
    TUNNEL_NAME=${TUNNEL_NAME:-relay1}
    
    if tunnel_exists "$TUNNEL_NAME"; then
        echo -e "${YELLOW}[!]${NC} 隧道 '$TUNNEL_NAME' 已存在"
        read -p "是否覆盖? [y/N]: " CONFIRM
        [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && return
    fi
    
    read -p "请输入落地鸡IP [必填]: " REMOTE_IP
    [ -z "$REMOTE_IP" ] && { echo -e "${RED}[✗]${NC} IP不能为空"; return; }
    
    read -p "请输入落地鸡端口 [默认: 8443]: " REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-8443}
    
    read -p "请输入本地监听端口 [默认: 51520]: " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-51520}
    
    echo ""
    echo -e "${YELLOW}配置确认:${NC}"
    echo "  名称: $TUNNEL_NAME"
    echo "  类型: 中转隧道"
    echo "  本地端口: $LOCAL_PORT"
    echo "  目标地址: $REMOTE_IP:$REMOTE_PORT"
    echo ""
    read -p "确认创建? [Y/n]: " CONFIRM
    [[ "$CONFIRM" =~ ^[Nn]$ ]] && return
    
    # 安装 GOST
    install_gost_binary || return 1
    init_dirs
    
    # 测试连通性
    echo -e "${GREEN}[*]${NC} 测试落地鸡连通性..."
    if timeout 3 bash -c "echo >/dev/tcp/${REMOTE_IP}/${REMOTE_PORT}" 2>/dev/null; then
        echo -e "${GREEN}[✓]${NC} 落地鸡连接正常"
    else
        echo -e "${YELLOW}[!]${NC} 无法连接落地鸡，继续创建..."
    fi
    
    # 清理端口
    clean_port $LOCAL_PORT
    
    # 保存配置
    cat > "$GOST_TUNNEL_DIR/$TUNNEL_NAME.json" << EOF
{
    "name": "${TUNNEL_NAME}",
    "type": "relay",
    "local_port": "${LOCAL_PORT}",
    "remote_ip": "${REMOTE_IP}",
    "remote_port": "${REMOTE_PORT}"
}
EOF
    
    # 创建服务
    EXEC_CMD="${GOST_PATH} -L=tcp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT} -L=udp://:${LOCAL_PORT}/${REMOTE_IP}:${REMOTE_PORT}"
    create_tunnel_service "$TUNNEL_NAME" "$EXEC_CMD"
    
    # 启动服务
    start_tunnel "$TUNNEL_NAME"
    sleep 2
    
    # 安装快捷命令
    install_shortcut
    
    # 检查状态
    if systemctl is-active --quiet "$(get_service_name "$TUNNEL_NAME")"; then
        echo ""
        echo -e "${GREEN}============================================${NC}"
        echo -e "${GREEN}          ✓ 中转隧道创建成功!${NC}"
        echo -e "${GREEN}============================================${NC}"
        echo ""
        echo -e "  名称: ${CYAN}${TUNNEL_NAME}${NC}"
        echo -e "  本地: ${CYAN}0.0.0.0:${LOCAL_PORT}${NC}"
        echo -e "  目标: ${CYAN}${REMOTE_IP}:${REMOTE_PORT}${NC}"
        echo ""
        echo -e "${GREEN}============================================${NC}"
    else
        echo -e "${RED}[✗]${NC} 隧道启动失败"
        systemctl status "$(get_service_name "$TUNNEL_NAME")" --no-pager
    fi
}

#===============================================
# 查看隧道列表
#===============================================

list_tunnels() {
    print_logo
    echo -e "${GREEN}============ 隧道列表 ============${NC}"
    echo ""
    
    if [ "$(get_tunnel_count)" -eq 0 ]; then
        echo -e "  ${YELLOW}暂无隧道${NC}"
        echo ""
        return
    fi
    
    printf "  ${CYAN}%-12s %-10s %-8s %-25s %s${NC}\n" "名称" "类型" "状态" "地址" "目标"
    echo "  ─────────────────────────────────────────────────────────────────────"
    
    for tunnel in $(get_all_tunnels); do
        CONFIG=$(read_tunnel_config "$tunnel")
        TYPE=$(echo "$CONFIG" | grep '"type"' | sed 's/.*: *"\(.*\)".*/\1/')
        STATUS=$(get_tunnel_status "$tunnel")
        
        if [ "$TYPE" = "landing" ]; then
            PORT=$(echo "$CONFIG" | grep '"port"' | sed 's/.*: *"\(.*\)".*/\1/')
            printf "  %-12s %-10s %-18b %-25s %s\n" "$tunnel" "落地" "$STATUS" "0.0.0.0:$PORT" "-"
        elif [ "$TYPE" = "relay" ]; then
            LOCAL=$(echo "$CONFIG" | grep '"local_port"' | sed 's/.*: *"\(.*\)".*/\1/')
            REMOTE_IP=$(echo "$CONFIG" | grep '"remote_ip"' | sed 's/.*: *"\(.*\)".*/\1/')
            REMOTE_PORT=$(echo "$CONFIG" | grep '"remote_port"' | sed 's/.*: *"\(.*\)".*/\1/')
            printf "  %-12s %-10s %-18b %-25s %s\n" "$tunnel" "中转" "$STATUS" "0.0.0.0:$LOCAL" "$REMOTE_IP:$REMOTE_PORT"
        fi
    done
    
    echo ""
}

#===============================================
# 删除隧道
#===============================================

delete_tunnel() {
    print_logo
    echo -e "${RED}============ 删除隧道 ============${NC}"
    echo ""
    
    if [ "$(get_tunnel_count)" -eq 0 ]; then
        echo -e "  ${YELLOW}暂无隧道可删除${NC}"
        return
    fi
    
    # 列出所有隧道
    echo "可删除的隧道:"
    echo ""
    i=1
    declare -a TUNNEL_ARRAY
    for tunnel in $(get_all_tunnels); do
        STATUS=$(get_tunnel_status "$tunnel")
        echo -e "  ${GREEN}$i.${NC} $tunnel [$STATUS]"
        TUNNEL_ARRAY[$i]=$tunnel
        ((i++))
    done
    echo ""
    echo -e "  ${NC}0.${NC} 返回"
    echo ""
    
    read -p "请选择要删除的隧道 [0-$((i-1))]: " CHOICE
    
    [ "$CHOICE" = "0" ] && return
    [ -z "${TUNNEL_ARRAY[$CHOICE]}" ] && { echo -e "${RED}[✗]${NC} 无效选项"; return; }
    
    TUNNEL_NAME="${TUNNEL_ARRAY[$CHOICE]}"
    
    echo ""
    read -p "确认删除隧道 '$TUNNEL_NAME'? [y/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && return
    
    # 删除服务和配置
    remove_tunnel_service "$TUNNEL_NAME"
    rm -f "$GOST_TUNNEL_DIR/$TUNNEL_NAME.json"
    
    echo ""
    echo -e "${GREEN}[✓]${NC} 隧道 '$TUNNEL_NAME' 已删除"
}

#===============================================
# 隧道操作
#===============================================

manage_tunnel() {
    print_logo
    echo -e "${BLUE}============ 隧道操作 ============${NC}"
    echo ""
    
    if [ "$(get_tunnel_count)" -eq 0 ]; then
        echo -e "  ${YELLOW}暂无隧道${NC}"
        return
    fi
    
    # 列出所有隧道
    echo "选择隧道:"
    echo ""
    i=1
    declare -a TUNNEL_ARRAY
    for tunnel in $(get_all_tunnels); do
        STATUS=$(get_tunnel_status "$tunnel")
        echo -e "  ${GREEN}$i.${NC} $tunnel [$STATUS]"
        TUNNEL_ARRAY[$i]=$tunnel
        ((i++))
    done
    echo ""
    echo -e "  ${NC}0.${NC} 返回"
    echo ""
    
    read -p "请选择隧道 [0-$((i-1))]: " CHOICE
    
    [ "$CHOICE" = "0" ] && return
    [ -z "${TUNNEL_ARRAY[$CHOICE]}" ] && { echo -e "${RED}[✗]${NC} 无效选项"; return; }
    
    TUNNEL_NAME="${TUNNEL_ARRAY[$CHOICE]}"
    
    echo ""
    echo -e "对 ${CYAN}$TUNNEL_NAME${NC} 执行操作:"
    echo ""
    echo -e "  ${GREEN}1.${NC} 启动"
    echo -e "  ${GREEN}2.${NC} 停止"
    echo -e "  ${GREEN}3.${NC} 重启"
    echo -e "  ${GREEN}4.${NC} 查看日志"
    echo -e "  ${GREEN}5.${NC} 查看详情"
    echo ""
    read -p "请选择 [1-5]: " ACTION
    
    case $ACTION in
        1)
            start_tunnel "$TUNNEL_NAME"
            echo -e "${GREEN}[✓]${NC} 隧道已启动"
            ;;
        2)
            stop_tunnel "$TUNNEL_NAME"
            echo -e "${GREEN}[✓]${NC} 隧道已停止"
            ;;
        3)
            restart_tunnel "$TUNNEL_NAME"
            echo -e "${GREEN}[✓]${NC} 隧道已重启"
            ;;
        4)
            echo ""
            echo -e "${CYAN}日志 (Ctrl+C 退出):${NC}"
            journalctl -u "$(get_service_name "$TUNNEL_NAME")" -f
            ;;
        5)
            echo ""
            echo -e "${CYAN}配置详情:${NC}"
            cat "$GOST_TUNNEL_DIR/$TUNNEL_NAME.json" | sed 's/^/  /'
            echo ""
            echo -e "${CYAN}服务状态:${NC}"
            systemctl status "$(get_service_name "$TUNNEL_NAME")" --no-pager | sed 's/^/  /'
            ;;
    esac
}

#===============================================
# 批量操作
#===============================================

start_all_tunnels() {
    echo -e "${GREEN}[*]${NC} 启动所有隧道..."
    for tunnel in $(get_all_tunnels); do
        start_tunnel "$tunnel"
        echo -e "  ${GREEN}[✓]${NC} $tunnel"
    done
    echo -e "${GREEN}[✓]${NC} 全部启动完成"
}

stop_all_tunnels() {
    echo -e "${GREEN}[*]${NC} 停止所有隧道..."
    for tunnel in $(get_all_tunnels); do
        stop_tunnel "$tunnel"
        echo -e "  ${GREEN}[✓]${NC} $tunnel"
    done
    echo -e "${GREEN}[✓]${NC} 全部停止完成"
}

restart_all_tunnels() {
    echo -e "${GREEN}[*]${NC} 重启所有隧道..."
    for tunnel in $(get_all_tunnels); do
        restart_tunnel "$tunnel"
        echo -e "  ${GREEN}[✓]${NC} $tunnel"
    done
    echo -e "${GREEN}[✓]${NC} 全部重启完成"
}

#===============================================
# 卸载
#===============================================

uninstall_all() {
    print_logo
    echo -e "${RED}============ 完全卸载 ============${NC}"
    echo ""
    
    echo -e "${YELLOW}将删除以下内容:${NC}"
    echo "  - 所有隧道配置和服务"
    echo "  - GOST 程序"
    echo "  - 快捷命令 gg"
    echo ""
    
    read -p "确认完全卸载? [y/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && return
    
    echo ""
    
    # 停止并删除所有隧道服务
    for tunnel in $(get_all_tunnels); do
        echo -e "${GREEN}[*]${NC} 删除隧道: $tunnel"
        remove_tunnel_service "$tunnel"
    done
    
    # 删除旧版单一服务（兼容）
    systemctl stop gost 2>/dev/null
    systemctl disable gost 2>/dev/null
    rm -f /etc/systemd/system/gost.service
    
    # 删除文件
    echo -e "${GREEN}[*]${NC} 删除文件..."
    rm -f "$GOST_PATH"
    rm -rf "$GOST_CONF_DIR"
    rm -f "$MANAGER_PATH"
    rm -f /usr/bin/gg
    
    systemctl daemon-reload
    
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}          ✓ GOST 已完全卸载${NC}"
    echo -e "${GREEN}============================================${NC}"
}

#===============================================
# 主菜单
#===============================================

main_menu() {
    while true; do
        print_logo
        
        # 状态统计
        TOTAL=$(get_tunnel_count)
        RUNNING=0
        for tunnel in $(get_all_tunnels); do
            systemctl is-active --quiet "$(get_service_name "$tunnel")" && ((RUNNING++))
        done
        
        echo -e "  隧道统计: ${GREEN}${RUNNING}${NC} 运行中 / ${CYAN}${TOTAL}${NC} 总计"
        echo ""
        echo -e "${CYAN}================== 主菜单 ==================${NC}"
        echo ""
        echo -e "  ${GREEN}1.${NC} 查看隧道"
        echo -e "  ${GREEN}2.${NC} 新增隧道"
        echo -e "  ${GREEN}3.${NC} 删除隧道"
        echo -e "  ${GREEN}4.${NC} 隧道操作 (启动/停止/重启/日志)"
        echo ""
        echo -e "  ${BLUE}5.${NC} 启动全部"
        echo -e "  ${BLUE}6.${NC} 停止全部"
        echo -e "  ${BLUE}7.${NC} 重启全部"
        echo ""
        echo -e "  ${RED}8.${NC} 完全卸载"
        echo ""
        echo -e "  ${NC}0.${NC} 退出"
        echo ""
        echo -e "${CYAN}==============================================${NC}"
        echo ""
        read -p "请选择 [0-8]: " CHOICE
        
        case $CHOICE in
            1) list_tunnels; press_any_key ;;
            2) add_tunnel; press_any_key ;;
            3) delete_tunnel; press_any_key ;;
            4) manage_tunnel; press_any_key ;;
            5) start_all_tunnels; press_any_key ;;
            6) stop_all_tunnels; press_any_key ;;
            7) restart_all_tunnels; press_any_key ;;
            8) uninstall_all; exit 0 ;;
            0) echo ""; echo "再见!"; exit 0 ;;
            *) echo -e "${RED}[✗]${NC} 无效选项"; sleep 1 ;;
        esac
    done
}

#===============================================
# 入口
#===============================================

# 初始化
init_dirs

# 启动菜单
main_menu
