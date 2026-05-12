<p align="center">
  <img src="./pixel-cat.svg" alt="PixelCat" width="120" />
</p>

# 🐱 像素猫 - 科学上网ICU

「像素猫 - 科学上网ICU」是一个中文教程博客,主要整理科学上网工具配置、网络诊断、节点维护与隐私安全相关的实用经验。🚀

## 🎯 关注方向

- 🧰 科学上网工具的基础配置与故障排查
- 🌐 DNS、路由、延迟、丢包等网络问题的定位方法
- 🔐 面向普通用户的隐私安全与设备自护清单

⚠️ 这里的内容默认用于合法合规的学习、研究、远程办公与公开信息访问场景。任何配置都应该遵守所在地法律法规、学校或公司的网络使用政策。

## 📺 频道入口

- 🏠 [官网](https://pixelcat.icu)
- ▶️ [YouTube 订阅](https://www.youtube.com/@PixelCatICU)
- 💻 [GitHub 地址](https://github.com/PixelCatICU)
- 🐦 [X](https://x.com/PixelCatICU)

# 🎁 项目能做什么

这是一份 **Linux 一键部署脚本**,同时支持以下两种代理协议,两者可以独立部署、也可以在同一台服务器同一个域名共存:

| 协议 | 传输层 | 端口 | 特点 |
| --- | --- | --- | --- |
| **ForwardProxy**(NaiveProxy 兼容) | HTTPS / TCP | 443/tcp | Caddy + `forwardproxy` 插件,反代真实网站做伪装 |
| **Hysteria2** | QUIC / UDP | 443/udp + 端口跳跃 | 内核层 UDP 端口跳跃(nftables/iptables),抗 QoS、抗封锁 |

共通能力:

- 🔐 自动申请和续期 Let's Encrypt 证书,同域名时两个协议共享证书
- 👤 systemd 以专用 `pixelcat-proxy` 用户 + `CAP_NET_BIND_SERVICE` 运行,不裸跑 root
- 🛡 systemd sandbox:`ProtectSystem=strict` / `ProtectHome` / `PrivateTmp` / `RestrictNamespaces` / `LockPersonality` 等
- 📁 `.env` / `.env.hysteria2` / 配置文件 0600/0640 权限,密码不全局可读
- ⚡ 预编译二进制下载,**强制 SHA256 校验**,任一步骤校验失败拒绝使用并回退到本地编译
- 🦘 输入实时校验(域名 / 用户名 / 端口 / 邮箱 / 端口跳跃范围 / 限速),错误立刻重输,不必重跑脚本
- 📱 部署完成自动打印对应协议的 sing-box 客户端配置(Hysteria2 自带 `server_ports` 跳跃字段)
- 🚀 菜单内置一键 BBR
- 🧹 安装 / 更新 / 卸载 / 彻底清理(`--purge`)

启动脚本会显示像素猫 ASCII logo + 中文菜单,5 个选项覆盖以上全部能力。

# 🚀 PixelCat ForwardProxy 直装部署

这个项目提供 PixelCat ForwardProxy 一键部署脚本:优先下载带 `forwardproxy` 插件的预编译 Caddy(并强制校验 SHA256),失败或不可用时再本地编译,然后通过 `systemd` 以专用低权限用户运行。Caddy 会自动申请和续期 HTTPS 证书。🔒

## ✨ 功能

- ⚡ 优先下载预编译 Caddy,强制 SHA256 校验,部署更快也更安全
- 🔧 校验失败或缺架构时自动回退到本地编译(Go + xcaddy)
- 🔐 自动申请和续期 Let's Encrypt 证书
- 🎭 支持反代伪装网站域名
- 👤 服务以专用系统用户 + `CAP_NET_BIND_SERVICE` 运行,不裸跑 root
- 📁 配置和密码文件权限收紧:`.env` / Caddyfile 仅服务用户可读
- 📱 部署完成后自动打印 sing-box 客户端配置
- 🚀 菜单内置一键开启 BBR
- 🧹 支持安装、更新、卸载和彻底清理

## ✅ 前置条件

- 🌍 域名 `A/AAAA` 记录已经解析到这台服务器。
- 🛡️ 服务器防火墙和云厂商安全组放行 `80/tcp` 和 `443/tcp`。
- 🧱 系统需要 Linux + systemd(Debian / Ubuntu / RHEL 系 / Alpine)。
- 📦 脚本会自动安装基础依赖;预编译下载失败时,会自动安装 Go、xcaddy 并本地编译。

## ⚡ 一键部署脚本

### ⭐ 方式一:交互式部署(推荐) ⭐

> ✅ 推荐新手优先使用这个方式:复制一条命令运行,然后按中文菜单输入 `1` 安装即可。

在服务器执行:

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash
```

这个入口脚本会自动执行:

```bash
mkdir -p /opt/pixelcat
cd /opt/pixelcat
git clone https://github.com/PixelCatICU/pixelcat-proxy.git pixelcat-forwardproxy
cd pixelcat-forwardproxy
chmod +x deploy.sh
./deploy.sh
```

如果项目已经存在,它会自动进入 `/opt/pixelcat/pixelcat-forwardproxy` 拉取最新代码,然后启动 `deploy.sh` 菜单。

如果你已经把项目放到了服务器上,也可以直接:

```bash
cd /path/to/pixelcat-forwardproxy
./deploy.sh
```

脚本会显示中文菜单:

```text
1) 安装 / 更新 PixelCat ForwardProxy
2) 安装 / 更新 PixelCat Hysteria2
3) 卸载 PixelCat ForwardProxy
4) 卸载 PixelCat Hysteria2
5) 一键开启 BBR
6) IP 质量检测           (xykt/IPQuality)
7) 流媒体解锁检测         (lmc999/RegionRestrictionCheck)
8) 网络质量 / 回程检测     (xykt/NetQuality)
0) 退出
```

输入 `1` 后,按中文提示填写部署参数:

- `代理域名`:例如 `proxy.example.com`
- `代理用户名`:客户端连接用的用户名
- `代理密码`:客户端连接用的密码(隐藏输入)
- `伪装网站域名`:例如 `www.example.com`
- `证书邮箱`:Let's Encrypt 邮箱,可留空
- `HTTP 端口`:默认 `80`
- `HTTPS 端口`:默认 `443`

每个字段都会在输入后立刻校验格式,无效会让你重新输入,不必重新跑脚本。

部署完成后,脚本会打印:

- ✅ systemd 服务状态命令
- 🔗 代理地址
- 📱 sing-box 客户端配置
- 📜 日志查看命令

### 方式二:带参数部署

也可以一次性传入参数(`-y` 用于免确认覆盖 `.env`):

```bash
./deploy.sh --install -y \
  --domain proxy.example.com \
  --username your_user \
  --password change_this_strong_password \
  --decoy-domain www.example.com \
  --email admin@example.com
