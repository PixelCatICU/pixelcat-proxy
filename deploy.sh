#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN="${DOMAIN:-}"
USERNAME="${USERNAME:-}"
PASSWORD="${PASSWORD:-}"
DECOY_DOMAIN="${DECOY_DOMAIN:-}"
EMAIL="${EMAIL:-}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
ASSUME_YES="false"
SKIP_START="false"

usage() {
  cat <<'USAGE'
PixelCat NaiveProxy one-click deploy script

Usage:
  ./deploy.sh
  ./deploy.sh --domain proxy.example.com --username user --password pass --decoy-domain www.example.com --email admin@example.com

Options:
  -d, --domain          Proxy domain, required
  -u, --username        NaiveProxy username, required
  -p, --password        NaiveProxy password, required
      --decoy-domain    Decoy reverse proxy domain, required
  -e, --email           ACME email, optional
      --http-port       Host HTTP port, default: 80
      --https-port      Host HTTPS port, default: 443
  -y, --yes             Overwrite .env without asking
      --skip-start      Only write .env, do not run docker compose
  -h, --help            Show help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    -u|--username)
      USERNAME="${2:-}"
      shift 2
      ;;
    -p|--password)
      PASSWORD="${2:-}"
      shift 2
      ;;
    --decoy-domain)
      DECOY_DOMAIN="${2:-}"
      shift 2
      ;;
    -e|--email)
      EMAIL="${2:-}"
      shift 2
      ;;
    --http-port)
      HTTP_PORT="${2:-80}"
      shift 2
      ;;
    --https-port)
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
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

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

    echo "$var_name cannot be empty." >&2
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

  if [ -n "$default_value" ]; then
    read -r -p "$label [$default_value]: " input
    printf '%s' "${input:-$default_value}"
  else
    read -r -p "$label, optional: " input
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

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1" >&2
    exit 1
  fi
}

DOMAIN="$(strip_scheme "$(prompt_value DOMAIN "Proxy domain, for example proxy.example.com" "$DOMAIN")")"
USERNAME="$(prompt_value USERNAME "NaiveProxy username" "$USERNAME")"
PASSWORD="$(prompt_value PASSWORD "NaiveProxy password" "$PASSWORD" true)"
DECOY_DOMAIN="$(strip_scheme "$(prompt_value DECOY_DOMAIN "Decoy domain, for example www.example.com" "$DECOY_DOMAIN")")"
EMAIL="$(prompt_optional "ACME email" "$EMAIL")"
HTTP_PORT="$(prompt_optional "Host HTTP port" "$HTTP_PORT" "80")"
HTTPS_PORT="$(prompt_optional "Host HTTPS port" "$HTTPS_PORT" "443")"

if [ "$DOMAIN" = "$DECOY_DOMAIN" ]; then
  echo "DOMAIN and DECOY_DOMAIN should not be the same." >&2
  exit 1
fi

if [ -f ".env" ] && [ "$ASSUME_YES" != "true" ]; then
  read -r -p ".env already exists. Overwrite it? [y/N]: " overwrite
  case "$overwrite" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Canceled."
      exit 0
      ;;
  esac
fi

cat > .env <<EOF
DOMAIN=$DOMAIN
USERNAME=$USERNAME
PASSWORD=$PASSWORD
DECOY_DOMAIN=$DECOY_DOMAIN
EMAIL=$EMAIL
HTTP_PORT=$HTTP_PORT
HTTPS_PORT=$HTTPS_PORT
EOF

chmod 600 .env

echo
echo ".env has been written."

if [ "$SKIP_START" = "true" ]; then
  echo "Skipped docker compose start."
  exit 0
fi

need_command docker

echo
echo "Pulling image and starting service..."
docker compose pull
docker compose up -d

echo
echo "Deployment finished."
echo "Proxy URL: https://$USERNAME:******@$DOMAIN"
echo "Logs: docker compose logs -f"
