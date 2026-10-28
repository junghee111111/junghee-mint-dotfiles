#!/bin/bash
# ============================================================
#  setup.sh
#
#  install.sh / install-apps.sh 로 기본 환경을 만든 뒤,
#  "실사용하면서 추가로 맞춘" 항목들을 적용하는 스크립트입니다.
#
#  다루는 항목
#    1. GitHub SSH 인증 키 생성 + ~/.ssh/config 등록
#    2. Blender(Flatpak)가 NVIDIA GPU를 쓰도록 GL 확장 설치
#    3. Godot을 Wayland 네이티브로 실행하는 래퍼 설치
#    4. 한글 입력기(fcitx5) / Claude Code 상태 점검 (설치는 install.sh 담당)
#
#  사용법
#    ./setup.sh                  # 전체 실행
#    ./setup.sh --dry-run        # 실제 변경 없이 무엇을 할지 출력
#    ./setup.sh --no-verify      # Blender GPU 확인(수십 초) 생략
#    ./setup.sh --skip-ssh       # 특정 항목만 건너뛰기
#                                #   --skip-blender --skip-godot
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME}"
CURRENT_USER="$(id -un)"

DRY_RUN=0
DO_VERIFY=1
SKIP_SSH=0
SKIP_BLENDER=0
SKIP_GODOT=0

for arg in "$@"; do
    case "${arg}" in
        --dry-run|-n)   DRY_RUN=1 ;;
        --no-verify)    DO_VERIFY=0 ;;
        --skip-ssh)     SKIP_SSH=1 ;;
        --skip-blender) SKIP_BLENDER=1 ;;
        --skip-godot)   SKIP_GODOT=1 ;;
        -h|--help)      sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "알 수 없는 옵션: ${arg}" >&2; exit 2 ;;
    esac
done

if [ "${DRY_RUN}" = "1" ]; then
    echo -e "${YELLOW}※ dry-run 모드: 실제로 아무것도 변경하지 않습니다.${NC}"
fi

# 실제 실행 (dry-run이면 명령만 출력)
run() {
    if [ "${DRY_RUN}" = "1" ]; then
        echo -e "    ${YELLOW}[dry-run]${NC} $*"
    else
        "$@"
    fi
}

ok()   { echo -e "    ${GREEN}✔${NC} $*"; }
warn() { echo -e "    ${YELLOW}!${NC} $*"; }
fail() { echo -e "    ${RED}✘${NC} $*"; }

# sudo가 필요한 순간에만 비밀번호를 미리 받아둔다
ensure_sudo() {
    if [ "${DRY_RUN}" = "1" ]; then
        echo -e "    ${YELLOW}[dry-run]${NC} sudo -v"
        return 0
    fi
    sudo -v
}

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}   추가 환경 설정 (SSH / Blender GPU / Godot Wayland)  ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo -e "대상 사용자: ${GREEN}${CURRENT_USER}${NC}"
echo -e "Dotfiles 경로: ${GREEN}${DOTFILES_DIR}${NC}\n"

# ------------------------------------------------------------
# 1. GitHub SSH 인증 키
#    - 개인 키는 절대 이 저장소에 넣지 않는다. 없으면 새로 만든다.
# ------------------------------------------------------------
echo -e "${BLUE}[1/4] GitHub SSH 인증 키 준비 중...${NC}"

SSH_DIR="${USER_HOME}/.ssh"
SSH_KEY="${SSH_DIR}/id_ed25519_github"
SSH_CONFIG="${SSH_DIR}/ssh_config_github"   # 실제로는 ~/.ssh/config 에 병합

if [ "${SKIP_SSH}" = "1" ]; then
    warn "건너뜀 (--skip-ssh)"
