<p align="center">
  <img src="./pixel-cat.svg" alt="PixelCat" width="120" />
</p>

# 像素猫 - PixelCat Proxy

PixelCat Proxy 是一份面向 Linux 服务器的中文一键部署脚本,用于部署和维护:

- PixelCat NaiveProxy: 下载并运行 `klzgrad/naiveproxy` 官方预编译 `naive` 二进制,由 Caddy 提供 TLS、证书和伪装站点。
- PixelCat Hysteria2: QUIC/UDP 代理,支持端口跳跃。
- 常用节点维护能力: BBR、IP 质量检测、流媒体解锁检测、网络质量/回程检测。

默认场景是合法合规的学习、研究、远程办公与公开信息访问。请遵守所在地法律法规以及学校、公司或服务商的网络使用政策。

## 频道入口

- 官网: [pixelcat.icu](https://pixelcat.icu)
- YouTube: [@PixelCatICU](https://www.youtube.com/@PixelCatICU)
- GitHub: [PixelCatICU](https://github.com/PixelCatICU)
- X: [@PixelCatICU](https://x.com/PixelCatICU)

## 功能概览

| 功能 | 协议/工具 | 默认端口 | 说明 |
| --- | --- | --- | --- |
| NaiveProxy | HTTPS/TCP | `443/tcp` | 官方 `klzgrad/naiveproxy` 后端 + Caddy TLS 前端,普通浏览器访问时反代伪装网站 |
| Hysteria2 | QUIC/UDP | `443/udp` | 支持 nftables/iptables 端口跳跃 |
| BBR | Linux sysctl | - | 写入 `/etc/sysctl.d/99-pixelcat-bbr.conf` |
| IP 质量检测 | xykt/IPQuality | - | 检测原生 IP、风险标签、黑名单、部分解锁状态 |
| 流媒体解锁检测 | lmc999/RegionRestrictionCheck | - | 检测主流流媒体和区域解锁 |
| 网络质量/回程检测 | xykt/NetQuality | - | 检测延迟、测速、回程线路 |

主要特性:

- 中文菜单和 CLI 参数两种使用方式。
- NaiveProxy 使用官方 `klzgrad/naiveproxy` release 预编译包。
- Caddy 独立负责 TLS、证书和伪装站点。
- Hysteria2 官方二进制强制校验 `hashes.txt`。
- systemd 专用用户 `pixelcat-proxy`,默认不裸跑 root 服务进程。
- 配置文件和密码文件权限收紧。
- 安装、更新、卸载、彻底清理都在同一脚本中完成。

## 系统要求

- Linux + systemd。
- Debian / Ubuntu / RHEL 系 / Fedora / Alpine 等常见发行版。
- 域名 `A/AAAA` 记录已解析到服务器。
- 防火墙和云安全组按需放行:
  - NaiveProxy: `80/tcp`, `443/tcp`
  - Hysteria2: `443/udp`,以及端口跳跃范围,默认 `20000-50000/udp`
- 脚本会自动安装基础依赖;NaiveProxy 官方包下载失败会中止安装,Caddy 预编译包不可用时会自动安装 Go 和 xcaddy 本地编译。

## 一键安装

在服务器执行:

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-proxy/main/install.sh | bash
```

这个入口脚本会下载当前 `main` 分支源码到:

```text
/opt/pixelcat/pixelcat-naiveproxy
```

然后启动 `deploy.sh` 中文菜单。

如果你已经把项目放到了服务器上,也可以直接运行:

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

查看全部参数:

```bash
./deploy.sh --help
```

## NaiveProxy 部署

交互式部署:

```bash
./deploy.sh
```

菜单选择 `1`,然后按提示填写:

- 代理域名: 例如 `proxy.example.com`
- 代理用户名
- 代理密码
- 伪装网站域名: 例如 `www.example.com`,不要带 `https://`
- Let's Encrypt 邮箱: 可留空
- HTTP 端口: 默认 `80`
- HTTPS 端口: 默认 `443`

带参数部署:

```bash
./deploy.sh --install -y \
  --domain proxy.example.com \
  --username your_user \
  --password change_this_strong_password \
  --decoy-domain www.example.com \
  --email admin@example.com
```

生产环境更推荐交互式输入密码,因为 `--password` 可能被 shell 历史或进程列表记录。

强制本地编译 PixelCat Caddy:

```bash
./deploy.sh --install --build-from-source
```

只生成配置,不启动服务:

```bash
./deploy.sh --install --skip-start
```

### NaiveProxy 文件位置

```text
/usr/local/bin/pixelcat-caddy
/usr/local/bin/pixelcat-naiveproxy
/etc/pixelcat-caddy/Caddyfile
/etc/pixelcat-naiveproxy/config.json
/var/lib/pixelcat-caddy
/var/lib/pixelcat-naiveproxy
/etc/systemd/system/pixelcat-caddy.service
/etc/systemd/system/pixelcat-naiveproxy.service
/opt/pixelcat/pixelcat-naiveproxy/.env
```

### NaiveProxy 常用命令

```bash
systemctl status pixelcat-caddy --no-pager
systemctl status pixelcat-naiveproxy --no-pager
journalctl -u pixelcat-caddy -f
systemctl restart pixelcat-caddy
```

### NaiveProxy 卸载

保留配置和证书数据:

```bash
./deploy.sh --uninstall
```

删除 NaiveProxy 本地 `.env`:

```bash
./deploy.sh --uninstall --purge
```

`pixelcat-caddy`、Caddy 证书目录和 Hysteria2 相关文件会保留,避免影响其他协议复用证书。

免确认卸载:

```bash
./deploy.sh --uninstall -y
```

## Hysteria2 部署

交互式部署:

```bash
./deploy.sh
```

菜单选择 `2`,然后按提示填写:

- Hysteria2 域名: 如果当前目录已有 NaiveProxy `.env`,默认沿用 `DOMAIN`。
- Hysteria2 密码: 如果当前目录已有 NaiveProxy `.env`,默认沿用 `PASSWORD`;没有可复用密码时才自动生成随机密码。
- 监听 UDP 端口: 默认 `443`。
- 端口跳跃范围: 默认 `20000-50000`,输入 `off` 关闭。
- 上行/下行限速 Mbps: 默认 `0`,表示不限速。
- 伪装 URL: 如果当前目录已有 NaiveProxy `.env`,默认沿用 `https://DECOY_DOMAIN`;否则默认 `https://www.bing.com`。

带参数部署:

```bash
./deploy.sh --install-hysteria2 -y \
  --hy2-domain proxy.example.com \
  --hy2-port 443 \
  --hy2-hop-range 20000-50000 \
  --hy2-up-mbps 0 \
  --hy2-down-mbps 0 \
  --hy2-masquerade https://www.bing.com
```

只安装 Hysteria2 且复用现有 NaiveProxy 配置时,可以直接执行:

```bash
./deploy.sh --install-hysteria2 -y
```

显式传入 `--hy2-domain`、`--hy2-password` 或 `--hy2-masquerade` 时,会覆盖从 NaiveProxy `.env` 读取到的默认值。

关闭端口跳跃:

```bash
./deploy.sh --install-hysteria2 -y --hy2-hop-range off
```

只生成配置,不启动服务:

```bash
./deploy.sh --install-hysteria2 --skip-start
```

### Hysteria2 证书逻辑

- 安装 Hysteria2 前会先检查 `pixelcat-caddy.service`。
- 如果 Caddy 已存在且已有同域名证书,脚本会优先复用 `/var/lib/pixelcat-caddy` 下的证书。
- 如果 Caddy 不存在,脚本会先安装并启动 PixelCat Caddy,再继续安装 Hysteria2。
- 如果没有可复用证书,Hysteria2 会自己使用 ACME 申请证书。
- Hysteria2 自申请 ACME 时需要 `443/tcp` 可用于 TLS-ALPN-01 校验。

### Hysteria2 文件位置

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

### Hysteria2 常用命令

```bash
systemctl status pixelcat-hysteria2 --no-pager
systemctl status pixelcat-hysteria2-hop --no-pager
journalctl -u pixelcat-hysteria2 -f
systemctl restart pixelcat-hysteria2
nft list table inet pixelcat-hy 2>/dev/null || iptables -t nat -L PREROUTING -n
```

### Hysteria2 卸载

保留配置和证书数据:

```bash
./deploy.sh --uninstall-hysteria2
```

彻底清理配置、证书数据和 `.env.hysteria2`:

```bash
./deploy.sh --uninstall-hysteria2 --purge
```

免确认卸载:

```bash
./deploy.sh --uninstall-hysteria2 -y
```

## BBR

菜单选择 `5`,或直接执行:

```bash
./deploy.sh --bbr
```

检查当前状态:

```bash
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

脚本会写入:

```conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
```

## 节点诊断工具

三个诊断入口会下载并运行第三方检测脚本:

```bash
./deploy.sh --ip-quality
./deploy.sh --unlock-check
./deploy.sh --net-quality
```

来源:

- `--ip-quality`: [xykt/IPQuality](https://github.com/xykt/IPQuality)
- `--unlock-check`: [lmc999/RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck)
- `--net-quality`: [xykt/NetQuality](https://github.com/xykt/NetQuality)

说明:

- 脚本会尽量自动安装 `jq`、`dig`、`mtr`、`iperf3`、`bc`、`imagemagick`、`nexttrace` 等检测依赖。
- 部分检测项需要 root 权限或完整网络连通性。
- 第三方脚本可能在生成报告后仍返回非 0 状态码,这种情况会显示报告链接,同时提示执行返回码。
- 网络质量/回程检测耗时较长,可能受目标测速点、BGP 数据源或路由探测可用性影响。

## 客户端配置

部署完成后脚本会自动打印对应协议的 sing-box 配置。

NaiveProxy 输出示例:

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

Hysteria2 输出示例:

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

客户端配置包含明文密码,不要在公开场合展示或截图。

## 配置变量

NaiveProxy:

| 变量 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `DOMAIN` | 是 | - | 代理域名 |
| `USERNAME` | 是 | - | Basic Auth 用户名 |
| `PASSWORD` | 是 | - | Basic Auth 密码 |
| `DECOY_DOMAIN` | 是 | - | 伪装站点域名,不要带协议 |
| `EMAIL` | 否 | 空 | Let's Encrypt 邮箱 |
| `HTTP_PORT` | 否 | `80` | HTTP 端口 |
| `HTTPS_PORT` | 否 | `443` | HTTPS 代理端口 |

Hysteria2:

| 变量 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- |
| `HY2_DOMAIN` | 是 | 优先沿用 `.env` 里的 `DOMAIN` | TLS SNI 域名 |
| `HY2_PASSWORD` | 是 | 优先沿用 `.env` 里的 `PASSWORD`,否则自动生成 | 客户端密码 |
| `HY2_PORT` | 否 | `443` | UDP 监听端口 |
| `HY2_HOP_RANGE` | 否 | `20000-50000` | 端口跳跃范围,留空或 `off` 关闭 |
| `HY2_HOP_IFACE` | 否 | 自动检测 | DNAT 使用的网卡 |
| `HY2_UP_MBPS` | 否 | `0` | 上行限速 Mbps |
| `HY2_DOWN_MBPS` | 否 | `0` | 下行限速 Mbps |
| `HY2_MASQUERADE_URL` | 否 | 优先沿用 `.env` 里的 `https://DECOY_DOMAIN`,否则 `https://www.bing.com` | 伪装站点 URL |

## 发布预编译 PixelCat Caddy

发布 GitHub Release 时,GitHub Actions 会构建:

```text
pixelcat-caddy-linux-amd64.tar.gz
pixelcat-caddy-linux-arm64.tar.gz
```

每个产物会同时上传 `.sha256` 文件。部署脚本会强制校验:

- 校验和文件下载失败: 拒绝使用,回退本地编译。
- 校验和不匹配: 拒绝使用,回退本地编译。
- 缺少 `sha256sum`: 回退本地编译。

发布方式:

```bash
git tag v1.0.0
git push origin v1.0.0
```

然后在 GitHub Release 页面发布这个 tag。也可以在 GitHub Actions 页面手动运行 `Build PixelCat Caddy`。

## 开源协议

本项目采用 [GNU General Public License v3.0](./LICENSE) 开源协议。

你可以自由使用、复制、修改和分发本项目代码;如果分发修改版或基于本项目的衍生作品,需要继续按照 GPLv3 开源,并保留原版权声明和许可证文本。

## 注意事项

- 首次申请证书时,公网必须能访问到对应域名和端口。
- `DECOY_DOMAIN` 只填域名,例如 `www.example.com`。
- 复杂网站可能因为 Cookie、CSP、WebSocket 或静态资源跨域限制导致反代显示不完整。
- `/var/lib/pixelcat-caddy` 和 `/var/lib/pixelcat-hysteria2` 保存证书和 ACME 数据,不要随意删除。
- 如果域名套了 CDN,请确认 CDN 支持相关代理流量;不确定时先使用仅 DNS 解析。
- OpenVZ 等不支持 nftables/iptables NAT 的环境,建议关闭 Hysteria2 端口跳跃。
