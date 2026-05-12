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

SERVICE_NAME="pixelcat-forwardproxy"
LEGACY_SERVICE_NAME="pixelcat-naiveproxy"
INSTALL_DIR="/etc/pixelcat-forwardproxy"
DATA_DIR="/var/lib/pixelcat-forwardproxy"
LEGACY_INSTALL_DIR="/etc/pixelcat-naiveproxy"
LEGACY_DATA_DIR="/var/lib/pixelcat-naiveproxy"
CADDY_BIN="/usr/local/bin/caddy-forwardproxy"
LEGACY_CADDY_BIN="/usr/local/bin/caddy-naiveproxy"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LEGACY_SERVICE_FILE="/etc/systemd/system/${LEGACY_SERVICE_NAME}.service"
SERVICE_USER="pixelcat-proxy"
SERVICE_GROUP="pixelcat-proxy"
GO_ROOT="/usr/local/go-pixelcat"
GO_BIN=""
XCADDY_BIN="/usr/local/bin/xcaddy"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://github.com/PixelCatICU/pixelcat-proxy/releases/latest/download}"
BUILD_FROM_SOURCE="false"

HY2_DOMAIN="${HY2_DOMAIN:-}"
HY2_PASSWORD="${HY2_PASSWORD:-}"
HY2_PORT="${HY2_PORT:-}"
HY2_HOP_RANGE="${HY2_HOP_RANGE-__UNSET__}"
HY2_HOP_IFACE="${HY2_HOP_IFACE:-}"
HY2_UP_MBPS="${HY2_UP_MBPS:-}"
HY2_DOWN_MBPS="${HY2_DOWN_MBPS:-}"
HY2_MASQUERADE_URL="${HY2_MASQUERADE_URL:-}"
HY2_PASSWORD_FROM_ARG="false"

HY2_SERVICE_NAME="pixelcat-hysteria2"
HY2_HOP_SERVICE_NAME="pixelcat-hysteria2-hop"
HY2_INSTALL_DIR="/etc/pixelcat-hysteria2"
HY2_DATA_DIR="/var/lib/pixelcat-hysteria2"
HY2_BIN="/usr/local/bin/pixelcat-hysteria2"
HY2_SERVICE_FILE="/etc/systemd/system/${HY2_SERVICE_NAME}.service"
HY2_HOP_SERVICE_FILE="/etc/systemd/system/${HY2_HOP_SERVICE_NAME}.service"
HY2_RELEASE_BASE_URL="${HY2_RELEASE_BASE_URL:-https://github.com/apernet/hysteria/releases/latest/download}"
HY2_DEFAULT_HOP_RANGE="20000-50000"
HY2_DEFAULT_MASQUERADE_URL="https://www.bing.com"

usage() {
  cat <<'USAGE'
PixelCat 一键脚本(ForwardProxy + Hysteria2)

用法:
  ./deploy.sh                          显示中文菜单
  ./deploy.sh --install                安装或更新 PixelCat ForwardProxy
  ./deploy.sh --install-hysteria2      安装或更新 PixelCat Hysteria2
  ./deploy.sh --uninstall              卸载 PixelCat ForwardProxy
  ./deploy.sh --uninstall-hysteria2    卸载 PixelCat Hysteria2
  ./deploy.sh --bbr                    一键开启 BBR
  ./deploy.sh --ip-quality             运行 IP 质量检测
  ./deploy.sh --unlock-check           运行流媒体解锁检测
  ./deploy.sh --net-quality            运行网络质量 / 回程检测

通用选项:
      --purge           配合 --uninstall* 一起删除配置、证书数据和系统用户
  -y, --yes             自动确认覆盖配置
      --skip-start      只生成配置,不启动服务
  -h, --help            显示帮助

ForwardProxy 选项:
  -d, --domain          代理域名,必填
  -u, --username        代理用户名,必填
  -p, --password        代理密码,必填
      --decoy-domain    伪装网站域名,必填
  -e, --email           Let's Encrypt 证书邮箱,可选
      --http-port       HTTP 端口,默认 80
      --https-port      HTTPS 端口,默认 443
      --build-from-source
                        跳过预编译下载,本地编译 Caddy

Hysteria2 选项:
      --hy2-domain      Hysteria2 域名,留空沿用 ForwardProxy 域名
      --hy2-password    Hysteria2 客户端密码,留空自动生成
      --hy2-port        监听 UDP 端口,默认 443
      --hy2-hop-range   端口跳跃范围,例如 20000-50000;传 "off" 禁用
      --hy2-hop-iface   端口跳跃使用的网卡,默认自动检测默认路由网卡
      --hy2-up-mbps     上行限速 Mbps,默认 0(无限)
      --hy2-down-mbps   下行限速 Mbps,默认 0(无限)
      --hy2-masquerade  伪装目标 URL,默认 https://www.bing.com
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
    --install-hysteria2)
      ACTION="install-hysteria2"
      shift
      ;;
    --uninstall-hysteria2)
      ACTION="uninstall-hysteria2"
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
    --ip-quality)
      ACTION="ip-quality"
      shift
      ;;
    --unlock-check)
      ACTION="unlock-check"
      shift
      ;;
    --net-quality)
      ACTION="net-quality"
      shift
      ;;
    --build-from-source)
      BUILD_FROM_SOURCE="true"
      shift
      ;;
    --hy2-domain)
      require_option_value "$1" "${2:-}"
      HY2_DOMAIN="${2:-}"
      shift 2
      ;;
    --hy2-password)
      require_option_value "$1" "${2:-}"
      HY2_PASSWORD="${2:-}"
      HY2_PASSWORD_FROM_ARG="true"
      shift 2
      ;;
    --hy2-port)
      require_option_value "$1" "${2:-}"
      HY2_PORT="${2:-}"
      shift 2
      ;;
    --hy2-hop-range)
      require_option_value "$1" "${2:-}"
      HY2_HOP_RANGE="${2:-}"
      shift 2
      ;;
    --hy2-hop-iface)
      require_option_value "$1" "${2:-}"
      HY2_HOP_IFACE="${2:-}"
      shift 2
      ;;
    --hy2-up-mbps)
      require_option_value "$1" "${2:-}"
      HY2_UP_MBPS="${2:-}"
      shift 2
      ;;
    --hy2-down-mbps)
      require_option_value "$1" "${2:-}"
      HY2_DOWN_MBPS="${2:-}"
      shift 2
      ;;
    --hy2-masquerade)
      require_option_value "$1" "${2:-}"
      HY2_MASQUERADE_URL="${2:-}"
      shift 2
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

if [ "$PURGE" = "true" ] && [ "$ACTION" != "uninstall" ] && [ "$ACTION" != "uninstall-hysteria2" ]; then
  echo "--purge 只能和 --uninstall / --uninstall-hysteria2 一起使用。" >&2
  exit 1
fi

if [ "$ACTION" = "menu" ]; then
  if [ -n "$HY2_DOMAIN" ] || [ -n "$HY2_PASSWORD" ] || [ -n "$HY2_PORT" ] || [ "$HY2_HOP_RANGE" != "__UNSET__" ] || [ -n "$HY2_HOP_IFACE" ] || [ -n "$HY2_UP_MBPS" ] || [ -n "$HY2_DOWN_MBPS" ] || [ -n "$HY2_MASQUERADE_URL" ]; then
    ACTION="install-hysteria2"
  elif [ -n "$DOMAIN" ] || [ -n "$USERNAME" ] || [ -n "$PASSWORD" ] || [ -n "$DECOY_DOMAIN" ] || [ -n "$EMAIL" ] || [ "$SKIP_START" = "true" ]; then
    ACTION="install"
  fi
