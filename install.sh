#!/bin/bash
# Stop only cPanel/WHM services safely

set -e

echo "[+] Detecting init system..."

stop_service() {
    local svc="$1"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$svc" 2>/dev/null || true
    else
        service "$svc" stop 2>/dev/null || true
    fi
}

echo "[+] Stopping cPanel/WHM services..."

SERVICES=(
    cpanel
    cpsrvd
    chkservd
    tailwatchd
    cpdavd
)

for svc in "${SERVICES[@]}"; do
    stop_service "$svc"
done

echo "[+] Stopping internal cPanel daemons..."

if [ -d /usr/local/cpanel/scripts ]; then
    for f in /usr/local/cpanel/scripts/restartsrv_*; do
        [ -f "$f" ] || continue
        "$f" --stop 2>/dev/null || true
    done
fi

echo "[+] Killing remaining cPanel-only processes..."

pkill -TERM -f '/usr/local/cpanel' 2>/dev/null || true
sleep 2
pkill -9 -f '/usr/local/cpanel' 2>/dev/null || true

echo "[✓] cPanel/WHM stopped successfully."