```

生产环境更推荐交互式输入密码,因为 `--password` 参数可能被 shell 历史或进程列表记录。

如果你想强制本地编译,不下载预编译文件:

```bash
./deploy.sh --install --build-from-source
```

### 方式三:只生成配置

只生成 `.env`、Caddyfile 和 systemd 配置,不启动服务:

```bash
./deploy.sh --install --skip-start
```

### 🚀 一键开启 BBR

交互菜单输入 `3`,或直接执行:

```bash
./deploy.sh --bbr
```

脚本会写入 `/etc/sysctl.d/99-pixelcat-bbr.conf` 并执行 `sysctl --system`:

```conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
```

查看当前 BBR 状态:

```bash
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

### 常用命令

查看服务状态:

```bash
systemctl status pixelcat-forwardproxy --no-pager
```

查看日志:

```bash
journalctl -u pixelcat-forwardproxy -f
```

重启服务:

```bash
systemctl restart pixelcat-forwardproxy
```

查看脚本帮助:

```bash
./deploy.sh --help
```

## 🧹 卸载服务

停止并删除 PixelCat ForwardProxy systemd 服务,保留配置和证书数据:

```bash
./deploy.sh --uninstall
```

完全卸载,连配置、证书数据、本地 Go 工具、系统用户和 `.env` 一起删除:

