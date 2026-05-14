<p align="center">
  <img src="./pixel-cat.svg" alt="PixelCat" width="120" />
</p>

# PixelCat Proxy

PixelCat Proxy 是面向 Linux 服务器的中文一键部署脚本，用来部署和维护：

- **NaiveProxy**：使用 NaiveProxy 作者维护的 `github.com/klzgrad/forwardproxy` Caddy 插件，由 Caddy 提供 TLS、HTTP/2 CONNECT、Basic Auth、probe resistance 和伪装站点。
- **Hysteria2**：使用官方 Hysteria2 二进制，支持 UDP 端口跳跃。
- **节点维护工具**：BBR、IP 质量检测、流媒体解锁检测、网络质量/回程检测。

默认用途是合法合规的学习、研究、远程办公与公开信息访问。请遵守所在地法律法规以及学校、公司或服务商的网络使用政策。

## 入口

- 官网：[pixelcat.icu](https://pixelcat.icu)
- YouTube：[@PixelCatICU](https://www.youtube.com/@PixelCatICU)
- GitHub：[PixelCatICU](https://github.com/PixelCatICU)
- X：[@PixelCatICU](https://x.com/PixelCatICU)

## 架构

| 组件 | 服务名 | 协议 | 默认端口 | 说明 |
| --- | --- | --- | --- | --- |
| NaiveProxy | `pixelcat-naiveproxy.service` | HTTPS/TCP | `443/tcp` | Caddy + `klzgrad/forwardproxy@naive` |
| Hysteria2 | `pixelcat-hysteria2.service` | QUIC/UDP | `443/udp` | 官方 Hysteria2 server |
| 端口跳跃 | `pixelcat-hysteria2-hop.service` | UDP DNAT | `20000-50000/udp` | nftables 优先，iptables 兜底 |

NaiveProxy 的构建方式与官方 README 的 Caddy 示例一致：

```bash
xcaddy build \
  --with github.com/caddyserver/forwardproxy=github.com/klzgrad/forwardproxy@naive
```

也就是说：

- 使用的是 `klzgrad/forwardproxy` 的 `naive` 分支。
- 服务端不是独立 `naive` 二进制，而是带 NaiveProxy padding layer 的 Caddy 插件。

## 系统要求

- Linux + systemd。
- Debian / Ubuntu / RHEL 系 / Fedora / Alpine 等常见发行版。
- 支持 `amd64` 和 `arm64`。
- 域名 `A/AAAA` 记录已解析到服务器。
- 防火墙和云安全组放行：
  - NaiveProxy：`80/tcp`、`443/tcp`
  - Hysteria2：`443/udp`
  - 端口跳跃：默认 `20000-50000/udp`

脚本会自动安装基础依赖。预编译 Caddy 不可用时，会自动安装 Go 和 xcaddy 在本机编译。

## 一键安装

在服务器执行：

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash
```

入口脚本会下载源码到：

```text
/opt/pixelcat/pixelcat-naiveproxy
```

然后启动中文菜单。

如果已经把项目放到服务器，也可以直接运行：

```bash
cd /path/to/pixelcat-naiveproxy
./deploy.sh
```

## 菜单

```text
1) 安装 / 更新 PixelCat NaiveProxy
2) 安装 / 更新 PixelCat Hysteria2
3) 卸载 PixelCat NaiveProxy
4) 卸载 PixelCat Hysteria2
5) 一键开启 BBR
6) IP 质量检测           (xykt/IPQuality)
7) 流媒体解锁检测         (lmc999/RegionRestrictionCheck)
8) 网络质量 / 回程检测     (xykt/NetQuality)
0) 退出
```

查看全部参数：

```bash
./deploy.sh --help
```

## 安装 NaiveProxy

交互式安装：

```bash
./deploy.sh
```

菜单选择 `1`，按提示填写：

- 代理域名，例如 `proxy.example.com`
- 用户名
- 密码
- 伪装站点域名，例如 `www.example.com`，不要带 `https://`
- Let's Encrypt 邮箱，可留空
- HTTP 端口，默认 `80`
- HTTPS 端口，默认 `443`

非交互安装：

```bash
./deploy.sh --install -y \
  --domain proxy.example.com \
  --username your_user \
  --password change_this_strong_password \
  --decoy-domain www.example.com \
  --email admin@example.com
```

生产环境更推荐交互式输入密码，因为 `--password` 可能被 shell 历史或进程列表记录。

强制本地编译 Caddy：

```bash
./deploy.sh --install --build-from-source
```

只写入配置，不启动服务：

```bash
./deploy.sh --install --skip-start
```

### NaiveProxy 文件

```text
/usr/local/bin/pixelcat-naiveproxy-caddy
/etc/pixelcat-naiveproxy/Caddyfile
/var/lib/pixelcat-naiveproxy
/etc/systemd/system/pixelcat-naiveproxy.service
/opt/pixelcat/pixelcat-naiveproxy/.env
```

