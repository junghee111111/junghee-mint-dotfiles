# My KDE Dotfiles & System Config

오늘 맞춘 커스텀 KDE Plasma 환경, 단축키, OpenCode 테마, 한글 입력기(fcitx5), Claude Code, 네트워크 자동 설정 모음입니다.

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
5. **한글 입력기 (fcitx5 + Hangul)**:
   - `Right Alt` 키로 한글/영어 전환
   - 로그인 시 자동 시작 및 KDE 환경변수 설정
6. **Claude Code**:
   - `install.sh` 실행 시 공식 설치 스크립트로 자동 설치
7. **GitHub SSH 인증 키** (`setup.sh`):
   - `~/.ssh/id_ed25519_github` (ed25519) 생성 + `~/.ssh/config` 에 `github.com` 등록
   - 개인 키는 저장소에 포함하지 않고, 없을 때만 새로 생성
8. **GPU 가속 / 표시 경로 최적화** (`setup.sh`):
   - Blender(Flatpak): 호스트 NVIDIA 드라이버와 일치하는 `org.freedesktop.Platform.GL.nvidia-*` 확장 자동 설치
   - Godot: Xwayland 대신 네이티브 Wayland로 실행하는 래퍼(`~/.local/bin/godot`) 설치

---

## 🚀 새 컴퓨터에서 1분 만에 복원하는 방법

### 1단계: Git Clone (또는 폴더 복사)
```bash
git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2단계: 한 번에 전체 설치 (권장)
```bash
./install-all.sh
```
> 아래 3~5단계를 한 번에 실행합니다. 단, `install-apps.sh`(Vivaldi, VS Code, Godot 등)는 **제외**됩니다.
> - `install.sh`: KDE 테마/단축키, **fcitx5 한글 입력기**, **Claude Code**, 캡티브 포털
> - `setup.sh`: **GitHub SSH 키**, **Blender NVIDIA GPU**, **Godot Wayland 래퍼**, 입력기 상태 점검
> - RAM 용량을 자동 감지해 8GB/16GB 메모리 최적화 적용

### 2-1단계: 추가 환경 설정만 따로 실행 (`setup.sh`)
```bash
./setup.sh                 # 전체
./setup.sh --dry-run       # 무엇을 바꿀지 미리 확인만
./setup.sh --no-verify     # Blender GPU 확인(수십 초) 생략
./setup.sh --skip-blender  # 특정 항목만 건너뛰기 (--skip-ssh, --skip-godot)
```
> - **SSH**: 키가 없을 때만 `~/.ssh/id_ed25519_github` 를 생성하고 공개 키를 출력합니다.
>   GitHub → Settings → SSH and GPG keys → New SSH key (**Authentication Key**) 에 등록한 뒤
>   `ssh -T git@github.com` 으로 확인하세요.
> - **Blender**: `nvidia-smi` 로 드라이버 버전을 읽어 `org.freedesktop.Platform.GL.nvidia-<버전>` 을 설치합니다.
>   이 확장이 없으면 Blender가 Mesa llvmpipe(CPU 렌더링)로 떨어져 오브젝트가 없어도 매우 느려집니다.
>   드라이버를 업데이트하면 확장도 다시 맞춰야 합니다(스크립트 재실행).
> - **Godot**: Xwayland(X11) 창 경로는 프레임 표시가 소프트웨어로 처리되어 17 FPS 수준으로 떨어집니다.
>   같은 씬이 Wayland 네이티브에서는 모니터 주사율(75 FPS)까지 나옵니다.
>   X11로 강제하려면 `godot --display-driver x11 ...`.

### 3단계: RAM 압축(ZRAM zstd) & Swap 최적화 (시스템 사양에 맞춰 선택)

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

### 4단계: 필수 앱(Vivaldi, VS Code, Godot Mono 등) 일괄 설치 (선택)
```bash
./install-apps.sh
```
> **자동 설치 목록**:
> - Vivaldi Browser (공식 APT)
> - Visual Studio Code (공식 APT)
> - .NET SDK 8.0 & Godot Engine (.NET/Mono 버전 자동 셋업)
> - Anki, PCSX2, Blender, Discord, VLC (Flathub)

### 5단계: KDE 환경 및 단축키 설정 복원
```bash
./install.sh
```
*(fcitx5 한글 입력기와 Claude Code도 함께 설치됩니다. 루트 권한이 필요한 설정을 위해 sudo 비밀번호를 한 번 물어봅니다.)*

> **한글 입력기**: 설치 후 로그아웃 → 재로그인하면 적용되며, `Right Alt` 키로 한글/영어를 전환할 수 있습니다.

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