else
    if [ "${DRY_RUN}" != "1" ]; then
        mkdir -p "${SSH_DIR}"
        chmod 700 "${SSH_DIR}"
    else
        echo -e "    ${YELLOW}[dry-run]${NC} mkdir -p ${SSH_DIR} && chmod 700 ${SSH_DIR}"
    fi

    if [ -f "${SSH_KEY}" ]; then
        ok "이미 존재: ${SSH_KEY} (덮어쓰지 않음)"
    else
        if command -v ssh-keygen >/dev/null 2>&1; then
            run ssh-keygen -t ed25519 -a 100 \
                -f "${SSH_KEY}" -N "" \
                -C "github-${CURRENT_USER}@$(hostname)"
            run chmod 600 "${SSH_KEY}"
            run chmod 644 "${SSH_KEY}.pub"
            ok "새 키 생성 완료: ${SSH_KEY}"
        else
            fail "ssh-keygen 이 없습니다. 'sudo apt-get install -y openssh-client' 후 다시 실행하세요."
        fi
    fi

    # ~/.ssh/config 에 github.com 블록이 없을 때만 추가 (기존 설정 보존)
    if [ -f "${SSH_DIR}/config" ] && grep -q '^Host github\.com$' "${SSH_DIR}/config" 2>/dev/null; then
        ok "~/.ssh/config 에 github.com 설정이 이미 있습니다."
    else
        if [ "${DRY_RUN}" = "1" ]; then
            echo -e "    ${YELLOW}[dry-run]${NC} ~/.ssh/config 에 github.com 블록 추가"
        else
            mkdir -p "${SSH_DIR}"
            {
                echo ""
                echo "Host github.com"
                echo "    HostName github.com"
                echo "    User git"
                echo "    IdentityFile ${SSH_KEY}"
                echo "    IdentitiesOnly yes"
            } >> "${SSH_DIR}/config"
            chmod 600 "${SSH_DIR}/config"
            ok "~/.ssh/config 에 github.com 블록 추가"
        fi
    fi

    # 공개 키 안내 (등록은 사용자가 직접)
    if [ -f "${SSH_KEY}.pub" ]; then
        echo
        echo -e "    ${BLUE}아래 공개 키를 GitHub > Settings > SSH and GPG keys > New SSH key"
        echo -e "    (Key type: Authentication Key) 에 등록하세요:${NC}"
        echo
        sed 's/^/      /' "${SSH_KEY}.pub"
        echo
        echo -e "    등록 후 확인: ${GREEN}ssh -T git@github.com${NC}"
        echo -e "    키 지문 확인: ${GREEN}ssh-keygen -lf ${SSH_KEY}.pub${NC}"
    fi
fi

# ------------------------------------------------------------
# 2. Blender(Flatpak) NVIDIA GPU 사용
#    Flatpak 샌드박스는 호스트 NVIDIA 드라이버를 그대로 쓰지 못한다.
#    드라이버 버전과 일치하는 GL 확장이 없으면 Mesa llvmpipe(CPU)로
#    떨어져 오브젝트가 없어도 심하게 느려진다.
# ------------------------------------------------------------
echo -e "\n${BLUE}[2/4] Blender(Flatpak) NVIDIA GPU 설정 중...${NC}"

BLENDER_APP="org.blender.Blender"

if [ "${SKIP_BLENDER}" = "1" ]; then
    warn "건너뜀 (--skip-blender)"
elif ! command -v flatpak >/dev/null 2>&1; then
    warn "flatpak 이 없습니다. install-apps.sh 를 먼저 실행하세요."
