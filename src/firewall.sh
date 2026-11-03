#!/bin/bash

# ufw 防火墙: 只放行 sing-box 配置实际使用的端口
# 开启 ufw 前一定先放行 SSH 端口, 避免断开 SSH
# 仅支持 ufw (Ubuntu / Debian), 没有 ufw 的系统直接跳过

fw_ok() {
    [[ $(type -P ufw) ]]
}

# ssh ports from: sshd config, listening sshd, current ssh session
fw_ssh_ports() {
    {
        sshd -T 2>/dev/null | awk '$1 == "port" {print $2}'
        ss -tlnpH 2>/dev/null | grep '"sshd"' | awk '{print $4}' | sed 's/.*://'
        [[ $SSH_CONNECTION ]] && awk '{print $4}' <<<"$SSH_CONNECTION"
    } | grep -E '^[0-9]+$' | sort -nu
}

# enable ufw if inactive (allow ssh first)
fw_enable() {
    fw_ok || return 1
    [[ $(ufw status | grep -i '^Status: active') ]] && return
    local p is_ssh_ports=$(fw_ssh_ports)
    [[ ! $is_ssh_ports ]] && {
        warn "无法识别 SSH 端口, 为避免断开 SSH, 未开启 ufw 防火墙.\n请手动执行: ufw allow <SSH端口>/tcp && ufw enable"
        return 1
    }
    for p in $is_ssh_ports; do
        ufw allow $p/tcp comment ssh >/dev/null
    done
    ufw --force enable >/dev/null && msg "\n已开启 ufw 防火墙, 已放行 SSH 端口: $(echo $is_ssh_ports)\n"
}

# port protocols of a config file: tcp / udp / tcp udp
fw_conf_protos() {
    case $1 in
    hysteria2 | tuic)
        echo udp
        ;;
    shadowsocks | direct)
        echo tcp udp
        ;;
    vmess)
        [[ $2 == 'quic' ]] && echo udp || echo tcp
        ;;
    *)
        echo tcp
        ;;
    esac
}

# usage: fw_conf <allow | delete> <config json file>
fw_conf() {
    fw_ok || return
    [[ ! -f $2 ]] && return
    local is_fw_type is_fw_port is_fw_listen is_fw_net p
    IFS=$'\t' read -r is_fw_type is_fw_port is_fw_listen is_fw_net < <(jq -r '.inbounds[0]|[.type,.listen_port,(.listen // "-"),(.transport.type // "-")]|@tsv' $2 2>/dev/null)
    [[ ! $is_fw_port || $is_fw_port == 'null' ]] && return
    # only local (behind caddy), no need to open
    [[ $is_fw_listen == '127.0.0.1' ]] && return
    for p in $(fw_conf_protos $is_fw_type $is_fw_net); do
        fw_port $1 $is_fw_port $p
    done
}

# usage: fw_port <allow | delete> <port> <tcp | udp>
fw_port() {
    fw_ok || return
    if [[ $1 == 'allow' ]]; then
        fw_enable
        ufw allow $2/$3 comment $is_core >/dev/null
    else
        ufw delete allow $2/$3 &>/dev/null
    fi
}

# allow all config ports & caddy ports, then show status
fw_sync() {
    fw_ok || err "未找到 ufw, 请先安装: $cmd install -y ufw"
    fw_enable
    local f
    for f in $(ls $is_conf_dir | grep '\.json$'); do
        fw_conf allow $is_conf_dir/$f
    done
    [[ $is_caddy ]] && {
        fw_port allow $is_http_port tcp
        fw_port allow $is_https_port tcp
    }
    ufw status verbose
}
