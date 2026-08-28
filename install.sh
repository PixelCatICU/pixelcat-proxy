#!/usr/bin/env bash
set -Eeuo pipefail

REPO_OWNER="${REPO_OWNER:-PixelCatICU}"
REPO_NAME="${REPO_NAME:-pixelcat-proxy}"
BASE_DIR="${BASE_DIR:-/opt/pixelcat}"
APP_DIR="${APP_DIR:-pixelcat-naiveproxy}"
REF="${REF:-main}"
BOOT_LANG="${PIXELCAT_LANG:-zh}"

args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  if [ "${args[$i]}" = "--lang" ] && [ $((i + 1)) -lt ${#args[@]} ]; then
    BOOT_LANG="${args[$((i + 1))]}"
    break
  fi
done
case "$BOOT_LANG" in
  zh|zh-CN|cn) BOOT_LANG="zh" ;;
  ru|ru-RU) BOOT_LANG="ru" ;;
  fa|fa-IR|per|persian) BOOT_LANG="fa" ;;
  *) BOOT_LANG="zh" ;;
esac
export PIXELCAT_LANG="$BOOT_LANG"

if [ -z "${NO_COLOR:-}" ] && { [ -t 1 ] || [ -t 2 ]; }; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_BLUE=$'\033[34m'
  C_YELLOW=$'\033[33m'
else
  C_RESET=""
  C_RED=""
  C_GREEN=""
  C_BLUE=""
  C_YELLOW=""
fi

info() {
  printf '%b%s%b\n' "$C_BLUE" "$1" "$C_RESET"
}

success() {
  printf '%b%s%b\n' "$C_GREEN" "$1" "$C_RESET"
}

warn() {
  printf '%b%s%b\n' "$C_YELLOW" "$1" "$C_RESET" >&2
}

error() {
  printf '%b%s%b\n' "$C_RED" "$1" "$C_RESET" >&2
}

boot_msg() {
  case "${BOOT_LANG}:$1" in
    ru:need_root) printf 'Требуются права root, но sudo не найден. Запустите скрипт от root.' ;;
    fa:need_root) printf 'دسترسی root لازم است، اما sudo پیدا نشد. اسکریپت را با root اجرا کنید.' ;;
    *:need_root) printf '脚本需要 root 权限，但系统没有 sudo。请使用 root 运行。' ;;
    ru:missing_tools) printf 'Не найдены инструменты: %s. Выполняется автоматическая установка...' "$2" ;;
    fa:missing_tools) printf 'ابزارهای زیر پیدا نشدند: %s. نصب خودکار آغاز می‌شود...' "$2" ;;
    *:missing_tools) printf '缺少 %s，正在尝试自动安装...' "$2" ;;
    ru:unknown_pm) printf 'Менеджер пакетов не распознан. Установите вручную: %s' "$2" ;;
    fa:unknown_pm) printf 'مدیر بسته شناسایی نشد. این موارد را دستی نصب کنید: %s' "$2" ;;
    *:unknown_pm) printf '无法识别包管理器，请手动安装：%s' "$2" ;;
    ru:install_failed) printf 'Не удалось установить %s.' "$2" ;;
    fa:install_failed) printf 'نصب %s ناموفق بود.' "$2" ;;
    *:install_failed) printf '%s 安装失败。' "$2" ;;
    ru:downloading) printf 'Загрузка %s...' "$2" ;;
    fa:downloading) printf 'در حال دریافت %s...' "$2" ;;
    *:downloading) printf '正在下载 %s...' "$2" ;;
    ru:download_failed) printf 'Ошибка загрузки: %s' "$2" ;;
    fa:download_failed) printf 'دریافت ناموفق بود: %s' "$2" ;;
    *:download_failed) printf '下载失败：%s' "$2" ;;
    ru:extracting) printf 'Распаковка...' ;; fa:extracting) printf 'در حال استخراج...' ;; *:extracting) printf '正在解压...' ;;
    ru:no_deploy) printf 'После распаковки deploy.sh не найден.' ;; fa:no_deploy) printf 'پس از استخراج، deploy.sh پیدا نشد.' ;; *:no_deploy) printf '解压后没有找到 deploy.sh。' ;;
    ru:ready) printf 'Скрипт PixelCat Proxy готов.' ;; fa:ready) printf 'اسکریپت PixelCat Proxy آماده است.' ;; *:ready) printf 'PixelCat Proxy 脚本已准备完成。' ;;
  esac
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    error "$(boot_msg need_root)"
    exit 1
  fi
}

ensure_tools() {
  local missing=()
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -eq 0 ]; then
    return
  fi

  info "$(boot_msg missing_tools "${missing[*]}")"
  if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update >/dev/null
    run_as_root apt-get install -y "${missing[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y "${missing[@]}"
  elif command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y "${missing[@]}"
  elif command -v apk >/dev/null 2>&1; then
    run_as_root apk add --no-cache "${missing[@]}"
  else
    error "$(boot_msg unknown_pm "${missing[*]}")"
    exit 1
  fi

  for cmd in "${missing[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "$(boot_msg install_failed "$cmd")"
      exit 1
    fi
  done
}

ensure_tools curl tar

if ! mkdir -p "$BASE_DIR" 2>/dev/null; then
  run_as_root mkdir -p "$BASE_DIR"
fi

if [ ! -w "$BASE_DIR" ]; then
  run_as_root chown "$(id -u):$(id -g)" "$BASE_DIR"
fi

cd "$BASE_DIR"

# 同时支持分支和 tag
if printf '%s' "$REF" | grep -Eq '^v[0-9]'; then
  ARCHIVE_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/tags/${REF}"
else
  ARCHIVE_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REF}"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

archive="$tmp_dir/source.tar.gz"
extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir"

info "$(boot_msg downloading "${REPO_OWNER}/${REPO_NAME}@${REF}")"
if ! curl -fL "$ARCHIVE_URL" -o "$archive"; then
  error "$(boot_msg download_failed "$ARCHIVE_URL")"
  exit 1
fi

info "$(boot_msg extracting)"
tar -C "$extract_dir" -xzf "$archive"

src_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [ -z "$src_dir" ] || [ ! -f "$src_dir/deploy.sh" ]; then
  error "$(boot_msg no_deploy)"
  exit 1
fi

mkdir -p "$APP_DIR"

# 把所有内容(含隐藏文件)同步过去,保留 APP_DIR 里已有的 .env*
cp -rf "$src_dir"/. "$APP_DIR"/

cd "$APP_DIR"
chmod +x deploy.sh
success "$(boot_msg ready)"

# 把脚本的 stdin 切换到 /dev/tty,这样从 curl | bash 启动也能交互;
# 没有 tty(纯非交互或仅传 --help/--bbr 等)时保持原 stdin。
if (exec 0</dev/tty) >/dev/null 2>&1; then
  exec ./deploy.sh "$@" </dev/tty
fi

exec ./deploy.sh "$@"
