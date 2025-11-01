# 💼 VS Code Portable Multi-OS Manager · Version 0.0.1

> **Purpose:** Simplify using Visual Studio Code portably across Windows, Linux, and macOS.  
> **Use Case:** Ideal for USB drives, multi-boot setups, or users maintaining isolated VS Code environments per OS.  
> **Status:** Experimental — use at your own discretion.

---

This project provides a **portable, USB-hostable VS Code setup** that works across **Windows, Linux, and macOS**, while allowing you to maintain **multiple VS Code versions per OS**.

It can also be used locally on a single OS by copying only that OS’s folder and using its included updater tools.

A **cross-platform portable VS Code environment** that lets you:

- 🧩 Install and maintain multiple VS Code versions per OS  
- 🔄 Automatically update to the latest releases  
- ⚙️ Share extensions, settings, and user data across systems  
- 🚀 Launch VS Code without installation  
- 💾 Keep everything self-contained and portable (USB-ready)

---

## 🚀 Getting Started (from scratch)

### 1️⃣ Download or Clone the Repository

You can **clone this repository** or **download it as a ZIP** and extract it.  
The minimal folder structure looks like this:

```text
vscode-portable/
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
│   └── settings_sync_config.txt  # Configuration defining sync direction
│
├── windows/
│   ├── data/                     # Shared user data for all Windows versions
│   ├── vscode-stable-<ver>/      # Installed Windows VS Code versions
│   └── updater/
│       ├── update_vscode.ps1     # PowerShell updater/downloader
│       ├── linkupdater.ps1       # Maintains launcher and shortcut
│       ├── update_vscode.bat     # One-click runner for updater
│       └── linkupdater.bat       # One-click runner for link updater
│
├── linux/
│   ├── data/
│   ├── vscode-stable-<ver>/
│   └── updater/
│       ├── update_vscode.sh      # Bash updater (auto-download/extract)
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

1. Open:
   ```
   windows/updater/
   ```
2. Double-click:
   - **`update_vscode.bat`** → downloads and installs the latest VS Code version  
   - **`linkupdater.bat`** → updates launcher (`launch-vscode.bat` / `VSCode.lnk`)
3. Launch using **`VSCode.lnk`** or **`launch-vscode.bat`**  
   Settings and extensions live in `windows/data/`

---

## 🐧 Linux Setup

1. Open:
   ```
   linux/updater/
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
4. Launch:
   ```bash
   ./launch-vscode.sh
   ```

> 🧠 **Note for Linux users:**  
> After copying from Windows or a ZIP, re-run `chmod +x *.sh` if scripts lose executable permissions.

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
4. Launch:
   ```bash
   ./launch-vscode.command
   ```

> 🧠 **Note for macOS users:**  
> If macOS blocks a script (Gatekeeper), right-click it → **Open**, then confirm.  
> Or remove the quarantine flag:  
> `xattr -dr com.apple.quarantine ./update_vscode.sh`

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
| `arch` | Architecture for download (e.g. `win32-x64-archive`) |
| `maxVersionsToKeep` | Number of old versions to retain (`0` = keep all) |
| `defaultVersion` | Specific version to install (e.g. `1.92.0`) |
| `check_sha` | Validate downloaded files’ integrity |
| `auto_check_for_update` | Automatically check for new releases |

---

## 🔄 Keeping Settings Synchronized

The `settings_sync/` folder helps synchronize VS Code settings between OSes.

### Files
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
- Run `settings_sync.sh` from within the `settings_sync/` folder.  
- The script reads `versions_sync` and, for each `[src, dest]` pair, copies settings from the **source** to the **destination**.  
- Ensures all systems share a consistent configuration.

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
- Checks for the latest VS Code version via the update API.  
- Downloads and extracts the correct archive.  
- Links to the shared `data/` folder (for extensions/settings).  
- Keeps a configurable number of previous versions.  
- Logs all actions to `log.txt`.

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
|----|------|--------------|
| 🪟 Windows | `windows/data/` | Stores extensions, settings, and user data |
| 🐧 Linux | `linux/data/` | Same structure |
| 🍎 macOS | `mac/data/` | Same structure |

This allows identical VS Code environments across different systems or portable drives.

---

## 🧹 Maintenance Tips

- To **limit disk usage**, set `maxVersionsToKeep` to 2–3.  
- To **clean install**, delete all `vscode-stable-*` folders but keep `data/`.  
- To **manually sync settings**, re-run `settings_sync.sh`.

---

## 🚧 Known Limitations / Future Plans

- macOS and Linux scripts are minimally tested.  
- VS Code Insiders channel support is experimental.  
- Planned: cross-OS extension sync and conflict-free merging.

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
