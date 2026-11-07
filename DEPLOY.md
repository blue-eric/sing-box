# sing-box 部署指南（VLESS-REALITY + Hysteria2 + SSH 密钥登录）

适用于你的仓库：https://github.com/blue-eric/sing-box
系统要求：Ubuntu 22.04，64 位（amd64 或 arm64），使用 root 用户操作

---

## 第 0 步：准备新 IP

1. 在云厂商控制台更换 VPS 的公网 IP（或新开一台 VPS）。
2. 打开 itdog，对新 IP 做 **ping 检测** 和 **TCPing 检测（端口 22）**。
3. 国内大部分地区都能连通再继续。如果全部超时，说明新 IP 也被封了，换一个再测。

---

## 第 1 步：登录 VPS

```bash
ssh root@你的VPS IP
```

如果登录的是普通用户，先执行 `sudo -i` 切换到 root。

> ⚠️ **安装过程中会自动开启防火墙。请保持这个 SSH 窗口一直开着，直到第 5 步确认新窗口能正常登录。**

---

## 第 2 步：安装

依次执行下面的命令：

```bash
apt update && apt install -y git wget ca-certificates qrencode
git clone https://github.com/blue-eric/sing-box.git
cd sing-box && bash install.sh -l
```

安装完成后会自动：
- 下载 sing-box 1.14.4 并校验指纹（不一致会拒绝安装）
- 检测伪装网站，选出延迟最低的合格站点
- 先放行 SSH 端口，再开启 ufw 防火墙，并放行 REALITY 端口
- 创建一个 **VLESS-REALITY** 节点，并显示节点信息和 `vless://` 链接

**需要留意的提示：**

| 提示内容 | 含义和处理 |
|---|---|
| `已开启 ufw 防火墙, 已放行 SSH 端口: 22` | 正常。请确认显示的端口就是你登录 SSH 用的端口 |
| `无法识别 SSH 端口 ... 未开启 ufw 防火墙` | 脚本为了不把你锁在外面，没有开启防火墙。到第 5 步手动处理 |
| `候选站点均未通过检测` | 伪装网站检测都没通过，到第 4 步处理 |

---

## 第 3 步：添加 Hysteria2 备用节点

```bash
sb add hy2
```

会显示一个 `hysteria2://` 链接，端口是随机的，脚本也会自动在防火墙里放行它的 UDP 端口。

查看所有节点的端口：

```bash
sb info
```

如果有多个节点，按提示选择要查看的那个。也可以直接用 `ls /etc/sing-box/conf` 看文件名，文件名里的数字就是端口，例如 `VLESS-REALITY-12345.json` 的端口是 12345。

---

## 第 4 步：检查伪装网站

```bash
sb sni-test
```

第一行会显示识别到的 VPS 地区，例如 `VPS 地区: US (本国候选 + 通用候选)`，然后列出每个候选站点检测 **通过** 或 **失败**，以及延迟或失败原因。

**候选站点按 VPS 所在国家自动选择：**

| VPS 所在地区 | 检测哪些站点 |
|---|---|
| 美国、日本、韩国、新加坡、香港、台湾、德国、英国 | 本国候选 + 通用候选 |
| 其他国家，或识别不到地区 | 只检测通用候选（apple / icloud / microsoft） |

地区来自获取公网 IP 时请求的同一个 Cloudflare 接口，可以这样查看：
```bash
wget -qO- https://one.one.one.one/cdn-cgi/trace | grep -E '^(loc|colo)='
```
`loc` 是国家代码，`colo` 是离 VPS 最近的 Cloudflare 机房。候选列表在仓库的 `src/sni.sh` 里，可以按需增删。

**失败原因说明：**

| 提示 | 含义 |
|---|---|
| 无法连接 (域名解析失败或网络不通) | 从 VPS 连不上这个站点 |
| 无法建立 TLS 1.3 (X25519) 连接 | 站点不支持 TLS 1.3 或 X25519 |
| 证书校验失败 | 证书无效或和域名不匹配 |
| 不支持 h2 | 站点不支持 HTTP/2 |

