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
INSTALL_DOCKER="auto"

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
      --no-install-docker
                           Do not install Docker automatically
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
    --no-install-docker)
      INSTALL_DOCKER="false"
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

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "This command needs root privileges, but sudo is not installed." >&2
    exit 1
  fi
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi

  if [ "$INSTALL_DOCKER" = "false" ]; then
    echo "Docker is not installed. Install Docker first, then rerun this script." >&2
    exit 1
  fi

  if [ "$ASSUME_YES" != "true" ]; then
    read -r -p "Docker is not installed. Install Docker Engine now? [y/N]: " install_confirm
    case "$install_confirm" in
      y|Y|yes|YES)
        ;;
      *)
        echo "Canceled. Install Docker first, then rerun this script."
        exit 0
        ;;
    esac
  fi

  if [ "$(uname -s)" != "Linux" ]; then
    echo "Automatic Docker installation only supports Linux." >&2
    echo "Install Docker Desktop manually, then rerun this script." >&2
    exit 1
  fi

  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  else
    echo "Cannot detect Linux distribution: /etc/os-release not found." >&2
    exit 1
  fi

  local distro_id="${ID:-}"
  local distro_like="${ID_LIKE:-}"

  echo
  echo "Installing Docker Engine..."

  case "$distro_id $distro_like" in
    *ubuntu*|*debian*)
      local docker_repo_os="$distro_id"
      if [ "$distro_id" != "ubuntu" ] && [ "$distro_id" != "debian" ]; then
        if echo "$distro_like" | grep -q "ubuntu"; then
          docker_repo_os="ubuntu"
        elif echo "$distro_like" | grep -q "debian"; then
          docker_repo_os="debian"
        fi
      fi
      run_as_root apt-get update
      run_as_root apt-get install -y ca-certificates curl gnupg
      run_as_root install -m 0755 -d /etc/apt/keyrings
      if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        run_as_root curl -fsSL https://download.docker.com/linux/"$docker_repo_os"/gpg -o /etc/apt/keyrings/docker.asc
        run_as_root chmod a+r /etc/apt/keyrings/docker.asc
      fi
      local arch
      arch="$(dpkg --print-architecture)"
      local codename="${VERSION_CODENAME:-}"
      if [ -z "$codename" ] && command -v lsb_release >/dev/null 2>&1; then
        codename="$(lsb_release -cs)"
      fi
      if [ -z "$codename" ]; then
        echo "Cannot detect Debian/Ubuntu codename." >&2
        exit 1
      fi
      echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$docker_repo_os $codename stable" | run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null
      run_as_root apt-get update
      run_as_root apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;
    *centos*|*rhel*|*rocky*|*almalinux*|*fedora*)
      if command -v dnf >/dev/null 2>&1; then
        run_as_root dnf install -y dnf-plugins-core
        run_as_root dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        run_as_root dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      elif command -v yum >/dev/null 2>&1; then
        run_as_root yum install -y yum-utils
        run_as_root yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        run_as_root yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      else
        echo "Neither dnf nor yum is available." >&2
        exit 1
      fi
      ;;
    *alpine*)
      run_as_root apk add --no-cache docker docker-cli-compose
      ;;
    *)
      echo "Unsupported Linux distribution: ${PRETTY_NAME:-unknown}" >&2
      echo "Install Docker manually, then rerun this script." >&2
      exit 1
      ;;
  esac

  if command -v systemctl >/dev/null 2>&1; then
    run_as_root systemctl enable --now docker
  elif command -v service >/dev/null 2>&1; then
    run_as_root service docker start || true
  fi

  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker installation finished, but docker command is still unavailable." >&2
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin is not available after installation." >&2
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

install_docker

echo
echo "Pulling image and starting service..."
docker compose pull
docker compose up -d

echo
echo "Deployment finished."
echo "Proxy URL: https://$USERNAME:******@$DOMAIN"
echo "Logs: docker compose logs -f"
