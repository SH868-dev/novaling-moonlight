<#
.SYNOPSIS
    NovaLinG Moonlight (Windows) 원클릭 / 한줄 설치 스크립트.

.DESCRIPTION
    기본 실행 시 최신 설치 파일(NovaLinG-Moonlight-Setup-*.exe)을 내려받아
    SHA-256 무결성을 확인한 뒤 설치합니다.
    -Portable 옵션(또는 $env:NOVALING_MOONLIGHT_PORTABLE=1)을 사용하면
    관리자 권한 없이 %LOCALAPPDATA%\NovaLinG-Moonlight에 압축을 풀고 바로가기를 만듭니다.

.EXAMPLE
    # GitHub Releases에서 한줄 설치 (환경변수로 저장소 지정 가능)
    irm https://github.com/<OWNER>/<REPO>/releases/latest/download/install.ps1 | iex

.EXAMPLE
    # 포터블(무설치) 모드로 한줄 설치
    $env:NOVALING_MOONLIGHT_PORTABLE = "1"; irm https://github.com/<OWNER>/<REPO>/releases/latest/download/install.ps1 | iex

.EXAMPLE
    # 사설 다운로드 서버(latest.json 호스팅 또는 직접 .exe/.zip URL)에서 설치
    $env:NOVALING_MOONLIGHT_URL = "https://oracle.novalinai.com/moonlight"; irm https://oracle.novalinai.com/moonlight/install.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$Repo = $(if ($env:NOVALING_MOONLIGHT_REPO) { $env:NOVALING_MOONLIGHT_REPO } else { "SH868-dev/novaling-moonlight" }),
    [string]$BaseUrl = $(if ($env:NOVALING_MOONLIGHT_URL) { $env:NOVALING_MOONLIGHT_URL } else { "" }),
    [switch]$Portable = $(if ($env:NOVALING_MOONLIGHT_PORTABLE -in @("1", "true", "yes")) { $true } else { $false }),
    [switch]$Interactive = $(if ($env:NOVALING_MOONLIGHT_INTERACTIVE -in @("1", "true", "yes")) { $true } else { $false }),
    [string]$InstallDir = $(if ($env:NOVALING_MOONLIGHT_DIR) { $env:NOVALING_MOONLIGHT_DIR } else { Join-Path $env:LOCALAPPDATA "NovaLinG-Moonlight" })
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step([string]$Message) {
    Write-Host "[NovaLinG] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[NovaLinG] $Message" -ForegroundColor Yellow
}

function Get-HostArch {
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
    if ($arch -eq "arm64") { return "arm64" }
    if ([Environment]::Is64BitOperatingSystem) { return "x64" }
    throw "NovaLinG Moonlight는 64비트 Windows 10 이상에서만 지원됩니다."
}

function Parse-Sha256Sums([string]$Text) {
    $map = @{}
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$') {
            $map[$matches[2].Trim()] = $matches[1].ToLowerInvariant()
        }
    }
    return $map
}

function Verify-Sha256([string]$FilePath, [string]$ExpectedHash) {
    if (-not $ExpectedHash) {
        return
    }
    $actual = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedHash.ToLowerInvariant()) {
        throw "SHA-256 무결성 검증 실패: 기대값=$ExpectedHash, 실제값=$actual"
    }
    Write-Step "SHA-256 무결성 검증 완료"
}