- 安装时已经自动选好了延迟最低的合格站点，一般不用改。
- 如果想换成其他站点（比如延迟更低的那个），执行：
  ```bash
  sb change VLESS-REALITY-端口号.json sni www.example.com
  ```
  改完后，客户端需要**重新导入**新的链接（节点信息里的 SNI 变了）。
- 候选站点在国内能不能访问，可以用 itdog 的网站测速查一下。

---

## 第 5 步：防火墙和安全组

**1. 检查 ufw**

```bash
ufw status
```

应该能看到三条规则：SSH 端口（`# ssh`）、REALITY 端口 `/tcp`、Hysteria2 端口 `/udp`。

如果第 2 步提示"无法识别 SSH 端口"，手动执行（22 换成你的 SSH 端口）：
```bash
ufw allow 22/tcp
ufw enable
sb fw
```

**2. 确认 SSH 正常**

**另开一个新的终端窗口**，重新 `ssh root@你的VPS IP`。能正常登录，再关闭旧窗口。

**3. 云厂商安全组（容易漏掉）**

到云厂商的网页控制台，找到这台 VPS 的"安全组"或"防火墙"设置，添加入站规则：

| 端口 | 协议 | 用途 |
|---|---|---|
| REALITY 的端口 | **TCP** | 主力节点 |
| Hysteria2 的端口 | **UDP** | 备用节点 |

注意：TCP 和 UDP 要分别添加，协议不能选错。

---

## 第 6 步：检查运行状态

```bash
sb status                      # 应显示 running
ss -tulnp | grep sing-box      # 应看到 REALITY 的 tcp 端口和 Hysteria2 的 udp 端口
```

然后用 itdog 的 **TCPing** 测试 **REALITY 端口**，国内应能连通。

> Hysteria2 是 UDP，**TCPing 测不了，测出来不通是正常的**，直接用客户端测试。

---

## 第 7 步：开启 BBR

```bash
sb bbr
```

可以提升网络较差时的速度。

---

## 第 8 步：客户端导入

获取链接：

```bash
sb url        # 显示链接（多个节点时按提示选择）
sb qr         # 显示二维码，手机扫码导入
```

- **v2rayN**：复制 `vless://` 和 `hysteria2://` 链接，在软件里"从剪贴板导入"。
- **其他客户端**：如果需要手动填写，`sb info` 会列出全部参数。
  - Hysteria2 需要填写 **证书指纹（SHA-256）**，`sb info` 里"跳过证书验证"那一行会显示。不要只开"跳过证书验证"而不填指纹。

**测试顺序**：先连 REALITY，打开网页确认可用；再切到 Hysteria2 测试。

**建议**：把两个节点放进一个"故障转移"（fallback）分组，REALITY 不通时会自动切到 Hysteria2。

---

## 第 9 步：SSH 改为只允许密钥登录（推荐）

前提：已经把你电脑上的公钥加到了 VPS 的 `~/.ssh/authorized_keys`。

> ⚠️ 原则：**先确认密钥能登录，再关闭密码登录**。全程保持当前 SSH 窗口不要关。

**1. 确认密钥能登录**

在**你自己的电脑**上新开一个终端，强制只用密钥登录：

```bash
ssh -o PasswordAuthentication=no root@你的VPS IP
```

- 直接登录成功、没有问密码 → 继续
- 显示 `Permission denied` → **停下**，先解决密钥问题

登录后在 VPS 上修正密钥文件权限（权限过宽时 SSH 会拒绝使用密钥）：