else
    if ! flatpak list --app --columns=application 2>/dev/null | grep -qx "${BLENDER_APP}"; then
        warn "${BLENDER_APP} 가 설치되어 있지 않습니다. (install-apps.sh 로 설치)"
    else
        DRIVER_VER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 | tr -d ' ' || true)"
        if [ -z "${DRIVER_VER}" ]; then
            warn "NVIDIA 드라이버를 감지하지 못했습니다 (nvidia-smi 없음). 건너뜁니다."
        else
            # 580.178.04 -> org.freedesktop.Platform.GL.nvidia-580-178-04
            EXT_NAME="org.freedesktop.Platform.GL.nvidia-$(echo "${DRIVER_VER}" | tr '.' '-')"
            EXT_PREFIX="org.freedesktop.Platform.GL.nvidia-$(echo "${DRIVER_VER}" | cut -d. -f1-2 | tr '.' '-')"

            echo -e "    드라이버 버전: ${GREEN}${DRIVER_VER}${NC}"

            if flatpak list --runtime --columns=application 2>/dev/null | grep -qx "${EXT_NAME}"; then
                ok "필요한 확장이 이미 설치되어 있습니다: ${EXT_NAME}"
            else
                INSTALL_TARGET=""
                if flatpak remote-ls flathub --columns=application 2>/dev/null | grep -qx "${EXT_NAME}"; then
                    INSTALL_TARGET="${EXT_NAME}"
                else
                    # 정확한 버전이 없으면 같은 major.minor 계열의 최신 확장 사용
                    INSTALL_TARGET="$(flatpak remote-ls flathub --columns=application 2>/dev/null \
                        | grep -E "^${EXT_PREFIX}(-|$)" | sort -V | tail -n1 || true)"
                    if [ -n "${INSTALL_TARGET}" ]; then
                        warn "정확히 일치하는 ${EXT_NAME} 이 없어 근접 버전을 사용합니다: ${INSTALL_TARGET}"
                    fi
                fi

                if [ -z "${INSTALL_TARGET}" ]; then
                    fail "Flathub에 ${EXT_PREFIX}* 확장이 없습니다."
                    fail "Blender가 CPU(llvmpipe)로 동작합니다. 드라이버를 낮추거나 네이티브 Blender를 사용하세요."
                else
                    echo -e "    설치: ${GREEN}${INSTALL_TARGET}${NC}"
                    ensure_sudo
                    run sudo flatpak install -y flathub "${INSTALL_TARGET}"
                    ok "NVIDIA GL 확장 설치 완료 (Blender 재시작 필요)"
                fi
            fi

            # 실제로 GPU를 쓰는지 확인
            if [ "${DO_VERIFY}" = "1" ] && [ "${DRY_RUN}" != "1" ]; then
                echo -e "    GPU 확인 중... (수십 초 걸릴 수 있습니다)"
                RENDERER="$(timeout 120 flatpak run "${BLENDER_APP}" -b --factory-startup \
                    --python-expr "import gpu; gpu.init(); print('RENDERER|' + gpu.platform.renderer_get())" 2>/dev/null \
                    | grep '^RENDERER|' | head -n1 | cut -d'|' -f2 || true)"
                if [ -z "${RENDERER}" ]; then
                    warn "렌더러를 확인하지 못했습니다. Blender를 직접 실행해 확인하세요."
                elif echo "${RENDERER}" | grep -qi 'llvmpipe'; then
                    fail "아직 소프트웨어 렌더링입니다: ${RENDERER}"
                    fail "Blender를 완전히 종료 후 다시 실행하거나, 드라이버/확장 버전을 확인하세요."
                else
                    ok "GPU 사용 확인: ${RENDERER}"
                fi
            fi
        fi
    fi
fi

# ------------------------------------------------------------
# 3. Godot Wayland 래퍼
#    Xwayland(X11) 경로는 프레임 표시가 소프트웨어로 처리되어
#    같은 씬이 17 FPS → Wayland 75 FPS 로 차이난다.
# ------------------------------------------------------------
echo -e "\n${BLUE}[3/4] Godot Wayland 래퍼 설치 중...${NC}"

GODOT_WRAPPER="${USER_HOME}/.local/bin/godot"
GODOT_DESKTOP="${USER_HOME}/.local/share/applications/godot.desktop"
GODOT_SRC="${DOTFILES_DIR}/config/godot/godot-wayland-wrapper.sh"

if [ "${SKIP_GODOT}" = "1" ]; then
    warn "건너뜀 (--skip-godot)"
elif [ ! -f "${GODOT_SRC}" ]; then
    fail "래퍼 원본이 없습니다: ${GODOT_SRC}"
else
    run mkdir -p "${USER_HOME}/.local/bin" "${USER_HOME}/.local/share/applications"
    run cp "${GODOT_SRC}" "${GODOT_WRAPPER}"
    run chmod +x "${GODOT_WRAPPER}"
    ok "래퍼 설치: ${GODOT_WRAPPER}"

    # 데스크톱 항목 (GUI 실행용)
    if [ "${DRY_RUN}" = "1" ]; then
        echo -e "    ${YELLOW}[dry-run]${NC} ${GODOT_DESKTOP} 생성 (Exec=${GODOT_WRAPPER} %f)"
    else
        sed "s|__GODOT_WRAPPER__|${GODOT_WRAPPER}|" \
            "${DOTFILES_DIR}/config/godot/godot.desktop" > "${GODOT_DESKTOP}"
        command -v update-desktop-database >/dev/null 2>&1 && \
            update-desktop-database "${USER_HOME}/.local/share/applications" >/dev/null 2>&1 || true
        ok "데스크톱 항목: ${GODOT_DESKTOP}"
    fi

    # PATH 우선순위 확인 (~/.local/bin 이 /usr/local/bin 보다 앞이어야 함)
    if [ "${DRY_RUN}" != "1" ]; then
        if bash -ic 'command -v godot' 2>/dev/null | grep -qx "${GODOT_WRAPPER}"; then
            ok "PATH 우선순위 정상 (godot -> ${GODOT_WRAPPER})"
        else
            warn "~/.local/bin 이 PATH 앞에 없습니다. ~/.bashrc 에 아래 줄을 추가하세요:"
            echo -e "      ${GREEN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        fi
    fi

    if [ ! -x "/usr/local/bin/godot" ] && ! ls /opt/godot-mono/Godot_*_mono_linux_x86_64/Godot_*_mono_linux.x86_64 >/dev/null 2>&1; then
        warn "Godot 본체가 아직 없습니다. install-apps.sh 로 설치하면 래퍼가 자동으로 잡습니다."
    fi

    echo -e "    X11로 강제 실행: ${GREEN}godot --display-driver x11 ...${NC}"
