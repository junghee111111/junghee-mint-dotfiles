#!/bin/bash
set -e

# 색상 출력 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}===================================================${NC}"
echo -e "${GREEN}      필수 애플리케이션 일괄 설치 스크립트         ${NC}"
echo -e "${BLUE}===================================================${NC}"
echo "설치 대상:"
echo "  1. Vivaldi Browser"
echo "  2. Visual Studio Code (VS Code)"
echo "  3. .NET SDK 8.0 & Godot Engine (.NET / Mono)"
echo "  4. Anki (Flashcard)"
echo "  5. PCSX2 (PS2 Emulator)"
echo "  6. Blender"
echo "  7. Discord"
echo "  8. VLC Media Player"
echo -e "${BLUE}---------------------------------------------------${NC}\n"

# sudo 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}시스템 패키지 설치를 위해 sudo 권한을 확인합니다.${NC}"
    sudo -v
fi

# 0. 기본 빌드/다운로드 필수 도구 설치
echo -e "\n${BLUE}[Step 0] 기본 필수 유틸리티 설치 중 (curl, wget, gpg, flatpak)...${NC}"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl wget gpg software-properties-common apt-transport-https ca-certificates \
    flatpak unzip tar

# Flathub 저장소 등록
echo -e "${BLUE}Flathub 저장소 활성화 중...${NC}"
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# 1. Vivaldi Browser
echo -e "\n${BLUE}[Step 1] Vivaldi 웹 브라우저 설치 중...${NC}"
if ! command -v vivaldi >/dev/null 2>&1; then
    curl -fsSL https://repo.vivaldi.com/archive/linux_signing_key.pub | sudo gpg --dearmor --yes -o /usr/share/keyrings/vivaldi-browser.gpg
    echo "deb [signed-by=/usr/share/keyrings/vivaldi-browser.gpg arch=amd64] https://repo.vivaldi.com/archive/deb/ stable main" | sudo tee /etc/apt/sources.list.d/vivaldi.list > /dev/null
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vivaldi-stable
    echo -e "${GREEN}Vivaldi 설치 완료!${NC}"
else
    echo -e "${GREEN}Vivaldi가 이미 설치되어 있습니다.${NC}"
fi

# 2. Visual Studio Code
echo -e "\n${BLUE}[Step 2] Visual Studio Code 설치 중...${NC}"
if ! command -v code >/dev/null 2>&1; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y code
    echo -e "${GREEN}VS Code 설치 완료!${NC}"
else
    echo -e "${GREEN}VS Code가 이미 설치되어 있습니다.${NC}"
fi

# 3. .NET SDK 8.0 & Godot Engine (.NET / Mono)
echo -e "\n${BLUE}[Step 3] .NET SDK 8.0 & Godot Engine (.NET) 설치 중...${NC}"
# .NET SDK
if ! command -v dotnet >/dev/null 2>&1; then
    echo "dotnet-sdk-8.0 설치 중..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dotnet-sdk-8.0 || {
        # Ubuntu/Mint 버전에 따라 저장소 추가가 필요한 경우
        wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
        sudo dpkg -i /tmp/packages-microsoft-prod.deb
        rm /tmp/packages-microsoft-prod.deb
        sudo apt-get update -y
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dotnet-sdk-8.0
    }
fi

# Godot Engine .NET 다운로드 및 설치 (/opt/godot-mono)
if ! command -v godot >/dev/null 2>&1; then
    echo "Godot .NET 최신 버전 확인 및 다운로드 중..."
    GODOT_JSON=$(curl -fsSL https://api.github.com/repos/godotengine/godot/releases/latest)
    # mono linux x86_64 zip 다운로드 링크 추출
    GODOT_URL=$(echo "$GODOT_JSON" | grep -o 'https://[^"]*mono_linux_x86_64\.zip' | head -n 1)
    
    if [ -z "$GODOT_URL" ]; then
        # Fallback URL (4.3-stable mono)
        GODOT_URL="https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_mono_linux_x86_64.zip"
    fi

    echo "다운로드 URL: $GODOT_URL"
    mkdir -p /tmp/godot-download
    wget -q --show-progress "$GODOT_URL" -O /tmp/godot-download/godot-mono.zip
    
    sudo mkdir -p /opt/godot-mono
    sudo unzip -q -o /tmp/godot-download/godot-mono.zip -d /opt/godot-mono/
    rm -rf /tmp/godot-download

    # 실행 파일 탐색 및 심볼릭 링크
    GODOT_BIN=$(find /opt/godot-mono -type f -name "Godot_*_mono_linux.x86_64" | head -n 1)
    if [ -n "$GODOT_BIN" ]; then
        sudo chmod +x "$GODOT_BIN"
        sudo ln -sf "$GODOT_BIN" /usr/local/bin/godot
        
        # 데스크톱 바로가기 생성
        cat << 'EOF' | sudo tee /usr/share/applications/godot.desktop > /dev/null
[Desktop Entry]
Name=Godot Engine (.NET / C#)
GenericName=Game Engine
Comment=Multi-platform 2D and 3D game engine (Mono / .NET)
Exec=godot %f
Icon=godot
Terminal=false
Type=Application
MimeType=application/x-godot-project;
Categories=Development;IDE;
StartupWMClass=Godot
EOF
        echo -e "${GREEN}Godot Engine (.NET) 설치 완료! (/usr/local/bin/godot)${NC}"
    fi
else
    echo -e "${GREEN}Godot Engine이 이미 설치되어 있습니다.${NC}"
fi

# 4. Flatpak 기반 앱들 (Discord, PCSX2, Anki, VLC, Blender)
echo -e "\n${BLUE}[Step 4] Flatpak 애플리케이션 일괄 설치 중...${NC}"
FLATPAK_APPS=(
    "com.discordapp.Discord"   # Discord
    "net.pcsx2.PCSX2"          # PCSX2
    "net.ankiweb.Anki"         # Anki
    "org.videolan.VLC"         # VLC Player
    "org.blender.Blender"      # Blender
)

for app in "${FLATPAK_APPS[@]}"; do
    echo -e "설치 확인: ${YELLOW}${app}${NC}"
    sudo flatpak install -y flathub "$app" || true
done

echo -e "\n${GREEN}===================================================${NC}"
echo -e "${GREEN}        모든 애플리케이션 설치가 완료되었습니다!  ${NC}"
echo -e "${GREEN}===================================================${NC}"
