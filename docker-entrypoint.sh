#!/bin/sh
set -eu

required_vars="DOMAIN USERNAME PASSWORD DECOY_DOMAIN"
for name in $required_vars; do
	value="$(printenv "$name" || true)"
	if [ -z "$value" ]; then
		echo "Missing required environment variable: $name" >&2
		exit 1
	fi
done

case "$DECOY_DOMAIN" in
	http://*|https://*)
		echo "DECOY_DOMAIN must be a host name only, for example: www.example.com" >&2
		exit 1
		;;
esac

if [ -z "${EMAIL:-}" ]; then
	sed '/email ${EMAIL}/d' /etc/caddy/Caddyfile.template > /tmp/Caddyfile.template
else
	cp /etc/caddy/Caddyfile.template /tmp/Caddyfile.template
fi

envsubst '${DOMAIN} ${USERNAME} ${PASSWORD} ${DECOY_DOMAIN} ${EMAIL}' < /tmp/Caddyfile.template > /etc/caddy/Caddyfile

exec "$@"
