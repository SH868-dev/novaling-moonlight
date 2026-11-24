#!/usr/bin/env bash
# NovaLinG Moonlight (macOS) 한줄 설치 스크립트
#
# 사용 예:
#   curl -fsSL https://github.com/<OWNER>/<REPO>/releases/latest/download/install.sh | bash
#
# 환경 변수 옵션:
#   NOVALING_MOONLIGHT_REPO : GitHub 저장소 (기본값: SH868-dev/novaling-moonlight)
#   NOVALING_MOONLIGHT_URL  : 사설 다운로드 서버 베이스 URL(latest.json) 또는 직접 .dmg URL
#   NOVALING_INSTALL_DIR    : 설치 폴더 (기본값: /Applications, 권한 없으면 ~/Applications)

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[NovaLinG] 이 스크립트는 macOS 전용입니다." >&2
  exit 1
fi

REPO="${NOVALING_MOONLIGHT_REPO:-SH868-dev/novaling-moonlight}"
BASE_URL="${NOVALING_MOONLIGHT_URL:-}"
INSTALL_DIR="${NOVALING_INSTALL_DIR:-/Applications}"

log() {
  printf '\033[1;32m[NovaLinG]\033[0m %s\n' "$1"
}

warn() {
  printf '\033[1;33m[NovaLinG]\033[0m %s\n' "$1"
}

die() {
  printf '\033[1;31m[NovaLinG]\033[0m %s\n' "$1" >&2
  exit 1
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/novaling-moonlight.XXXXXX")"
MOUNT_DIR=""

cleanup() {
  if [[ -n "${MOUNT_DIR}" ]] && mount | grep -q " on ${MOUNT_DIR} "; then
    hdiutil detach "${MOUNT_DIR}" -quiet || hdiutil detach "${MOUNT_DIR}" -force -quiet || true
  fi
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

resolve_download() {
  python3 - "${REPO}" "${BASE_URL}" <<'PY'
import json, re, sys, urllib.request

repo, base_url = sys.argv[1], sys.argv[2]
headers = {"User-Agent": "NovaLinG-Moonlight-Installer/1.0"}

def fetch_text(url):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.read().decode("utf-8")

if base_url and re.search(r"\.dmg(\?.*)?$", base_url, re.I):
    name = base_url.split("?", 1)[0].rsplit("/", 1)[-1]
    print(f"{base_url}\t{name}\t\tdirect")
    sys.exit(0)

if base_url:
    root = base_url.rstrip("/")
    manifest = json.loads(fetch_text(f"{root}/latest.json"))
    asset = manifest.get("assets", {}).get("macos_dmg")
    if not asset:
        raise SystemExit("latest.json에서 macos_dmg 항목을 찾을 수 없습니다.")
    url = asset.get("url") or f"{root}/{asset['file']}"
    print(f"{url}\t{asset['file']}\t{asset.get('sha256', '')}\t{manifest.get('version', '')}")
    sys.exit(0)

release = json.loads(fetch_text(f"https://api.github.com/repos/{repo}/releases/latest"))
assets = release.get("assets") or []
sums = {}
for item in assets:
    if item.get("name") == "SHA256SUMS.txt":
        try:
            for line in fetch_text(item["browser_download_url"]).splitlines():
                m = re.match(r"^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$", line)
                if m:
                    sums[m.group(2).strip()] = m.group(1).lower()
        except Exception:
            pass
        break

dmg = next((a for a in assets if str(a.get("name", "")).lower().endswith(".dmg")), None)
if not dmg:
    raise SystemExit(f"릴리즈에서 .dmg 설치 파일을 찾을 수 없습니다 ({repo}).")

name = dmg["name"]
print(f"{dmg['browser_download_url']}\t{name}\t{sums.get(name, '')}\t{release.get('tag_name', '')}")
PY
}

log "최신 macOS 설치 파일 확인 중..."
IFS=$'\t' read -r DMG_URL DMG_NAME EXPECTED_SHA VERSION <<<"$(resolve_download)"

DMG_PATH="${WORK_DIR}/${DMG_NAME}"
log "다운로드 중 (${VERSION:-latest}): ${DMG_NAME}"
curl -fL --progress-bar -o "${DMG_PATH}" "${DMG_URL}"

if [[ -n "${EXPECTED_SHA}" ]]; then
  ACTUAL_SHA="$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
  if [[ "${ACTUAL_SHA}" != "${EXPECTED_SHA}" ]]; then
    die "SHA-256 무결성 검증 실패 (기대값=${EXPECTED_SHA}, 실제값=${ACTUAL_SHA})"
  fi
  log "SHA-256 무결성 검증 완료"
fi

MOUNT_DIR="${WORK_DIR}/mnt"
mkdir -p "${MOUNT_DIR}"
log "DMG 마운트 중..."
hdiutil attach "${DMG_PATH}" -nobrowse -readonly -mountpoint "${MOUNT_DIR}" -quiet

APP_SRC="$(find "${MOUNT_DIR}" -maxdepth 2 -name "*.app" -type d | head -n 1)"
if [[ -z "${APP_SRC}" ]]; then
  die "DMG 안에서 .app 번들을 찾지 못했습니다."
fi
APP_NAME="$(basename "${APP_SRC}")"

if [[ ! -w "${INSTALL_DIR}" ]]; then
  if [[ "${INSTALL_DIR}" == "/Applications" ]]; then
    warn "/Applications 쓰기 권한이 없어 ~/Applications 에 설치합니다."
    INSTALL_DIR="${HOME}/Applications"
    mkdir -p "${INSTALL_DIR}"
  else
    die "설치 폴더에 쓰기 권한이 없습니다: ${INSTALL_DIR}"
  fi
fi

TARGET_APP="${INSTALL_DIR}/${APP_NAME}"
if [[ -d "${TARGET_APP}" ]]; then
  log "기존 앱 교체 중: ${TARGET_APP}"
  rm -rf "${TARGET_APP}"
fi

log "앱 복사 중: ${TARGET_APP}"
ditto "${APP_SRC}" "${TARGET_APP}"

# 비공증(자체 빌드) DMG 실행 시 macOS Gatekeeper 격리 속성 제거
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "${TARGET_APP}" 2>/dev/null || true
fi

log "설치 완료! 다음 경로에서 실행할 수 있습니다: ${TARGET_APP}"
echo "  실행 명령: open \"${TARGET_APP}\""