fi

# ------------------------------------------------------------
# 4. 점검: 한글 입력기(fcitx5) / Claude Code
#    실제 설치와 설정 복사는 install.sh 가 담당한다. 여기서는
#    "Right Alt 한/영 전환"이 제대로 걸려 있는지만 확인한다.
# ------------------------------------------------------------
echo -e "\n${BLUE}[4/4] 한글 입력기 / Claude Code 상태 점검${NC}"

# fcitx5
if ! command -v fcitx5 >/dev/null 2>&1; then
    warn "fcitx5 미설치 → install.sh 를 먼저 실행하세요."
else
    ok "fcitx5 설치됨: $(fcitx5 --version 2>/dev/null | head -n1 || echo '5.x')"

    [ -f "${USER_HOME}/.config/fcitx5/profile" ] \
        && ok "~/.config/fcitx5/profile 있음 (hangul 엔진 등록)" \
        || warn "~/.config/fcitx5/profile 없음 → install.sh 로 복원하세요."

    [ -f "${USER_HOME}/.config/fcitx5/config" ] \
        && ok "~/.config/fcitx5/config 있음" \
        || warn "~/.config/fcitx5/config 없음 → install.sh 로 복원하세요."

    # Right Alt(한/영) 매핑: KDE kxkbrc 의 korean:ralt_hangul 옵션
    if [ -f "${USER_HOME}/.config/kxkbrc" ] && grep -q 'korean:ralt_hangul' "${USER_HOME}/.config/kxkbrc"; then
        ok "Right Alt → 한/영 전환 매핑 확인 (korean:ralt_hangul)"
    else
        warn "kxkbrc 에 korean:ralt_hangul 옵션이 없습니다. install.sh 로 복원하거나"
        echo -e "      ${GREEN}setxkbmap -option korean:ralt_hangul${NC} 를 실행하세요."
    fi

    # 세션 입력기 지정
    if [ -f "${USER_HOME}/.pam_environment" ] || [ -f "${USER_HOME}/.config/plasma-workspace/env/fcitx5.sh" ]; then
        ok "세션 입력기 환경변수 파일 있음"
    else
        warn "입력기 환경변수 파일이 없습니다 → install.sh 로 복원하세요."
    fi

    # 자동 시작
    if [ -f "${USER_HOME}/.config/autostart/org.fcitx.Fcitx5.desktop" ]; then
        ok "로그인 시 자동 시작 등록됨"
    else
        warn "자동 시작 항목이 없습니다 → install.sh 로 복원하세요."
    fi

    echo -e "    수동 재시작: ${GREEN}fcitx5 -r -d${NC}"
    echo -e "    설정 GUI  : ${GREEN}fcitx5-configtool${NC} (Hangul 엔진의 전환 키 확인)"
    echo -e "    로그아웃/로그인 후 적용됩니다."
fi

# Claude Code
echo
if [ -x "${USER_HOME}/.local/bin/claude" ]; then
    ok "Claude Code 설치됨: $("${USER_HOME}/.local/bin/claude" --version 2>/dev/null || echo '버전 확인은 새 터미널에서')"
else
    warn "Claude Code 미설치 → install.sh 를 먼저 실행하세요."
fi

# ------------------------------------------------------------
# 마무리
# ------------------------------------------------------------
echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}            추가 환경 설정 완료                       ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "  • GitHub SSH 키 : ${SSH_KEY}"
echo -e "  • Blender       : Flatpak NVIDIA GL 확장"
echo -e "  • Godot         : ${GODOT_WRAPPER} (Wayland)"
echo -e "  • fcitx5        : Right Alt = 한/영 (install.sh 담당)"
echo
echo -e "${YELLOW}※ Blender/Godot은 실행 중이던 프로세스를 완전히 종료해야 적용됩니다.${NC}"
echo -e "${YELLOW}※ 새 터미널을 열어야 PATH 변경이 반영됩니다.${NC}"