fi

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "需要 root 权限,但系统没有 sudo。请使用 root 运行脚本。" >&2
    exit 1
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
  [ ${#value} -ge 1 ] && [ ${#value} -le 253 ] || return 1
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
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9._~-]{1,128}$'
}

is_valid_port() {
  local value="$1"
  printf '%s' "$value" | grep -Eq '^[1-9][0-9]{0,4}$' || return 1
  [ "$value" -ge 1 ] && [ "$value" -le 65535 ]
}

is_valid_email() {
  printf '%s' "$1" | grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
}

is_safe_env_value() {
  local value="$1"
  case "$value" in
    *$'\n'*|*$'\r'*|*$'\t'*)
      return 1
      ;;
  esac
  return 0
}

write_env_line() {
  local key="$1"
  local value="$2"
  local escaped
  escaped="$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\$/\\$/g; s/`/\\`/g')"
  printf '%s="%s"\n' "$key" "$escaped"
}

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN { ORS = "" }
    {
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if      (c == "\\") printf "\\\\"
        else if (c == "\"") printf "\\\""
        else if (c == "\b") printf "\\b"
        else if (c == "\f") printf "\\f"
        else if (c == "\n") printf "\\n"
        else if (c == "\r") printf "\\r"
        else if (c == "\t") printf "\\t"
        else                printf "%s", c
      }
    }
  '
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
    echo "直装模式需要 systemd,但当前系统没有 systemctl。" >&2
    exit 1
  fi
}

prompt_host() {
  local var_name="$1"
  local label="$2"
  local current_value="$3"
  local input value

  if [ -n "$current_value" ]; then
    value="$(strip_scheme "$current_value")"
    if ! is_valid_host "$value"; then
      echo "$var_name 无效: $current_value" >&2
      exit 1
    fi
    printf '%s' "$value"
    return
  fi

  while true; do
    read -r -p "$label: " input
    if [ -z "$input" ]; then
      echo "$var_name 不能为空。" >&2
      continue
    fi
    value="$(strip_scheme "$input")"
    if ! is_valid_host "$value"; then
      echo "无效的域名或 IP,请重新输入。" >&2
      continue
    fi
    printf '%s' "$value"
    return
  done
}

prompt_username() {
  local var_name="$1"
  local label="$2"
  local current_value="$3"
  local input

  if [ -n "$current_value" ]; then
    if ! is_valid_username "$current_value"; then
      echo "$var_name 无效:只能使用 1-128 位 A-Z a-z 0-9 . _ ~ -" >&2
      exit 1
    fi
    printf '%s' "$current_value"
    return
  fi

  while true; do
    read -r -p "$label: " input
    if [ -z "$input" ]; then
      echo "$var_name 不能为空。" >&2
      continue
    fi
    if ! is_valid_username "$input"; then
      echo "用户名无效:只能使用 1-128 位 A-Z a-z 0-9 . _ ~ -,请重新输入。" >&2
      continue
    fi
    printf '%s' "$input"
    return
  done
}

prompt_password() {
  local var_name="$1"
  local label="$2"
  local current_value="$3"
  local input

  if [ -n "$current_value" ]; then
    if ! is_safe_env_value "$current_value"; then
      echo "$var_name 不能包含换行符、回车或制表符。" >&2
      exit 1
    fi
    printf '%s' "$current_value"
    return
  fi

  while true; do
    read -r -s -p "$label: " input
    printf '\n' >&2
    if [ -z "$input" ]; then
      echo "$var_name 不能为空。" >&2
      continue
    fi
    if ! is_safe_env_value "$input"; then
      echo "密码不能包含换行符、回车或制表符,请重新输入。" >&2
      continue
    fi
    printf '%s' "$input"
    return
  done
}

prompt_optional_email() {
  local var_name="$1"
  local label="$2"
  local current_value="$3"
  local input

  if [ -n "$current_value" ]; then
    if ! is_valid_email "$current_value"; then
      echo "$var_name 无效: $current_value" >&2
      exit 1
    fi
    printf '%s' "$current_value"
    return
  fi

  if [ "$ASSUME_YES" = "true" ]; then
    printf '%s' ""
    return
  fi

  while true; do
    read -r -p "$label,可留空: " input
    if [ -z "$input" ]; then
      printf '%s' ""
      return
    fi
    if ! is_valid_email "$input"; then
      echo "邮箱格式无效,请重新输入。" >&2
      continue
    fi
    printf '%s' "$input"
    return
  done
}

prompt_optional_port() {
  local var_name="$1"
  local label="$2"
  local current_value="$3"
  local default_value="$4"
  local input

  if [ -n "$current_value" ]; then
    if ! is_valid_port "$current_value"; then
      echo "$var_name 无效: $current_value" >&2
      exit 1
    fi
    printf '%s' "$current_value"
    return
  fi

  if [ "$ASSUME_YES" = "true" ]; then
    printf '%s' "$default_value"
    return
  fi

  while true; do
    read -r -p "$label [$default_value]: " input
    input="${input:-$default_value}"
    if ! is_valid_port "$input"; then
      echo "端口必须是 1-65535 之间的整数,请重新输入。" >&2
      continue
    fi
    printf '%s' "$input"
    return
  done
}

install_base_packages() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  else
    echo "无法识别 Linux 发行版:缺少 /etc/os-release。" >&2
    exit 1
  fi

  echo
  echo "正在安装基础依赖..."

  case "${ID:-} ${ID_LIKE:-}" in
    *ubuntu*|*debian*)
      run_as_root apt-get update
      run_as_root apt-get install -y ca-certificates curl tar gzip
      ;;
    *centos*|*rhel*|*rocky*|*almalinux*|*fedora*)
      if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y ca-certificates curl tar gzip
      elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y ca-certificates curl tar gzip
      else
        echo "未找到 dnf 或 yum。" >&2
        exit 1
      fi
      ;;
    *alpine*)
      run_as_root apk add --no-cache ca-certificates curl tar gzip shadow
      ;;
    *)
      echo "暂不支持自动安装依赖的系统:${PRETTY_NAME:-unknown}" >&2
      echo "请先手动安装 ca-certificates curl tar gzip 后重试。" >&2
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
      echo "暂不支持的架构:$arch" >&2
      return 1
      ;;
  esac
}

