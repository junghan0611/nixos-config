#!/usr/bin/env bash
# 192.168.x.0/24 대역 허브 스캔 (IP + MAC 주소)
# Usage: scan-hubs [서브넷 번호]
# Example: scan-hubs 165  # 192.168.165.0/24 스캔

set -euo pipefail

# 서브넷 입력 받기
if [[ -n "${1:-}" ]]; then
    SUBNET="$1"
else
    read -p "📡 서브넷 입력 (192.168.X.0의 X 값, 기본값 0): " SUBNET
    SUBNET="${SUBNET:-0}"
fi

NETWORK="192.168.${SUBNET}.0/24"

# nmap 설치 확인
if ! command -v nmap &> /dev/null; then
    echo "❌ nmap 필요: nix-shell -p nmap"
    exit 1
fi

scan() {
    echo "========================================"
    echo "📡 허브 스캔 - $(date '+%H:%M:%S')"
    echo "   네트워크: $NETWORK"
    echo "========================================"
    echo ""
    printf "%-4s %-16s %-20s %s\n" "#" "IP" "MAC" "VENDOR"
    echo "----------------------------------------"

    # nmap으로 IP + MAC 스캔 (sudo 필요)
    sudo nmap -sn -PR "$NETWORK" 2>/dev/null | \
    awk '
    /Nmap scan report/ { ip=$5 }
    /MAC Address:/ {
        mac=$3
        vendor=""
        for(i=4; i<=NF; i++) vendor=vendor" "$i
        gsub(/^\(|\)$/, "", vendor)
        printf "%-4d %-16s %-20s %s\n", NR, ip, mac, vendor
    }
    '

    echo ""
    echo "----------------------------------------"
    echo "💡 아무 키: 새로고침 | q: 종료"
}

echo "🔍 허브 스캔: $NETWORK"
echo ""

# 첫 스캔
scan

# 키 입력 대기 루프
while true; do
    read -rsn1 key
    if [[ "$key" == "q" || "$key" == "Q" ]]; then
        echo ""
        echo "👋 종료"
        exit 0
    fi
    clear
    scan
done
