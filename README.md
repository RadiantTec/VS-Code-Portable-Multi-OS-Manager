# 💼 VS Code Portable Multi-OS Manager Version 0.0.1

The project is currently not fully stable/tested. Use at your own discretion.

The projects aids in making a **portable pendrive hostable vscode** which works across the 3 os windows, linux and macOS, while enabling to maintain different versions of vscode for each os. Each version for a os share the same data folder optimising resource usage across versions.

A **cross-platform portable VS Code environment** that allows you to easily:
- Install and maintain multiple VS Code versions per OS
- Automatically update to the latest versions
- Share extensions, settings, and user data across Windows, Linux, and macOS
- Launch VS Code directly without installation
- Keep everything fully self-contained and portable (USB-ready)

---

## 🚀 Getting Started (from scratch)

### 1️⃣ Download or Clone the Repository

You can **clone this repository** or **download it as a ZIP** and extract it.  
The minimal folder structure looks like this:

```
VSCode-Portable/
│
├── windows/
├── linux/
├── mac/
└── settings_sync/
```

Each OS folder includes its own scripts for downloading, updating, and managing VS Code versions.

---

## ⚙️ Folder Structure

```text
vscode-portable/
│
├── settings_sync/
│   ├── settings.json             # Centralized cross-OS settings
│   ├── settings_sync.sh          # Synchronization script
│   └── settings_sync_config.txt  # Configuration for which OS gets which settings
│
├── windows/
│   ├── data/                     # Shared user data for all Windows versions
│   ├── vscode-stable-<ver>/      # Installed Windows VS Code versions
│   └── updater/
│       ├── update_vscode.ps1     # PowerShell updater/downloader
│       ├── linkupdater.ps1       # Maintains launcher and shortcut
│       ├── update_vscode.bat     # One-click runner for PowerShell updater
│       └── linkupdater.bat       # One-click runner for link updater
│
├── linux/
│   ├── data/
│   ├── vscode-stable-<ver>/
│   └── updater/
│       ├── update_vscode.sh      # Bash updater (auto-download and extract)
│       └── linkupdater.sh        # Updates symbolic link and launcher
│
└── mac/
    ├── data/
    ├── vscode-stable-<ver>/
    └── updater/
        ├── update_vscode.sh      # Bash updater
        └── linkupdater.sh        # Updates launcher and symlink
```

---

## 🪟 Windows Setup

1. Open the folder:
   ```
   windows/updater/
   ```
2. Double-click:
   - **`update_vscode.bat`** → downloads and installs the latest VS Code version  
   - **`linkupdater.bat`** → updates the launcher (`launch-vscode.bat` / `VSCode.lnk`)
3. After installation:
   - Launch using **`VSCode.lnk`** or **`launch-vscode.bat`**
   - Your settings and extensions live in `windows/data/`

---

## 🐧 Linux Setup

1. Open the folder:
   ```
   linux/updater/
   ```
2. Make the scripts executable:
   ```bash
   chmod +x update_vscode.sh linkupdater.sh
   ```
3. Run:
   ```bash
   ./update_vscode.sh
   ./linkupdater.sh
   ```
4. Launch using:
   ```bash
   ./launch-vscode.sh
   ```

---

## 🍎 macOS Setup

1. Open:
   ```
   mac/updater/
   ```
2. Make scripts executable:
   ```bash
   chmod +x update_vscode.sh linkupdater.sh
   ```
3. Run:
   ```bash
   ./update_vscode.sh
   ./linkupdater.sh
   ```
4. Launch with:
   ```bash
   ./launch-vscode.command
   ```

---

## ⚙️ Configuration (`config.txt`)

Each updater folder can contain a `config.txt` file to customize behavior.

Example:

```ini
basePath=..
channel=stable
arch=win32-x64-archive
maxVersionsToKeep=3
defaultVersion=
check_sha=true
auto_check_for_update=true
```

| Key | Description |
|-----|--------------|
| `basePath` | Root folder containing data and version folders |
| `channel` | `stable` or `insider` |
| `arch` | Architecture for download (e.g., `win32-x64-archive`) |
| `maxVersionsToKeep` | How many old versions to retain (0 = keep all) |
| `defaultVersion` | Specific version to install (e.g., `1.92.0`) |
| `check_sha` | Validate downloaded files’ integrity |
| `auto_check_for_update` | Automatically check for new versions |

---

## 🔄 Keeping Settings Synchronized

The `settings_sync/` folder helps synchronize VS Code settings between OSes.

### Files:
- **`settings.json`** — master configuration file  
- **`settings_sync.sh`** — synchronization script  
- **`settings_sync_config.txt`** — defines which versions exchange settings

### Example Configuration

```text
versions_sync=[
    [latest,win],
    [latest,linux],
    [latest,mac]
]
```

### How It Works
- The `settings_sync.sh` script reads `versions_sync`.
- For each `[src,dest]` pair, it copies settings from the **source** to the **destination**.
- This ensures all systems share a consistent configuration.

### Possible Values for `src` and `dest`
| Value | Meaning |
|--------|----------|
| `self` | The central `settings_sync/settings.json` file |
| `latest` | The most recent settings from any OS’s `data/User/settings.json` |
| `win` | Windows data folder (`windows/data/User/settings.json`) |
| `linux` | Linux data folder (`linux/data/User/settings.json`) |
| `mac` | macOS data folder (`mac/data/User/settings.json`) |

**Example:**
```text
versions_sync=[
    [self,win],
    [self,linux],
    [self,mac]
]
```
→ Propagates the `settings_sync/settings.json` to all OS data folders.

---

## 🧩 Updater Script Behavior (Overview)

### `update_vscode` (Windows `.ps1`, Linux/macOS `.sh`)
- Checks for the latest version via VS Code’s update API.
- Downloads and extracts the correct archive.
- Creates a shared data link (`data/`) so extensions and settings persist.
- Keeps a configurable number of previous versions.
- Logs all actions in `log.txt`.

### `linkupdater`
- Scans for installed VS Code versions.
- Chooses the newest available version (prefers stable).
- Updates:
  - Launcher scripts (`launch-vscode.bat` / `.sh`)
  - Shortcuts (`VSCode.lnk` on Windows)

---

## 🧱 Portable Data and Reuse

Each OS maintains a shared `data/` folder:
| OS | Path | Description |
|----|------|-------------|
| 🪟 Windows | `windows/data/` | Stores extensions, settings, and user data |
| 🐧 Linux | `linux/data/` | Same structure |
| 🍎 macOS | `mac/data/` | Same structure |

This allows identical environments across different systems or drives.

---

## 🧹 Maintenance Tips

- To **limit disk usage**, set `maxVersionsToKeep` to 2–3.  
- To **clean install**, delete all `vscode-stable-*` folders but keep `data/`.  
- To **manually sync**, re-run `settings_sync.sh`.

---

## 🏁 Quick Summary

| Task | Windows | Linux | macOS |
|------|----------|--------|-------|
| Install/Update VS Code | `update_vscode.bat` | `update_vscode.sh` | `update_vscode.sh` |
| Update Launcher | `linkupdater.bat` | `linkupdater.sh` | `linkupdater.sh` |
| Sync Settings | `settings_sync.sh` | `settings_sync.sh` | `settings_sync.sh` |
| Launch VS Code | `VSCode.lnk` / `launch-vscode.bat` | `launch-vscode.sh` | `launch-vscode.command` |

---

✨ **Enjoy a unified, version-managed, and portable VS Code setup across all your operating systems!**