download_prebuilt_caddy() {
  local arch asset asset_url checksum_url tmp_dir archive checksum_file tmp_bin

  if [ "$BUILD_FROM_SOURCE" = "true" ]; then
    return 1
  fi

  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "缺少 sha256sum,无法校验预编译 Caddy,改用本地编译。" >&2
    return 1
  fi

  arch="$(linux_arch)" || return 1
  asset="caddy-forwardproxy-linux-${arch}.tar.gz"
  asset_url="${RELEASE_BASE_URL}/${asset}"
  checksum_url="${asset_url}.sha256"
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/$asset"
  checksum_file="$tmp_dir/$asset.sha256"
  tmp_bin="$tmp_dir/caddy-forwardproxy"

  echo
  echo "正在下载预编译 Caddy:$asset"
  if ! curl -fL "$asset_url" -o "$archive"; then
    echo "预编译 Caddy 下载失败,改用本地编译。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! curl -fsSL "$checksum_url" -o "$checksum_file"; then
    echo "预编译 Caddy 校验和文件下载失败,拒绝使用未经校验的二进制,改用本地编译。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! (cd "$tmp_dir" && sha256sum -c "$(basename "$checksum_file")" >/dev/null 2>&1); then
    echo "预编译 Caddy 校验和不匹配,改用本地编译。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! tar -C "$tmp_dir" -xzf "$archive"; then
    echo "预编译 Caddy 解压失败,改用本地编译。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if [ ! -x "$tmp_bin" ]; then
    echo "预编译 Caddy 包格式不正确,改用本地编译。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  run_as_root install -m 0755 "$tmp_bin" "$CADDY_BIN"
  rm -rf "$tmp_dir"
  echo "已安装预编译 Caddy:$CADDY_BIN"
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

  if [ -x "$GO_ROOT/bin/go" ] && go_version_ok "$GO_ROOT/bin/go"; then
    GO_BIN="$GO_ROOT/bin/go"
    return
  fi

  local go_arch go_version url tmp_dir tarball extract_dir
  go_arch="$(linux_arch)"

  go_version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | sed -n '1p')"
  if ! printf '%s' "$go_version" | grep -Eq '^go1\.[0-9]+(\.[0-9]+)?$'; then
    echo "获取到的 Go 版本号格式异常: $go_version" >&2
    exit 1
  fi

  url="https://go.dev/dl/${go_version}.linux-${go_arch}.tar.gz"
  tmp_dir="$(mktemp -d)"
  tarball="$tmp_dir/go.tar.gz"
  extract_dir="$tmp_dir/extract"

  echo
  echo "正在安装 Go:$go_version"
  curl -fL "$url" -o "$tarball"
  run_as_root rm -rf "$GO_ROOT"
  mkdir -p "$extract_dir"
  tar -C "$extract_dir" -xzf "$tarball"
  run_as_root mv "$extract_dir/go" "$GO_ROOT"
  rm -rf "$tmp_dir"

  GO_BIN="$GO_ROOT/bin/go"
  if [ ! -x "$GO_BIN" ]; then
    echo "Go 安装失败:$GO_BIN 不存在。" >&2
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
    echo "xcaddy 安装失败:$XCADDY_BIN 不存在。" >&2
    exit 1
  fi
}

build_caddy() {
  local tmp_bin
  tmp_bin="$(mktemp)"
  rm -f "$tmp_bin"

  echo
  echo "正在编译带 forwardproxy 插件的 Caddy..."
  env XCADDY_WHICH_GO="$GO_BIN" "$XCADDY_BIN" build \
    --output "$tmp_bin" \
    --with github.com/caddyserver/forwardproxy
  run_as_root install -m 0755 "$tmp_bin" "$CADDY_BIN"
  rm -f "$tmp_bin"
}

ensure_service_user() {
  if getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
    return
  fi

  echo
  echo "正在创建系统用户 $SERVICE_USER..."
  if command -v useradd >/dev/null 2>&1; then
    run_as_root useradd \
      --system \
      --no-create-home \
      --home-dir "$DATA_DIR" \
      --shell /usr/sbin/nologin \
      --user-group \
      "$SERVICE_USER"
  elif command -v adduser >/dev/null 2>&1; then
    run_as_root addgroup -S "$SERVICE_GROUP" 2>/dev/null || true
    run_as_root adduser -S -D -H \
      -h "$DATA_DIR" \
      -s /sbin/nologin \
      -G "$SERVICE_GROUP" \
      "$SERVICE_USER"
  else
    echo "无法创建系统用户:系统缺少 useradd / adduser。" >&2
    exit 1
  fi
}

migrate_legacy_install() {
  if systemctl list-unit-files "${LEGACY_SERVICE_NAME}.service" >/dev/null 2>&1 || [ -f "$LEGACY_SERVICE_FILE" ]; then
    echo
    echo "检测到旧服务 ${LEGACY_SERVICE_NAME},正在迁移到 ${SERVICE_NAME}..."
    run_as_root systemctl disable --now "$LEGACY_SERVICE_NAME" >/dev/null 2>&1 || true
    run_as_root rm -f "$LEGACY_SERVICE_FILE"
    run_as_root systemctl daemon-reload
  fi

  if [ ! -e "$INSTALL_DIR" ] && [ -e "$LEGACY_INSTALL_DIR" ]; then
    run_as_root mv "$LEGACY_INSTALL_DIR" "$INSTALL_DIR"
  fi

  if [ ! -e "$DATA_DIR" ] && [ -e "$LEGACY_DATA_DIR" ]; then
    run_as_root mv "$LEGACY_DATA_DIR" "$DATA_DIR"
  fi

  if [ -e "$LEGACY_CADDY_BIN" ]; then
    run_as_root rm -f "$LEGACY_CADDY_BIN"
  fi
}

write_caddyfile() {
  local caddy_user caddy_pass tmp
  caddy_user="$(caddy_escape "$USERNAME")"
  caddy_pass="$(caddy_escape "$PASSWORD")"

  run_as_root mkdir -p "$INSTALL_DIR" "$DATA_DIR"
  run_as_root chown root:"$SERVICE_GROUP" "$INSTALL_DIR"
  run_as_root chmod 0750 "$INSTALL_DIR"
  run_as_root chown -R "$SERVICE_USER":"$SERVICE_GROUP" "$DATA_DIR"
  run_as_root chmod 0700 "$DATA_DIR"

  tmp="$(mktemp)"
  {
    echo "{"
    echo "	admin off"
    echo "	order forward_proxy before reverse_proxy"
    echo "	http_port $HTTP_PORT"
    echo "	https_port $HTTPS_PORT"
    echo "	servers {"
    echo "		protocols h1 h2"
    echo "	}"
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
  } > "$tmp"

  run_as_root cp "$tmp" "$INSTALL_DIR/Caddyfile"
  run_as_root chown root:"$SERVICE_GROUP" "$INSTALL_DIR/Caddyfile"
  run_as_root chmod 0640 "$INSTALL_DIR/Caddyfile"
  rm -f "$tmp"
}

write_service() {
  cat <<EOF | run_as_root tee "$SERVICE_FILE" >/dev/null
[Unit]
Description=PixelCat ForwardProxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
Environment=HOME=$DATA_DIR
Environment=XDG_DATA_HOME=$DATA_DIR
Environment=XDG_CONFIG_HOME=$DATA_DIR
ExecStart=$CADDY_BIN run --config $INSTALL_DIR/Caddyfile --adapter caddyfile
ExecReload=$CADDY_BIN reload --config $INSTALL_DIR/Caddyfile --adapter caddyfile --force
Restart=on-failure
RestartSec=5s
TimeoutStartSec=60
TimeoutStopSec=20
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ProtectKernelTunables=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK
RestrictNamespaces=true
LockPersonality=true
ReadWritePaths=$DATA_DIR

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
注意:上面输出包含明文密码,请避免在公开场合显示或截图。
EOF
}

