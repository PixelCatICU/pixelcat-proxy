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
PASSWORD_FROM_ARG="false"
DOCKER_CMD="docker"

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

require_option_value() {
  local option="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    echo "$option requires a value." >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
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

configure_docker_command() {
  if docker compose version >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    DOCKER_CMD="docker"
    return
  fi

  if command -v sudo >/dev/null 2>&1 && sudo docker compose version >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
    return
  fi

  echo "Docker is installed, but the current user cannot access the Docker daemon." >&2
  echo "Try rerunning this script as root, or add your user to the docker group and log in again." >&2
  exit 1
}

DOMAIN="$(strip_scheme "$(prompt_value DOMAIN "Proxy domain, for example proxy.example.com" "$DOMAIN")")"
USERNAME="$(prompt_value USERNAME "NaiveProxy username" "$USERNAME")"
PASSWORD="$(prompt_value PASSWORD "NaiveProxy password" "$PASSWORD" true)"
DECOY_DOMAIN="$(strip_scheme "$(prompt_value DECOY_DOMAIN "Decoy domain, for example www.example.com" "$DECOY_DOMAIN")")"
EMAIL="$(prompt_optional "ACME email" "$EMAIL")"
HTTP_PORT="$(prompt_optional "Host HTTP port" "$HTTP_PORT" "80")"
HTTPS_PORT="$(prompt_optional "Host HTTPS port" "$HTTPS_PORT" "443")"

if [ "$PASSWORD_FROM_ARG" = "true" ]; then
  echo "Warning: passing --password can expose it in shell history and process lists." >&2
  echo "For production, run ./deploy.sh and enter the password interactively." >&2
fi

if ! is_valid_host "$DOMAIN"; then
  echo "Invalid DOMAIN: $DOMAIN" >&2
  exit 1
fi

if ! is_valid_host "$DECOY_DOMAIN"; then
  echo "Invalid DECOY_DOMAIN: $DECOY_DOMAIN" >&2
  exit 1
fi

if ! is_valid_username "$USERNAME"; then
  echo "Invalid USERNAME: use 1-128 characters: A-Z a-z 0-9 . _ ~ -" >&2
  exit 1
fi

if [ "$DOMAIN" = "$DECOY_DOMAIN" ]; then
  echo "DOMAIN and DECOY_DOMAIN should not be the same." >&2
  exit 1
fi

if [ -n "$EMAIL" ] && ! printf '%s' "$EMAIL" | grep -Eq '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'; then
  echo "Invalid EMAIL: $EMAIL" >&2
  exit 1
fi

if ! is_valid_port "$HTTP_PORT"; then
  echo "Invalid HTTP_PORT: $HTTP_PORT" >&2
  exit 1
fi

if ! is_valid_port "$HTTPS_PORT"; then
  echo "Invalid HTTPS_PORT: $HTTPS_PORT" >&2
  exit 1
fi

for value_name in DOMAIN USERNAME PASSWORD DECOY_DOMAIN EMAIL HTTP_PORT HTTPS_PORT; do
  value="$(eval "printf '%s' \"\${$value_name}\"")"
  if ! is_safe_env_value "$value"; then
    echo "$value_name cannot contain newlines." >&2
    exit 1
  fi
done

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
echo ".env has been written."

if [ "$SKIP_START" = "true" ]; then
  echo "Skipped docker compose start."
  exit 0
fi

install_docker
configure_docker_command

echo
echo "Pulling image and starting service..."
$DOCKER_CMD compose pull
$DOCKER_CMD compose up -d

echo
echo "Deployment finished."
echo "Proxy URL: https://$USERNAME:******@$DOMAIN"
echo "Logs: docker compose logs -f"
