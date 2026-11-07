# 本仓库说明 (fork)

本仓库 fork 自 [233boy/sing-box](https://github.com/233boy/sing-box) (GPL-3.0), 做了以下修改:

- 只支持本地安装: 先 `git clone` 本仓库, 再在仓库目录执行 `bash install.sh -l`; 不再从任何 Release 下载脚本
- 固定版本 + 文件指纹校验 (严格模式): sing-box / Caddy / jq 只安装 `src/versions.sh` 中记录了指纹的版本, 指纹不符直接丢弃
- 下载开启 HTTPS 证书校验 (去掉 `--no-check-certificate`)
- `sb update sh` 改为提示使用 `git pull` 同步; `sb reinstall` 使用本地脚本
- 二维码只在本地生成, 不再输出第三方二维码网页链接
- 去掉推广/广告输出; 节点名称前缀改为 VPS 主机名
- 修复手动更改 REALITY 密钥时校验无效的问题
- REALITY 伪装目标: 按 VPS 所在国家 (Cloudflare trace 的 `loc`) 选用候选列表 (美 / 日 / 韩 / 新 / 港 / 台 / 德 / 英 + 通用, 见 `src/sni.sh`), 添加时在 VPS 上实测 (TLS 1.3 + X25519 + h2 + 证书有效), 自动选延迟最低的合格站点; 未收录或识别不到的地区只用通用候选; `sb sni-test [域名]` 可检测任意站点
- ufw 防火墙 (Ubuntu / Debian): 先放行 SSH 端口再自动开启; 添加 / 删除 / 改端口时自动开关对应端口 (REALITY 为 TCP, Hysteria2 为 UDP); `sb fw` 重新同步全部规则
- 日志默认 `warn` 级别, 并自动轮转 (10M x 3); 依赖加入 openssl
- 卸载时只删除脚本添加的两行 alias; `sb reinstall` 先下载并校验 sing-box, 成功后才卸载

## 安装 (Ubuntu 22.04)

完整的分步部署指南 (防火墙、安全组、客户端导入、SSH 密钥登录、更新方法等) 见 **[DEPLOY.md](DEPLOY.md)**.

```bash
apt update && apt install -y git wget ca-certificates
git clone https://github.com/blue-eric/sing-box.git
cd sing-box && bash install.sh -l
```

可选: `apt install -y qrencode` (用于 `sb qr` 显示二维码)

注意: 云厂商控制台的 "安全组" 是另一层防火墙, 需要另外放行同样的端口 (REALITY: TCP, Hysteria2: UDP).

## 更新脚本

```bash
cd sing-box
git fetch && git log -p HEAD..origin/main   # 先查看改动
git pull
cp -rf ./* /etc/sing-box/sh/
```

## 升级 sing-box / Caddy

1. 在 `src/versions.sh` 中加入新版本的指纹, 并修改 `is_core_pin_ver` / `is_caddy_pin_ver`
2. 按上面的步骤同步脚本到 VPS
3. 执行 `sb update core` (或 `sb update caddy`)

# 介绍

最好用的 sing-box 一键安装脚本 & 管理脚本

# 特点

- 快速安装
- 无敌好用
- 零学习成本
- 自动化 TLS
- 简化所有流程
- 兼容 sing-box 命令
- 强大的快捷参数
- 支持所有常用协议
- 一键添加 VLESS-REALITY (默认)
- 一键添加 TUIC
- 一键添加 Trojan
- 一键添加 Hysteria2
- 一键添加 AnyTLS
- 一键添加 Shadowsocks 2022
- 一键添加 VMess-(TCP/HTTP/QUIC)
- 一键添加 VMess-(WS/H2/HTTPUpgrade)-TLS
- 一键添加 VLESS-(WS/H2/HTTPUpgrade)-TLS
- 一键添加 Trojan-(WS/H2/HTTPUpgrade)-TLS
- 一键启用 BBR
- 一键更改伪装网站
- 一键更改 (端口/UUID/密码/域名/路径/加密方式/SNI/等...)
- 还有更多...

# 设计理念

设计理念为：**高效率，超快速，极易用**

脚本基于作者的自身使用需求，以 **多配置同时运行** 为核心设计

并且专门优化了，添加、更改、查看、删除、这四项常用功能

你只需要一条命令即可完成 添加、更改、查看、删除、等操作

例如，添加一个配置仅需不到 1 秒！瞬间完成添加！其他操作亦是如此！

脚本的参数非常高效率并且超级易用，请掌握参数的使用

# 文档

安装及使用：https://233boy.com/sing-box/sing-box-script/

# 帮助

使用：`sing-box help`

```
sing-box script v1.0 by 233boy
Usage: sing-box [options]... [args]...

基本:
   v, version                                      显示当前版本
   ip                                              返回当前主机的 IP
   pbk                                             同等于 sing-box generate reality-keypair
   get-port                                        返回一个可用的端口
   ss2022                                          返回一个可用于 Shadowsocks 2022 的密码

一般:
   a, add [protocol] [args... | auto]              添加配置
   c, change [name] [option] [args... | auto]      更改配置
   d, del [name]                                   删除配置**
   i, info [name]                                  查看配置
   qr [name]                                       二维码信息
   url [name]                                      URL 信息
   log                                             查看日志
更改:
   full [name] [...]                               更改多个参数
   id [name] [uuid | auto]                         更改 UUID
   host [name] [domain]                            更改域名
   port [name] [port | auto]                       更改端口
   path [name] [path | auto]                       更改路径
   passwd [name] [password | auto]                 更改密码
   key [name] [Private key | auto] [Public key]    更改密钥
   method [name] [method | auto]                   更改加密方式
   sni [name] [ ip | domain]                       更改 serverName
   new [name] [...]                                更改协议
   web [name] [domain]                             更改伪装网站

进阶:
   dns [...]                                       设置 DNS
   dd, ddel [name...]                              删除多个配置**
   fix [name]                                      修复一个配置
   fix-all                                         修复全部配置
   fix-caddyfile                                   修复 Caddyfile
   fix-config.json                                 修复 config.json
   import                                          导入 sing-box/v2ray 脚本配置

管理:
   un, uninstall                                   卸载
   u, update [core | sh | caddy] [ver]             更新
   U, update.sh                                    更新脚本
   s, status                                       运行状态
   start, stop, restart [caddy]                    启动, 停止, 重启
   t, test                                         测试运行
   reinstall                                       重装脚本

测试:
   debug [name]                                    显示一些 debug 信息, 仅供参考
   gen [...]                                       同等于 add, 但只显示 JSON 内容, 不创建文件, 测试使用
   no-auto-tls [...]                               同等于 add, 但禁止自动配置 TLS, 可用于 *TLS 相关协议
其他:
   bbr                                             启用 BBR, 如果支持
   bin [...]                                       运行 sing-box 命令, 例如: sing-box bin help
   [...] [...]                                     兼容绝大多数的 sing-box 命令, 例如: sing-box generate uuid
   h, help                                         显示此帮助界面

谨慎使用 del, ddel, 此选项会直接删除配置; 无需确认
反馈问题) https://github.com/233boy/sing-box/issues
文档(doc) https://233boy.com/sing-box/sing-box-script/
```