<#
.SYNOPSIS
Updates the VS Code launcher and shortcut to the best available installed version.
Prefers stable channel, falls back to insider if stable is not installed.
#>

# -----------------------------
# Load configuration
# -----------------------------
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $scriptRoot "config.txt"
$config = @{}

if (Test-Path $configPath) {
    Get-Content $configPath | ForEach-Object {
        if ($_ -match "^\s*#") { return } # Skip comments
        if ($_ -match "^\s*(\w+)\s*=\s*(.*)$") {
            $config[$matches[1]] = $matches[2].Trim()
        }
    }
}

$parentDir = Split-Path -Parent $PSScriptRoot

$basePath      = if ($config.ContainsKey("basePath") -and $config.basePath) { $config.basePath } else { $parentDir }
$targetVersion = if ($config.ContainsKey("targetVersion")) { $config.targetVersion } else { "" }

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

Write-Log "[INFO] Starting VS Code Link Updater..." Cyan

# -----------------------------
# Detect installed VS Code folders
# -----------------------------
$installedFolders = Get-ChildItem -Directory -Path $basePath | Where-Object {
    $_.Name -match "^vscode-(?<channel>[^-]+)-(?<version>\d+\.\d+\.\d+)$"
}

if (-not $installedFolders) {
    Write-Log "[ERROR] No VS Code installations found in $basePath" Red
    exit
}

# -----------------------------
# Group installed by channel
# -----------------------------
$channels = @{
    stable  = @()
    insider = @()
}

foreach ($folder in $installedFolders) {
    if ($folder.Name -match "^vscode-(?<ch>[^-]+)-(?<ver>\d+\.\d+\.\d+)$") {
        $ch = $matches['ch']
        $ver = [version]$matches['ver']
        if ($channels.ContainsKey($ch)) {
            $channels[$ch] += [PSCustomObject]@{ Path = $folder.FullName; Version = $ver }
        } else {
            $channels[$ch] = @([PSCustomObject]@{ Path = $folder.FullName; Version = $ver })
        }
    }
}

# -----------------------------
# Choose version (priority: stable > insider)
# -----------------------------
$chosenChannel = $null
$chosenVersion = $null
$chosenPath    = $null

if ($targetVersion) {
    # Prefer targetVersion if it exists in any channel
    $match = $installedFolders | Where-Object { $_.Name -match "$targetVersion$" } | Select-Object -First 1
    if ($match) {
        if ($match.Name -match "^vscode-(?<ch>[^-]+)-(?<ver>\d+\.\d+\.\d+)$") {
            $chosenChannel = $matches['ch']
            $chosenVersion = $matches['ver']
            $chosenPath = $match.FullName
        }
        Write-Log "[INFO] Using targetVersion from config: $chosenVersion ($chosenChannel)" Green
    } else {
        Write-Log "[WARN] Target version $targetVersion not found. Falling back to latest available." Yellow
    }
}

if (-not $chosenPath) {
    if ($channels["stable"].Count -gt 0) {
        $latestStable = $channels["stable"] | Sort-Object Version -Descending | Select-Object -First 1
        $chosenChannel = "stable"
        $chosenVersion = $latestStable.Version
        $chosenPath    = $latestStable.Path
        Write-Log "[INFO] Selected latest stable version: $chosenVersion" Green
    } elseif ($channels["insider"].Count -gt 0) {
        $latestInsider = $channels["insider"] | Sort-Object Version -Descending | Select-Object -First 1
        $chosenChannel = "insider"
        $chosenVersion = $latestInsider.Version
        $chosenPath    = $latestInsider.Path
        Write-Log "[INFO] Stable not found; selected latest insider version: $chosenVersion" Green
    } else {
        # fallback if neither stable nor insider found
        $latest = $installedFolders | Sort-Object { [version]($_.Name -replace '.*-(\d+\.\d+\.\d+)$','$1') } -Descending | Select-Object -First 1
        $chosenPath = $latest.FullName
        $chosenChannel = ($latest.Name -split '-')[1]
        $chosenVersion = ($latest.Name -split '-')[-1]
        Write-Log "[INFO] Using fallback version: $chosenVersion ($chosenChannel)" Green
    }
}

if (-not $chosenPath) {
    Write-Log "[ERROR] Could not determine version to link." Red
    exit
}

# -----------------------------
# Update launch-vscode.bat
# -----------------------------
$batchFile = Join-Path $basePath "launch-vscode.bat"
$batchContent = @"
@echo off
start """" "%~dp0vscode-$chosenChannel-$chosenVersion\Code.exe" --user-data-dir="%~dp0data"
"@
Set-Content -Path $batchFile -Value $batchContent -Encoding ASCII
Write-Log "[OK] Updated launcher -> $chosenChannel $chosenVersion" Green

# -----------------------------
# Update Windows shortcut (.lnk)
# -----------------------------
try {
    $shortcutPath = Join-Path $basePath "VSCode.lnk"
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $chosenPath "Code.exe"
    $shortcut.Arguments = "--user-data-dir=`"$dataFolder`""
    $shortcut.WorkingDirectory = $chosenPath
    $shortcut.IconLocation = Join-Path $chosenPath "Code.exe"
    $shortcut.Save()
    Write-Log "[OK] Updated shortcut -> VSCode.lnk ($chosenChannel $chosenVersion)" Green
} catch {
    Write-Log "[ERROR] Failed to update shortcut: $_" Red
}

Write-Log "[DONE] Link updater finished successfully using $chosenChannel $chosenVersion" Green