```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

**2. 关闭密码登录**

`/etc/ssh/sshd_config.d/` 目录里的配置优先于主配置文件，很多 VPS 镜像在这里自带"允许密码登录"的设置。SSH 以**最先读到的设置为准**，该目录按文件名顺序读取，所以新建一个 `00-` 开头的文件，保证它最先生效：

```bash
cat > /etc/ssh/sshd_config.d/00-key-only.conf <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
```

| 设置 | 作用 |
|---|---|
| `PubkeyAuthentication yes` | 允许密钥登录 |
| `PasswordAuthentication no` | 禁止密码登录 |
| `KbdInteractiveAuthentication no` | 禁止"交互式"密码登录，避免从这里绕过 |
| `PermitRootLogin prohibit-password` | root 只能用密钥登录 |

**3. 检查并生效**

```bash
sshd -t && echo 配置正确
sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|pubkeyauthentication) '
```

第二条显示的是实际生效的设置，应为：

```
pubkeyauthentication yes
passwordauthentication no
kbdinteractiveauthentication no
permitrootlogin without-password
```

（`without-password` 与 `prohibit-password` 是同一个意思。）确认无误后：

```bash
systemctl reload ssh
```

**4. 验证（原窗口仍不要关）**

在你的电脑上再开两个新窗口：

```bash
ssh root@你的VPS IP                              # 应该：密钥登录成功
ssh -o PubkeyAuthentication=no root@你的VPS IP   # 应该：直接显示 Permission denied (publickey).，不提示输入密码
```

两项都符合，才可以关闭原窗口。

**注意事项**

- **私钥务必备份**（另一台设备或密码管理器）。关闭密码登录后，丢失私钥就无法通过 SSH 登录。
- **root 密码保留，并保持为强密码。** 云厂商控制面板的 VNC / 控制台是直接登录，不经过 SSH，仍然用密码，是私钥丢失时唯一的补救入口。
- 需要恢复密码登录时：
  ```bash
  rm /etc/ssh/sshd_config.d/00-key-only.conf && systemctl reload ssh
  ```

---

## 常用命令

| 命令 | 作用 |
|---|---|
| `sb` | 打开管理菜单 |
| `sb info` | 查看节点信息 |
| `sb url` / `sb qr` | 显示链接 / 二维码 |
| `sb status` | 查看运行状态 |
| `sb restart` | 重启 sing-box |
| `sb test` | 测试运行（启动失败时会显示错误原因） |
| `sb log` | 实时查看日志（Ctrl + C 退出） |
| `sb fw` | 重新同步防火墙规则 |
| `sb sni-test` | 检测伪装网站 |
| `sb change 配置名 port 新端口` | 更改端口（防火墙自动跟着改；安全组需手动改） |
| `sb del 配置名` | 删除节点（会直接删除，不再确认） |
| `sb help` | 查看全部命令 |

---

## 出问题时

1. 执行 `sb status` 和 `sb test`，看是否有报错。
2. 日志默认只记录警告和错误。需要更详细的日志时：
   ```bash
   sb log info     # 临时调成详细日志
   sb log          # 查看日志，复现问题后 Ctrl + C 退出
   sb log warn     # 排查完改回来
   ```
3. 把完整输出发给我。

---

## 以后更新脚本

```bash
cd ~/sing-box
git fetch && git log -p HEAD..origin/main    # 先看改了什么
git pull
cp -rf ./* /etc/sing-box/sh/
```

**查看改动时怎么退出**

`git log` 内容较多时，会自动用分页查看器打开，按 **`q`** 退出。如果什么都没显示就直接回到命令行，说明没有新的改动，已经是最新的了。

| 按键 | 作用 |
|---|---|
| `q` | **退出** |
| 空格 / `f` | 向下翻一页 |
| `b` | 向上翻一页 |
| `↓` / `↑` 或 `j` / `k` | 逐行滚动 |
| `/` + 关键词，再按回车 | 搜索，按 `n` 跳到下一个结果 |
| `G` | 跳到末尾 |

不想进入分页查看器，可以让内容直接打印在屏幕上：
```bash
git --no-pager log -p HEAD..origin/main
```

同步脚本**不需要重新建节点**：
- 只会覆盖 `/etc/sing-box/sh/` 里的脚本，节点配置（`/etc/sing-box/conf/`）和 sing-box 程序都不变。
- 不会重启 sing-box，连接不会中断；客户端里的节点也不用改。
- 新功能只在之后新建节点或执行对应命令时才生效。例如伪装网站的自动选择，只在新建 REALITY 节点或执行 `sb change … sni auto` 时运行。

升级 sing-box 版本：先在仓库的 `src/versions.sh` 里加入新版本和指纹（可以让我来做），同步脚本后执行 `sb update core`。
