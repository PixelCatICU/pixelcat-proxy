# 🐱 像素猫 - 科学上网ICU

「像素猫 - 科学上网ICU」是一个中文教程博客，主要整理科学上网工具配置、网络诊断、节点维护与隐私安全相关的实用经验。🚀

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

# 🚀 NaiveProxy 直装部署

这个项目提供 NaiveProxy 一键部署脚本：不依赖 Docker，直接在服务器上编译带 `forwardproxy` 插件的 Caddy，并通过 `systemd` 运行 NaiveProxy。Caddy 会自动申请和续期 HTTPS 证书。🔒

## ✨ 功能

- ⚡ 不用 Docker，直接安装到宿主机
- 🔐 自动申请和续期 Let's Encrypt 证书
- 🎭 支持反代伪装网站域名
- 📱 部署完成后自动打印 sing-box 客户端配置
- 🚀 菜单内置一键开启 BBR
- 🧹 支持安装、更新、卸载和彻底清理

## ✅ 前置条件

- 🌍 域名 `A/AAAA` 记录已经解析到这台服务器。
- 🛡️ 服务器防火墙和云厂商安全组放行 `80/tcp` 和 `443/tcp`。
- 🧱 系统需要 Linux + systemd。
- 📦 脚本会自动安装基础依赖、Go、xcaddy，并编译 Caddy。

## ⚡ 一键部署脚本

### ⭐ 方式一：交互式部署（推荐） ⭐

> ✅ 推荐新手优先使用这个方式：复制一条命令运行，然后按中文菜单输入 `1` 安装即可。

在服务器执行：

```bash
curl -fsSL https://raw.githubusercontent.com/PixelCatICU/pixelcat-naiveproxy/main/install.sh | bash
```

这个入口脚本会自动执行：

```bash
mkdir -p /opt/pixelcat
cd /opt/pixelcat
git clone https://github.com/PixelCatICU/pixelcat-naiveproxy.git
cd pixelcat-naiveproxy
chmod +x deploy.sh
./deploy.sh
```

如果项目已经存在，它会自动进入 `/opt/pixelcat/pixelcat-naiveproxy` 拉取最新代码，然后启动 `deploy.sh` 菜单。

脚本会显示中文菜单：

```text
1) 安装 / 更新 NaiveProxy
2) 卸载 NaiveProxy
3) 一键开启 BBR
0) 退出
```

输入 `1` 后，按中文提示填写部署参数：

- `代理域名`：例如 `proxy.example.com`
- `NaiveProxy 用户名`：客户端连接用的用户名
- `NaiveProxy 密码`：客户端连接用的密码
- `伪装网站域名`：例如 `www.example.com`
- `证书邮箱`：Let's Encrypt 邮箱，可留空
- `HTTP 端口`：默认 `80`
- `HTTPS 端口`：默认 `443`

部署完成后，脚本会打印：

- ✅ systemd 服务状态命令
- 🔗 NaiveProxy 代理地址
- 📱 sing-box 客户端配置
- 📜 日志查看命令

### 方式二：带参数部署

也可以一次性传入参数：

```bash
./deploy.sh --install -y \
  --domain proxy.example.com \
  --username your_user \
  --password change_this_strong_password \
  --decoy-domain www.example.com \
  --email admin@example.com
```

生产环境更推荐交互式输入密码，因为 `--password` 参数可能被 shell 历史或进程列表记录。

### 方式三：只生成配置

只生成 `.env`、Caddyfile 和 systemd 配置，不启动服务：

```bash
./deploy.sh --install --skip-start
```

### 🚀 一键开启 BBR

交互菜单输入 `3`，或直接执行：

```bash
./deploy.sh --bbr
```

脚本会写入 `/etc/sysctl.d/99-pixelcat-bbr.conf` 并执行 `sysctl --system`：

```conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
```

查看当前 BBR 状态：

```bash
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

### 常用命令

查看服务状态：

```bash
systemctl status pixelcat-naiveproxy --no-pager
```

查看日志：

```bash
journalctl -u pixelcat-naiveproxy -f
```

重启服务：

```bash
systemctl restart pixelcat-naiveproxy
```

查看脚本帮助：

```bash
./deploy.sh --help
```

## 🧹 卸载服务

停止并删除 NaiveProxy systemd 服务，保留配置和证书数据：

```bash
./deploy.sh --uninstall
```

完全卸载，连配置、证书数据、本地 Go 工具和 `.env` 一起删除：

```bash
./deploy.sh --uninstall --purge
```

免确认卸载：

```bash
./deploy.sh --uninstall -y
```

## 📱 NaiveProxy 客户端配置

客户端代理地址通常填写：

```text
https://USERNAME:PASSWORD@DOMAIN
```

✨ 示例：

```text
https://your_user:change_this_strong_password@proxy.example.com
```

部署完成后脚本会自动打印 sing-box 配置。结构类似：

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
| `USERNAME` | 是 | NaiveProxy Basic Auth 用户名 |
| `PASSWORD` | 是 | NaiveProxy Basic Auth 密码 |
| `DECOY_DOMAIN` | 是 | 反代伪装网站域名，普通浏览器访问 `DOMAIN` 时会跳转或反代到该网站 |
| `EMAIL` | 否 | Let's Encrypt 账号邮箱 |
| `HTTP_PORT` | 否 | HTTP 端口，默认 `80` |
| `HTTPS_PORT` | 否 | HTTPS/NaiveProxy 端口，默认 `443` |

脚本会把配置保存到当前项目的 `.env`，并把 Caddyfile 写入：

```text
/etc/pixelcat-naiveproxy/Caddyfile
```

证书和 Caddy 数据默认保存到：

```text
/var/lib/pixelcat-naiveproxy
```

## ⚠️ 注意

- 🌍 首次启动需要公网访问到 `DOMAIN:80` 和 `DOMAIN:443`，否则证书申请可能失败。
- 🎭 `DECOY_DOMAIN` 只填写域名，不要带 `https://`，例如 `www.example.com`。
- 💾 `/var/lib/pixelcat-naiveproxy` 保存证书和 ACME 账号信息，不要随意删除。
- ☁️ 如果域名套了 CDN，需要确认 CDN 支持 NaiveProxy 所需的 HTTPS 代理流量，否则建议 DNS 记录先仅 DNS 解析，不启用代理。

## 🐳 Docker 镜像部署（可选）

这个项目仍保留 Dockerfile 和 compose 文件，适合需要容器化的用户。当前推荐方式是上面的直装脚本。

```bash
cp .env.example .env
docker compose up -d
```

查看日志：

```bash
docker compose logs -f
```

停止：

```bash
docker compose down
```

## 📦 镜像发布（可选）

推送到 `main` 分支后，GitHub Actions 会自动构建并发布多架构镜像：

```text
ghcr.io/pixelcaticu/pixelcat-naiveproxy:latest
```

打版本标签也会发布对应版本镜像：

```bash
git tag v1.0.0
git push origin v1.0.0
```
