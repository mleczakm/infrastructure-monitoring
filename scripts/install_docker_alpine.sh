
#!/bin/sh
set -e
# Włącz community repo (jeśli nie ma)
if ! grep -q "community" /etc/apk/repositories; then
  echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories
fi
apk update
apk add docker docker-cli-compose
rc-update add docker default
service docker start
# Katalogi na dane
mkdir -p /opt/infrastructure-monitoring
. /opt/infrastructure-monitoring/.env 2>/dev/null || true
mkdir -p "$BESZEL_DATA" "$KUMA_DATA" "$DATABASUS_DATA" "$RESTICPROFILE_DIR"