```bash
./deploy.sh --uninstall --purge
```

免确认卸载:

```bash
./deploy.sh --uninstall -y
```

## 📱 sing-box 客户端配置

客户端代理地址通常填写:

```text
https://USERNAME:PASSWORD@DOMAIN
```

✨ 示例:

```text
https://your_user:change_this_strong_password@proxy.example.com
```

部署完成后脚本会自动打印 sing-box 配置。结构类似:

```json
{
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 2080
    }
  ],
  "outbounds": [
    {
      "type": "naive",
      "tag": "naive-out",
      "server": "proxy.example.com",
      "server_port": 443,
      "username": "your_user",
      "password": "change_this_strong_password",
      "tls": {
        "enabled": true,
        "server_name": "proxy.example.com"
      }
    }
  ],
  "route": {
    "final": "naive-out",
    "auto_detect_interface": true
  }
}
```

## ⚙️ 配置项

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `DOMAIN` | 是 | 用于申请证书和访问代理的域名 |
| `USERNAME` | 是 | Basic Auth 用户名 |
| `PASSWORD` | 是 | Basic Auth 密码 |
| `DECOY_DOMAIN` | 是 | 反代伪装网站域名,普通浏览器访问 `DOMAIN` 时会反代显示该网站 |
| `EMAIL` | 否 | Let's Encrypt 账号邮箱 |
| `HTTP_PORT` | 否 | HTTP 端口,默认 `80` |
| `HTTPS_PORT` | 否 | HTTPS 代理端口,默认 `443` |

脚本会把配置保存到当前项目目录下的 `.env`(权限 `600`),并把 Caddyfile 写入:

```text
/etc/pixelcat-forwardproxy/Caddyfile   (root:pixelcat-proxy 0640)
```

证书和 Caddy 数据默认保存到:

```text
/var/lib/pixelcat-forwardproxy         (pixelcat-proxy:pixelcat-proxy 0700)
```

systemd 服务以专用用户 `pixelcat-proxy` 运行,通过 `AmbientCapabilities=CAP_NET_BIND_SERVICE` 获得绑定 80/443 端口的能力,并启用了 `ProtectSystem`、`ProtectHome`、`PrivateTmp`、`RestrictNamespaces` 等加固项。

## ⚠️ 注意

- 🌍 首次启动需要公网访问到 `DOMAIN:80` 和 `DOMAIN:443`,否则证书申请可能失败。
- 🎭 `DECOY_DOMAIN` 只填写域名,不要带 `https://`,例如 `www.example.com`。
- 🧩 复杂网站可能因为 Cookie、CSP、WebSocket 或静态资源跨域限制导致反代显示不完整,静态博客、文档站、简单官网更适合做伪装站。
- 💾 `/var/lib/pixelcat-forwardproxy` 保存证书和 ACME 账号信息,不要随意删除。
- ☁️ 如果域名套了 CDN,需要确认 CDN 支持 HTTPS 代理流量,否则建议 DNS 记录先仅 DNS 解析,不启用代理。
- 🖥️ 部署完成后脚本会把 sing-box 配置(含明文密码)输出到终端,请避免在公开场合显示或截图。

# 🚀 PixelCat Hysteria2 部署

这个项目同时支持一键部署 Hysteria2 服务器:基于 QUIC/UDP 的代理协议,内置 BBR,自动 TLS,可配合**端口跳跃**降低单端口被识别/限速的概率。

## ✨ Hysteria2 功能

- ⚡ 直接下载 Hysteria 官方预编译二进制,强制 SHA256 校验
- 🔐 自动复用 ForwardProxy 的 Caddy 证书;若未部署 Caddy 则 Hysteria2 自申请 ACME 证书
- 🦘 内核层 UDP 端口跳跃(优先 nftables,回退 iptables)
- 👤 与 ForwardProxy 共用 `pixelcat-proxy` 系统用户 + `CAP_NET_BIND_SERVICE`,不裸跑 root
- 🎭 内置伪装站点反代(默认 `https://www.bing.com`)
- 📱 部署完成后自动打印 sing-box 客户端配置(含 `server_ports` 端口跳跃字段)
- 🧹 支持安装、更新、卸载和彻底清理

