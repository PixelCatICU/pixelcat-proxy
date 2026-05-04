# 🐱 像素猫 - 科学上网ICU

「像素猫 - 科学上网ICU」是一个中文教程博客，主要整理科学上网工具配置、网络诊断、节点维护与隐私安全相关的实用经验。🚀

## 🎯 关注方向

- 🧰 科学上网工具的基础配置与故障排查
- 🌐 DNS、路由、延迟、丢包等网络问题的定位方法
- 🔐 面向普通用户的隐私安全与设备自护清单

⚠️ 这里的内容默认用于合法合规的学习、研究、远程办公与公开信息访问场景。任何配置都应该遵守所在地法律法规、学校或公司的网络使用政策。

## 📺 频道入口

- 🏠 [官网](https://pixelcat.icu/about/)
- ▶️ [YouTube 订阅](https://www.youtube.com/@PixelCatICU)
- 💻 [GitHub 地址](https://github.com/PixelCatICU)
- 🐦 [X](https://x.com/PixelCatICU)

# 🚀 NaiveProxy Docker 部署

这个项目提供一个 Docker Compose 部署：默认从 GitHub Container Registry 拉取已构建镜像，容器内运行带 NaiveProxy 支持的 Caddy，启动后由 Caddy 自动申请和续期 HTTPS 证书。🔒

## ✅ 前置条件

- 🌍 域名 `A/AAAA` 记录已经解析到这台服务器。
- 🛡️ 服务器防火墙和云厂商安全组放行 `80/tcp` 和 `443/tcp`。
- 🐳 Docker 和 Docker Compose 已安装。

## 🛠️ 使用已发布镜像部署

```bash
# 进入当前项目目录
cp .env.example .env
```

📝 编辑 `.env`：

```env
DOMAIN=proxy.example.com
USERNAME=your_user
PASSWORD=change_this_strong_password
DECOY_DOMAIN=www.example.com
EMAIL=admin@example.com
```

🚀 启动：

```bash
docker compose up -d
```

📜 查看日志：

```bash
docker compose logs -f
```

🛑 停止：

```bash
docker compose down
```

🧹 如果要连证书数据一起删除：

```bash
docker compose down -v
```

## ⚡ 一键部署脚本

### 方式一：交互式部署

在服务器执行：

```bash
mkdir -p /opt/pixelcat
cd /opt/pixelcat
git clone https://github.com/PixelCatICU/pixelcat-naiveproxy.git
cd pixelcat-naiveproxy
chmod +x deploy.sh
./deploy.sh
```

脚本会显示菜单：

```text
1) Install / Update
2) Uninstall
0) Exit
```

输入 `1` 后，按提示填写部署参数。

然后按提示输入：

- `DOMAIN`：代理域名，例如 `proxy.example.com`
- `USERNAME`：NaiveProxy 用户名
- `PASSWORD`：NaiveProxy 密码
- `DECOY_DOMAIN`：伪装网站域名，例如 `www.example.com`
- `EMAIL`：证书邮箱，可选

脚本会自动生成 `.env`，拉取 GHCR 镜像并启动服务。

如果服务器没有 Docker，脚本会提示自动安装 Docker Engine 和 Docker Compose 插件。

Docker 自动安装优先支持 Ubuntu、Debian、CentOS、RHEL、Rocky Linux、AlmaLinux、Fedora 和 Alpine。部分云厂商定制系统可能需要先手动安装 Docker。

### 方式二：带参数部署

也可以一次性传入参数：

```bash
./deploy.sh -y \
  --domain proxy.example.com \
  --username your_user \
  --password change_this_strong_password \
  --decoy-domain www.example.com \
  --email admin@example.com
```

生产环境更推荐交互式输入密码，因为 `--password` 参数可能被 shell 历史或进程列表记录。

### 方式三：只生成配置

只生成 `.env`，不启动容器：

```bash
./deploy.sh --skip-start
```

### 常用选项

不希望脚本自动安装 Docker：

```bash
./deploy.sh --no-install-docker
```

查看脚本帮助：

```bash
./deploy.sh --help
```

部署完成后查看日志：

```bash
docker compose logs -f
```

### 卸载服务

停止并删除 NaiveProxy 容器，保留证书和 Caddy 数据卷：

```bash
./deploy.sh --uninstall
```

完全卸载，连证书数据卷和 `.env` 一起删除：

```bash
./deploy.sh --uninstall --purge
```

免确认卸载：

```bash
./deploy.sh --uninstall -y
```

## 🐳 Dockge 部署

Dockge 里推荐使用这个项目的 `docker-compose.yml`，它会直接拉取：

```text
ghcr.io/pixelcaticu/pixelcat-naiveproxy:latest
```

服务器准备：

```bash
cd /opt/stacks
git clone git@github.com:PixelCatICU/pixelcat-naiveproxy.git
cd pixelcat-naiveproxy
cp .env.example .env
```

编辑 `.env` 后，在 Dockge 里启动 `pixelcat-naiveproxy` Stack。

更新镜像：

```bash
docker compose pull
docker compose up -d
```

也可以在 Dockge 面板里点更新镜像后重启 Stack。

## 🏗️ 本地构建部署

如果不想使用 GHCR 镜像，可以在服务器本地构建：

```bash
docker compose -f docker-compose.build.yml up -d --build
```

本地构建模式会使用当前目录的 [Dockerfile](./Dockerfile) 构建镜像。

## 📦 镜像发布

推送到 `main` 分支后，GitHub Actions 会自动构建并发布多架构镜像：

```text
ghcr.io/pixelcaticu/pixelcat-naiveproxy:latest
```

打版本标签也会发布对应版本镜像：

```bash
git tag v1.0.0
git push origin v1.0.0
```

发布后如果 GHCR Package 默认是私有，需要在 GitHub 仓库的 Packages 设置里改成 Public，服务器才能免登录拉取镜像。

## 📱 NaiveProxy 客户端配置

客户端代理地址通常填写：

```text
https://USERNAME:PASSWORD@DOMAIN
```

✨ 示例：

```text
https://your_user:change_this_strong_password@proxy.example.com
```

## ⚙️ 环境变量

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `DOMAIN` | 是 | 用于申请证书和访问代理的域名 |
| `USERNAME` | 是 | NaiveProxy Basic Auth 用户名 |
| `PASSWORD` | 是 | NaiveProxy Basic Auth 密码 |
| `DECOY_DOMAIN` | 是 | 反代伪装网站域名，普通浏览器访问 `DOMAIN` 时会显示该网站 |
| `EMAIL` | 否 | Let's Encrypt 账号邮箱 |
| `HTTP_PORT` | 否 | 宿主机 HTTP 端口，默认 `80` |
| `HTTPS_PORT` | 否 | 宿主机 HTTPS 端口，默认 `443` |

## ⚠️ 注意

- 🌍 首次启动需要公网访问到 `DOMAIN:80` 或 `DOMAIN:443`，否则证书申请会失败。
- 🎭 `DECOY_DOMAIN` 只填写域名，不要带 `https://`，例如 `www.example.com`。
- 💾 `caddy_data` 卷保存证书和 ACME 账号信息，不要随意删除。
- ☁️ 如果域名套了 CDN，需要确认 CDN 支持 HTTPS 代理流量，否则建议 DNS 记录先仅 DNS 解析，不启用代理。
