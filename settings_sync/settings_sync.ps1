# ============================================
# VS Code Settings Sync Script (Windows)
# ============================================
# Sync settings.json across Windows, Linux, macOS according to versions_sync configuration.
# ============================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigFile = Join-Path $ScriptDir "settings_sync_config.txt"
$LogFile = Join-Path $ScriptDir "settings_sync.log"

# -----------------------------
# Logging helper
# -----------------------------
function Write-Log {
    param([string]$Message, [ConsoleColor]$Color = "Gray")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] $Message"
    Write-Host $entry -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $entry
}

# -----------------------------
# Read versions_sync from config
# -----------------------------
if (-not (Test-Path $ConfigFile)) {
    Write-Log "❌ Configuration file not found: $ConfigFile" Red
    exit
}

$configText = Get-Content $ConfigFile | Out-String
if ($configText -match 'versions_sync\s*=\s*(\[[^\]]*\])') {
    $versionsSync = Invoke-Expression $matches[1]
} else {
    Write-Log "❌ Could not read versions_sync from config. Using default." Yellow
    $versionsSync = @(
        @("latest","win"),
        @("latest","linux"),
        @("latest","mac")
    )
}

# -----------------------------
# Define OS folders
# -----------------------------
$WinDir   = Join-Path $ScriptDir "..\win"
$LinuxDir = Join-Path $ScriptDir "..\linux"
$MacDir   = Join-Path $ScriptDir "..\mac"
$DataSubpath = "data\User"

# -----------------------------
# Helper to get source path
# -----------------------------
function Get-SourcePath {
    param([string]$src)

    switch ($src.ToLower()) {
        "self" {
            $selfPath = Join-Path $ScriptDir "settings.json"
            if (Test-Path $selfPath) {
                return $selfPath
            } else {
                Write-Log "⚠️ Source 'self' settings.json not found in $ScriptDir. Skipping any sync from self." Yellow
                return $null
            }
        }
        "latest" {
            $latestFile = $null
            $latestTime = [DateTime]::MinValue
            foreach ($os in @($WinDir, $LinuxDir, $MacDir)) {
                $file = Join-Path $os $DataSubpath "settings.json"
                if (Test-Path $file) {
                    $time = (Get-Item $file).LastWriteTime
                    if ($time -gt $latestTime) {
                        $latestTime = $time
                        $latestFile = $file
                    }
                }
            }
            # Check self
            $selfPath = Join-Path $ScriptDir "settings.json"
            if (Test-Path $selfPath) {
                $time = (Get-Item $selfPath).LastWriteTime
                if ($time -gt $latestTime) {
                    $latestFile = $selfPath
                }
            }
            if (-not $latestFile) {
                Write-Log "⚠️ No settings.json found for 'latest'. Skipping this sync pair." Yellow
            }
            return $latestFile
        }
        "win" { return Join-Path $WinDir "$DataSubpath\settings.json" }
        "linux" { return Join-Path $LinuxDir "$DataSubpath\settings.json" }
        "mac" { return Join-Path $MacDir "$DataSubpath\settings.json" }
        default {
            Write-Log "⚠️ Unknown source: $src" Yellow
            return $null
        }
    }
}

# -----------------------------
# Helper to get destination path
# -----------------------------
function Get-DestPath {
    param([string]$dest)

    switch ($dest.ToLower()) {
        "self" { return Join-Path $ScriptDir "settings.json" }
        "win" {
            $path = Join-Path $WinDir $DataSubpath
            if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
            return Join-Path $path "settings.json"
        }
        "linux" {
            $path = Join-Path $LinuxDir $DataSubpath
            if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
            return Join-Path $path "settings.json"
        }
        "mac" {
            $path = Join-Path $MacDir $DataSubpath
            if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
            return Join-Path $path "settings.json"
        }
        default {
            Write-Log "⚠️ Unknown destination: $dest" Yellow
            return $null
        }
    }
}

# -----------------------------
# Perform sync
# -----------------------------
foreach ($pair in $versionsSync) {
    $src = $pair[0]
    $dest = $pair[1]

    $srcPath = Get-SourcePath $src
    $destPath = Get-DestPath $dest

    if (-not $srcPath -or -not (Test-Path $srcPath)) {
        Write-Log "⚠️ Skipping sync from $src to $dest because source is missing." Yellow
        continue
    }
    if (-not $destPath) {
        Write-Log "⚠️ Destination path invalid for: $dest" Yellow
        continue
    }

    Copy-Item -Path $srcPath -Destination $destPath -Force
    Write-Log "✅ Synced $src -> $dest ($srcPath -> $destPath)" Green
}

Write-Log "🎉 Settings sync completed." Green
