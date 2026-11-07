#!/bin/bash

# REALITY 伪装目标 (SNI) 候选列表
# 按 VPS 所在国家 (Cloudflare trace 的 loc) 选用 "本国列表 + 通用列表",
# 添加 REALITY 时在本机 (VPS) 上逐个检测, 自动选用延迟最低的合格站点.
# 合格条件: TLS 1.3 + X25519 + ALPN h2 + 证书有效且与域名匹配
# 注意: 以下候选未经预先检测, 由安装时的实测筛选; 国内能否访问需自行确认 (如 itdog)
# 可按需修改列表; 也可使用 sb sni-test <域名> 检测任意站点

# 通用候选, 任何地区都会检测
sni_list_global=(
    www.apple.com
    www.icloud.com
    www.microsoft.com
)

# 本国候选, key 为国家代码 (ISO 3166-1, 与 Cloudflare loc 一致)
# -g: 此文件在函数内被 source, 需保证为全局变量
declare -gA sni_list_region=(
    [US]="swdist.apple.com www.amd.com www.nvidia.com www.intel.com www.oracle.com"
    [JP]="www.lovelive-anime.jp www.nintendo.co.jp www.sony.co.jp www.rakuten.co.jp"
    [KR]="www.samsung.com www.lg.com www.naver.com www.kakaocorp.com"
    [SG]="www.singtel.com www.dbs.com.sg www.grab.com www.lazada.sg"
    [HK]="www.hkt.com www.mtr.com.hk www.cathaypacific.com www.hsbc.com.hk"
    [TW]="www.asus.com www.acer.com www.cht.com.tw www.momoshop.com.tw"
    [DE]="www.sap.com www.siemens.com www.bosch.com www.lufthansa.com"
    [GB]="www.tesco.com www.bt.com www.vodafone.co.uk www.sky.com"
)

# VPS country code from Cloudflare trace (same host as get_ip)
sni_region() {
    [[ $is_loc ]] && return
    is_loc=$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep '^loc=' | cut -d= -f2)
    [[ ! $is_loc ]] && is_loc=$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep '^loc=' | cut -d= -f2)
}

# set sni_list: region candidates (if any) + global candidates
sni_candidates() {
    sni_region
    sni_list=(${sni_list_region[${is_loc:-none}]} "${sni_list_global[@]}")
}

# region label for messages
sni_region_msg() {
    if [[ ${sni_list_region[${is_loc:-none}]} ]]; then
        echo "$is_loc (本国候选 + 通用候选)"
    else
        echo "${is_loc:-未识别} (无本国候选, 只用通用候选)"
    fi
}

# usage: sni_test <domain>
# pass: print handshake time (ms), return 0; fail: print reason, return 1
sni_test() {
    local d=$1 t0 t1 out
    t0=$(date +%s%N)
    out=$(timeout 8 openssl s_client -connect $d:443 -servername $d -verify_hostname $d -verify_return_error \
        -tls1_3 -groups X25519 -alpn h2 </dev/null 2>&1)
    t1=$(date +%s%N)
    # no TCP connection at all (dns failure, refused, timeout)
    if ! grep -q '^CONNECTED(' <<<"$out"; then
        echo "无法连接 (域名解析失败或网络不通)"
        return 1
    fi
    # TLS alert 120: no_application_protocol (server aborts when h2 is not supported)
    if grep -q 'alert number 120' <<<"$out"; then
        echo "不支持 h2"
        return 1
    fi
    if ! grep -q 'TLSv1.3' <<<"$out"; then
        echo "无法建立 TLS 1.3 (X25519) 连接"
        return 1
    fi
    if ! grep -q 'Verify return code: 0 (ok)' <<<"$out"; then
        echo "证书校验失败"
        return 1
    fi
    if ! grep -q 'ALPN protocol: h2' <<<"$out"; then
        echo "不支持 h2"
        return 1
    fi
    echo $(((t1 - t0) / 1000000))
}

# test all candidates in parallel, print the lowest latency one
sni_pick() {
    local d tmp
    [[ ! $(type -P openssl) ]] && return 1
    tmp=$(mktemp -d)
    for d in "${sni_list[@]}"; do
        {
            ms=$(sni_test $d) && echo "$ms $d" >$tmp/$d
        } &
    done
    wait
    cat $tmp/* 2>/dev/null | sort -n | head -1 | cut -d ' ' -f2
    rm -rf $tmp
}

# get a servername for REALITY; fallback to the first candidate
sni_get() {
    sni_candidates
    msg "\n检测 REALITY 伪装目标, VPS 地区: $(sni_region_msg)\n"
    is_servername=$(sni_pick)
    [[ ! $is_servername ]] && {
        is_servername=${sni_list[0]}
        warn "候选站点均未通过检测 (或缺少 openssl), 使用默认: $is_servername\n请使用 $is_core sni-test 检查网络, 并用 $is_core change [name] sni [domain] 更改."
    }
}

# sb sni-test [domain...]
sni_test_show() {
    local d r list=("$@")
    [[ ! $(type -P openssl) ]] && err "请先安装 openssl: $cmd install -y openssl"
    [[ ! $list ]] && {
        sni_candidates
        list=("${sni_list[@]}")
        msg "\nVPS 地区: $(sni_region_msg)"
    }
    msg "\n检测条件: TLS 1.3 + X25519 + h2 + 证书有效 (在本机上检测)\n"
    for d in "${list[@]}"; do
        if r=$(sni_test $d); then
            msg "$(_green 通过) ${r}ms\t$d"
        else
            msg "$(_red 失败) $r\t$d"
        fi
    done
    msg "\n更改 REALITY 的 SNI: $(_green "$is_core change [name] sni [domain]")\n"
}
