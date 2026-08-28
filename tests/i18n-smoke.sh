#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "$ROOT/deploy.sh"
bash -n "$ROOT/install.sh"

ru_help="$(NO_COLOR=1 "$ROOT/deploy.sh" --lang ru --help)"
fa_help="$(NO_COLOR=1 "$ROOT/deploy.sh" --lang fa --help)"
zh_help="$(NO_COLOR=1 "$ROOT/deploy.sh" --lang zh --help)"

grep -q 'Использование' <<<"$ru_help"
grep -q 'روش استفاده' <<<"$fa_help"
grep -q '用法' <<<"$zh_help"

if NO_COLOR=1 "$ROOT/deploy.sh" --lang en --help >/dev/null 2>&1; then
  echo 'unsupported language unexpectedly succeeded' >&2
  exit 1
fi

printf 'i18n smoke: zh/ru/fa OK\n'
