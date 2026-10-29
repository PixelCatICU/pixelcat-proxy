<p align="center"><img src="./pixel-cat.svg" alt="PixelCat" width="120" /></p>

# PixelCat Proxy

**中文** | [Русский](README.ru.md) | [فارسی](README.fa.md)

面向 Linux 的 NaiveProxy / Hysteria2 安装维护脚本，提供三语言菜单、诊断工具和一次性 sing-box 配置领取链接。

## 功能与环境

- NaiveProxy：Caddy + `klzgrad/forwardproxy@naive`，提供 TLS、HTTP/2 CONNECT、认证和伪装站点。
- Hysteria2：官方服务端，支持 UDP 端口跳跃和复用同域名 Caddy 证书。
- 维护：BBR、IP 质量、流媒体解锁、网络质量和回程检测。
- 一次性链接：随机 HTTPS 地址，限时且最多领取一次。

需要 Linux、Bash、systemd、root 或 sudo，支持 amd64 / arm64。推荐 Debian、Ubuntu、具备 systemd 的 RHEL 系 / Fedora。普通 Alpine/OpenRC 环境不能直接使用本脚本的服务管理。一次性链接额外需要 Python 3.7+、完整项目中的 `one_time_link.py` 和可用的 PixelCat Caddy HTTPS 服务。

域名 A/AAAA 记录应指向服务器，云安全组和系统防火墙需开放：

| 用途 | 默认端口 |
| --- | --- |
| HTTP / 证书验证 | `80/tcp` |
| NaiveProxy / HTTPS 领取 | `443/tcp` |
| Hysteria2 | `443/udp` |
| 可选 UDP 端口跳跃 | `20000-50000/udp` |

TCP 和 UDP 可共用域名及端口号。领取后台只监听 `127.0.0.1:18765`，无需对公网开放该端口。

## 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash
```

入口下载完整项目到 `/opt/pixelcat/pixelcat-naiveproxy`，保留已有 `.env*`，随后打开语言选择和安装菜单。

```bash
cd /opt/pixelcat/pixelcat-naiveproxy
./deploy.sh --lang zh
./deploy.sh --help
```

语言支持 `zh`、`ru`、`fa`，也可用 `PIXELCAT_LANG=ru ./deploy.sh`。入口传参示例：

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash -s -- --lang ru
```

## 菜单

| 选项 | 操作 |
| --- | --- |
| 1 / 2 | 安装或更新 NaiveProxy / Hysteria2 |
| 3 / 4 | 卸载 NaiveProxy / Hysteria2 |
| 5 | 开启 BBR |
| 6 | IP 质量检测 |
| 7 | 流媒体解锁检测 |
| 8 | 网络质量 / 回程检测 |
| 9 | 生成一次性 sing-box 配置领取链接 |
| 0 | 退出 |

## 安装与配置

推荐交互输入密码，避免凭据进入 shell 历史或进程参数。

```bash
./deploy.sh --install
./deploy.sh --install-hysteria2
```

NaiveProxy 需要域名、用户名、密码和伪装网站域名；邮箱可选。伪装网站只填域名，例如 `www.example.com`，不能与代理域名相同。

HTTP 访问（包括直接访问服务器 IP）会以 308 跳转到配置的代理域名 HTTPS 地址，保留路径和查询参数；非默认 HTTPS 端口会写入跳转地址。直接通过 IP 访问 HTTPS 仍需要匹配的证书。已有部署需下载新版脚本后重新运行 `./deploy.sh --install` 才会应用；重新安装会重写 Caddyfile 并重启服务。

Hysteria2 优先沿用当前目录 NaiveProxy `.env` 的域名和密码，否则提示输入域名并生成密码。默认 UDP 443，跳跃范围 20000-50000，上下行限速为 0（不限速），伪装 URL 优先沿用 NaiveProxy，否则使用 https://www.bing.com。

```bash
./deploy.sh --install-hysteria2 --hy2-hop-range off
./deploy.sh --install --build-from-source
./deploy.sh --install --skip-start
```

- `--hy2-hop-range off`：关闭跳跃；`--hy2-hop-iface` 可指定网卡。
- `--hy2-port`、`--hy2-up-mbps`、`--hy2-down-mbps`、`--hy2-masquerade`：覆盖对应默认值。
- `--build-from-source`：强制 Go + xcaddy 本地编译。默认预编译下载会验证 SHA-256 和 forward_proxy 模块，失败时回退编译。
- `--skip-start`：生成配置但不启动服务，Hysteria2 安装同样支持。

证书优先使用 Caddy 同域名证书；没有时尝试签发。Hysteria2 ACME 回退要求 TCP 443 可用，已有 Caddy 无法提供证书时可能需要手动处理。端口跳跃优先 nftables，iptables 兜底。

## 客户端使用

安装结束会打印完整 sing-box JSON。将最外层大括号及全部内容保存为 `config.json`，再按客户端支持的方式导入本地配置。

