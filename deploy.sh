#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="${DOMAIN:-}"
USERNAME="${USERNAME:-}"
PASSWORD="${PASSWORD:-}"
DECOY_DOMAIN="${DECOY_DOMAIN:-}"
EMAIL="${EMAIL:-}"
HTTP_PORT="${HTTP_PORT:-}"
HTTPS_PORT="${HTTPS_PORT:-}"
ASSUME_YES="false"
SKIP_START="false"
PASSWORD_FROM_ARG="false"
ACTION="menu"
PURGE="false"
INSTALL_DIR="/etc/pixelcat-naiveproxy"
DATA_DIR="/var/lib/pixelcat-naiveproxy"
CADDY_BIN="/usr/local/bin/caddy-naiveproxy"
SERVICE_FILE="/etc/systemd/system/pixelcat-naiveproxy.service"
GO_ROOT="/usr/local/go-pixelcat"
GO_BIN=""
XCADDY_BIN="/usr/local/bin/xcaddy"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://github.com/PixelCatICU/pixelcat-naiveproxy/releases/latest/download}"
BUILD_FROM_SOURCE="false"

usage() {
  cat <<'USAGE'
PixelCat NaiveProxy 一键脚本

用法:
  ./deploy.sh                 显示中文菜单
  ./deploy.sh --install       安装或更新 NaiveProxy
  ./deploy.sh --uninstall     卸载 NaiveProxy
  ./deploy.sh --bbr           一键开启 BBR
  ./deploy.sh --domain proxy.example.com --username user --password pass --decoy-domain www.example.com --email admin@example.com

选项:
      --install         安装或更新 NaiveProxy
      --uninstall       停止并删除 NaiveProxy systemd 服务
      --purge           配合 --uninstall 使用，同时删除配置和证书数据
      --bbr             一键开启 BBR
      --build-from-source
                        跳过预编译文件下载，直接本地编译 Caddy
  -d, --domain          代理域名，必填
  -u, --username        NaiveProxy 用户名，必填
  -p, --password        NaiveProxy 密码，必填
      --decoy-domain    伪装网站域名，必填
  -e, --email           Let's Encrypt 证书邮箱，可选
      --http-port       宿主机 HTTP 端口，默认 80
      --https-port      宿主机 HTTPS 端口，默认 443
  -y, --yes             自动确认覆盖 .env
      --skip-start      只生成配置，不启动服务
  -h, --help            显示帮助
USAGE
}

require_option_value() {
  local option="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    echo "$option 需要一个值。" >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install)
      ACTION="install"
      shift
      ;;
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    --purge)
      PURGE="true"
      shift
      ;;
    --bbr)
      ACTION="bbr"
      shift
      ;;
    --build-from-source)
      BUILD_FROM_SOURCE="true"
      shift
      ;;
    -d|--domain)
      require_option_value "$1" "${2:-}"
      DOMAIN="${2:-}"
      shift 2
      ;;
    -u|--username)
      require_option_value "$1" "${2:-}"
      USERNAME="${2:-}"
      shift 2
      ;;
    -p|--password)
      require_option_value "$1" "${2:-}"
      PASSWORD="${2:-}"
      PASSWORD_FROM_ARG="true"
      shift 2
      ;;
    --decoy-domain)
      require_option_value "$1" "${2:-}"
      DECOY_DOMAIN="${2:-}"
      shift 2
      ;;
    -e|--email)
      require_option_value "$1" "${2:-}"
      EMAIL="${2:-}"
      shift 2
      ;;
    --http-port)
      require_option_value "$1" "${2:-}"
      HTTP_PORT="${2:-80}"
      shift 2
      ;;
    --https-port)
      require_option_value "$1" "${2:-}"
      HTTPS_PORT="${2:-443}"
      shift 2
      ;;
    -y|--yes)
      ASSUME_YES="true"
      shift
      ;;
    --skip-start)
      SKIP_START="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知选项: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "$PURGE" = "true" ] && [ "$ACTION" != "uninstall" ]; then
  echo "--purge 只能和 --uninstall 一起使用。" >&2
  exit 1