function Resolve-Download([string]$Arch) {
    $headers = @{ "User-Agent" = "NovaLinG-Moonlight-Installer/1.0" }

    # 1) 직접 .exe 또는 .zip URL이 주어진 경우
    if ($BaseUrl -and ($BaseUrl -match '\.(exe|zip)(\?.*)?$')) {
        $fileName = Split-Path -Leaf (($BaseUrl -split '\?')[0])
        return [pscustomobject]@{
            Url      = $BaseUrl
            FileName = $fileName
            Sha256   = ""
            IsZip    = $fileName.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)
            Version  = "direct"
        }
    }

    # 2) 커스텀 호스트(latest.json 제공)가 주어진 경우
    if ($BaseUrl) {
        $root = $BaseUrl.TrimEnd("/")
        Write-Step "최신 버전 정보 확인 중: $root/latest.json"
        $manifest = Invoke-RestMethod -Uri "$root/latest.json" -Headers $headers -TimeoutSec 20
        $assetKey = if ($Portable) { "windows_portable_$Arch" } else { "windows_installer" }
        $asset = $manifest.assets.$assetKey
        if (-not $asset -and -not $Portable) {
            $asset = $manifest.assets."windows_portable_$Arch"
        }
        if (-not $asset) {
            throw "latest.json에서 '$assetKey' 항목을 찾을 수 없습니다."
        }
        $fileUrl = if ($asset.url) { $asset.url } else { "$root/$($asset.file)" }
        return [pscustomobject]@{
            Url      = $fileUrl
            FileName = $asset.file
            Sha256   = $asset.sha256
            IsZip    = $asset.file.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)
            Version  = $manifest.version
        }
    }

    # 3) GitHub Releases 최신 릴리즈 조회
    $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
    Write-Step "최신 릴리즈 확인 중: $Repo"
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 20
    $assets = @($release.assets)
    if ($assets.Count -eq 0) {
        throw "릴리즈에 다운로드 가능한 파일이 없습니다 ($Repo)."
    }

    $sumsMap = @{}
    $sumsAsset = $assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1
    if ($sumsAsset) {
        try {
            $sumsText = (Invoke-WebRequest -Uri $sumsAsset.browser_download_url -Headers $headers -UseBasicParsing -TimeoutSec 20).Content
            $sumsMap = Parse-Sha256Sums $sumsText
        } catch {
            Write-Warn "SHA256SUMS.txt를 읽지 못해 해시 확인을 건너뜁니다."
        }
    }

    $picked = $null
    if ($Portable) {
        $picked = $assets | Where-Object { $_.name -match "Portable-$Arch.*\.zip$" } | Select-Object -First 1
        if (-not $picked) {
            $picked = $assets | Where-Object { $_.name -match "$Arch.*\.zip$" } | Select-Object -First 1
        }
    } else {
        $picked = $assets | Where-Object { $_.name -match "(NovaLinG-Moonlight-Setup|MoonlightSetup).*\.exe$" } | Select-Object -First 1
    }

    if (-not $picked) {
        throw "해당 모드($(if ($Portable) { "포터블 $Arch" } else { "설치 파일" }))에 맞는 릴리즈 에셋을 찾을 수 없습니다."
    }

    return [pscustomobject]@{
        Url      = $picked.browser_download_url
        FileName = $picked.name
        Sha256   = $(if ($sumsMap.ContainsKey($picked.name)) { $sumsMap[$picked.name] } else { "" })
        IsZip    = $picked.name.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase)
        Version  = $release.tag_name
    }
}

function New-AppShortcut([string]$ShortcutPath, [string]$TargetPath, [string]$WorkingDir) {
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($ShortcutPath)
    $sc.TargetPath = $TargetPath
    $sc.WorkingDirectory = $WorkingDir
    $sc.Description = "NovaLinG Moonlight 원격 접속 클라이언트"
    $sc.Save()
}

$arch = Get-HostArch
$target = Resolve-Download -Arch $arch
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("novaling-moonlight-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

try {
    $downloadPath = Join-Path $tempDir $target.FileName
    Write-Step "다운로드 중 ($($target.Version)): $($target.FileName)"
    Invoke-WebRequest -Uri $target.Url -OutFile $downloadPath -UseBasicParsing -Headers @{ "User-Agent" = "NovaLinG-Moonlight-Installer/1.0" }
    Verify-Sha256 -FilePath $downloadPath -ExpectedHash $target.Sha256

    if ($target.IsZip) {
        Write-Step "포터블 폴더에 압축 해제 중: $InstallDir"
        if (Test-Path $InstallDir) {
            Remove-Item -Path $InstallDir -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        Expand-Archive -Path $downloadPath -DestinationPath $InstallDir -Force

        $exe = Get-ChildItem -Path $InstallDir -Filter "Moonlight.exe" -Recurse | Select-Object -First 1
        if (-not $exe) {
            throw "압축 해제 후 Moonlight.exe를 찾지 못했습니다."
        }

        $desktop = [Environment]::GetFolderPath("Desktop")
        $startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "NovaLinG"
        New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
        New-AppShortcut -ShortcutPath (Join-Path $desktop "NovaLinG.lnk") -TargetPath $exe.FullName -WorkingDir $exe.DirectoryName
        New-AppShortcut -ShortcutPath (Join-Path $startMenu "NovaLinG.lnk") -TargetPath $exe.FullName -WorkingDir $exe.DirectoryName

        Write-Step "설치 완료! 바탕화면/시작 메뉴의 'NovaLinG' 바로가기로 실행하세요."
    } else {
        $args = if ($Interactive) { @() } else { @("/install", "/passive", "/norestart") }
        Write-Step "설치 프로그램 실행 중... $(if (-not $Interactive) { '(자동 진행)' })"
        $proc = Start-Process -FilePath $downloadPath -ArgumentList $args -Wait -PassThru
        if ($proc.ExitCode -notin @(0, 3010)) {
            throw "설치 프로그램이 오류 코드 $($proc.ExitCode)로 종료되었습니다."
        }
        Write-Step "NovaLinG Moonlight 설치가 완료되었습니다."
        if ($proc.ExitCode -eq 3010) {
            Write-Warn "Visual C++ 런타임 적용을 위해 Windows 재시작이 필요할 수 있습니다."
        }
    }
} finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
