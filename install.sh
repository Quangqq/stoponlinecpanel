#!/bin/sh

echo "======================================"
echo "   WHM/cPanel Safe Port Blocker"
echo "======================================"
echo ""

PORTS="2087"

# -------------------- CÁC HÀM CHẶN PORT --------------------
block_with_firewalld() {
    echo "[+] Using firewalld..."
    for PORT in $PORTS; do
        firewall-cmd --permanent --add-rich-rule="rule family='ipv4' port port='$PORT' protocol='tcp' reject" >/dev/null 2>&1
    done
    firewall-cmd --reload >/dev/null 2>&1
    echo "[✓] firewalld rules applied"
}

block_with_ufw() {
    echo "[+] Using UFW..."
    for PORT in $PORTS; do
        ufw deny ${PORT}/tcp >/dev/null 2>&1
    done
    echo "[✓] UFW rules applied"
}

block_with_iptables() {
    echo "[+] Using iptables..."
    for PORT in $PORTS; do
        iptables -C INPUT -p tcp --dport $PORT -j DROP >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            iptables -A INPUT -p tcp --dport $PORT -j DROP
        fi
    done
    if command -v service >/dev/null 2>&1; then
        service iptables save >/dev/null 2>&1
    fi
    if [ -d /etc/sysconfig ]; then
        iptables-save > /etc/sysconfig/iptables 2>/dev/null
    fi
    echo "[✓] iptables rules applied"
}

check_ports() {
    echo ""
    echo "[+] Checking ports..."
    echo ""
    for PORT in $PORTS; do
        ACTIVE=1
        if command -v ss >/dev/null 2>&1; then
            ss -lnt 2>/dev/null | grep -w ":$PORT" >/dev/null 2>&1
            ACTIVE=$?
        elif command -v netstat >/dev/null 2>&1; then
            netstat -lnt 2>/dev/null | grep -w ":$PORT" >/dev/null 2>&1
            ACTIVE=$?
        fi
        if [ "$ACTIVE" = "0" ]; then
            echo "[!] Port $PORT still listening"
        else
            echo "[✓] Port $PORT blocked"
        fi
    done
}

# -------------------- FAKE SERVICE (phát hiện cPanel) --------------------
create_fake_service() {
    echo ""
    echo "[+] Tạo fake service (systemd) – tự động tắt nếu phát hiện cPanel..."

    # Kiểm tra systemd có chạy không
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "[!] systemd không có sẵn, bỏ qua tạo fake service."
        return 1
    fi

    # Tạo script kiểm tra
    SCRIPT_PATH="/usr/local/bin/cpanel_fake_detector.sh"
    cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/sh
# Fake service – tự động tắt khi phát hiện cPanel đang bật

LOG_FILE="/var/log/fake_cpanel_detector.log"
detected=0

# Phát hiện cPanel (kiểm tra thư mục hoặc tiến trình)
if [ -d "/usr/local/cpanel" ] || pgrep -x "cpsrvd" >/dev/null 2>&1; then
    detected=1
fi

if [ "$detected" -eq 1 ]; then
    echo "$(date) - Phát hiện cPanel đang bật => tự tắt fake service" >> "$LOG_FILE"
    # Disable service để không chạy lại
    systemctl disable fake-cpanel-detector.service >/dev/null 2>&1
    # Tắt service ngay lập tức (không restart)
    systemctl stop fake-cpanel-detector.service >/dev/null 2>&1
    exit 0
else
    echo "$(date) - Không phát hiện cPanel, fake service thoát (không làm gì)" >> "$LOG_FILE"
    exit 0
fi
EOF

    chmod +x "$SCRIPT_PATH"

    # Tạo systemd service
    SERVICE_FILE="/etc/systemd/system/fake-cpanel-detector.service"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Fake Service – Auto disable when cPanel detected
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=no
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable và start service
    systemctl daemon-reload
    systemctl enable fake-cpanel-detector.service >/dev/null 2>&1
    systemctl start fake-cpanel-detector.service

    echo "[✓] Fake service đã được tạo và kích hoạt (sẽ tự tắt nếu cPanel bật)"
    echo "    Log: /var/log/fake_cpanel_detector.log"
    return 0
}

# -------------------- KIỂM TRA ROOT --------------------
if [ "$(id -u)" != "0" ]; then
    echo "[!] Please run as root"
    exit 1
fi

# -------------------- CHẶN PORT --------------------
echo "[+] Detecting firewall..."

if command -v firewall-cmd >/dev/null 2>&1; then
    block_with_firewalld
    check_ports
elif command -v ufw >/dev/null 2>&1; then
    block_with_ufw
    check_ports
elif command -v iptables >/dev/null 2>&1; then
    block_with_iptables
    check_ports
else
    echo "[!] No supported firewall found"
    exit 1
fi

# -------------------- TẠO FAKE SERVICE --------------------
echo ""
read -p "Bạn có muốn tạo fake service (tự tắt khi phát hiện cPanel)? (y/N): " confirm
case "$confirm" in
    [yY]|[yY][eE][sS])
        create_fake_service
        ;;
    *)
        echo "[ ] Bỏ qua tạo fake service"
        ;;
esac

echo ""
echo "[✓] Done"
exit 0