fi

if [ "$ACTION" = "menu" ]; then
  if [ -n "$DOMAIN" ] || [ -n "$USERNAME" ] || [ -n "$PASSWORD" ] || [ -n "$DECOY_DOMAIN" ] || [ -n "$EMAIL" ] || [ "$SKIP_START" = "true" ]; then
    ACTION="install"
  fi
fi

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "需要 root 权限，但系统没有 sudo。请使用 root 运行脚本。" >&2
    exit 1
  fi
}

prompt_value() {
  local var_name="$1"
  local label="$2"
  local current_value="$3"
  local secret="${4:-false}"
  local input

  if [ -n "$current_value" ]; then
    printf '%s' "$current_value"
    return
  fi

  while true; do
    if [ "$secret" = "true" ]; then
      read -r -s -p "$label: " input
      printf '\n' >&2
    else
      read -r -p "$label: " input
    fi

    if [ -n "$input" ]; then
      printf '%s' "$input"
      return
    fi

    echo "$var_name 不能为空。" >&2
  done
}

prompt_optional() {
  local label="$1"
  local current_value="$2"
  local default_value="${3:-}"
  local input

  if [ -n "$current_value" ]; then
    printf '%s' "$current_value"
    return
  fi

  if [ "$ASSUME_YES" = "true" ]; then
    printf '%s' "$default_value"
    return
  fi

  if [ -n "$default_value" ]; then
    read -r -p "$label [$default_value]: " input
    printf '%s' "${input:-$default_value}"
  else
    read -r -p "$label，可留空: " input
    printf '%s' "$input"
  fi
}

strip_scheme() {
  local value="$1"
  value="${value#http://}"
  value="${value#https://}"
  value="${value%%/*}"
  printf '%s' "$value"
}

is_valid_host() {
  local value="$1"
  [ ${#value} -le 253 ] || return 1
  if printf '%s' "$value" | grep -Eq '^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$'; then
    return 0
  fi
  if printf '%s' "$value" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    local o1 o2 o3 o4
    IFS=. read -r o1 o2 o3 o4 <<EOF
$value
EOF
    [ "$o1" -le 255 ] && [ "$o2" -le 255 ] && [ "$o3" -le 255 ] && [ "$o4" -le 255 ]
    return
  fi
  return 1
}

is_valid_username() {
  local value="$1"
  printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._~-]{1,128}$'
}

is_valid_port() {
  local value="$1"
  printf '%s' "$value" | grep -Eq '^[0-9]+$' || return 1
  [ "$value" -ge 1 ] && [ "$value" -le 65535 ]
}

is_safe_env_value() {
  local value="$1"
  case "$value" in
    *$'\n'*|*$'\r'*)
      return 1
      ;;
  esac
}

write_env_line() {
  local key="$1"
  local value="$2"
  local escaped
  escaped="$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\$/\\$/g; s/`/\\`/g')"
  printf '%s="%s"\n' "$key" "$escaped"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

caddy_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

need_linux() {
  if [ "$(uname -s)" != "Linux" ]; then
    echo "直装模式只支持 Linux。" >&2
    exit 1
  fi
}

need_systemd() {
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "直装模式需要 systemd，但当前系统没有 systemctl。" >&2
    exit 1
  fi
}

install_base_packages() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  else
    echo "无法识别 Linux 发行版：缺少 /etc/os-release。" >&2
    exit 1
  fi

  echo
  echo "正在安装基础依赖..."

  case "${ID:-} ${ID_LIKE:-}" in
    *ubuntu*|*debian*)
      run_as_root apt-get update
      run_as_root apt-get install -y ca-certificates curl tar gzip git
      ;;
    *centos*|*rhel*|*rocky*|*almalinux*|*fedora*)
      if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y ca-certificates curl tar gzip git
      elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y ca-certificates curl tar gzip git
      else
        echo "未找到 dnf 或 yum。" >&2
        exit 1
      fi
      ;;
    *alpine*)
      run_as_root apk add --no-cache ca-certificates curl tar gzip git
      ;;
    *)
      echo "暂不支持自动安装依赖的系统：${PRETTY_NAME:-unknown}" >&2
      echo "请先手动安装 ca-certificates curl tar gzip git 后重试。" >&2
      exit 1
      ;;
  esac
}

