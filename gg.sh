#!/bin/bash
#===============================================
# GOST 多隧道管理脚本 v2.0
# 快捷命令: gg
#===============================================

# 配置路径
GOST_BIN="/usr/local/bin/gost"
CONF_DIR="/etc/gost"
TUNNEL_DIR="/etc/gost/tunnels"
SERVICE_PREFIX="gost-tun"
MANAGER_CMD="/usr/local/bin/gg"
GOST_VER="2.11.5"

# 颜色定义
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[0;34m'
N='\033[0m'

#===============================================
# 工具函数
#===============================================

msg_info()  { echo -e "${G}[✓]${N} $1"; }
msg_warn()  { echo -e "${Y}[!]${N} $1"; }
msg_error() { echo -e "${R}[✗]${N} $1"; }

pause() {
    echo ""
    read -rp "按回车键继续..."
}

init_env() {
    mkdir -p "$TUNNEL_DIR"
}

show_logo() {
    clear
    echo -e "${C}"
    echo '   ██████╗  ██████╗ ███████╗████████╗'
    echo '  ██╔════╝ ██╔═══██╗██╔════╝╚══██╔══╝'
    echo '  ██║  ███╗██║   ██║███████╗   ██║   '
    echo '  ██║   ██║██║   ██║╚════██║   ██║   '
    echo '  ╚██████╔╝╚██████╔╝███████║   ██║   '
    echo '   ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝   '
    echo -e "${N}"
    echo -e "${Y}     GOST 多隧道管理 v2.0  |  命令: gg${N}"
    echo ""
}

#===============================================
# GOST 安装
#===============================================

check_gost() {
    [[ -x "$GOST_BIN" ]]
}

install_gost() {
    if check_gost; then
        msg_info "GOST 已安装: $($GOST_BIN -V 2>&1 | head -1)"
        return 0
    fi

    msg_info "正在下载 GOST..."

    local arch
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
        i686)    arch="386" ;;
        *) msg_error "不支持的架构: $(uname -m)"; return 1 ;;
    esac

    local url="https://github.com/ginuerzh/gost/releases/download/v${GOST_VER}/gost-linux-${arch}-${GOST_VER}.gz"
    
    cd /tmp || return 1
    rm -f gost.gz gost 2>/dev/null

    if command -v wget &>/dev/null; then
        wget -q --show-progress -O gost.gz "$url" || { msg_error "下载失败"; return 1; }
    elif command -v curl &>/dev/null; then
        curl -L -o gost.gz "$url" || { msg_error "下载失败"; return 1; }
    else
        msg_error "请先安装 wget 或 curl"
        return 1
    fi

    gunzip -f gost.gz || { msg_error "解压失败"; return 1; }
    chmod +x gost
    mv -f gost "$GOST_BIN"

    msg_info "GOST 安装成功: $($GOST_BIN -V 2>&1 | head -1)"
}

install_cmd() {
    local script_path
    script_path="$(readlink -f "$0")"
    
    if [[ -f "$script_path" && "$script_path" != "$MANAGER_CMD" ]]; then
        cp -f "$script_path" "$MANAGER_CMD"
        chmod +x "$MANAGER_CMD"
    fi
}

#===============================================
# 隧道核心函数
#===============================================

svc_name() {
    echo "${SERVICE_PREFIX}-$1"
}

get_tunnels() {
    find "$TUNNEL_DIR" -maxdepth 1 -name "*.json" -printf "%f\n" 2>/dev/null | sed 's/\.json$//' | sort
}

tunnel_count() {
    get_tunnels | wc -l
}

running_count() {
    local count=0
    for t in $(get_tunnels); do
        systemctl is-active --quiet "$(svc_name "$t")" && ((count++))
    done
    echo "$count"
}

tunnel_exists() {
    [[ -f "$TUNNEL_DIR/$1.json" ]]
}

