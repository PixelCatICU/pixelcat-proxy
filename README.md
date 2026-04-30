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

这个项目提供一个 Docker Compose 部署：容器内自动构建带 NaiveProxy 支持的 Caddy，启动后由 Caddy 自动申请和续期 HTTPS 证书。🔒

## ✅ 前置条件

- 🌍 域名 `A/AAAA` 记录已经解析到这台服务器。
- 🛡️ 服务器防火墙和云厂商安全组放行 `80/tcp` 和 `443/tcp`。
- 🐳 Docker 和 Docker Compose 已安装。

## 🛠️ 使用

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
docker compose up -d --build
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