linux_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)
      printf '%s' "amd64"
      ;;
    aarch64|arm64)
      printf '%s' "arm64"
      ;;
    *)
      echo "暂不支持的架构：$arch" >&2
      return 1
      ;;
  esac
}

download_prebuilt_caddy() {
  local arch asset checksum_url tmp_dir archive checksum_file tmp_bin

  if [ "$BUILD_FROM_SOURCE" = "true" ]; then
    return 1
  fi

  arch="$(linux_arch)" || return 1
  asset="caddy-naiveproxy-linux-${arch}.tar.gz"
  checksum_url="${RELEASE_BASE_URL}/${asset}.sha256"
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/$asset"
  checksum_file="$tmp_dir/$asset.sha256"
  tmp_bin="$tmp_dir/caddy-naiveproxy"

  echo
  echo "正在下载预编译 Caddy：$asset"
  if ! curl -fL "${RELEASE_BASE_URL}/${asset}" -o "$archive"; then
    echo "预编译 Caddy 下载失败，准备改用本地编译。"
    rm -rf "$tmp_dir"
    return 1
  fi

  if command -v sha256sum >/dev/null 2>&1 && curl -fsSL "$checksum_url" -o "$checksum_file"; then
    (cd "$tmp_dir" && sha256sum -c "$(basename "$checksum_file")")
  fi

  tar -C "$tmp_dir" -xzf "$archive"
  if [ ! -x "$tmp_bin" ]; then
    echo "预编译 Caddy 包格式不正确，准备改用本地编译。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  run_as_root install -m 0755 "$tmp_bin" "$CADDY_BIN"
  rm -rf "$tmp_dir"
  echo "已安装预编译 Caddy：$CADDY_BIN"
  return 0
}

go_version_ok() {
  local go_cmd="$1"
  local version major minor
  version="$("$go_cmd" version 2>/dev/null | awk '{print $3}' | sed 's/^go//; s/[^0-9.].*$//')"
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"
  [ -n "$major" ] && [ -n "$minor" ] || return 1
  [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -ge 22 ]; }
}

select_or_install_go() {
  if command -v go >/dev/null 2>&1 && go_version_ok "$(command -v go)"; then
    GO_BIN="$(command -v go)"
    return
  fi

  local go_arch go_version url tmp_dir tarball extract_dir
  go_arch="$(linux_arch)"

  go_version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | sed -n '1p')"
  if [ -z "$go_version" ]; then
    echo "无法获取 Go 最新版本号。" >&2
    exit 1
  fi

  url="https://go.dev/dl/${go_version}.linux-${go_arch}.tar.gz"
  tmp_dir="$(mktemp -d)"
  tarball="$tmp_dir/go.tar.gz"
  extract_dir="$tmp_dir/extract"

  echo
  echo "正在安装 Go：$go_version"
  curl -fL "$url" -o "$tarball"
  run_as_root rm -rf "$GO_ROOT"
  mkdir -p "$extract_dir"
  tar -C "$extract_dir" -xzf "$tarball"
  run_as_root mv "$extract_dir/go" "$GO_ROOT"
  rm -rf "$tmp_dir"

  GO_BIN="$GO_ROOT/bin/go"
  if [ ! -x "$GO_BIN" ]; then
    echo "Go 安装失败：$GO_BIN 不存在。" >&2
    exit 1
  fi
}