install_stack() {
  need_linux
  need_systemd
  migrate_legacy_install
  install_base_packages
  ensure_service_user
  if ! download_prebuilt_caddy; then
    select_or_install_go
    install_xcaddy
    build_caddy
  fi
  write_caddyfile
  write_service

  if [ "$SKIP_START" = "true" ]; then
    echo "已生成配置,按要求未启动服务。"
    exit 0
  fi

  echo
  echo "正在启动 PixelCat ForwardProxy systemd 服务..."
  run_as_root systemctl daemon-reload
  run_as_root systemctl enable "$SERVICE_NAME" >/dev/null
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    run_as_root systemctl restart "$SERVICE_NAME"
  else
    run_as_root systemctl start "$SERVICE_NAME"
  fi

  echo
  echo "部署完成。"
  echo "服务状态: systemctl status $SERVICE_NAME --no-pager"
  echo "代理地址: https://$USERNAME:******@$DOMAIN"
  print_sing_box_config
  echo "查看日志: journalctl -u $SERVICE_NAME -f"
}

uninstall_stack() {
  need_linux
  need_systemd

  if [ "$ASSUME_YES" != "true" ]; then
    if [ "$PURGE" = "true" ]; then
      read -r -p "确认卸载 PixelCat ForwardProxy,并删除配置、证书数据、本地 Go 工具和系统用户?[y/N]: " uninstall_confirm
    else
      read -r -p "确认卸载 PixelCat ForwardProxy 服务?配置和证书数据会保留。[y/N]: " uninstall_confirm
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
  run_as_root systemctl disable --now "$SERVICE_NAME" >/dev/null 2>&1 || true
  run_as_root systemctl disable --now "$LEGACY_SERVICE_NAME" >/dev/null 2>&1 || true
  run_as_root rm -f "$SERVICE_FILE" "$LEGACY_SERVICE_FILE"
  run_as_root systemctl daemon-reload
  run_as_root rm -f "$CADDY_BIN" "$LEGACY_CADDY_BIN"

  if [ "$PURGE" = "true" ]; then
    run_as_root rm -rf "$INSTALL_DIR" "$DATA_DIR" "$LEGACY_INSTALL_DIR" "$LEGACY_DATA_DIR" "$GO_ROOT"
    run_as_root rm -f "$XCADDY_BIN"
    if [ -f ".env" ]; then
      rm -f .env
    fi
    if getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
      if command -v userdel >/dev/null 2>&1; then
        run_as_root userdel "$SERVICE_USER" >/dev/null 2>&1 || true
      elif command -v deluser >/dev/null 2>&1; then
        run_as_root deluser "$SERVICE_USER" >/dev/null 2>&1 || true
      fi
    fi
    echo "已删除配置、证书数据、.env、本地 Go 工具和系统用户。"
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
    echo "BBR 未成功开启,可能是内核不支持。请检查内核版本。" >&2
    exit 1
  fi
}

# ===== 节点诊断工具 =====

DIAGNOSTIC_DEPS_PREPPED="false"

ensure_curl_available() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "未检测到 curl,正在安装基础依赖..."
    install_base_packages
  fi
}

ensure_diagnostic_deps() {
  if [ "$DIAGNOSTIC_DEPS_PREPPED" = "true" ]; then
    return 0
  fi

  need_linux
  ensure_curl_available

  if [ ! -f /etc/os-release ]; then
    echo "无法识别发行版,跳过诊断依赖预装(可能影响检测脚本运行)。" >&2
    DIAGNOSTIC_DEPS_PREPPED="true"
    return 0
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  local missing=""
  local cmd
  for cmd in jq dig mtr iperf3 bc convert; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing="${missing}${cmd} "
    fi
  done

  if [ -n "$missing" ]; then
    echo "正在安装诊断脚本依赖: ${missing}"
    case "${ID:-} ${ID_LIKE:-}" in
      *ubuntu*|*debian*)
        run_as_root apt-get update
        run_as_root apt-get install -y jq dnsutils mtr-tiny iperf3 bc imagemagick
        ;;
      *ol*|*oracle*|*centos*|*rhel*|*rocky*|*almalinux*|*fedora*)
        if command -v dnf >/dev/null 2>&1; then
          run_as_root dnf install -y jq bind-utils mtr iperf3 bc
          run_as_root dnf install -y epel-release 2>/dev/null || true
          run_as_root dnf install -y ImageMagick 2>/dev/null || \
            echo "ImageMagick 未能自动安装,IP 质量报告图片可能不可用。" >&2
        elif command -v yum >/dev/null 2>&1; then
          run_as_root yum install -y jq bind-utils mtr iperf3 bc
          run_as_root yum install -y epel-release 2>/dev/null || true
          run_as_root yum install -y ImageMagick 2>/dev/null || \
            echo "ImageMagick 未能自动安装,IP 质量报告图片可能不可用。" >&2
        else
          echo "未找到 dnf 或 yum,无法预装诊断依赖。" >&2
        fi
        ;;
      *alpine*)
        run_as_root apk add --no-cache jq bind-tools mtr iperf3 bc imagemagick
        ;;
      *)
        echo "暂不支持自动预装诊断依赖的系统: ${PRETTY_NAME:-unknown}" >&2
        echo "请先手动安装 jq dig mtr iperf3 bc imagemagick,然后重试。" >&2
        ;;
    esac
  fi

  if ! command -v nexttrace >/dev/null 2>&1; then
    echo "正在安装 nexttrace(回程路由检测依赖)..."
    local nt_script
    if nt_script="$(mktemp -t pixelcat-nt.XXXXXX)"; then
      if curl -fsSL https://nxtrace.org/nt -o "$nt_script" && [ -s "$nt_script" ]; then
        bash "$nt_script" || echo "nexttrace 安装脚本返回失败,回程路由检测可能不可用。" >&2
      else
        echo "下载 nexttrace 安装脚本失败,回程路由检测可能不可用。" >&2
      fi
      rm -f "$nt_script"
    else
      echo "无法创建临时文件,跳过 nexttrace 安装。" >&2
    fi
  fi

  DIAGNOSTIC_DEPS_PREPPED="true"
}

run_remote_diagnostic() {
  local title="$1"
  local source_url="$2"
  local fetch_url="$3"
  shift 3

  need_linux
  ensure_curl_available

  echo
  echo "===== ${title} ====="
  echo "来源: ${source_url}"
  if [ "$(id -u)" -ne 0 ]; then
    echo "提示: 当前非 root 用户,部分子项(如 mtr / 路由探测)可能无法运行,可考虑使用 sudo 重新运行。"
  fi
  echo "----------------------------------------"

  local tmp_script
  if ! tmp_script="$(mktemp -t pixelcat-diag.XXXXXX)"; then
    echo "无法创建临时文件,无法继续。" >&2
    return 1
  fi
  trap 'rm -f "$tmp_script"' EXIT

  if ! curl -fsSL "$fetch_url" -o "$tmp_script"; then
    echo "----------------------------------------"
    echo "下载远程脚本失败: ${fetch_url}" >&2
    echo "请检查网络连通性后重试。" >&2
    rm -f "$tmp_script"
    trap - EXIT
    return 1
  fi

  if [ ! -s "$tmp_script" ]; then
    echo "----------------------------------------"
    echo "远程脚本下载结果为空: ${fetch_url}" >&2
    rm -f "$tmp_script"
    trap - EXIT
    return 1
  fi

  local rc=0
  bash "$tmp_script" "$@" || rc=$?

  rm -f "$tmp_script"
  trap - EXIT

  echo "----------------------------------------"
  if [ "$rc" -ne 0 ]; then
    echo "${title} 执行返回码 ${rc},如系网络问题请稍后重试。" >&2
    return "$rc"
  fi
  echo "${title} 完成。"
}