get_conf() {
    local name=$1 key=$2
    grep "\"$key\"" "$TUNNEL_DIR/$name.json" 2>/dev/null | sed 's/.*: *"\(.*\)".*/\1/'
}

tunnel_status() {
    if systemctl is-active --quiet "$(svc_name "$1")" 2>/dev/null; then
        echo -e "${G}运行中${N}"
    else
        echo -e "${R}已停止${N}"
    fi
}

create_service() {
    local name=$1 cmd=$2
    local svc
    svc=$(svc_name "$name")

    cat > "/etc/systemd/system/${svc}.service" <<EOF
[Unit]
Description=GOST Tunnel - $name
After=network.target

[Service]
Type=simple
ExecStart=$cmd
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$svc" &>/dev/null
}

remove_service() {
    local svc
    svc=$(svc_name "$1")
    systemctl stop "$svc" &>/dev/null
    systemctl disable "$svc" &>/dev/null
    rm -f "/etc/systemd/system/${svc}.service"
    systemctl daemon-reload
}

start_tunnel() {
    systemctl start "$(svc_name "$1")"
}

stop_tunnel() {
    systemctl stop "$(svc_name "$1")"
}

restart_tunnel() {
    systemctl restart "$(svc_name "$1")"
}

kill_port() {
    local port=$1
    if command -v fuser &>/dev/null; then
        fuser -k "${port}/tcp" &>/dev/null
        fuser -k "${port}/udp" &>/dev/null
    fi
    sleep 1
}

#===============================================
# 1. 添加隧道
#===============================================

menu_add() {
    show_logo
    echo -e "${G}══════════ 添加隧道 ══════════${N}"
    echo ""
    echo -e "  ${G}1.${N} 落地隧道 (SS服务端)"
    echo -e "  ${G}2.${N} 中转隧道 (端口转发)"
    echo ""
    echo -e "  ${N}0.${N} 返回"
    echo ""
    read -rp "请选择 [0-2]: " choice

    case $choice in
        1) add_landing ;;
        2) add_relay ;;
        0) return ;;
        *) msg_error "无效选项" ;;
    esac
}

add_landing() {
    echo ""
    echo -e "${C}>>> 添加落地隧道${N}"
    echo ""

    read -rp "隧道名称 [回车默认: ss-8443]: " name
    name=${name:-ss-8443}
    name=$(echo "$name" | tr ' ' '-')

    if tunnel_exists "$name"; then
        msg_warn "隧道 '$name' 已存在"
        read -rp "是否覆盖? [y/N]: " yn
        [[ ! "$yn" =~ ^[Yy]$ ]] && return
        remove_service "$name"
    fi

    read -rp "请设置监听端口 [回车默认: 8443]: " port
    port=${port:-8443}

    read -rp "请设置加密方式 [回车默认: chacha20-ietf-poly1305]: " method
    method=${method:-chacha20-ietf-poly1305}

    read -rp "请设置密码 [回车默认: Qwert1470]: " passwd
    passwd=${passwd:-Qwert1470}

    echo ""
    echo -e "${Y}请确认配置:${N}"
    echo "  名称: $name"
    echo "  端口: $port"
    echo "  加密: $method"
    echo "  密码: $passwd"
    echo ""
    read -rp "确认创建? [Y/n]: " yn
    [[ "$yn" =~ ^[Nn]$ ]] && return

    install_gost || return 1
    init_env

    kill_port "$port"

    cat > "$TUNNEL_DIR/$name.json" <<EOF
{
    "name": "$name",
    "type": "landing",
    "port": "$port",
    "method": "$method",
    "password": "$passwd"
}
EOF

    local cmd="$GOST_BIN -L=ss://${method}:${passwd}@:${port}"
    create_service "$name" "$cmd"

    start_tunnel "$name"
    sleep 2

    install_cmd

    if systemctl is-active --quiet "$(svc_name "$name")"; then
        echo ""
        echo -e "${G}════════════════════════════════════${N}"
        echo -e "${G}        ✓ 落地隧道创建成功!${N}"
        echo -e "${G}════════════════════════════════════${N}"
        echo -e "  名称: ${C}$name${N}"
        echo -e "  端口: ${C}$port${N}"
        echo -e "  加密: ${C}$method${N}"
        echo -e "  密码: ${C}$passwd${N}"
        echo -e "${G}════════════════════════════════════${N}"
    else
        msg_error "启动失败"
        systemctl status "$(svc_name "$name")" --no-pager
    fi
}

