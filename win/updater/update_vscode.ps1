# ============================================
# VS Code Portable Updater / Version Manager
# ============================================

# --- ensure proper PowerShell host (needs Desktop .NET for WebClient) ---
if ($PSVersionTable.PSEdition -ne "Desktop") {
    Write-Host "Restarting under Windows PowerShell for compatibility..." -ForegroundColor Yellow
    Start-Process "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# -----------------------------
# Read configuration
# -----------------------------
$configPath = Join-Path $PSScriptRoot "config.txt"
$config = @{}

if (Test-Path $configPath) {
    Get-Content $configPath | ForEach-Object {
        if ($_ -match "^\s*#") { return }
        if ($_ -match "^\s*(\w+)\s*=\s*(.*)$") {
            $config[$matches[1]] = $matches[2].Trim()
        }
    }
}

$parentDir = Split-Path -Parent $PSScriptRoot

$basePath          = if ($config["basePath"]) { $config["basePath"] } else { $parentDir }
$channel           = if ($config["channel"]) { $config["channel"] } else { "stable" }
$arch              = if ($config["arch"]) { $config["arch"] } else { "win32-x64-archive" }
$maxVersionsToKeep = if ($config["maxVersionsToKeep"]) { [int]$config["maxVersionsToKeep"] } else { 0 }
$defaultVersion    = if ($config["defaultVersion"]) { $config["defaultVersion"] } else { "" }
$checkSha          = if ($config["check_sha"]) { [bool]::Parse($config["check_sha"]) } else { $false }
$autoCheckUpdate   = if ($config["auto_check_for_update"]) { [bool]::Parse($config["auto_check_for_update"]) } else { $false }

$dataFolder = Join-Path $basePath "data"
$logFile    = Join-Path $PSScriptRoot "log.txt"

# -----------------------------
# Logging helper
# -----------------------------
function Write-Log {
    param([string]$Message, [ConsoleColor]$Color = "Gray")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] $Message"
    Write-Host $entry -ForegroundColor $Color
    Add-Content -Path $logFile -Value $entry
}

# -----------------------------
# Friendly startup message
# -----------------------------
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " VS Code Portable Updater / Version Manager " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Controls while downloading:" -ForegroundColor Yellow
Write-Host "  P : Pause download" -ForegroundColor Yellow
Write-Host "  R : Resume download" -ForegroundColor Yellow
Write-Host "  Ctrl+C : Cancel download (you can resume later)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Green
[console]::ReadKey($true) | Out-Null

# -----------------------------
# Graceful exit handler
# -----------------------------
$onCancel = {
    Write-Log "[WARN] Script interrupted by user. You can resume later." Yellow
    exit
}
Register-EngineEvent PowerShell.Exiting -Action $onCancel

# -----------------------------
# Get latest version (fixed API)
# -----------------------------
function Get-LatestVersion {
    param($channel)
    try {
        $url = "https://update.code.visualstudio.com/api/update/win32-x64-archive/$channel/latest"
        $json = Invoke-RestMethod -Uri $url -ErrorAction Stop
        if ($json.name) { return $json.name }
        elseif ($json.version) { return $json.version }
        else {
            Write-Log "[ERROR] Could not find version field in API response." Red
            exit
        }
    } catch {
        Write-Log "[ERROR] Cannot get latest version: $_" Red
        exit
    }
}

# -----------------------------
# SHA256 from metadata
# -----------------------------
function Get-Sha256Hash {
    param([string]$version)
    try {
        $apiUrl = "https://update.code.visualstudio.com/api/versions/$version/$arch/$channel"
        Write-Log "[INFO] Fetching SHA256 hash metadata for version $version"
        $json = Invoke-RestMethod -Uri $apiUrl -Method Get
        if ($json.sha256hash) { return $json.sha256hash }
        elseif ($json.hash)   { return $json.hash }
        else { Write-Log "[WARN] No SHA256 field found." Yellow; return $null }
    } catch {
        Write-Log "[ERROR] Failed to get hash metadata: $_" Red
        return $null
    }
}