run_ip_quality() {
  ensure_diagnostic_deps
  run_remote_diagnostic \
    "IP 质量检测 (xykt/IPQuality)" \
    "https://github.com/xykt/IPQuality" \
    "https://IP.Check.Place" \
    -n -l cn
}

run_unlock_check() {
  run_remote_diagnostic \
    "流媒体解锁检测 (lmc999/RegionRestrictionCheck)" \
    "https://github.com/lmc999/RegionRestrictionCheck" \
    "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh" \
    -E zh
}

run_net_quality() {
  ensure_diagnostic_deps
  run_remote_diagnostic \
    "网络质量 / 回程检测 (xykt/NetQuality)" \
    "https://github.com/xykt/NetQuality" \
    "https://Net.Check.Place" \
    -n -l cn
}

# ===== Hysteria2 =====

is_valid_hop_range() {
  local value="$1" start end
  printf '%s' "$value" | grep -Eq '^[1-9][0-9]{0,4}-[1-9][0-9]{0,4}$' || return 1
  start="${value%%-*}"
  end="${value##*-}"
  [ "$start" -ge 1 ] && [ "$start" -le 65535 ] || return 1
  [ "$end" -ge 1 ] && [ "$end" -le 65535 ] || return 1
  [ "$start" -le "$end" ] || return 1
  return 0
}

is_valid_mbps() {
  printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]{0,4})$'
}

is_valid_url() {
  printf '%s' "$1" | grep -Eq '^https?://[^[:space:]]+$'
}

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n' | tr -d '+/=' | cut -c1-32
  else
    head -c 32 /dev/urandom | base64 | tr -d '\n+/=' | cut -c1-32
  fi
}

detect_default_iface() {
  ip route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}'
}

prompt_optional_mbps() {
  local var_name="$1" label="$2" current_value="$3" default_value="$4" input

  if [ -n "$current_value" ]; then
    if ! is_valid_mbps "$current_value"; then
      echo "$var_name 无效:必须是 0-99999 的整数。" >&2
      exit 1
    fi
    printf '%s' "$current_value"
    return
  fi

  if [ "$ASSUME_YES" = "true" ]; then
    printf '%s' "$default_value"
    return
  fi

  while true; do
    read -r -p "$label [$default_value]: " input
    input="${input:-$default_value}"
    if ! is_valid_mbps "$input"; then
      echo "请输入 0-99999 的整数(0 表示不限速)。" >&2
      continue
    fi
    printf '%s' "$input"
    return
  done
}

prompt_optional_hop_range() {
  local var_name="$1" label="$2" current_value="$3" default_value="$4" input

  if [ "$current_value" != "__UNSET__" ]; then
    if [ -z "$current_value" ] || [ "$current_value" = "off" ] || [ "$current_value" = "OFF" ]; then
      printf '%s' ""
      return
    fi
    if ! is_valid_hop_range "$current_value"; then
      echo "$var_name 无效:应为 start-end 格式,例如 20000-50000。" >&2
      exit 1
    fi
    printf '%s' "$current_value"
    return
  fi

  if [ "$ASSUME_YES" = "true" ]; then
    printf '%s' "$default_value"
    return
  fi

  while true; do
    read -r -p "$label [$default_value,输入 off 关闭]: " input
    input="${input:-$default_value}"
    if [ "$input" = "off" ] || [ "$input" = "OFF" ]; then
      printf '%s' ""
      return
    fi
    if ! is_valid_hop_range "$input"; then
      echo "请输入 start-end 格式,例如 20000-50000。" >&2
      continue
    fi
    printf '%s' "$input"
    return
  done
}

prompt_optional_url() {
  local var_name="$1" label="$2" current_value="$3" default_value="$4" input

  if [ -n "$current_value" ]; then
    if ! is_valid_url "$current_value"; then
      echo "$var_name 无效:必须以 http:// 或 https:// 开头。" >&2
      exit 1
    fi
    printf '%s' "$current_value"
    return
  fi

  if [ "$ASSUME_YES" = "true" ]; then
    printf '%s' "$default_value"
    return
  fi

  while true; do
    read -r -p "$label [$default_value]: " input
    input="${input:-$default_value}"
    if ! is_valid_url "$input"; then
      echo "URL 无效,必须以 http:// 或 https:// 开头。" >&2
      continue
    fi
    printf '%s' "$input"
    return
  done
}

install_hop_packages() {
  if [ -z "$HY2_HOP_RANGE" ]; then
    return
  fi
  if command -v nft >/dev/null 2>&1 || command -v iptables >/dev/null 2>&1; then
    return
  fi

  echo
  echo "正在安装 nftables..."
  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get install -y nftables
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y nftables
  elif command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y nftables
  elif command -v apk >/dev/null 2>&1; then
    run_as_root apk add --no-cache nftables
  fi

  if ! command -v nft >/dev/null 2>&1 && ! command -v iptables >/dev/null 2>&1; then
    echo "未能安装 nftables/iptables,无法启用端口跳跃。" >&2
    return 1
  fi
}

download_hysteria2() {
  local arch asset asset_url hashes_url tmp_dir bin_file hashes_file expected actual

  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "缺少 sha256sum,无法校验 Hysteria2 二进制。" >&2
    return 1
  fi

  arch="$(linux_arch)" || return 1
  asset="hysteria-linux-${arch}"
  asset_url="${HY2_RELEASE_BASE_URL}/${asset}"
  hashes_url="${HY2_RELEASE_BASE_URL}/hashes.txt"
  tmp_dir="$(mktemp -d)"
  bin_file="$tmp_dir/hysteria"
  hashes_file="$tmp_dir/hashes.txt"

  echo
  echo "正在下载 Hysteria2:$asset"
  if ! curl -fL "$asset_url" -o "$bin_file"; then
    echo "Hysteria2 下载失败。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! curl -fsSL "$hashes_url" -o "$hashes_file"; then
    echo "Hysteria2 hashes.txt 下载失败,拒绝安装未经校验的二进制。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # hashes.txt 行格式:<sha256>  build/<asset>
  expected="$(awk -v t="build/$asset" '$2 == t {print $1; exit}' "$hashes_file")"
  if [ -z "$expected" ]; then
    echo "Hysteria2 hashes.txt 中没有 $asset 的校验和。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  actual="$(sha256sum "$bin_file" | awk '{print $1}')"
  if [ "$expected" != "$actual" ]; then
    echo "Hysteria2 校验和不匹配(expected $expected, got $actual)。" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  chmod +x "$bin_file"
  run_as_root install -m 0755 "$bin_file" "$HY2_BIN"
  rm -rf "$tmp_dir"
  echo "已安装 Hysteria2:$HY2_BIN"
}

HY2_USE_ACME="true"
HY2_CERT_FILE=""
HY2_KEY_FILE=""

resolve_hy2_cert_paths() {
  local base cert key
  base="$DATA_DIR/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$HY2_DOMAIN"
  cert="$base/${HY2_DOMAIN}.crt"
  key="$base/${HY2_DOMAIN}.key"

  if run_as_root test -f "$cert" && run_as_root test -f "$key"; then
    HY2_CERT_FILE="$cert"
    HY2_KEY_FILE="$key"
    HY2_USE_ACME="false"
  else
    HY2_CERT_FILE=""
    HY2_KEY_FILE=""
    HY2_USE_ACME="true"
  fi
}

