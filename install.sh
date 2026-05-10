#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/PixelCatICU/pixelcat-naiveproxy.git}"
BASE_DIR="${BASE_DIR:-/opt/pixelcat}"
APP_DIR="${APP_DIR:-pixelcat-forwardproxy}"
LEGACY_APP_DIR="${LEGACY_APP_DIR:-pixelcat-naiveproxy}"
BRANCH="${BRANCH:-main}"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "脚本需要 root 权限创建 $BASE_DIR，但系统没有 sudo。请使用 root 运行。" >&2
    exit 1
  fi
}

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少命令: $1" >&2
    exit 1
  fi
}

need_command git

if ! mkdir -p "$BASE_DIR" 2>/dev/null; then
  run_as_root mkdir -p "$BASE_DIR"
fi

if [ ! -w "$BASE_DIR" ]; then
  run_as_root chown "$(id -u):$(id -g)" "$BASE_DIR"
fi

cd "$BASE_DIR"

if [ ! -e "$APP_DIR" ] && [ -d "$LEGACY_APP_DIR/.git" ]; then
  echo "检测到旧项目目录 $LEGACY_APP_DIR，正在改名为 $APP_DIR..."
  mv "$LEGACY_APP_DIR" "$APP_DIR"
fi

if [ -d "$APP_DIR/.git" ]; then
  echo "正在更新 $APP_DIR..."
  git -C "$APP_DIR" fetch origin "$BRANCH"
  git -C "$APP_DIR" checkout "$BRANCH"
  git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
else
  if [ -e "$APP_DIR" ]; then
    echo "$BASE_DIR/$APP_DIR 已存在，但不是 Git 仓库。" >&2
    exit 1
  fi

  echo "正在克隆 $REPO_URL..."
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
chmod +x deploy.sh

if [ -r /dev/tty ]; then
  exec ./deploy.sh "$@" < /dev/tty
fi

exec ./deploy.sh "$@"
