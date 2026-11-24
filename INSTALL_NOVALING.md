# NovaLinG Moonlight 빌드 · 설치 가이드

NovaLinG Sage 디자인이 적용된 데스크톱 Moonlight 클라이언트(Windows / macOS)의 설치 파일 빌드 및 한줄 설치 안내입니다.

## 1. 설치 파일 빌드 (GitHub Actions)

1. 이 저장소를 본인 GitHub 계정(예: `SH868-dev/novaling-moonlight`)에 푸시합니다.
2. 버전 태그(`v6.2.0-novaling.1`)를 푸시하거나 GitHub Actions에서 **`Release NovaLinG Moonlight (Windows & macOS)`** 워크플로를 수동 실행(`workflow_dispatch`)합니다.
3. 워크플로가 완료되면 GitHub Releases에 아래 파일이 자동 업로드됩니다.
   - `NovaLinG-Moonlight-Setup-<version>.exe` (Windows 설치 파일, x64 + ARM64 통합)
   - `NovaLinG-Moonlight-Portable-x64-<version>.zip` (Windows 무설치 포터블 x64)
   - `NovaLinG-Moonlight-Portable-arm64-<version>.zip` (Windows 무설치 포터블 ARM64)
   - `NovaLinG-Moonlight-<version>.dmg` (macOS Universal 설치 파일)
   - `install.ps1`, `install.sh`, `SHA256SUMS.txt`, `latest.json`

## 2. 한줄 설치 명령어

### Windows (PowerShell)

**기본 설치 (`.exe` 자동 설치)**
```powershell
irm https://github.com/SH868-dev/novaling-moonlight/releases/latest/download/install.ps1 | iex
```

**무설치 포터블 모드 (관리자 권한 불필요, 바탕화면·시작 메뉴 바로가기 자동 생성)**
```powershell
$env:NOVALING_MOONLIGHT_PORTABLE = "1"; irm https://github.com/SH868-dev/novaling-moonlight/releases/latest/download/install.ps1 | iex
```

### macOS (Terminal)

```bash
curl -fsSL https://github.com/SH868-dev/novaling-moonlight/releases/latest/download/install.sh | bash
```

## 3. 사설 서버(`oracle.novalinai.com` 등)에서 배포할 때

GitHub Releases 대신 자체 서버에 `latest.json`, `SHA256SUMS.txt`, `.exe`/`.zip`/`.dmg`, `install.ps1`, `install.sh`를 올려두고 URL 환경변수만 지정하면 그대로 동작합니다.

```powershell
# Windows
$env:NOVALING_MOONLIGHT_URL = "https://oracle.novalinai.com/moonlight"
irm https://oracle.novalinai.com/moonlight/install.ps1 | iex
```

```bash
# macOS
NOVALING_MOONLIGHT_URL="https://oracle.novalinai.com/moonlight" \
  curl -fsSL https://oracle.novalinai.com/moonlight/install.sh | bash
```