yaml_quote() {
  local value="$1" escaped
  escaped="$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '"%s"' "$escaped"
}

write_hy2_config() {
  local tmp
  tmp="$(mktemp)"

  run_as_root mkdir -p "$HY2_INSTALL_DIR" "$HY2_DATA_DIR"
  run_as_root chown root:"$SERVICE_GROUP" "$HY2_INSTALL_DIR"
  run_as_root chmod 0750 "$HY2_INSTALL_DIR"
  run_as_root chown -R "$SERVICE_USER":"$SERVICE_GROUP" "$HY2_DATA_DIR"
  run_as_root chmod 0700 "$HY2_DATA_DIR"

  resolve_hy2_cert_paths

  {
    echo "# PixelCat Hysteria2 server config"
    echo "listen: :$HY2_PORT"
    echo
    if [ "$HY2_USE_ACME" = "true" ]; then
      echo "acme:"
      echo "  domains:"
      echo "    - $(yaml_quote "$HY2_DOMAIN")"
      if [ -n "$EMAIL" ]; then
        echo "  email: $(yaml_quote "$EMAIL")"
      fi
      echo "  ca: letsencrypt"
      echo "  dir: $HY2_DATA_DIR/acme"
    else
      echo "tls:"
      echo "  cert: $(yaml_quote "$HY2_CERT_FILE")"
      echo "  key: $(yaml_quote "$HY2_KEY_FILE")"
    fi
    echo
    echo "auth:"
    echo "  type: password"
    echo "  password: $(yaml_quote "$HY2_PASSWORD")"
    echo
    echo "masquerade:"
    echo "  type: proxy"
    echo "  proxy:"
    echo "    url: $(yaml_quote "$HY2_MASQUERADE_URL")"
    echo "    rewriteHost: true"
    if [ "$HY2_UP_MBPS" != "0" ] || [ "$HY2_DOWN_MBPS" != "0" ]; then
      echo
      echo "bandwidth:"
      if [ "$HY2_UP_MBPS" != "0" ]; then
        echo "  up: $HY2_UP_MBPS mbps"
      fi
      if [ "$HY2_DOWN_MBPS" != "0" ]; then
        echo "  down: $HY2_DOWN_MBPS mbps"
      fi
    fi
  } > "$tmp"

  run_as_root cp "$tmp" "$HY2_INSTALL_DIR/config.yaml"
  run_as_root chown root:"$SERVICE_GROUP" "$HY2_INSTALL_DIR/config.yaml"
  run_as_root chmod 0640 "$HY2_INSTALL_DIR/config.yaml"
  rm -f "$tmp"
}

write_hop_scripts() {
  local iface="$HY2_HOP_IFACE" hop_start hop_end up_script down_script
  hop_start="${HY2_HOP_RANGE%%-*}"
  hop_end="${HY2_HOP_RANGE##*-}"

  up_script="$(mktemp)"
  down_script="$(mktemp)"

  if command -v nft >/dev/null 2>&1; then
    cat > "$up_script" <<EOF
#!/usr/bin/env bash
set -e
nft delete table inet pixelcat-hy 2>/dev/null || true
nft -f - <<NFT
table inet pixelcat-hy {
    chain prerouting {
        type nat hook prerouting priority dstnat;
        iifname "$iface" udp dport $hop_start-$hop_end redirect to :$HY2_PORT
    }
}
NFT
EOF
    cat > "$down_script" <<'EOF'
#!/usr/bin/env bash
nft delete table inet pixelcat-hy 2>/dev/null || true
EOF
  else
    cat > "$up_script" <<EOF
#!/usr/bin/env bash
set -e
iptables -t nat -C PREROUTING -i $iface -p udp --dport $hop_start:$hop_end -j REDIRECT --to-ports $HY2_PORT 2>/dev/null || \\
  iptables -t nat -A PREROUTING -i $iface -p udp --dport $hop_start:$hop_end -j REDIRECT --to-ports $HY2_PORT
EOF
    cat > "$down_script" <<EOF
#!/usr/bin/env bash
iptables -t nat -D PREROUTING -i $iface -p udp --dport $hop_start:$hop_end -j REDIRECT --to-ports $HY2_PORT 2>/dev/null || true
EOF
  fi

  run_as_root install -m 0755 "$up_script" "$HY2_INSTALL_DIR/hop-up.sh"
  run_as_root install -m 0755 "$down_script" "$HY2_INSTALL_DIR/hop-down.sh"
  rm -f "$up_script" "$down_script"
}

write_hop_service() {
  cat <<EOF | run_as_root tee "$HY2_HOP_SERVICE_FILE" >/dev/null
[Unit]
Description=PixelCat Hysteria2 Port Hopping
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=$HY2_INSTALL_DIR/hop-up.sh
ExecStop=$HY2_INSTALL_DIR/hop-down.sh

[Install]
WantedBy=multi-user.target
EOF
}

write_hy2_service() {
  {
    echo "[Unit]"
    echo "Description=PixelCat Hysteria2"
    echo "After=network-online.target"
    echo "Wants=network-online.target"
    if [ -n "$HY2_HOP_RANGE" ]; then
      echo "Requires=$HY2_HOP_SERVICE_NAME.service"
      echo "After=$HY2_HOP_SERVICE_NAME.service"
    fi
    echo
    echo "[Service]"
    echo "Type=simple"
    echo "User=$SERVICE_USER"
    echo "Group=$SERVICE_GROUP"
    echo "WorkingDirectory=$HY2_DATA_DIR"
    echo "ExecStart=$HY2_BIN server --config $HY2_INSTALL_DIR/config.yaml"
    echo "Restart=on-failure"
    echo "RestartSec=5s"
    echo "TimeoutStartSec=60"
    echo "TimeoutStopSec=20"
    echo "LimitNOFILE=1048576"
    echo "AmbientCapabilities=CAP_NET_BIND_SERVICE"
    echo "CapabilityBoundingSet=CAP_NET_BIND_SERVICE"
    echo "NoNewPrivileges=true"
    echo "ProtectSystem=strict"
    echo "ProtectHome=true"
    echo "PrivateTmp=true"
    echo "ProtectKernelTunables=true"
    echo "ProtectControlGroups=true"
    echo "RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK"
    echo "RestrictNamespaces=true"
    echo "LockPersonality=true"
    if [ "$HY2_USE_ACME" = "true" ]; then
      echo "ReadWritePaths=$HY2_DATA_DIR"
    else
      echo "ReadOnlyPaths=$DATA_DIR"
      echo "ReadWritePaths=$HY2_DATA_DIR"
    fi
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } | run_as_root tee "$HY2_SERVICE_FILE" >/dev/null
}

apply_hysteria2_sysctl() {
  cat <<'EOF' | run_as_root tee /etc/sysctl.d/99-pixelcat-hysteria2.conf >/dev/null
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF
  run_as_root sysctl --system >/dev/null
}