install_xcaddy() {
  if [ -x "$XCADDY_BIN" ]; then
    return
  fi

  echo
  echo "正在安装 xcaddy..."
  run_as_root env GOBIN=/usr/local/bin "$GO_BIN" install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

  if [ ! -x "$XCADDY_BIN" ]; then
    echo "xcaddy 安装失败：$XCADDY_BIN 不存在。" >&2
    exit 1
  fi
}

build_caddy() {
  local tmp_bin
  tmp_bin="$(mktemp)"
  rm -f "$tmp_bin"

  echo
  echo "正在编译带 NaiveProxy 支持的 Caddy..."
  env XCADDY_WHICH_GO="$GO_BIN" "$XCADDY_BIN" build --output "$tmp_bin" --with github.com/caddyserver/forwardproxy
  run_as_root install -m 0755 "$tmp_bin" "$CADDY_BIN"
  rm -f "$tmp_bin"
}

write_caddyfile() {
  local caddy_user caddy_pass
  caddy_user="$(caddy_escape "$USERNAME")"
  caddy_pass="$(caddy_escape "$PASSWORD")"

  run_as_root mkdir -p "$INSTALL_DIR" "$DATA_DIR"

  {
    echo "{"
    echo "	admin off"
    echo "	order forward_proxy before reverse_proxy"
    echo "	http_port $HTTP_PORT"
    echo "	https_port $HTTPS_PORT"
    if [ -n "$EMAIL" ]; then
      echo "	email $EMAIL"
    fi
    echo "}"
    echo
    echo ":$HTTPS_PORT, $DOMAIN {"
    echo "	tls {"
    echo "		protocols tls1.2 tls1.3"
    echo "	}"
    echo
    echo "	route {"
    echo "		forward_proxy {"
    echo "			basic_auth \"$caddy_user\" \"$caddy_pass\""
    echo "			hide_ip"
    echo "			hide_via"
    echo "			probe_resistance"
    echo "		}"
    echo
    echo "		reverse_proxy https://$DECOY_DOMAIN {"
    echo "			header_up Host $DECOY_DOMAIN"
    echo "			header_up X-Forwarded-Host $DOMAIN"
    echo "			header_up X-Forwarded-Proto https"
    echo "		}"
    echo "	}"
    echo "}"
  } | run_as_root tee "$INSTALL_DIR/Caddyfile" >/dev/null
}

