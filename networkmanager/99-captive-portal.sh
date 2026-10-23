#!/bin/bash
IFACE="$1"
ACTION="$2"

# 네트워크 인터페이스가 활성화되었을 때
if [ "$ACTION" = "up" ]; then
    # IP 할당 및 DNS 설정이 안정화될 때까지 2초 대기
    sleep 2

    STATUS=$(nmcli networking connectivity check)

    if [ "$STATUS" = "portal" ] || [ "$STATUS" = "limited" ]; then
        TARGET_USER="junghee"
        TARGET_UID=1000

        # 데스크톱 알림
        sudo -u "$TARGET_USER" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
            DISPLAY=:0 \
            notify-send "와이파이 인증 필요" "캡티브 포털 로그인 페이지를 엽니다." -i network-wireless 2>/dev/null || true

        # 캡티브 포털 브라우저 실행
        sudo -u "$TARGET_USER" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
            DISPLAY=:0 \
            xdg-open "http://captive.apple.com" >/dev/null 2>&1 &
    fi
fi
