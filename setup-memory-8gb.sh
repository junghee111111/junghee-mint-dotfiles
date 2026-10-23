#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    [8GB RAM 전용] ZRAM 압축 및 8GB Swap 최적화     ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo "타겟 환경: 물리 RAM 8GB 시스템"
echo "설정 구성:"
echo "  1. ZRAM: RAM의 100% (8GB), zstd 알고리즘, 우선순위 100"
echo "  2. SSD Swap: 8GB (/swapfile)"
echo "  3. sysctl: swappiness=180, page-cluster=0 (적극적 ZRAM 활용)"
echo -e "${BLUE}-----------------------------------------------------${NC}\n"

if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}시스템 설정을 위해 sudo 권한을 확인합니다.${NC}"
    sudo -v
fi

# 1. 8GB SSD Swapfile 생성 및 fstab 등록
echo -e "\n${BLUE}[1/3] 8GB SSD 스왑파일(/swapfile) 확인 및 생성...${NC}"
if ! swapon --show | grep -q '/swapfile'; then
    if [ ! -f /swapfile ]; then
        echo "/swapfile (8GB) 생성 중..."
        sudo fallocate -l 8G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
    fi
    echo "/swapfile 활성화..."
    sudo swapon /swapfile
    
    if ! grep -q '/swapfile' /etc/fstab; then
        echo "/etc/fstab 에 /swapfile 등록..."
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    fi
    echo -e "${GREEN}8GB /swapfile 설정 완료.${NC}"
else
    echo -e "${GREEN}/swapfile이 이미 활성화되어 있습니다.${NC}"
fi

# 2. ZRAM 설정 (RAM 100% 용량 = 약 8GB, zstd, 우선순위 100)
echo -e "\n${BLUE}[2/3] ZRAM (zstd 압축) 패키지 및 서비스 구성...${NC}"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools zstd util-linux

cat << 'EOF' | sudo tee /etc/default/zramswap > /dev/null
# 8GB RAM 최적화 ZRAM 설정
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF

echo "ZRAM 서비스 재시작 중..."
sudo systemctl restart zramswap || sudo zramswap reload || true
echo -e "${GREEN}ZRAM 설정 완료.${NC}"

# 3. 8GB 최적화 sysctl 적용
echo -e "\n${BLUE}[3/3] 8GB 맞춤형 sysctl 커널 튜닝 적용...${NC}"
cat << 'EOF' | sudo tee /etc/sysctl.d/99-memory-8gb-tuning.conf > /dev/null
# [8GB RAM 최적화] 커널 메모리 튜닝
# 8GB 환경에서는 ZRAM을 적극적으로 활용하여 가용 메모리 극대화
vm.swappiness = 180

# 파일/디렉터리 캐시 보존율 향상 (앱 반응성 증가)
vm.vfs_cache_pressure = 50

# 1페이지 단위 개별 압축/해제로 스왑 레이턴시 제로화
vm.page-cluster = 0

# 메모리 워터마크 부스트 비활성화
vm.watermark_boost_factor = 0

# 선제적이고 부드러운 메모리 회수
vm.watermark_scale_factor = 125

# 더티 메모리 플러시 임계값
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
EOF

sudo sysctl --system > /dev/null
echo -e "${GREEN}8GB 맞춤형 sysctl 튜닝 적용 완료.${NC}"

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}          8GB 시스템 메모리 및 스왑 상태             ${NC}"
echo -e "${GREEN}=====================================================${NC}"
free -h
echo "-----------------------------------------------------"
swapon --show
echo "-----------------------------------------------------"
sudo zramctl 2>/dev/null || true
echo -e "\n${GREEN}[8GB RAM 시스템 최적화 완료!]${NC}"