write_service() {
  cat <<EOF | run_as_root tee "$SERVICE_FILE" >/dev/null
[Unit]
Description=PixelCat NaiveProxy
Documentation=https://github.com/PixelCatICU/pixelcat-naiveproxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
Environment=HOME=$DATA_DIR
Environment=XDG_DATA_HOME=$DATA_DIR
Environment=XDG_CONFIG_HOME=$INSTALL_DIR
ExecStart=$CADDY_BIN run --config $INSTALL_DIR/Caddyfile --adapter caddyfile
ExecReload=$CADDY_BIN reload --config $INSTALL_DIR/Caddyfile --adapter caddyfile --force
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

print_sing_box_config() {
  local json_domain json_username json_password
  json_domain="$(json_escape "$DOMAIN")"
  json_username="$(json_escape "$USERNAME")"
  json_password="$(json_escape "$PASSWORD")"

  cat <<EOF

sing-box 客户端配置:

{
  "log": {
    "level": "info",
    "timestamp": true
  },
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
      "server": "$json_domain",
      "server_port": $HTTPS_PORT,
      "username": "$json_username",
      "password": "$json_password",
      "tls": {
        "enabled": true,
        "server_name": "$json_domain"
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "naive-out",
    "auto_detect_interface": true
  }
}

本地 mixed 代理: 127.0.0.1:2080
EOF
}

install_stack() {
  need_linux
  need_systemd
  install_base_packages
  if ! download_prebuilt_caddy; then
    select_or_install_go
    install_xcaddy
    build_caddy
  fi
  write_caddyfile
  write_service

  if [ "$SKIP_START" = "true" ]; then
    echo "已生成配置，按要求未启动服务。"
    exit 0
  fi

  echo
  echo "正在启动 NaiveProxy systemd 服务..."
  run_as_root systemctl daemon-reload
  run_as_root systemctl enable --now pixelcat-naiveproxy

  echo
  echo "部署完成。"
  echo "服务状态: systemctl status pixelcat-naiveproxy --no-pager"
  echo "代理地址: https://$USERNAME:******@$DOMAIN"
  print_sing_box_config
  echo "查看日志: journalctl -u pixelcat-naiveproxy -f"
}

uninstall_stack() {
  need_linux
  need_systemd

  if [ "$ASSUME_YES" != "true" ]; then
    if [ "$PURGE" = "true" ]; then
      read -r -p "确认卸载 NaiveProxy，并删除配置、证书数据和本地 Go 工具？[y/N]: " uninstall_confirm
    else
      read -r -p "确认卸载 NaiveProxy 服务？配置和证书数据会保留。[y/N]: " uninstall_confirm
    fi
    case "$uninstall_confirm" in
      y|Y|yes|YES)
        ;;
      *)
        echo "已取消。"
        exit 0
        ;;
    esac
  fi

  echo
  echo "正在停止并删除 systemd 服务..."
  run_as_root systemctl disable --now pixelcat-naiveproxy >/dev/null 2>&1 || true
  run_as_root rm -f "$SERVICE_FILE"
  run_as_root systemctl daemon-reload
  run_as_root rm -f "$CADDY_BIN"

  if [ "$PURGE" = "true" ]; then
    run_as_root rm -rf "$INSTALL_DIR" "$DATA_DIR" "$GO_ROOT"
    run_as_root rm -f "$XCADDY_BIN"
    if [ -f ".env" ]; then
      rm -f .env
    fi
    echo "已删除配置、证书数据、.env 和本地 Go 工具。"
  fi

  echo "卸载完成。"
}

enable_bbr() {
  need_linux

  echo
  echo "正在开启 BBR..."
  cat <<'EOF' | run_as_root tee /etc/sysctl.d/99-pixelcat-bbr.conf >/dev/null
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

  run_as_root sysctl --system >/dev/null

  echo "当前拥塞控制算法: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
  echo "当前队列算法: $(sysctl -n net.core.default_qdisc 2>/dev/null || true)"

  if [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)" = "bbr" ]; then
    echo "BBR 已开启。"
  else
    echo "BBR 未成功开启，可能是内核不支持。请检查内核版本。" >&2
    exit 1
  fi
}

show_menu() {
  local choice

  while true; do
    cat <<'MENU'

PixelCat NaiveProxy 一键脚本

像素猫 - 科学上网ICU
中文教程博客，整理科学上网、网络诊断、节点维护与隐私安全的实用经验。

官网: https://pixelcat.icu
YouTube: https://www.youtube.com/@PixelCatICU
GitHub: https://github.com/PixelCatICU
X: https://x.com/PixelCatICU

1) 安装 / 更新 NaiveProxy
2) 卸载 NaiveProxy
3) 一键开启 BBR
0) 退出

MENU
    read -r -p "请输入选项 [1/2/3/0]: " choice
    case "$choice" in
      1)
        ACTION="install"
        return
        ;;
      2)
        ACTION="uninstall"
        if [ "$ASSUME_YES" != "true" ]; then
          read -r -p "是否同时删除配置和证书数据？[y/N]: " purge_confirm
          case "$purge_confirm" in
            y|Y|yes|YES)
              PURGE="true"
              ;;
          esac
        fi
        return
        ;;
      3)
        ACTION="bbr"
        return
        ;;
      0)
        echo "已退出。"
        exit 0
        ;;
      *)
        echo "无效选项。"
        ;;
    esac
  done
}