print_hysteria2_client_config() {
  local json_domain json_password hop_line=""
  json_domain="$(json_escape "$HY2_DOMAIN")"
  json_password="$(json_escape "$HY2_PASSWORD")"

  if [ -n "$HY2_HOP_RANGE" ]; then
    local hop_colon
    hop_colon="${HY2_HOP_RANGE/-/:}"
    hop_line="      \"server_ports\": [\"$hop_colon\"],"
  fi

  cat <<EOF

sing-box 客户端配置(Hysteria2):

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
      "type": "hysteria2",
      "tag": "hysteria-out",
      "server": "$json_domain",
      "server_port": $HY2_PORT,
EOF

  if [ -n "$hop_line" ]; then
    echo "$hop_line"
  fi

  cat <<EOF
      "password": "$json_password",
      "tls": {
        "enabled": true,
        "server_name": "$json_domain"
      },
      "up_mbps": $HY2_UP_MBPS,
      "down_mbps": $HY2_DOWN_MBPS
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "hysteria-out",
    "auto_detect_interface": true
  }
}

注意:上面输出包含明文密码,请避免在公开场合显示或截图。
EOF
}

install_hysteria2() {
  need_linux
  need_systemd
  install_base_packages
  install_hop_packages
  ensure_service_user

  if ! download_hysteria2; then
    echo "Hysteria2 安装失败。" >&2
    exit 1
  fi

  write_hy2_config

  if [ -n "$HY2_HOP_RANGE" ]; then
    write_hop_scripts
    write_hop_service
  else
    if [ -f "$HY2_HOP_SERVICE_FILE" ]; then
      run_as_root systemctl disable --now "$HY2_HOP_SERVICE_NAME" >/dev/null 2>&1 || true
      run_as_root rm -f "$HY2_HOP_SERVICE_FILE" \
        "$HY2_INSTALL_DIR/hop-up.sh" "$HY2_INSTALL_DIR/hop-down.sh"
    fi
  fi

  write_hy2_service
  apply_hysteria2_sysctl

  if [ "$SKIP_START" = "true" ]; then
    echo "已生成 Hysteria2 配置,按要求未启动服务。"
    exit 0
  fi

  echo
  echo "正在启动 Hysteria2 systemd 服务..."
  run_as_root systemctl daemon-reload
  if [ -n "$HY2_HOP_RANGE" ]; then
    run_as_root systemctl enable "$HY2_HOP_SERVICE_NAME" >/dev/null
    if systemctl is-active --quiet "$HY2_HOP_SERVICE_NAME"; then
      run_as_root systemctl restart "$HY2_HOP_SERVICE_NAME"
    else
      run_as_root systemctl start "$HY2_HOP_SERVICE_NAME"
    fi
  fi
  run_as_root systemctl enable "$HY2_SERVICE_NAME" >/dev/null
  if systemctl is-active --quiet "$HY2_SERVICE_NAME"; then
    run_as_root systemctl restart "$HY2_SERVICE_NAME"
  else
    run_as_root systemctl start "$HY2_SERVICE_NAME"
  fi

  echo
  echo "Hysteria2 部署完成。"
  echo "服务状态: systemctl status $HY2_SERVICE_NAME --no-pager"
  echo "查看日志: journalctl -u $HY2_SERVICE_NAME -f"
  if [ -n "$HY2_HOP_RANGE" ]; then
    echo "端口跳跃: $HY2_HOP_RANGE/udp → :$HY2_PORT/udp(网卡:$HY2_HOP_IFACE)"
  fi
  if [ "$HY2_USE_ACME" = "true" ]; then
    echo "证书来源: Hysteria2 自申请 (ACME),数据保存在 $HY2_DATA_DIR/acme"
    echo "提示:Hysteria2 ACME 默认会用 443/tcp 完成 ALPN-01 校验,请确认该端口未被占用。"
  else
    echo "证书来源: 复用 Caddy 已签发的 $HY2_DOMAIN 证书"
  fi
  print_hysteria2_client_config
}

uninstall_hysteria2() {
  need_linux
  need_systemd

  if [ "$ASSUME_YES" != "true" ]; then
    if [ "$PURGE" = "true" ]; then
      read -r -p "确认卸载 Hysteria2,并删除配置、证书数据和系统用户?[y/N]: " ans
    else
      read -r -p "确认卸载 Hysteria2 服务?配置和证书数据会保留。[y/N]: " ans
    fi
    case "$ans" in
      y|Y|yes|YES) ;;
      *) echo "已取消。"; exit 0 ;;
    esac
  fi

  echo
  echo "正在停止并删除 Hysteria2 systemd 服务..."
  run_as_root systemctl disable --now "$HY2_SERVICE_NAME" >/dev/null 2>&1 || true
  run_as_root systemctl disable --now "$HY2_HOP_SERVICE_NAME" >/dev/null 2>&1 || true
  run_as_root rm -f "$HY2_SERVICE_FILE" "$HY2_HOP_SERVICE_FILE"
  run_as_root systemctl daemon-reload
  run_as_root rm -f "$HY2_BIN"
  run_as_root rm -f /etc/sysctl.d/99-pixelcat-hysteria2.conf

  if [ "$PURGE" = "true" ]; then
    run_as_root rm -rf "$HY2_INSTALL_DIR" "$HY2_DATA_DIR"
    if [ -f ".env.hysteria2" ]; then
      rm -f .env.hysteria2
    fi
    if [ ! -f "$SERVICE_FILE" ] && getent passwd "$SERVICE_USER" >/dev/null 2>&1; then
      if command -v userdel >/dev/null 2>&1; then
        run_as_root userdel "$SERVICE_USER" >/dev/null 2>&1 || true
      elif command -v deluser >/dev/null 2>&1; then
        run_as_root deluser "$SERVICE_USER" >/dev/null 2>&1 || true
      fi
    fi
    echo "已删除 Hysteria2 配置、证书和 .env.hysteria2。"
  fi

  echo "Hysteria2 卸载完成。"
}