add_relay() {
    echo ""
    echo -e "${C}>>> 添加中转隧道${N}"
    echo ""

    read -rp "隧道名称 [回车默认: relay-51520]: " name
    name=${name:-relay-51520}
    name=$(echo "$name" | tr ' ' '-')

    if tunnel_exists "$name"; then
        msg_warn "隧道 '$name' 已存在"
        read -rp "是否覆盖? [y/N]: " yn
        [[ ! "$yn" =~ ^[Yy]$ ]] && return
        remove_service "$name"
    fi

    read -rp "请输入落地鸡 IP [必填]: " remote_ip
    if [[ -z "$remote_ip" ]]; then
        msg_error "IP 不能为空"
        return
    fi

    read -rp "请设置落地鸡端口 [回车默认: 8443]: " remote_port
    remote_port=${remote_port:-8443}

    read -rp "请设置本地监听端口 [回车默认: 51520]: " local_port
    local_port=${local_port:-51520}

    echo ""
    echo -e "${Y}请确认配置:${N}"
    echo "  名称: $name"
    echo "  本地端口: $local_port"
    echo "  目标: $remote_ip:$remote_port"
    echo ""
    read -rp "确认创建? [Y/n]: " yn
    [[ "$yn" =~ ^[Nn]$ ]] && return

    install_gost || return 1
    init_env

    msg_info "测试落地鸡连通性..."
    if timeout 3 bash -c "echo >/dev/tcp/$remote_ip/$remote_port" 2>/dev/null; then
        msg_info "连接正常"
    else
        msg_warn "无法连接，继续创建..."
    fi

    kill_port "$local_port"

    cat > "$TUNNEL_DIR/$name.json" <<EOF
{
    "name": "$name",
    "type": "relay",
    "local_port": "$local_port",
    "remote_ip": "$remote_ip",
    "remote_port": "$remote_port"
}
EOF

    local cmd="$GOST_BIN -L=tcp://:${local_port}/${remote_ip}:${remote_port} -L=udp://:${local_port}/${remote_ip}:${remote_port}"
    create_service "$name" "$cmd"

    start_tunnel "$name"
    sleep 2

    install_cmd

    if systemctl is-active --quiet "$(svc_name "$name")"; then
        echo ""
        echo -e "${G}════════════════════════════════════${N}"
        echo -e "${G}        ✓ 中转隧道创建成功!${N}"
        echo -e "${G}════════════════════════════════════${N}"
        echo -e "  名称: ${C}$name${N}"
        echo -e "  本地: ${C}0.0.0.0:$local_port${N}"
        echo -e "  目标: ${C}$remote_ip:$remote_port${N}"
        echo -e "${G}════════════════════════════════════${N}"
    else
        msg_error "启动失败"
        systemctl status "$(svc_name "$name")" --no-pager
    fi
}

#===============================================
# 2. 隧道列表
#===============================================

