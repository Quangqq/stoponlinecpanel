#!/bin/sh

echo "======================================"
echo "   WHM/cPanel Safe Port Blocker"
echo "======================================"
echo ""

PORTS="2082 2083 2086 2087"

block_with_firewalld() {

    echo "[+] Using firewalld..."

    for PORT in $PORTS
    do
        firewall-cmd --permanent \
        --add-rich-rule="rule family='ipv4' port port='$PORT' protocol='tcp' reject" \
        >/dev/null 2>&1
    done

    firewall-cmd --reload >/dev/null 2>&1

    echo "[✓] firewalld rules applied"
}

block_with_ufw() {

    echo "[+] Using UFW..."

    for PORT in $PORTS
    do
        ufw deny ${PORT}/tcp >/dev/null 2>&1
    done

    echo "[✓] UFW rules applied"
}

block_with_iptables() {

    echo "[+] Using iptables..."

    for PORT in $PORTS
    do
        iptables -C INPUT -p tcp --dport $PORT -j DROP \
        >/dev/null 2>&1

        if [ $? -ne 0 ]; then
            iptables -A INPUT -p tcp --dport $PORT -j DROP
        fi
    done

    # Save rules
    if command -v service >/dev/null 2>&1; then

        service iptables save >/dev/null 2>&1

    fi

    if [ -d /etc/sysconfig ]; then

        iptables-save > /etc/sysconfig/iptables \
        2>/dev/null

    fi

    echo "[✓] iptables rules applied"
}

check_ports() {

    echo ""
    echo "[+] Checking ports..."
    echo ""

    for PORT in $PORTS
    do

        ACTIVE=1

        if command -v ss >/dev/null 2>&1; then

            ss -lnt 2>/dev/null | \
            grep -w ":$PORT" >/dev/null 2>&1

            ACTIVE=$?

        elif command -v netstat >/dev/null 2>&1; then

            netstat -lnt 2>/dev/null | \
            grep -w ":$PORT" >/dev/null 2>&1

            ACTIVE=$?

        fi

        if [ "$ACTIVE" = "0" ]; then
            echo "[!] Port $PORT still listening"
        else
            echo "[✓] Port $PORT blocked"
        fi

    done
}

# Root check
if [ "$(id -u)" != "0" ]; then
    echo "[!] Please run as root"
    exit 1
fi

echo "[+] Detecting firewall..."

# firewalld
if command -v firewall-cmd >/dev/null 2>&1; then

    block_with_firewalld
    check_ports

    echo ""
    echo "[✓] Done"
    exit 0
fi

# ufw
if command -v ufw >/dev/null 2>&1; then

    block_with_ufw
    check_ports

    echo ""
    echo "[✓] Done"
    exit 0
fi

# iptables
if command -v iptables >/dev/null 2>&1; then

    block_with_iptables
    check_ports

    echo ""
    echo "[✓] Done"
    exit 0
fi

echo "[!] No supported firewall found"
exit 1
