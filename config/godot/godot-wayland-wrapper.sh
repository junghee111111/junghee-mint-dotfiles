#!/bin/sh
# Godot 실행 래퍼 (Wayland 강제)
#
# 왜 필요한가:
#   이 환경(KDE Plasma Wayland + NVIDIA)에서 Godot을 Xwayland(X11)로 띄우면
#   프레임 표시가 소프트웨어(Mesa llvmpipe)로 처리되어 같은 씬이 17 FPS까지
#   떨어집니다. 네이티브 Wayland 백엔드로 띄우면 75 FPS(모니터 주사율)까지
#   올라갑니다. 렌더러(Forward+/Mobile)를 바꿔도 X11에서는 그대로 느립니다.
#
# 우회 방법:
#   1. 이 파일을 ~/.local/bin/godot 으로 복사 (setup.sh가 자동 처리)
#   2. ~/.local/bin 이 /usr/local/bin 보다 PATH 앞에 있어야 함
#   3. X11로 강제하려면: godot --display-driver x11 ...

set -eu

# 실제 Godot 바이너리 찾기 (자기 자신은 제외)
real=""
if [ -n "${GODOT_REAL_BIN:-}" ] && [ -x "${GODOT_REAL_BIN}" ]; then
    real="${GODOT_REAL_BIN}"
else
    for candidate in \
        /usr/local/bin/godot \
        /opt/godot-mono/Godot_*_mono_linux_x86_64/Godot_*_mono_linux.x86_64
    do
        [ -x "${candidate}" ] || continue
        if [ "$(readlink -f "${candidate}")" = "$(readlink -f "$0")" ]; then
            continue
        fi
        real="${candidate}"
        break
    done
fi

if [ -z "${real}" ]; then
    echo "godot: 실제 Godot 실행 파일을 찾지 못했습니다." >&2
    echo "       GODOT_REAL_BIN 환경변수로 경로를 지정하거나 install-apps.sh를 실행하세요." >&2
    exit 127
fi

# 사용자가 display driver를 직접 지정했으면 그대로 존중
for arg in "$@"; do
    case "${arg}" in
        --display-driver|--display-driver=*)
            exec "${real}" "$@"
            ;;
    esac
done

# Wayland 세션이면 X11(DISPLAY)을 제거해 Wayland 백엔드가 선택되게 한다
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${DISPLAY:-}" ]; then
    exec env -u DISPLAY "${real}" --display-driver wayland "$@"
fi

exec "${real}" "$@"
