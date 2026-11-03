#!/bin/bash

# REALITY 伪装目标 (SNI) 候选列表: 美国站点
# 添加 REALITY 时会在本机 (VPS) 上逐个检测, 自动选用延迟最低的合格站点.
# 合格条件: TLS 1.3 + X25519 + ALPN h2 + 证书有效且与域名匹配
# 可按需修改此列表; 也可使用 sb sni-test <域名> 检测任意站点
sni_list=(
    www.apple.com
    swdist.apple.com
    www.icloud.com
    www.microsoft.com
    www.amd.com
    www.nvidia.com
    www.intel.com
    www.oracle.com
)

# usage: sni_test <domain>
# pass: print handshake time (ms), return 0; fail: print reason, return 1
sni_test() {
    local d=$1 t0 t1 out
    t0=$(date +%s%N)
    out=$(timeout 8 openssl s_client -connect $d:443 -servername $d -verify_hostname $d -verify_return_error \
        -tls1_3 -groups X25519 -alpn h2 </dev/null 2>&1)
    t1=$(date +%s%N)
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
    [[ ! $list ]] && list=("${sni_list[@]}")
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