# -----------------------------
# Download with pause/resume
# -----------------------------
function Invoke-DownloadFile {
    param([string]$Url, [string]$OutFile)

    $partFile = "$OutFile.part"
    $metaFile = "$OutFile.meta"

    # --- Check existing part ---
    $start = 0
    $totalSize = 0
    if (Test-Path $partFile) {
        $start = (Get-Item $partFile).Length
        if (Test-Path $metaFile) {
            try {
                $meta = Get-Content $metaFile | ConvertFrom-Json
                $totalSize = [int64]$meta.TotalSize
            } catch { $totalSize = 0 }
        }
    }

    # --- Probe total size from server ---
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = "HEAD"
    try {
        $resp = $req.GetResponse()
        $totalSize = [int64]$resp.Headers["Content-Length"]
        $resp.Close()
    } catch {
        Write-Log "[WARN] Could not determine total file size: $_" Yellow
    }

    # --- Prepare client ---
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "VSCode Portable Updater")
    if ($start -gt 0 -and $totalSize -gt 0 -and $start -lt $totalSize) {
        Write-Log "[INFO] Resuming from byte offset $start of $totalSize"
        $wc.Headers.Add("Range", "bytes=$start-")
    } elseif ($start -gt 0 -and $start -ge $totalSize -and $totalSize -gt 0) {
        Write-Log "[OK] File already fully downloaded. Renaming..."
        Rename-Item -Path $partFile -NewName $OutFile -Force
        return
    } elseif ($start -gt 0) {
        Write-Log "[WARN] Partial file found but size unknown. Restarting download."
        Remove-Item $partFile -Force
        $start = 0
    }

    # --- Save meta info for resume ---
    @{ Url = $Url; TotalSize = $totalSize } | ConvertTo-Json | Set-Content -Path $metaFile -Encoding UTF8

    Write-Log "[INFO] Downloading $Url (resume offset $start bytes)..."

    $global:lastBytes = $start
    $global:lastTime = Get-Date
    $global:startTime = Get-Date
    $global:paused = $false

    Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
        $e = $EventArgs
        $now = Get-Date
        $elapsed = ($now - $global:lastTime).TotalSeconds
        if ($elapsed -gt 0) {
            $bytesDiff = ($e.BytesReceived + $start) - $global:lastBytes
            $speedMB = [math]::Round(($bytesDiff / $elapsed) / 1MB, 2)
        } else { $speedMB = 0 }

        $global:lastBytes = $e.BytesReceived + $start
        $global:lastTime = $now

        $received = $e.BytesReceived + $start
        $total = if ($totalSize -gt 0) { $totalSize } else { $e.TotalBytesToReceive + $start }
        $percent = if ($total -gt 0) { [math]::Round(($received / $total) * 100, 2) } else { 0 }
        $receivedMB = [math]::Round($received / 1MB, 2)
        $totalMB = [math]::Round($total / 1MB, 2)

        $statusText = ("{0}% ({1}/{2} MB @ {3} MB/s)" -f $percent, $receivedMB, $totalMB, $speedMB)
        Write-Progress -Activity "Downloading VS Code" -Status $statusText -PercentComplete $percent
    }

    # --- Start download ---
    $wc.DownloadFileAsync([Uri]$Url, $partFile)

    while ($wc.IsBusy) {
        if ([console]::KeyAvailable) {
            $key = [console]::ReadKey($true)
            if ($key.Key -eq 'P') {
                $global:paused = $true
                Write-Host "Paused. Press R to resume." -ForegroundColor Yellow
            } elseif ($key.Key -eq 'R') {
                $global:paused = $false
                Write-Host "Resumed." -ForegroundColor Green
            }
        }
        while ($global:paused) { Start-Sleep -Milliseconds 300 }
        Start-Sleep -Milliseconds 200
    }

    # --- Finalize ---
    if (Test-Path $partFile) {
        Rename-Item -Path $partFile -NewName $OutFile -Force
        Write-Log "[OK] Download complete: $OutFile" Green
    }
    if (Test-Path $metaFile) { Remove-Item $metaFile -Force }
}

