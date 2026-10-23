# My KDE Dotfiles & System Config

오늘 맞춘 커스텀 KDE Plasma 환경, 단축키, OpenCode 테마, 네트워크 자동 설정 모음입니다.

---

## 📦 포함된 설정들

1. **KDE Plasma 커스텀 창 테마 (`Irixium`)**:
   - 상단 타이틀바: 정통 네이비 블루 (`#0a246a`) 단색
   - 우측 버튼: 선명한 흰색 (`#ffffff`) 닫기/최소화/최대화 기호
2. **전역 단축키**:
   - `Win + Shift + S`: 직사각형 영역 캡처 (`Spectacle`)
   - `Alt + Space` / `Alt + F2`: 전체 검색창 (`KRunner`)
   - `Win + E`: 파일 탐색기 (`Dolphin`)
   - `Ctrl + Alt + T`: 터미널 (`Konsole`)
3. **OpenCode 설정**:
   - 터미널 반투명 배경을 투과시키는 `system` (dark) 테마
4. **네트워크 매니저 (캡티브 포털 자동 팝업)**:
   - 카페/공용 Wi-Fi 연결 시 로그인 창(`http://captive.apple.com`) 자동 팝업

---

## 🚀 새 컴퓨터에서 1분 만에 복원하는 방법

### 1단계: Git Clone (또는 폴더 복사)
```bash
git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2단계: RAM 압축(ZRAM zstd) & Swap 최적화 (시스템 사양에 맞춰 선택)

- **8GB 램 시스템**:
  ```bash
  ./setup-memory-8gb.sh
  ```
  *(ZRAM 8GB + SSD 스왑 8GB + 적극적 ZRAM 활용 swappiness=180)*

- **16GB 램 시스템**:
  ```bash
  ./setup-memory-16gb.sh
  ```
  *(ZRAM 16GB + SSD 스왑 16GB + 균형 튜닝 swappiness=160, dirty_ratio=15)*

> **공통 적용 최적화**:
> - **ZRAM (초고속 실시간 압축)**: `zstd` 알고리즘, 최우선순위 100
> - **레이턴시 제로**: `vm.page-cluster = 0` (1페이지 단위 개별 압축/해제로 스왑 렉 방지)
> - **반응성 극대화**: `vm.vfs_cache_pressure = 50` (디렉터리/파일 캐시 보존)
> - **전원 연동 최대 성능**: 노트북 전원(AC) 연결 시 `performance` 거버너, 최대 부스트 클럭(Intel Turbo Boost / AMD Core Boost), EPP `performance` 자동 고정 (udev & systemd 자동화)

### 3단계: 필수 앱(Vivaldi, VS Code, Godot Mono 등) 일괄 설치 (선택)
```bash
./install-apps.sh
```
> **자동 설치 목록**:
> - Vivaldi Browser (공식 APT)
> - Visual Studio Code (공식 APT)
> - .NET SDK 8.0 & Godot Engine (.NET/Mono 버전 자동 셋업)
> - Anki, PCSX2, Blender, Discord, VLC (Flathub)

### 4단계: KDE 환경 및 단축키 설정 복원
```bash
./install.sh
```
*(루트 권한이 필요한 NetworkManager 설정을 위해 sudo 비밀번호를 한 번 물어봅니다)*

---

## 🐙 GitHub에 올려두려면?

1. GitHub에서 `dotfiles` 이름으로 새 저장소(Private 또는 Public)를 생성합니다.
2. 현재 컴퓨터 터미널에서:
   ```bash
   cd ~/dotfiles
   git init
   git add .
   git commit -m "Initial commit of KDE dotfiles"
   git branch -M main
   git remote add origin https://github.com/<your-username>/dotfiles.git
   git push -u origin main
   ```
