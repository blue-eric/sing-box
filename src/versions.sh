#!/bin/bash

# 固定版本 & 文件指纹 (严格模式: 只允许安装此处记录了指纹的版本)
#
# 升级步骤:
#   1. 在下面加入新版本的指纹, 并修改 is_core_pin_ver / is_caddy_pin_ver
#   2. 提交到仓库, 在 VPS 上同步脚本后执行: sb update core (或 sb update caddy)
#
# 指纹来源:
#   sing-box: 官方 Release 不提供校验文件, 指纹取自 GitHub Release 页面显示的 sha256, 并下载实测核对
#   Caddy:    官方 Release 中的 caddy_<ver>_checksums.txt (SHA-512)
#   jq:       官方 Release 中的 sha256sum.txt (SHA-256)

is_core_pin_ver=v1.14.4
is_caddy_pin_ver=v2.11.7
is_jq_pin_ver=1.7.1

# key: <名称>-<版本>-<架构>
# -g: 此文件可能在函数内被 source, 需保证为全局变量
declare -gA is_pin_hash=(
    [sing-box-v1.14.4-amd64]=699a1b510aa4396b2176d32d1181920399ebf1e267835da6f3b598d0f7c24968
    [sing-box-v1.14.4-arm64]=436441f76ee2f7fe21b5b2d426d3cb261a480455a704865789ad533e4273ec26
    [caddy-v2.11.7-amd64]=a7a433a1b133efc3c8d10eb0b99d52a24b5ef5c322dc77f5282182b1c0402139ab83f3a99f0c52409df77d20123fb0b523edad8a66d8f5e49136197bf61ef0e7
    [caddy-v2.11.7-arm64]=3db36ba90c7a6e8dda40ee3dd71fa08844c76b5fb08f61b31e5e78d2ed38e71c51dc7baed875e50d1ca1279196e84302967237386ae87c91ae9f2aaceada682e
    [jq-1.7.1-amd64]=5942c9b0934e510ee61eb3e30273f1b3fe2590df93933a93d7c58b81d19c8ff5
    [jq-1.7.1-arm64]=4dd2d8a0661df0b22f1bb9a1f9830f06b6f3b8f7d91211a1ef5d7c4f06a8b4a5
)

# 是否记录了指纹; usage: is_pinned <name> <ver>
is_pinned() {
    [[ ${is_pin_hash[$1-$2-$is_arch]} ]]
}

# 校验文件指纹; usage: verify_file <name> <ver> <file>
# 64 位为 SHA-256, 128 位为 SHA-512
verify_file() {
    local is_want=${is_pin_hash[$1-$2-$is_arch]} is_got
    [[ ! $is_want || ! -f $3 ]] && return 1
    case ${#is_want} in
    64) is_got=$(sha256sum "$3" | cut -d ' ' -f1) ;;
    128) is_got=$(sha512sum "$3" | cut -d ' ' -f1) ;;
    *) return 1 ;;
    esac
    [[ $is_got == "$is_want" ]]
}
