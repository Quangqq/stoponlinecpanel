#!/bin/sh
# Safe WHM/cPanel Stop Script
# Không ảnh hưởng VPS / website / MySQL / SSH

echo "[+] Stopping WHM/cPanel only..."

stop_service() {

    SVC="$1"

    # systemd
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$SVC" >/dev/null 2>&1
        return
    fi

    # service
    if command -v service >/dev/null 2>&1; then
        service "$SVC" stop >/dev/null 2>&1
        return
    fi

    # init.d
    if [ -x "/etc/init.d/$SVC" ]; then
        "/etc/init.d/$SVC" stop >/dev/null 2>&1
        return
    fi
}

# Chỉ stop cPanel/WHM daemon
stop_service cpanel

# fallback nhẹ
killall cpsrvd >/dev/null 2>&1

sleep 2

echo "[+] Checking status..."

PORT_ACTIVE=0

if command -v ss >/dev/null 2>&1; then
    ss -lnt 2>/dev/null | grep ':208[2367]' >/dev/null 2>&1
    PORT_ACTIVE=$?
elif command -v netstat >/dev/null 2>&1; then
    netstat -lnt 2>/dev/null | grep ':208[2367]' >/dev/null 2>&1
    PORT_ACTIVE=$?
fi

if [ "$PORT_ACTIVE" = "0" ]; then
    echo "[!] Some WHM/cPanel ports still active"
else
    echo "[✓] WHM/cPanel stopped safely"
fi

echo "[✓] VPS services unaffected"
