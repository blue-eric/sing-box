download() {
    # only pinned versions (src/versions.sh)
    latest_ver=$2
    case $1 in
    core)
        [[ ! $latest_ver ]] && latest_ver=$is_core_pin_ver
        is_pin_name=$is_core
        ;;
    caddy)
        [[ ! $latest_ver ]] && latest_ver=$is_caddy_pin_ver
        is_pin_name=caddy
        ;;
    *)
        err "不支持下载: $1"
        ;;
    esac
    ! is_pinned $is_pin_name $latest_ver && {
        err "$is_pin_name $latest_ver 未在 src/versions.sh 中记录指纹, 不允许安装."
    }
    # tmp dir
    tmpdir=$(mktemp -u)
    [[ ! $tmpdir ]] && {
        tmpdir=/tmp/tmp-$RANDOM
    }
    mkdir -p $tmpdir
    case $1 in
    core)
        name=$is_core_name
        tmpfile=$tmpdir/$is_core.tar.gz
        link="https://github.com/${is_core_repo}/releases/download/${latest_ver}/${is_core}-${latest_ver:1}-linux-${is_arch}.tar.gz"
        download_file
        tar zxf $tmpfile --strip-components 1 -C $is_core_dir/bin
        chmod +x $is_core_bin
        ;;
    caddy)
        name="Caddy"
        tmpfile=$tmpdir/caddy.tar.gz
        # https://github.com/caddyserver/caddy/releases/download/v2.6.4/caddy_2.6.4_linux_amd64.tar.gz
        link="https://github.com/${is_caddy_repo}/releases/download/${latest_ver}/caddy_${latest_ver:1}_linux_${is_arch}.tar.gz"
        download_file
        tar zxf $tmpfile -C $tmpdir
        cp -f $tmpdir/caddy $is_caddy_bin
        chmod +x $is_caddy_bin
        ;;
    esac
    rm -rf $tmpdir
    unset latest_ver
}
download_file() {
    if ! _wget -t 5 -c $link -O $tmpfile; then
        rm -rf $tmpdir
        err "\n下载 ${name} 失败.\n"
    fi
    if ! verify_file $is_pin_name $latest_ver $tmpfile; then
        rm -rf $tmpdir
        err "\n${name} 文件指纹校验失败, 已丢弃: ${link}\n"
    fi
}