**当前入口是 mixed，监听 `127.0.0.1:2080`（HTTP/SOCKS），未包含手机全局 VPN 的 TUN/DNS 配置，也不是小火箭订阅格式。** 服务安装成功不代表客户端端到端连接已验证。

配置含明文密码，请勿公开上传、截图或放进视频。

## 一次性配置领取

在包含 `.env` / `.env.hysteria2` 的服务器脚本目录选择菜单 9，或执行：

```bash
cd /opt/pixelcat/pixelcat-naiveproxy
./deploy.sh --one-time-link
./deploy.sh --one-time-link --link-ttl 300
```

输出示例：

```text
https://proxy.example.com:443/pixelcat-once/<随机密钥>
```

- 默认 600 秒有效，允许 30–3600 秒。
- 首次匹配的 GET 请求立即消耗链接，即使下载中断也不会恢复。HEAD 不消耗；错误密钥不能领取。
- 新链接撤销旧链接，不要多终端同时生成。不要预先打开链接；自动重试或订阅刷新会失败。
- 领取后保存为本地配置。合并本地环境文件与服务文件均存在的节点，优先使用 NaiveProxy，仍输出上述 mixed JSON。
- 取消当前链接：`sudo systemctl stop pixelcat-once.service`。

### 服务行为与限制

密钥为随机 256 位。准备文件权限为 0600，服务读入后删除，内容只留在进程内存；临时服务到期退出。后台不记录请求路径，响应禁止缓存；外部 CDN / 代理的日志和缓存策略需另外检查。

脚本验证、备份并修改 Caddyfile，然后重启 Caddy，已有连接可能短暂中断。重启失败时尝试恢复文件和服务。自定义日志或不支持的路由布局会拒绝自动修改。重新安装或卸载 NaiveProxy 会重写 Caddyfile，必要时重新生成链接。

一次性领取不能阻止他人抢先领取，也不能撤销已下载的凭据；凭据泄露仍需更换节点密码。

## 维护、更新与卸载

```bash
systemctl status pixelcat-naiveproxy --no-pager
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager
journalctl -u pixelcat-naiveproxy -f
journalctl -u pixelcat-hysteria2 -f
systemctl restart pixelcat-naiveproxy
systemctl restart pixelcat-hysteria2
```

| 数据 | 路径 |
| --- | --- |
| 节点环境文件 | 项目目录 `.env`、`.env.hysteria2` |
| Caddy 配置 / 数据 | `/etc/pixelcat-naiveproxy/Caddyfile` / `/var/lib/pixelcat-naiveproxy` |
| Hysteria2 配置 / 数据 | `/etc/pixelcat-hysteria2/config.yaml` / `/var/lib/pixelcat-hysteria2` |
| 领取程序 | `/usr/local/bin/pixelcat-one-time-link.py` |

重新执行安装入口更新脚本，再选择对应安装菜单更新节点。

```bash
./deploy.sh --uninstall
./deploy.sh --uninstall-hysteria2
```

NaiveProxy 卸载移除转发功能，保留 Caddy、证书和伪装服务；`--purge` 额外删除当前目录 `.env`。Hysteria2 默认保留配置和证书，`--purge` 会清理配置、证书数据与 `.env.hysteria2`。一次性服务请单独停止。

## 诊断与开发

```bash
./deploy.sh --bbr
./deploy.sh --ip-quality
./deploy.sh --unlock-check
./deploy.sh --net-quality
bash tests/i18n-smoke.sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

检测来源：[IPQuality](https://github.com/xykt/IPQuality)、[RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck)、[NetQuality](https://github.com/xykt/NetQuality)。执行前显示 URL 和 SHA-256；交互模式确认后运行，`-y` 或非交互模式自动继续。

测试覆盖并发领取、错误密钥、过期、HEAD/GET、配置合并和 Caddy 文本修改，不替代 Linux systemd、证书及客户端联网验证。

构建默认 Caddy `v2.11.7`、xcaddy `v0.4.7`、forwardproxy `naive`。可通过 `CADDY_VERSION`、`XCADDY_VERSION`、`CADDY_FORWARDPROXY_REF` 覆盖。发布 Release 或手动运行 Actions 的 `Build PixelCat Caddy` 生成 amd64/arm64 产物和校验文件。

Hysteria2 默认固定为 `app/v2.13.0`，可通过 `HY2_VERSION` 或 `HY2_RELEASE_BASE_URL` 覆盖。构建流程使用 Go `1.27.3`，本地源码编译至少需要 Go 1.26；旧工具链会自动更新。重新安装时会更新版本不匹配的 Caddy 和 xcaddy；预编译 Caddy 若版本不符则回退源码编译。`--build-from-source` 可强制重新编译。

## 项目链接

[官网](https://pixelcat.icu) · [YouTube](https://www.youtube.com/@PixelCatICU) · [GitHub](https://github.com/PixelCatICU) · [X](https://x.com/PixelCatICU)

许可证：[GNU GPL v3.0](LICENSE)。
