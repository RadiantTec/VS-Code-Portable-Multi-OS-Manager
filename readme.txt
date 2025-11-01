VS Code Portable Multi-OS Manager

This repository provides a portable VS Code setup for Windows, Linux, and macOS, including version management, automatic updates, and settings synchronization across OSes.

Folder Structure
vscode-portable/
│
├── settings_sync/
│   ├── settings.json             # Master settings file
│   ├── settings_sync.sh          # Shell script to sync settings
│   └── settings_sync_config.txt  # Configuration for settings sync
│
├── windows/
│   ├── data/                     # Shared data folder for all Windows VS Code versions
│   ├── vscode-stable-<ver>/      # Windows VS Code versions
│   └── updater/
│       ├── update_vscode.ps1     # PowerShell updater for Windows
│       ├── linkupdater.ps1       # PowerShell link updater
│       ├── update_vscode.bat     # Double-click to run PS1 updater
│       └── linkupdater.bat       # Double-click to run link updater
│
├── linux/
│   ├── data/                     # Shared data folder for all Linux VS Code versions
│   ├── vscode-stable-<ver>/      # Linux VS Code versions
│   └── updater/
│       ├── update_vscode.sh      # Bash updater for Linux
│       └── linkupdater.sh        # Bash link updater for Linux
│
└── mac/
    ├── data/                     # Shared data folder for all macOS VS Code versions
    ├── vscode-stable-<ver>/      # macOS VS Code versions
    └── updater/
        ├── update_vscode.sh      # Bash updater for macOS
        └── linkupdater.sh        # Bash link updater

Usage
Windows

Open the windows/updater folder.

Double-click:

update_vscode.bat → updates installed VS Code versions.

linkupdater.bat → updates the launcher and .lnk shortcut to the latest available version.

VS Code versions are stored in windows/vscode-stable-<ver>/.

All versions share the windows/data/ folder for settings, extensions, and user data.

Linux / macOS

Open the linux/updater or mac/updater folder.

Make scripts executable:

chmod +x update_vscode.sh linkupdater.sh


Run via double-click (depending on your file manager) or via terminal:

./update_vscode.sh
./linkupdater.sh


All versions share the linux/data/ or mac/data/ folder, meaning settings and extensions are common across versions.

Settings Synchronization

The settings_sync folder manages a central settings.json that can be propagated across OS-specific VS Code installations.

Configuration (settings_sync_config.txt)

versions_sync variable defines which OS versions get the settings.

Format:

versions_sync=[
    [latest,win],
    [latest,linux],
    [latest,mac]
]


Values for src and dest:

self → the settings_sync/settings.json file.

latest → latest settings.json from any OS/data folder.

win, linux, mac → use that OS’s data/User/settings.json as source or destination.

How it Works

settings_sync.sh reads versions_sync.

Copies settings.json from source to destination for each pair.

Ensures all OSes have consistent VS Code settings if desired.

Defaults in settings_sync_config.txt:

versions_sync=[
    [latest,win],
    [latest,linux],
    [latest,mac]
]


This propagates the latest available settings to all OSes.

Supports cross-OS synchronization without bidirectional conflicts.

Notes

Shared data folders:

Windows → windows/data/

Linux → linux/data/

macOS → mac/data/

All VS Code versions within the same OS share a single data/ folder.

Updater scripts handle downloading, version management, and link/launcher updates.

Linux and macOS scripts need execution permission (chmod +x).

Windows updater scripts can be double-clicked, leveraging .bat files that run PowerShell scripts.