menu_list() {
    show_logo
    echo -e "${G}══════════ 隧道列表 ══════════${N}"
    echo ""

    local total
    total=$(tunnel_count)

    if [[ "$total" -eq 0 ]]; then
        echo -e "  ${Y}暂无隧道，请先添加${N}"
        echo ""
        return
    fi

    printf "  ${C}%-15s %-8s %-10s %-20s %s${N}\n" "名称" "类型" "状态" "本地地址" "目标"
    echo "  ────────────────────────────────────────────────────────────────"

    for t in $(get_tunnels); do
        local type status addr target
        type=$(get_conf "$t" "type")
        status=$(tunnel_status "$t")

        if [[ "$type" == "landing" ]]; then
            local port
            port=$(get_conf "$t" "port")
            addr="0.0.0.0:$port"
            target="-"
            printf "  %-15s %-8s %-20b %-20s %s\n" "$t" "落地" "$status" "$addr" "$target"
        else
            local lp rip rp
            lp=$(get_conf "$t" "local_port")
            rip=$(get_conf "$t" "remote_ip")
            rp=$(get_conf "$t" "remote_port")
            addr="0.0.0.0:$lp"
            target="$rip:$rp"
            printf "  %-15s %-8s %-20b %-20s %s\n" "$t" "中转" "$status" "$addr" "$target"
        fi
    done

    echo ""
}

#===============================================
# 3. 隧道管理
#===============================================

menu_manage() {
    show_logo
    echo -e "${B}══════════ 隧道管理 ══════════${N}"
    echo ""

    local total
    total=$(tunnel_count)

    if [[ "$total" -eq 0 ]]; then
        echo -e "  ${Y}暂无隧道${N}"
        return
    fi

    echo "选择要管理的隧道:"
    echo ""

    local i=1
    declare -a arr
    for t in $(get_tunnels); do
        local status
        status=$(tunnel_status "$t")
        echo -e "  ${G}$i.${N} $t [$status]"
        arr[$i]=$t
        ((i++))
    done

    echo ""
    echo -e "  ${N}0.${N} 返回"
    echo ""
    read -rp "请选择 [0-$((i-1))]: " choice

    [[ "$choice" == "0" ]] && return
    [[ -z "${arr[$choice]}" ]] && { msg_error "无效选项"; return; }

    local selected="${arr[$choice]}"
    manage_single "$selected"
}

manage_single() {
    local name=$1

    echo ""
    echo -e "管理隧道: ${C}$name${N}"
    echo ""
    echo -e "  ${G}1.${N} 启动"
    echo -e "  ${G}2.${N} 停止"
    echo -e "  ${G}3.${N} 重启"
    echo -e "  ${G}4.${N} 查看日志"
    echo -e "  ${G}5.${N} 查看配置"
    echo -e "  ${R}6.${N} 删除"
    echo ""
    echo -e "  ${N}0.${N} 返回"
    echo ""
    read -rp "请选择 [0-6]: " choice

    case $choice in
        1)
            start_tunnel "$name"
            sleep 1
            msg_info "已启动"
            ;;
        2)
            stop_tunnel "$name"
            msg_info "已停止"
            ;;
        3)
            restart_tunnel "$name"
            sleep 1
            msg_info "已重启"
            ;;
        4)
            echo ""
            echo -e "${C}═══ 日志 (Ctrl+C 退出) ═══${N}"
            journalctl -u "$(svc_name "$name")" -f --no-pager
            ;;
        5)
            echo ""
            echo -e "${C}═══ 配置 ═══${N}"
            cat "$TUNNEL_DIR/$name.json"
            echo ""
            echo -e "${C}═══ 服务状态 ═══${N}"
            systemctl status "$(svc_name "$name")" --no-pager
            ;;
        6)
            echo ""
            read -rp "确认删除 '$name'? [y/N]: " yn
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                remove_service "$name"
                rm -f "$TUNNEL_DIR/$name.json"
                msg_info "隧道 '$name' 已删除"
            fi
            ;;
        0) return ;;
        *) msg_error "无效选项" ;;
    esac
}

#===============================================
# 4. 批量操作
#===============================================

