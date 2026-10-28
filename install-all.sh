#!/bin/bash
set -e

# ANSI 색상 코드
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}     Dotfiles + 시스템 설정 한 번에 설치 (all-in-one)   ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo "실행 항목:"
echo "  1. install.sh  (KDE 테마/단축키, fcitx5 한글 입력기, Claude Code, 캡티브 포털)"
echo "  2. setup.sh    (GitHub SSH 키, Blender NVIDIA GPU, Godot Wayland, 입력기 점검)"
echo "  3. RAM 용량에 맞는 메모리 최적화 (ZRAM + Swap + 전원 튜닝)"
echo -e "${YELLOW}  ※ install-apps.sh (Vivaldi, VS Code, Godot 등)는 제외됩니다.${NC}"
echo -e "${BLUE}-----------------------------------------------------${NC}\n"

# 1. Dotfiles 복원 + 입력기 + Claude Code
echo -e "${BLUE}[1/3] Dotfiles 및 사용자 환경 설치 중...${NC}"
bash "${DOTFILES_DIR}/install.sh"

# 2. 추가 환경 설정 (SSH 키 / Blender GPU / Godot Wayland / 입력기 점검)
echo -e "\n${BLUE}[2/3] 추가 환경 설정 적용 중...${NC}"
if [ -f "${DOTFILES_DIR}/setup.sh" ]; then
    bash "${DOTFILES_DIR}/setup.sh" || echo -e "${YELLOW}setup.sh 에서 일부 항목이 실패했습니다. 위 로그를 확인하세요.${NC}"
else
    echo -e "${YELLOW}setup.sh 가 없어 2단계를 건너뜁니다.${NC}"
fi

# 3. 물리 RAM 용량에 맞는 메모리 최적화 스크립트 선택
RAM_MB="$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)"
echo -e "\n${BLUE}[3/3] 메모리 최적화 설정 중... (감지된 RAM: ${RAM_MB}MB)${NC}"
if [ "${RAM_MB}" -le 10240 ]; then
    echo -e "${GREEN}8GB 이하 시스템으로 판단하여 setup-memory-8gb.sh 를 실행합니다.${NC}"
    bash "${DOTFILES_DIR}/setup-memory-8gb.sh"
else
    echo -e "${GREEN}16GB 시스템으로 판단하여 setup-memory-16gb.sh 를 실행합니다.${NC}"
    bash "${DOTFILES_DIR}/setup-memory-16gb.sh"
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}          모든 설치 및 설정이 완료되었습니다!          ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "${YELLOW}※ fcitx5 한글 입력기는 로그아웃 후 다시 로그인하면 적용됩니다.${NC}"
echo -e "${YELLOW}※ 앱 설치(Vivaldi, VS Code, Godot 등)는 ./install-apps.sh 를 따로 실행하세요.${NC}"
echo -e "${YELLOW}※ GitHub SSH 공개 키는 setup.sh 출력에서 확인해 GitHub에 등록하세요.${NC}"