## ✅ Hysteria2 前置条件

- 🌍 域名 `A/AAAA` 记录已经解析到这台服务器(可与 ForwardProxy 同域名)。
- 🛡️ 防火墙和安全组放行 `443/udp` 以及端口跳跃范围(默认 `20000-50000/udp`)。
- 🧱 系统需要 Linux + systemd,端口跳跃需要 nftables 或 iptables(脚本会自动安装)。
- 🪪 **证书来源**:
  - 已部署 ForwardProxy 且域名一致 → 自动复用 Caddy 已申请的证书,零证书配置
  - 未部署 ForwardProxy → Hysteria2 自己跑 ACME,需要 80/tcp **和** 443/tcp 空闲

## ⚡ Hysteria2 部署方式

### ⭐ 方式一:交互式部署

```bash
./deploy.sh
```

菜单选择 `2)`,按提示填:

- `Hysteria2 域名`:留空默认沿用 ForwardProxy 的域名
- `Hysteria2 密码`:留空自动生成随机强密码
- `监听 UDP 端口`:默认 `443`
- `端口跳跃范围`:默认 `20000-50000`;输入 `off` 关闭
- `上行/下行限速 Mbps`:默认 `0`(不限速)
- `伪装 URL`:默认 `https://www.bing.com`

### 方式二:带参数部署

```bash
./deploy.sh --install-hysteria2 -y \
  --hy2-domain proxy.example.com \
  --hy2-port 443 \
  --hy2-hop-range 20000-50000 \
  --hy2-up-mbps 0 \
  --hy2-down-mbps 0 \
  --hy2-masquerade https://www.bing.com
```

完整 CLI 参数:

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `--hy2-domain` | 沿用 `--domain` | TLS SNI 域名 |
| `--hy2-password` | 自动生成 32 位强密码 | 客户端密码 |
| `--hy2-port` | `443` | UDP 监听端口 |
| `--hy2-hop-range` | `20000-50000` | 端口跳跃范围,传 `off` 关闭 |
| `--hy2-hop-iface` | 自动检测默认路由网卡 | DNAT 网卡(`ip route show default` 解析) |
| `--hy2-up-mbps` | `0`(不限速) | 上行限速 Mbps |
| `--hy2-down-mbps` | `0`(不限速) | 下行限速 Mbps |
| `--hy2-masquerade` | `https://www.bing.com` | 伪装站点 URL |

不传 `--hy2-password` 会自动生成强密码(并打印到终端)。

关闭端口跳跃:

```bash
./deploy.sh --install-hysteria2 -y --hy2-hop-range off
```

### 方式三:只生成配置

```bash
./deploy.sh --install-hysteria2 --skip-start
```

### Hysteria2 常用命令

```bash
# 服务状态
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager   # 端口跳跃 oneshot

# 实时日志
journalctl -u pixelcat-hysteria2 -f

# 重启
systemctl restart pixelcat-hysteria2

# 查看当前生效的跳跃规则
nft list table inet pixelcat-hy 2>/dev/null || \
  iptables -t nat -L PREROUTING -n
```

## 🧹 卸载 Hysteria2

保留配置和证书:

```bash
./deploy.sh --uninstall-hysteria2
```

完全清理(配置、证书、`.env.hysteria2`,以及在 ForwardProxy 也卸载的前提下连同系统用户):

```bash
./deploy.sh --uninstall-hysteria2 --purge
```

免确认卸载:

```bash
./deploy.sh --uninstall-hysteria2 -y
```

## ⚙️ Hysteria2 配置项