menu_batch() {
    show_logo
    echo -e "${B}══════════ 批量操作 ══════════${N}"
    echo ""

    local total
    total=$(tunnel_count)

    if [[ "$total" -eq 0 ]]; then
        echo -e "  ${Y}暂无隧道${N}"
        return
    fi

    echo -e "  ${G}1.${N} 启动全部"
    echo -e "  ${G}2.${N} 停止全部"
    echo -e "  ${G}3.${N} 重启全部"
    echo ""
    echo -e "  ${N}0.${N} 返回"
    echo ""
    read -rp "请选择 [0-3]: " choice

    case $choice in
        1)
            echo ""
            for t in $(get_tunnels); do
                start_tunnel "$t"
                echo -e "  ${G}[✓]${N} $t 已启动"
            done
            msg_info "全部启动完成"
            ;;
        2)
            echo ""
            for t in $(get_tunnels); do
                stop_tunnel "$t"
                echo -e "  ${G}[✓]${N} $t 已停止"
            done
            msg_info "全部停止完成"
            ;;
        3)
            echo ""
            for t in $(get_tunnels); do
                restart_tunnel "$t"
                echo -e "  ${G}[✓]${N} $t 已重启"
            done
            msg_info "全部重启完成"
            ;;
        0) return ;;
        *) msg_error "无效选项" ;;
    esac
}

#===============================================
# 9. 卸载
#===============================================

menu_uninstall() {
    show_logo
    echo -e "${R}══════════ 完全卸载 ══════════${N}"
    echo ""
    echo -e "${Y}将删除:${N}"
    echo "  • 所有隧道及服务"
    echo "  • GOST 程序"
    echo "  • 配置文件"
    echo "  • 快捷命令 gg"
    echo ""
    read -rp "确认卸载? [y/N]: " yn
    [[ ! "$yn" =~ ^[Yy]$ ]] && return

    echo ""

    for t in $(get_tunnels); do
        msg_info "删除隧道: $t"
        remove_service "$t"
        rm -f "$TUNNEL_DIR/$t.json"
    done

    systemctl stop gost &>/dev/null
    systemctl disable gost &>/dev/null
    rm -f /etc/systemd/system/gost.service

    rm -f "$GOST_BIN"
    rm -rf "$CONF_DIR"
    rm -f "$MANAGER_CMD"

    systemctl daemon-reload

    echo ""
    echo -e "${G}════════════════════════════════${N}"
    echo -e "${G}      ✓ GOST 已完全卸载${N}"
    echo -e "${G}════════════════════════════════${N}"
}

#===============================================
# 主菜单
#===============================================

main_menu() {
    while true; do
        show_logo

        local total running
        total=$(tunnel_count)
        running=$(running_count)

        if check_gost; then
            echo -e "  GOST: ${G}已安装${N} ($($GOST_BIN -V 2>&1 | grep -oP 'gost \K[0-9.]+'))"
        else
            echo -e "  GOST: ${Y}未安装${N}"
        fi
        echo -e "  隧道: ${G}$running${N} 运行 / ${C}$total${N} 总计"
        echo ""

        echo -e "${C}═══════════════ 主菜单 ═══════════════${N}"
        echo ""
        echo -e "  ${G}1.${N} 添加隧道"
        echo -e "  ${G}2.${N} 隧道列表"
        echo -e "  ${G}3.${N} 隧道管理"
        echo -e "  ${G}4.${N} 批量操作"
        echo ""
        echo -e "  ${R}9.${N} 完全卸载"
        echo -e "  ${N}0.${N} 退出"
        echo ""
        echo -e "${C}══════════════════════════════════════${N}"
        echo ""
        read -rp "请选择 [0-9]: " choice

        case $choice in
            1) menu_add; pause ;;
            2) menu_list; pause ;;
            3) menu_manage; pause ;;
            4) menu_batch; pause ;;
            9) menu_uninstall; exit 0 ;;
            0) echo ""; echo "再见!"; exit 0 ;;
            *) msg_error "无效选项"; sleep 1 ;;
        esac
    done
}

#===============================================
# 入口
#===============================================

if [[ $EUID -ne 0 ]]; then
    echo -e "${R}[✗]${N} 请使用 root 用户运行"
    exit 1
fi

init_env

main_menu