if [ "$ACTION" = "menu" ]; then
  show_menu
fi

if [ "$ACTION" = "uninstall" ]; then
  uninstall_stack
  exit 0
fi

if [ "$ACTION" = "bbr" ]; then
  enable_bbr
  exit 0
fi

DOMAIN="$(strip_scheme "$(prompt_value DOMAIN "请输入代理域名，例如 proxy.example.com" "$DOMAIN")")"
USERNAME="$(prompt_value USERNAME "请输入 NaiveProxy 用户名" "$USERNAME")"
PASSWORD="$(prompt_value PASSWORD "请输入 NaiveProxy 密码" "$PASSWORD" true)"
DECOY_DOMAIN="$(strip_scheme "$(prompt_value DECOY_DOMAIN "请输入伪装网站域名，例如 www.example.com" "$DECOY_DOMAIN")")"
EMAIL="$(prompt_optional "请输入证书邮箱" "$EMAIL")"
HTTP_PORT="$(prompt_optional "请输入 HTTP 端口" "$HTTP_PORT" "80")"
HTTPS_PORT="$(prompt_optional "请输入 HTTPS 端口" "$HTTPS_PORT" "443")"

if [ "$PASSWORD_FROM_ARG" = "true" ]; then
  echo "警告：通过 --password 传入密码可能会被 shell 历史或进程列表记录。" >&2
  echo "生产环境更推荐运行 ./deploy.sh 后交互式输入密码。" >&2
fi

if ! is_valid_host "$DOMAIN"; then
  echo "代理域名无效: $DOMAIN" >&2
  exit 1
fi

if ! is_valid_host "$DECOY_DOMAIN"; then
  echo "伪装网站域名无效: $DECOY_DOMAIN" >&2
  exit 1
fi

if ! is_valid_username "$USERNAME"; then
  echo "用户名无效：只能使用 1-128 位字符：A-Z a-z 0-9 . _ ~ -" >&2
  exit 1
fi

if [ "$DOMAIN" = "$DECOY_DOMAIN" ]; then
  echo "代理域名和伪装网站域名不能相同。" >&2
  exit 1
fi

if [ -n "$EMAIL" ] && ! printf '%s' "$EMAIL" | grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'; then
  echo "证书邮箱无效: $EMAIL" >&2
  exit 1
fi

if ! is_valid_port "$HTTP_PORT"; then
  echo "HTTP 端口无效: $HTTP_PORT" >&2
  exit 1
fi

if ! is_valid_port "$HTTPS_PORT"; then
  echo "HTTPS 端口无效: $HTTPS_PORT" >&2
  exit 1
fi

for value_name in DOMAIN USERNAME PASSWORD DECOY_DOMAIN EMAIL HTTP_PORT HTTPS_PORT; do
  value="$(eval "printf '%s' \"\${$value_name}\"")"
  if ! is_safe_env_value "$value"; then
    echo "$value_name 不能包含换行符。" >&2
    exit 1
  fi
done

if [ -f ".env" ] && [ "$ASSUME_YES" != "true" ]; then
  read -r -p ".env 已存在，是否覆盖？[y/N]: " overwrite
  case "$overwrite" in
    y|Y|yes|YES)
      ;;
    *)
      echo "已取消。"
      exit 0
      ;;
  esac
fi

{
  write_env_line DOMAIN "$DOMAIN"
  write_env_line USERNAME "$USERNAME"
  write_env_line PASSWORD "$PASSWORD"
  write_env_line DECOY_DOMAIN "$DECOY_DOMAIN"
  write_env_line EMAIL "$EMAIL"
  write_env_line HTTP_PORT "$HTTP_PORT"
  write_env_line HTTPS_PORT "$HTTPS_PORT"
} > .env

chmod 600 .env

echo
echo ".env 已写入。"

install_stack