### NaiveProxy 命令

```bash
systemctl status pixelcat-naiveproxy --no-pager
journalctl -u pixelcat-naiveproxy -f
systemctl restart pixelcat-naiveproxy
/usr/local/bin/pixelcat-naiveproxy-caddy list-modules | grep forward_proxy
```

### NaiveProxy 卸载

移除 NaiveProxy 转发配置，保留 Caddy 服务、证书目录和 Hysteria2 数据：

```bash
./deploy.sh --uninstall
```

同时删除当前项目目录下的 NaiveProxy `.env`：

```bash
./deploy.sh --uninstall --purge
```

说明：

- `--uninstall` 会去掉 Caddyfile 里的 `forward_proxy` 配置，让 Caddy 只保留伪装站点和证书能力。
- `/var/lib/pixelcat-naiveproxy` 默认保留，因为 Hysteria2 可能正在复用这里的证书。
- `pixelcat-naiveproxy.service` 默认保留，这是证书和伪装站点的基础服务。

免确认卸载：

```bash
./deploy.sh --uninstall -y
```

## 安装 Hysteria2

交互式安装：

```bash
./deploy.sh
```

菜单选择 `2`，按提示填写：

- Hysteria2 域名：如果当前目录已有 NaiveProxy `.env`，默认沿用 `DOMAIN`。
- Hysteria2 密码：如果当前目录已有 NaiveProxy `.env`，默认沿用 `PASSWORD`；否则自动生成。
- UDP 监听端口：默认 `443`。
- 端口跳跃范围：默认 `20000-50000`，输入 `off` 关闭。
- 上行/下行限速 Mbps：默认 `0`，表示不限速。
- 伪装 URL：优先沿用 `https://DECOY_DOMAIN`，否则默认 `https://www.bing.com`。

非交互安装：

```bash
./deploy.sh --install-hysteria2 -y \
  --hy2-domain proxy.example.com \
  --hy2-port 443 \
  --hy2-hop-range 20000-50000 \
  --hy2-up-mbps 0 \
  --hy2-down-mbps 0 \
  --hy2-masquerade https://www.bing.com
```

只安装 Hysteria2，并复用现有 NaiveProxy `.env`：

```bash
./deploy.sh --install-hysteria2 -y
```

关闭端口跳跃：

```bash
./deploy.sh --install-hysteria2 -y --hy2-hop-range off
```

只写入配置，不启动服务：

```bash
./deploy.sh --install-hysteria2 --skip-start
```

### Hysteria2 证书

安装 Hysteria2 时，脚本会先确保 `pixelcat-naiveproxy.service` 存在：

- 如果 `/var/lib/pixelcat-naiveproxy` 下已经有同域名证书，Hysteria2 会直接复用。
- 证书查找会遍历 Caddy 的证书存储，不再只依赖 Let's Encrypt 单一路径。
- 如果没有可复用证书，脚本会先尝试让 PixelCat Caddy 为该域名签出证书。
- 如果 Caddy 原本没有运行且签证书超时，脚本会停止临时 Caddy 服务，再让 Hysteria2 自己申请 ACME 证书，避免两边抢占 `443/tcp`。
- 如果 Caddy 原本已经在运行但仍没有该域名证书，脚本会停止安装并提示手动处理，避免打断现有 NaiveProxy 服务。
- Hysteria2 自申请 ACME 时需要 `443/tcp` 可用于 TLS-ALPN-01 校验。
- 先安装 Hysteria2、后安装 NaiveProxy 也可以；同域名场景下后续会优先复用 `/var/lib/pixelcat-naiveproxy` 里的 Caddy 证书。

### Hysteria2 文件

```text
/usr/local/bin/pixelcat-hysteria2
/etc/pixelcat-hysteria2/config.yaml
/etc/pixelcat-hysteria2/hop-up.sh
/etc/pixelcat-hysteria2/hop-down.sh
/var/lib/pixelcat-hysteria2
/etc/systemd/system/pixelcat-hysteria2.service
/etc/systemd/system/pixelcat-hysteria2-hop.service
/etc/sysctl.d/99-pixelcat-hysteria2.conf
/opt/pixelcat/pixelcat-naiveproxy/.env.hysteria2
```

### Hysteria2 命令

```bash
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager
journalctl -u pixelcat-hysteria2 -f
systemctl restart pixelcat-hysteria2
nft list table inet pixelcat-hy 2>/dev/null || iptables -t nat -L PREROUTING -n
```

### Hysteria2 卸载

停止并删除 Hysteria2 服务，保留配置和证书数据：

```bash
./deploy.sh --uninstall-hysteria2
```

彻底清理 Hysteria2 配置、证书数据和 `.env.hysteria2`：

```bash
./deploy.sh --uninstall-hysteria2 --purge
```

