#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    [16GB RAM 전용] ZRAM, Swap & 전원 최대성능 튜닝  ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo "타겟 환경: 물리 RAM 16GB 시스템"
echo "설정 구성:"
echo "  1. ZRAM: RAM의 100% (16GB), zstd 초고속 압축, 우선순위 100"
echo "  2. SSD Swap: 16GB (/swapfile - 대용량 작업 & 최대절전모드 완벽 지원)"
echo "  3. sysctl: swappiness=160, page-cluster=0, dirty_ratio=15"
echo "  4. 전원 연동: AC 어댑터 연결 시 CPU 최대 성능/최대 클럭/터보 부스트 고정"
echo -e "${BLUE}-----------------------------------------------------${NC}\n"

if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}시스템 설정을 위해 sudo 권한을 확인합니다.${NC}"
    sudo -v
fi

# 1. 16GB SSD Swapfile 생성 및 fstab 등록
echo -e "\n${BLUE}[1/4] 16GB SSD 스왑파일(/swapfile) 확인 및 생성...${NC}"
if ! swapon --show | grep -q '/swapfile'; then
    if [ ! -f /swapfile ]; then
        echo "/swapfile (16GB) 생성 중..."
        sudo fallocate -l 16G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=16384 status=progress
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
    fi
    echo "/swapfile 활성화..."
    sudo swapon /swapfile
    
    if ! grep -q '/swapfile' /etc/fstab; then
        echo "/etc/fstab 에 /swapfile 등록..."
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    fi
    echo -e "${GREEN}16GB /swapfile 설정 완료.${NC}"
else
    echo -e "${GREEN}/swapfile이 이미 활성화되어 있습니다.${NC}"
fi

# 2. ZRAM 설정 (RAM 100% 용량 = 약 16GB, zstd, 우선순위 100)
echo -e "\n${BLUE}[2/4] ZRAM (zstd 압축) 패키지 및 서비스 구성...${NC}"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools zstd util-linux

cat << 'EOF' | sudo tee /etc/default/zramswap > /dev/null
# 16GB RAM 최적화 ZRAM 설정
ALGO=zstd
PERCENT=100
PRIORITY=100
EOF

echo "ZRAM 서비스 재시작 중..."
sudo systemctl restart zramswap || sudo zramswap reload || true
echo -e "${GREEN}ZRAM 설정 완료.${NC}"

# 3. 16GB 맞춤형 sysctl 적용
echo -e "\n${BLUE}[3/4] 16GB 맞춤형 sysctl 커널 튜닝 적용...${NC}"
cat << 'EOF' | sudo tee /etc/sysctl.d/99-memory-16gb-tuning.conf > /dev/null
# [16GB RAM 최적화] 커널 메모리 튜닝
# 16GB 넉넉한 램 용량과 ZRAM을 균형 있게 활용
vm.swappiness = 160

# 파일/디렉터리 캐시 보존율 향상
vm.vfs_cache_pressure = 50

# 1페이지 단위 개별 압축/해제로 스왑 레이턴시 제로화
vm.page-cluster = 0

# 메모리 워터마크 부스트 비활성화
vm.watermark_boost_factor = 0

# 부드러운 메모리 회수
vm.watermark_scale_factor = 125

# 16GB 환경에서 디스크 쓰기 병목을 방지하기 위한 선제적 백그라운드 플러시
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

sudo sysctl --system > /dev/null
echo -e "${GREEN}16GB 맞춤형 sysctl 튜닝 적용 완료.${NC}"

# 4. AC 어댑터 연결 시 CPU 최대 성능/최대 부스트 자동 전환 구성
echo -e "\n${BLUE}[4/4] 전원 연결 시 CPU 최대 성능/최대 부스트 자동화 설정...${NC}"

# 전원 상태 감지 및 CPU 제어 스크립트 생성
cat << 'EOF' | sudo tee /usr/local/bin/power-profile-switch.sh > /dev/null
#!/bin/bash
# AC(전원 어댑터) 연결 여부 판별 (1: 연결됨, 0: 배터리)
AC_ONLINE=0
for ps in /sys/class/power_supply/A*/online /sys/class/power_supply/BAT*/status; do
    if [[ "$ps" =~ online ]] && [ -f "$ps" ]; then
        if [ "$(cat "$ps")" = "1" ]; then
            AC_ONLINE=1
            break
        fi
    fi
done

# AC 어댑터 연결 시 -> 최대 클럭, 최대 부스트, 퍼포먼스 거버너 고정
if [ "$AC_ONLINE" -eq 1 ] || [ "$1" = "ac" ]; then
    # 1. CPU Scaling Governor -> performance
    for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$g" ] && echo "performance" > "$g" 2>/dev/null || true
    done

    # 2. Intel/AMD Energy Performance Preference (EPP) -> performance
    for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        [ -f "$e" ] && echo "performance" > "$e" 2>/dev/null || true
    done

    # 3. Intel Turbo Boost 활성화 (no_turbo=0)
    if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
    fi

    # 4. AMD Core Performance Boost 활성화 (boost=1)
    if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
    fi

    echo "[Power Profile] AC 연결 감지: CPU Performance & 최대 터보 부스트 활성화 완료"
else
    # 배터리 모드 시 -> powersave & balance_performance
    for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -f "$g" ] && echo "powersave" > "$g" 2>/dev/null || true
    done
    for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        [ -f "$e" ] && echo "balance_performance" > "$e" 2>/dev/null || true
    done
    echo "[Power Profile] 배터리 모드: CPU Powersave & Balanced 모드로 복귀"
fi
EOF

sudo chmod +x /usr/local/bin/power-profile-switch.sh

# udev 규칙 등록: 전원 잭 꽂거나 뺄 때 즉시 실행
cat << 'EOF' | sudo tee /etc/udev/rules.d/99-power-performance.rules > /dev/null
SUBSYSTEM=="power_supply", ACTION=="change", RUN+="/usr/local/bin/power-profile-switch.sh"
EOF

sudo udevadm control --reload-rules || true

# 부팅 시 자동 1회 실행을 위한 systemd 서비스
cat << 'EOF' | sudo tee /etc/systemd/system/power-performance.service > /dev/null
[Unit]
Description=Set CPU Performance based on AC/Battery power state
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/power-profile-switch.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now power-performance.service
# 지금 즉시 1회 실행하여 현재 전원 상태 반영
sudo /usr/local/bin/power-profile-switch.sh

echo -e "${GREEN}전원 연결 시 최대 성능/최대 부스트 자동화 설정 완료!${NC}"

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}         16GB 시스템 메모리 및 CPU 상태              ${NC}"
echo -e "${GREEN}=====================================================${NC}"
free -h
echo "-----------------------------------------------------"
swapon --show
echo "-----------------------------------------------------"
sudo zramctl 2>/dev/null || true
echo "-----------------------------------------------------"
echo -n "현재 CPU Governor: "
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A"
echo -n "현재 EPP (선호도): "
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo "N/A"
echo -n "Intel Turbo Boost: "
[ "$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)" = "0" ] && echo "활성화됨 (Active)" || echo "N/A"
echo -e "\n${GREEN}[16GB RAM 시스템 최적화 완료!]${NC}"
