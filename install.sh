#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/PixelCatICU/pixelcat-naiveproxy.git}"
BASE_DIR="${BASE_DIR:-/opt/pixelcat}"
APP_DIR="${APP_DIR:-pixelcat-naiveproxy}"
BRANCH="${BRANCH:-main}"

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "This script needs root privileges to create $BASE_DIR, but sudo is not installed." >&2
    exit 1
  fi
}

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
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

if [ -d "$APP_DIR/.git" ]; then
  echo "Updating $APP_DIR..."
  git -C "$APP_DIR" fetch origin "$BRANCH"
  git -C "$APP_DIR" checkout "$BRANCH"
  git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
else
  if [ -e "$APP_DIR" ]; then
    echo "$BASE_DIR/$APP_DIR already exists, but it is not a Git repository." >&2
    exit 1
  fi

  echo "Cloning $REPO_URL..."
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
chmod +x deploy.sh
exec ./deploy.sh "$@"
