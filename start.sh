#!/bin/bash
set -euo pipefail

COOKIES="/tmp/cookies.txt"
PORT_FILE="${PORT_FORWARDED}"
RECHECK_TIME="${RECHECK_TIME:-60}"
QBIT_BASE_URL="${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}"

trap 'rm -f "$COOKIES"' EXIT

validate_port () {
  if [ ! -f "$PORT_FILE" ]; then
    return 1
  fi
  local raw
  raw="$(cat "$PORT_FILE" 2>/dev/null || true)"
  raw="${raw//$'\r'/}"
  raw="${raw//$'\n'/}"
  raw="${raw// /}"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf "%s" "$raw"
    return 0
  fi
  return 1
}

login_qb () {
  rm -f "$COOKIES"
  curl -sS -c "$COOKIES" \
    -H "Referer: ${QBIT_BASE_URL}/" \
    -H "Origin: ${QBIT_BASE_URL}" \
    --data "username=${QBITTORRENT_USER}&password=${QBITTORRENT_PASS}" \
    "${QBIT_BASE_URL}/api/v2/auth/login" > /dev/null || return 1
  grep -q 'SID' "$COOKIES"
}

set_listen_port () {
  local port="$1"
  curl -sS -b "$COOKIES" \
    -H "Referer: ${QBIT_BASE_URL}/" \
    -H "Origin: ${QBIT_BASE_URL}" \
    --data-urlencode "json={\"listen_port\": ${port}}" \
    "${QBIT_BASE_URL}/api/v2/app/setPreferences" > /dev/null
}

update_port () {
  local port
  port="$(validate_port || true)"
  if [ -z "${port:-}" ]; then
    echo "Forwarded port is missing/invalid in $PORT_FILE"
    return 1
  fi
  local attempt
  for attempt in 1 2 3; do
    if login_qb && set_listen_port "$port"; then
      rm -f "$COOKIES"
      echo "Successfully updated qbittorrent to port $port"
      return 0
    fi
    echo "Failed to update (attempt $attempt). Retrying in 3s..."
    sleep 3
  done
  rm -f "$COOKIES"
  return 1
}

watch_port_file () {
  local dir
  dir="$(dirname "$PORT_FILE")"
  mkdir -p "$dir"
  if [ -f "$PORT_FILE" ]; then
    update_port || true
  fi
  inotifywait -mq -e close_write,create,moved_to "$dir" --format "%w%f" | while read -r path; do
    if [ "$path" = "$PORT_FILE" ]; then
      update_port || true
    fi
  done
}

periodic_recheck () {
  local interval="$RECHECK_TIME"
  if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
    interval=60
  fi
  while sleep "$interval"; do
    update_port || true
  done
}

until login_qb; do
  echo "Waiting for qBittorrent WebUI at $QBIT_BASE_URL..."
  sleep 5
done
rm -f "$COOKIES"

periodic_recheck &
watch_port_file
