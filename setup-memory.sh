#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}      RAM 압축(ZRAM) 및 Swap 메모리 최적화 설정     ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo "설정 내용:"
echo "  1. ZRAM (RAM 압축: zstd 알고리즘, RAM 크기의 100%, 우선순위 100)"
echo "  2. 8GB 디스크 스왑파일 (/swapfile 자동 생성 및 fstab 등록)"
echo "  3. sysctl 커널 메모리 반응성 극대화 튜닝"
echo -e "${BLUE}-----------------------------------------------------${NC}\n"

# sudo 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}시스템 메모리 설정을 위해 sudo 권한을 확인합니다.${NC}"
    sudo -v
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 8GB SSD Swapfile 생성 및 fstab 등록 (없는 경우에만 생성)
echo -e "\n${BLUE}[1/3] 디스크 스왑(/swapfile 8GB) 확인 및 생성...${NC}"
if ! swapon --show | grep -q '/swapfile'; then
    if [ ! -f /swapfile ]; then
        echo "/swapfile (8GB) 생성 중 (fallocate)..."
        sudo fallocate -l 8G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
    fi
    echo "/swapfile 활성화..."
    sudo swapon /swapfile
    
    # /etc/fstab 등록
    if ! grep -q '/swapfile' /etc/fstab; then
        echo "/etc/fstab 에 /swapfile 자동 마운트 추가..."
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    fi
    echo -e "${GREEN}8GB /swapfile 설정 완료.${NC}"
else
    echo -e "${GREEN}/swapfile이 이미 활성화되어 있습니다.${NC}"
fi

# 2. ZRAM (RAM 압축: zstd 알고리즘, 100% 램 크기) 설정
echo -e "\n${BLUE}[2/3] ZRAM (zstd 압축 램) 패키지 및 서비스 구성...${NC}"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools zstd util-linux

# /etc/default/zramswap 설정 (zstd 압축, RAM의 100% 용량, 최우선 순위 100)
cat << 'EOF' | sudo tee /etc/default/zramswap > /dev/null
# ZRAM 설정 파일 (dotfiles에서 생성됨)
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF

echo "ZRAM 서비스 재시작 중..."
sudo systemctl restart zramswap || sudo zramswap reload || true
echo -e "${GREEN}ZRAM 설정 완료.${NC}"

# 3. sysctl 커널 메모리 튜닝 파일 복사 및 적용
echo -e "\n${BLUE}[3/3] sysctl 메모리/ZRAM 최적화 매개변수 적용...${NC}"
if [ -f "${DOTFILES_DIR}/system/99-zram-tuning.conf" ]; then
    sudo cp "${DOTFILES_DIR}/system/99-zram-tuning.conf" /etc/sysctl.d/
    sudo sysctl --system > /dev/null
    echo -e "${GREEN}sysctl 커널 튜닝 적용 완료.${NC}"
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}             현재 메모리 및 스왑 상태                ${NC}"
echo -e "${GREEN}=====================================================${NC}"
free -h
echo "-----------------------------------------------------"
swapon --show
echo "-----------------------------------------------------"
sudo zramctl 2>/dev/null || true
echo -e "\n${GREEN}모든 RAM 압축 튜닝 및 스왑 설정이 성공적으로 완료되었습니다!${NC}"