do_install_hysteria2() {
  if [ -z "$HY2_DOMAIN" ] && [ -n "$DOMAIN" ]; then
    HY2_DOMAIN="$DOMAIN"
  fi
  HY2_DOMAIN="$(prompt_host HY2_DOMAIN "请输入 Hysteria2 域名" "$HY2_DOMAIN")"

  if [ -z "$HY2_PASSWORD" ]; then
    local generated keep
    generated="$(generate_password)"
    if [ "$ASSUME_YES" = "true" ] || [ ! -r /dev/tty ]; then
      HY2_PASSWORD="$generated"
      echo "已自动生成 Hysteria2 密码:$HY2_PASSWORD"
    else
      read -r -p "请输入 Hysteria2 密码 [回车使用随机密码 $generated]: " keep
      HY2_PASSWORD="${keep:-$generated}"
    fi
  else
    HY2_PASSWORD="$(prompt_password HY2_PASSWORD "请输入 Hysteria2 密码" "$HY2_PASSWORD")"
  fi

  HY2_PORT="$(prompt_optional_port HY2_PORT "请输入 Hysteria2 监听 UDP 端口" "$HY2_PORT" "443")"
  HY2_HOP_RANGE="$(prompt_optional_hop_range HY2_HOP_RANGE "请输入端口跳跃范围" "$HY2_HOP_RANGE" "$HY2_DEFAULT_HOP_RANGE")"

  if [ -n "$HY2_HOP_RANGE" ]; then
    if [ -z "$HY2_HOP_IFACE" ]; then
      HY2_HOP_IFACE="$(detect_default_iface)"
      if [ -z "$HY2_HOP_IFACE" ]; then
        echo "无法自动检测默认网卡,请用 --hy2-hop-iface 指定,或输入 off 关闭端口跳跃。" >&2
        exit 1
      fi
      echo "默认网卡:$HY2_HOP_IFACE"
    fi
  fi

  HY2_UP_MBPS="$(prompt_optional_mbps HY2_UP_MBPS "请输入上行限速 Mbps,0 表示不限速" "$HY2_UP_MBPS" "0")"
  HY2_DOWN_MBPS="$(prompt_optional_mbps HY2_DOWN_MBPS "请输入下行限速 Mbps,0 表示不限速" "$HY2_DOWN_MBPS" "0")"
  HY2_MASQUERADE_URL="$(prompt_optional_url HY2_MASQUERADE_URL "请输入伪装 URL" "$HY2_MASQUERADE_URL" "$HY2_DEFAULT_MASQUERADE_URL")"

  if [ "$HY2_PASSWORD_FROM_ARG" = "true" ]; then
    echo "警告:通过 --hy2-password 传入密码可能会被 shell 历史或进程列表记录。" >&2
  fi

  for value_name in HY2_DOMAIN HY2_PASSWORD HY2_PORT HY2_HOP_RANGE HY2_HOP_IFACE HY2_UP_MBPS HY2_DOWN_MBPS HY2_MASQUERADE_URL; do
    value="$(eval "printf '%s' \"\${$value_name}\"")"
    if ! is_safe_env_value "$value"; then
      echo "$value_name 不能包含换行符、回车或制表符。" >&2
      exit 1
    fi
  done

  if [ -f ".env.hysteria2" ] && [ "$ASSUME_YES" != "true" ]; then
    read -r -p ".env.hysteria2 已存在,是否覆盖?[y/N]: " overwrite
    case "$overwrite" in
      y|Y|yes|YES) ;;
      *) echo "已取消。"; exit 0 ;;
    esac
  fi

  {
    write_env_line HY2_DOMAIN "$HY2_DOMAIN"
    write_env_line HY2_PASSWORD "$HY2_PASSWORD"
    write_env_line HY2_PORT "$HY2_PORT"
    write_env_line HY2_HOP_RANGE "$HY2_HOP_RANGE"
    write_env_line HY2_HOP_IFACE "$HY2_HOP_IFACE"
    write_env_line HY2_UP_MBPS "$HY2_UP_MBPS"
    write_env_line HY2_DOWN_MBPS "$HY2_DOWN_MBPS"
    write_env_line HY2_MASQUERADE_URL "$HY2_MASQUERADE_URL"
  } > .env.hysteria2

  chmod 600 .env.hysteria2
  echo
  echo ".env.hysteria2 已写入。"

  install_hysteria2
}

show_menu() {
  local choice

  while true; do
    cat <<'MENU'

     ██        ██
    ██████████████
    ██  ██  ██  ██
    ██  ██  ██  ██
    ██          ██
    ██   ●●     ██
    ██  ██████  ██
     ████████████

PixelCat 一键脚本(ForwardProxy + Hysteria2)

像素猫 - 科学上网ICU
中文教程博客,整理科学上网、网络诊断、节点维护与隐私安全的实用经验。

官网: https://pixelcat.icu
YouTube: https://www.youtube.com/@PixelCatICU
GitHub: https://github.com/PixelCatICU
X: https://x.com/PixelCatICU

1) 安装 / 更新 PixelCat ForwardProxy
2) 安装 / 更新 PixelCat Hysteria2
3) 卸载 PixelCat ForwardProxy
4) 卸载 PixelCat Hysteria2
5) 一键开启 BBR
6) IP 质量检测           (xykt/IPQuality)
7) 流媒体解锁检测         (lmc999/RegionRestrictionCheck)
8) 网络质量 / 回程检测     (xykt/NetQuality)
0) 退出

MENU
    read -r -p "请输入选项 [1-8/0]: " choice
    case "$choice" in
      1)
        ACTION="install"
        return
        ;;
      2)
        ACTION="install-hysteria2"
        return
        ;;
      3)
        ACTION="uninstall"
        if [ "$ASSUME_YES" != "true" ]; then
          read -r -p "是否同时删除配置和证书数据?[y/N]: " purge_confirm
          case "$purge_confirm" in
            y|Y|yes|YES)
              PURGE="true"
              ;;
          esac
        fi
        return
        ;;
      4)
        ACTION="uninstall-hysteria2"
        if [ "$ASSUME_YES" != "true" ]; then
          read -r -p "是否同时删除 Hysteria2 配置和证书数据?[y/N]: " purge_confirm
          case "$purge_confirm" in
            y|Y|yes|YES)
              PURGE="true"
              ;;
          esac
        fi
        return
        ;;
      5)
        ACTION="bbr"
        return
        ;;
      6)
        ACTION="ip-quality"
        return
        ;;
      7)
        ACTION="unlock-check"
        return
        ;;
      8)
        ACTION="net-quality"
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

if [ "$ACTION" = "uninstall-hysteria2" ]; then
  uninstall_hysteria2
  exit 0
fi

if [ "$ACTION" = "bbr" ]; then
  enable_bbr
  exit 0
fi

if [ "$ACTION" = "ip-quality" ]; then
  run_ip_quality
  exit 0
fi

if [ "$ACTION" = "unlock-check" ]; then
  run_unlock_check
  exit 0
fi

if [ "$ACTION" = "net-quality" ]; then
  run_net_quality
  exit 0
fi

if [ "$ACTION" = "install-hysteria2" ]; then
  do_install_hysteria2
  exit 0
fi

DOMAIN="$(prompt_host DOMAIN "请输入代理域名,例如 proxy.example.com" "$DOMAIN")"
USERNAME="$(prompt_username USERNAME "请输入代理用户名" "$USERNAME")"
PASSWORD="$(prompt_password PASSWORD "请输入代理密码" "$PASSWORD")"
DECOY_DOMAIN="$(prompt_host DECOY_DOMAIN "请输入伪装网站域名,例如 www.example.com" "$DECOY_DOMAIN")"
EMAIL="$(prompt_optional_email EMAIL "请输入证书邮箱" "$EMAIL")"
HTTP_PORT="$(prompt_optional_port HTTP_PORT "请输入 HTTP 端口" "$HTTP_PORT" "80")"
HTTPS_PORT="$(prompt_optional_port HTTPS_PORT "请输入 HTTPS 端口" "$HTTPS_PORT" "443")"

if [ "$PASSWORD_FROM_ARG" = "true" ]; then
  echo "警告:通过 --password 传入密码可能会被 shell 历史或进程列表记录。" >&2
  echo "生产环境更推荐运行 ./deploy.sh 后交互式输入密码。" >&2
fi

if [ "$DOMAIN" = "$DECOY_DOMAIN" ]; then
  echo "代理域名和伪装网站域名不能相同。" >&2
  exit 1
fi

for value_name in DOMAIN USERNAME PASSWORD DECOY_DOMAIN EMAIL HTTP_PORT HTTPS_PORT; do
  value="$(eval "printf '%s' \"\${$value_name}\"")"
  if ! is_safe_env_value "$value"; then
    echo "$value_name 不能包含换行符、回车或制表符。" >&2
    exit 1
  fi
done

if [ -f ".env" ] && [ "$ASSUME_YES" != "true" ]; then
  read -r -p ".env 已存在,是否覆盖?[y/N]: " overwrite
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
