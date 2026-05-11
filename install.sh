#!/usr/bin/env bash
set -Eeuo pipefail

REPO_OWNER="${REPO_OWNER:-PixelCatICU}"
REPO_NAME="${REPO_NAME:-pixelcat-proxy}"
BASE_DIR="${BASE_DIR:-/opt/pixelcat}"
APP_DIR="${APP_DIR:-pixelcat-forwardproxy}"
LEGACY_APP_DIR="${LEGACY_APP_DIR:-pixelcat-naiveproxy}"
REF="${REF:-main}"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "脚本需要 root 权限,但系统没有 sudo。请使用 root 运行。" >&2
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

  echo "缺少 ${missing[*]},正在尝试自动安装..."
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
    echo "无法识别包管理器,请手动安装:${missing[*]}" >&2
    exit 1
  fi

  for cmd in "${missing[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "$cmd 安装失败。" >&2
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

if [ ! -e "$APP_DIR" ] && [ -e "$LEGACY_APP_DIR" ]; then
  echo "检测到旧项目目录 $LEGACY_APP_DIR,正在改名为 $APP_DIR..."
  mv "$LEGACY_APP_DIR" "$APP_DIR"
fi

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

echo "正在下载 ${REPO_OWNER}/${REPO_NAME}@${REF}..."
if ! curl -fL "$ARCHIVE_URL" -o "$archive"; then
  echo "下载失败:$ARCHIVE_URL" >&2
  exit 1
fi

echo "正在解压..."
tar -C "$extract_dir" -xzf "$archive"

src_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [ -z "$src_dir" ] || [ ! -f "$src_dir/deploy.sh" ]; then
  echo "解压后没有找到 deploy.sh。" >&2
  exit 1
fi

mkdir -p "$APP_DIR"

# 把所有内容(含隐藏文件)同步过去,保留 APP_DIR 里已有的 .env*
cp -rf "$src_dir"/. "$APP_DIR"/

cd "$APP_DIR"
chmod +x deploy.sh

# 把脚本的 stdin 切换到 /dev/tty,这样从 curl | bash 启动也能交互;
# 没有 tty(纯非交互或仅传 --help/--bbr 等)时保持原 stdin。
if (exec 0</dev/tty) >/dev/null 2>&1; then
  exec ./deploy.sh "$@" </dev/tty
fi

exec ./deploy.sh "$@"
