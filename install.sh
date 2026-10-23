#!/bin/bash
set -e

# ANSI 색상 코드
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="$(id -un)"
CURRENT_UID="$(id -u)"
USER_HOME="$HOME"

echo -e "${BLUE}=== Dotfiles 자동 설치 및 복원 시작 ===${NC}"
echo -e "대상 사용자: ${GREEN}${CURRENT_USER}${NC} (UID: ${CURRENT_UID})"
echo -e "Dotfiles 경로: ${GREEN}${DOTFILES_DIR}${NC}\n"

# 1. 디렉터리 준비
echo -e "${BLUE}[1/5] 대상 디렉터리 생성 중...${NC}"
mkdir -p "${USER_HOME}/.config/opencode"
mkdir -p "${USER_HOME}/.local/share/aurorae/themes"
mkdir -p "${USER_HOME}/.local/share/color-schemes"
mkdir -p "${USER_HOME}/.local/share/plasma/desktoptheme"
mkdir -p "${USER_HOME}/.local/share/plasma/look-and-feel"

# 2. KDE 테마 및 장식 파일 복사
echo -e "${BLUE}[2/5] 커스텀 테마(Irixium 네이비 블루 및 버튼) 복사 중...${NC}"
if [ -d "${DOTFILES_DIR}/local-share/aurorae/themes/Irixium" ]; then
    cp -r "${DOTFILES_DIR}/local-share/aurorae/themes/Irixium" "${USER_HOME}/.local/share/aurorae/themes/"
fi
if [ -f "${DOTFILES_DIR}/local-share/color-schemes/Irixium.colors" ]; then
    cp "${DOTFILES_DIR}/local-share/color-schemes/Irixium.colors" "${USER_HOME}/.local/share/color-schemes/"
fi
if [ -d "${DOTFILES_DIR}/local-share/plasma/desktoptheme/irixium" ]; then
    cp -r "${DOTFILES_DIR}/local-share/plasma/desktoptheme/irixium" "${USER_HOME}/.local/share/plasma/desktoptheme/"
fi
if [ -d "${DOTFILES_DIR}/local-share/plasma/look-and-feel/Irixium" ]; then
    cp -r "${DOTFILES_DIR}/local-share/plasma/look-and-feel/Irixium" "${USER_HOME}/.local/share/plasma/look-and-feel/"
fi

# 3. 설정 파일(단축키, 창 장식, OpenCode) 복사
echo -e "${BLUE}[3/5] 설정 파일(단축키 및 OpenCode 테마) 복사 중...${NC}"
cp "${DOTFILES_DIR}/config/kglobalshortcutsrc" "${USER_HOME}/.config/"
cp "${DOTFILES_DIR}/config/kwinrc" "${USER_HOME}/.config/"
cp "${DOTFILES_DIR}/config/opencode/cli.json" "${USER_HOME}/.config/opencode/"

# 4. NetworkManager 캡티브 포털 자동 팝업 설정 (sudo 필요)
echo -e "${BLUE}[4/5] 캡티브 포털 자동 팝업 설정 적용 중 (sudo 권한 필요)...${NC}"
if sudo -v 2>/dev/null; then
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo mkdir -p /etc/NetworkManager/dispatcher.d

    sudo cp "${DOTFILES_DIR}/networkmanager/20-connectivity.conf" /etc/NetworkManager/conf.d/
    
    # 디스패처 스크립트 복사 및 현재 사용자에 맞게 UID/USER 동적 업데이트
    TMP_SCRIPT="/tmp/99-captive-portal.sh"
    sed -e "s/TARGET_USER=\"[^\"]*\"/TARGET_USER=\"${CURRENT_USER}\"/" \
        -e "s/TARGET_UID=[0-9]*/TARGET_UID=${CURRENT_UID}/" \
        "${DOTFILES_DIR}/networkmanager/99-captive-portal.sh" > "${TMP_SCRIPT}"
    
    sudo mv "${TMP_SCRIPT}" /etc/NetworkManager/dispatcher.d/99-captive-portal.sh
    sudo chmod +x /etc/NetworkManager/dispatcher.d/99-captive-portal.sh
    sudo nmcli general reload 2>/dev/null || true
    echo -e "${GREEN}NetworkManager 캡티브 포털 설정 완료.${NC}"
else
    echo -e "${YELLOW}sudo 권한이 없어 NetworkManager 설정은 건너뛰었습니다.${NC}"
fi

# 5. 실행 중인 KDE 데몬 리로드
echo -e "${BLUE}[5/5] KDE 세션 및 단축키 데몬 갱신 중...${NC}"
if command -v qdbus >/dev/null 2>&1; then
    qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
fi
if command -v killall >/dev/null 2>&1 && command -v kglobalaccel5 >/dev/null 2>&1; then
    killall kglobalaccel5 2>/dev/null || true
    sleep 0.5
    nohup /usr/bin/kglobalaccel5 >/dev/null 2>&1 &
fi

echo -e "\n${GREEN}=== 모든 복원 및 설정이 완료되었습니다! ===${NC}"
echo -e "적용된 항목:"
echo -e "  - Win+Shift+S (영역 지정 캡처 Spectacle)"
echo -e "  - Irixium 네이비 블루 단색 + 선명한 흰색 버튼 테마"
echo -e "  - OpenCode 반투명 터미널 배경 테마"
echo -e "  - Wi-Fi 캡티브 포털 자동 감지 및 팝업"