# -----------------------------
# Compute SHA256
# -----------------------------
function Get-FileSha256 {
    param([string]$FilePath)
    $hashAlg = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($FilePath)
    try {
        ($hashAlg.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join ""
    } finally { $stream.Close(); $hashAlg.Dispose() }
}

# -----------------------------
# Remove old versions
# -----------------------------
function Remove-OldVersions {
    param([string]$BasePath, [string]$Channel, [int]$Keep)
    $versions = Get-ChildItem -Path $BasePath -Directory -Filter "vscode-$Channel-*" | Sort-Object Name -Descending
    $old = $versions | Select-Object -Skip $Keep
    foreach ($v in $old) {
        Write-Log "[INFO] Removing old version: $($v.FullName)"
        Remove-Item $v.FullName -Recurse -Force
    }
}

# -----------------------------
# Install VS Code
# -----------------------------
function Install-VSCode {
    param([string]$version)

    $versionPath = Join-Path $basePath "vscode-$channel-$version"
    if (-not (Test-Path $versionPath)) {
        $zipFile = Join-Path $basePath "vscode-$channel-$version.zip"
        $downloadUrl = "https://update.code.visualstudio.com/$version/$arch/$channel"

        Write-Log "[INFO] Downloading VS Code $version ($channel)..."
        Invoke-DownloadFile -Url $downloadUrl -OutFile $zipFile

        if ($checkSha) {
            $expected = Get-Sha256Hash -version $version
            $actual   = Get-FileSha256 -FilePath $zipFile
            Write-Log "[INFO] Expected SHA256 = $expected"
            Write-Log "[INFO] Actual   SHA256 = $actual"
            if ($expected -and $expected -ne $actual) {
                Write-Log "[ERROR] SHA256 mismatch! Aborting." Red
                exit
            }
        }

        Write-Log "[INFO] Extracting..."
        Expand-Archive -Path $zipFile -DestinationPath $versionPath -Force
        Remove-Item $zipFile -Force
        Write-Log "[OK] Extracted to $versionPath"
    } else {
        Write-Log "[OK] VS Code $version already exists."
    }

    if ($maxVersionsToKeep -gt 0) {
        Remove-OldVersions -BasePath $basePath -Channel $channel -Keep $maxVersionsToKeep
    }

    if (-not (Test-Path $dataFolder)) { New-Item -ItemType Directory -Path $dataFolder | Out-Null }
    $linkPath = Join-Path $versionPath "data"
    if (Test-Path $linkPath) { Remove-Item $linkPath -Force -Recurse }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    try {
        if ($isAdmin) {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $dataFolder | Out-Null
            Write-Log "[OK] Created symbolic link: $linkPath -> $dataFolder"
        } else {
            New-Item -ItemType Junction -Path $linkPath -Target $dataFolder | Out-Null
            Write-Log "[OK] Created junction: $linkPath -> $dataFolder"
        }
    } catch { Write-Log "[ERROR] Link creation failed: $_" Red }

    return $versionPath
}

# -----------------------------
# Launcher and shortcut
# -----------------------------
function Update-LauncherShortcut {
    param([string]$versionPath)
    $launcher = Join-Path $basePath "launch-vscode.bat"
    $shortcut = Join-Path $basePath "VSCode.lnk"

$batContent = @"
@echo off
start """" "$versionPath\Code.exe" --user-data-dir="$dataFolder"
"@
    Set-Content -Path $launcher -Value $batContent -Encoding ASCII
    Write-Log "[OK] Launcher updated: $launcher"

    $WshShell = New-Object -ComObject WScript.Shell
    $lnk = $WshShell.CreateShortcut($shortcut)
    $lnk.TargetPath = Join-Path $versionPath "Code.exe"
    $lnk.Arguments = "--user-data-dir=`"$dataFolder`""
    $lnk.WorkingDirectory = $versionPath
    $lnk.IconLocation = Join-Path $versionPath "Code.exe,0"
    $lnk.Save()
    Write-Log "[OK] Shortcut updated: $shortcut"
}

# -----------------------------
# Main workflow
# -----------------------------
if ($autoCheckUpdate) {
    $latest = Get-LatestVersion $channel
    Write-Log "[INFO] Latest version available = $latest"
    $installed = Get-ChildItem -Path $basePath -Directory -Filter "vscode-$channel-*" |
        ForEach-Object { $_.Name.Split('-')[-1] }
    if ($installed) {
        $highest = ($installed | Sort-Object {[Version]$_} -Descending)[0]
        if ([Version]$latest -le [Version]$highest) {
            Write-Log "[OK] No update needed." Green
            return
        }
    }
    $versionToInstall = $latest
} else {
    $versionToInstall = if ($defaultVersion) { $defaultVersion } else { Get-LatestVersion $channel }
}

$path = Install-VSCode -version $versionToInstall
Update-LauncherShortcut -versionPath $path
Write-Log "[DONE] VS Code portable ready. Launch via launch-vscode.bat or VSCode.lnk" Green