| 变量 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `HY2_DOMAIN` | 是 | 沿用 `DOMAIN` | TLS SNI 域名 |
| `HY2_PASSWORD` | 是 | 自动生成 | 客户端密码 |
| `HY2_PORT` | 否 | `443` | UDP 监听端口 |
| `HY2_HOP_RANGE` | 否 | `20000-50000` | 端口跳跃范围,留空或 `off` 关闭 |
| `HY2_HOP_IFACE` | 否 | 自动检测 | DNAT 使用的网卡 |
| `HY2_UP_MBPS` | 否 | `0` | 上行限速 Mbps,`0` = 不限速 |
| `HY2_DOWN_MBPS` | 否 | `0` | 下行限速 Mbps,`0` = 不限速 |
| `HY2_MASQUERADE_URL` | 否 | `https://www.bing.com` | 伪装站点 URL |

配置会保存到 `.env.hysteria2`(权限 `600`),示例见 [`.env.example.hysteria2`](.env.example.hysteria2)。

## 📁 Hysteria2 文件位置

```text
/usr/local/bin/pixelcat-hysteria2                     # 二进制
/etc/pixelcat-hysteria2/config.yaml                   # 配置 0640 root:pixelcat-proxy
/etc/pixelcat-hysteria2/hop-up.sh / hop-down.sh       # 端口跳跃规则脚本
/var/lib/pixelcat-hysteria2/                          # ACME 数据 0700 pixelcat-proxy
/etc/systemd/system/pixelcat-hysteria2.service        # 主服务
/etc/systemd/system/pixelcat-hysteria2-hop.service    # 端口跳跃 oneshot 服务
/etc/sysctl.d/99-pixelcat-hysteria2.conf              # UDP 缓冲调优
```

## 📱 Hysteria2 sing-box 客户端配置

部署完成后脚本会自动打印类似:

```json
{
  "outbounds": [
    {
      "type": "hysteria2",
      "tag": "hysteria-out",
      "server": "proxy.example.com",
      "server_port": 443,
      "server_ports": ["20000:50000"],
      "password": "<生成的密码>",
      "tls": {
        "enabled": true,
        "server_name": "proxy.example.com"
      },
      "up_mbps": 0,
      "down_mbps": 0
    }
  ]
}
```

启用了端口跳跃时,客户端会在 `server_ports` 范围内随机选 UDP 端口发包,服务器内核侧 DNAT 到实际监听端口 (`server_port`)。

## ⚠️ Hysteria2 注意事项

- 🔥 防火墙务必放行 `HY2_PORT/udp`(默认 `443/udp`)和整个跳跃范围。
- 🧱 端口跳跃用 nftables 优先;OpenVZ 等不支持 nftables/iptables-nat 的虚拟化平台,请用 `--hy2-hop-range off` 关闭跳跃。
- 🪪 ACME 自申请模式会用 443/tcp 完成 ALPN-01 校验,因此**不能和 ForwardProxy 不同域名却共用 Caddy** —— 真要不同域名,把 Hysteria2 域名也加到 Caddyfile 让 Caddy 一并签发。
- 📡 默认 UDP 缓冲已调到 16MB(`/etc/sysctl.d/99-pixelcat-hysteria2.conf`),如需进一步性能调优可改大。
- 🖥️ sing-box 配置含明文密码,请勿在公开场合显示或截图。

# 📚 其它

## 📦 发布预编译 Caddy

这个项目内置 GitHub Actions,会在发布 GitHub Release 时自动编译:

```text
caddy-forwardproxy-linux-amd64.tar.gz
caddy-forwardproxy-linux-arm64.tar.gz
```

每个产物都会同时上传 `.sha256` 校验和文件。部署脚本会**强制验证 SHA256**:

- 校验和文件下载失败 → 拒绝使用未经校验的二进制,自动回退到本地编译
- 校验和不匹配 → 拒绝使用,自动回退到本地编译
- 系统缺少 `sha256sum` → 自动回退到本地编译

发布方式:

```bash
git tag v1.0.0
git push origin v1.0.0
```

然后在 GitHub 仓库页面创建 Release,选择这个 tag 并发布。发布后 Actions 会自动把二进制文件和校验和上传到 Release Assets。

也可以在 GitHub Actions 页面手动运行 `Build Caddy ForwardProxy`,先检查构建是否正常。