免确认卸载：

```bash
./deploy.sh --uninstall-hysteria2 -y
```

## 客户端配置

部署完成后，脚本会自动打印 sing-box 客户端配置。

NaiveProxy 示例：

```json
{
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

Hysteria2 示例：

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

客户端配置包含明文密码，不要公开展示或截图。

## 诊断工具

```bash
./deploy.sh --bbr
./deploy.sh --ip-quality
./deploy.sh --unlock-check
./deploy.sh --net-quality
```

来源：

- `--ip-quality`：[xykt/IPQuality](https://github.com/xykt/IPQuality)
- `--unlock-check`：[lmc999/RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck)
- `--net-quality`：[xykt/NetQuality](https://github.com/xykt/NetQuality)

说明：

- BBR 会写入 `/etc/sysctl.d/99-pixelcat-bbr.conf`。
- 诊断脚本会尽量自动安装 `jq`、`dig`、`mtr`、`iperf3`、`bc`、`imagemagick`、`nexttrace` 等依赖。
- 执行第三方远程脚本前会显示来源 URL 和本次下载 SHA256；交互模式需要确认，`-y` 或非交互模式会自动继续。
- 部分检测项需要 root 权限和完整网络连通性。
- 第三方脚本可能在生成报告后仍返回非 0 状态码，脚本会保留提示。

## 配置变量

NaiveProxy：

| 变量 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `DOMAIN` | 是 | - | 代理域名 |
| `USERNAME` | 是 | - | Basic Auth 用户名 |
| `PASSWORD` | 是 | - | Basic Auth 密码 |
| `DECOY_DOMAIN` | 是 | - | 伪装站点域名，不带协议 |
| `EMAIL` | 否 | 空 | Let's Encrypt 邮箱 |
| `HTTP_PORT` | 否 | `80` | HTTP 端口 |
| `HTTPS_PORT` | 否 | `443` | HTTPS 代理端口 |

Hysteria2：

| 变量 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `HY2_DOMAIN` | 是 | 优先沿用 `.env` 的 `DOMAIN` | TLS SNI 域名 |
| `HY2_PASSWORD` | 是 | 优先沿用 `.env` 的 `PASSWORD`，否则自动生成 | 客户端密码 |
| `HY2_PORT` | 否 | `443` | UDP 监听端口 |
| `HY2_HOP_RANGE` | 否 | `20000-50000` | 端口跳跃范围，`off` 关闭 |
| `HY2_HOP_IFACE` | 否 | 自动检测默认路由网卡 | DNAT 使用的网卡 |
| `HY2_UP_MBPS` | 否 | `0` | 上行限速 Mbps |
| `HY2_DOWN_MBPS` | 否 | `0` | 下行限速 Mbps |
| `HY2_MASQUERADE_URL` | 否 | 优先沿用 `https://DECOY_DOMAIN`，否则 `https://www.bing.com` | 伪装 URL |

## 发布预编译 Caddy

GitHub Actions 会构建：

```text
pixelcat-naiveproxy-caddy-linux-amd64.tar.gz
pixelcat-naiveproxy-caddy-linux-arm64.tar.gz
```

每个产物会同时上传 `.sha256`。部署脚本会强制校验：

- 校验和文件下载失败：拒绝使用，回退本地编译。
- 校验和不匹配：拒绝使用，回退本地编译。
- 二进制不包含 `http.handlers.forward_proxy`：拒绝使用，回退本地编译。
- 缺少 `sha256sum`：回退本地编译。

构建版本默认固定为：

```text
Go: 1.25.x
Caddy: v2.11.2
xcaddy: v0.4.5
forwardproxy: naive
```

本地编译时也会使用 `CADDY_VERSION`、`XCADDY_VERSION`、`CADDY_FORWARDPROXY_REF` 这三个变量，必要时可在运行脚本前覆盖。

发布方式：

```bash
git tag v1.0.0
git push origin v1.0.0
```

然后在 GitHub Release 页面发布这个 tag，也可以在 GitHub Actions 页面手动运行 `Build PixelCat Caddy`。

## 注意事项

- 首次申请证书时，公网必须能访问对应域名和端口。
- `DECOY_DOMAIN` 只填域名，例如 `www.example.com`。
- 复杂网站可能因为 Cookie、CSP、WebSocket 或静态资源跨域限制导致反代显示不完整。
- `/var/lib/pixelcat-naiveproxy` 和 `/var/lib/pixelcat-hysteria2` 保存证书和 ACME 数据，不要随意删除。
- 如果域名套了 CDN，请确认 CDN 支持相关代理流量；不确定时先使用仅 DNS 解析。
- OpenVZ 等不支持 nftables/iptables NAT 的环境，建议关闭 Hysteria2 端口跳跃。

## 开源协议

本项目采用 [GNU General Public License v3.0](./LICENSE) 开源协议。
