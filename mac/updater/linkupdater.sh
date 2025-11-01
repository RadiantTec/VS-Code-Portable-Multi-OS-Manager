#!/usr/bin/env bash

# -----------------------------
# linkupdater-mac.sh
# -----------------------------
# Updates the VS Code launcher and shortcut to the best installed version on macOS.
# Prefers stable channel, falls back to insider if stable is not installed.
# -----------------------------

# -----------------------------
# Load configuration
# -----------------------------
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_ROOT/config.txt"
declare -A CONFIG

if [[ -f "$CONFIG_PATH" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        if [[ "$line" =~ ^([a-zA-Z_]+)=(.*)$ ]]; then
            CONFIG["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        fi
    done < "$CONFIG_PATH"
fi

PARENT_DIR="$(dirname "$SCRIPT_ROOT")"

BASE_PATH="${CONFIG[basePath]:-$PARENT_DIR}"
TARGET_VERSION="${CONFIG[targetVersion]:-}"

DATA_FOLDER="$BASE_PATH/data"
LOG_FILE="$SCRIPT_ROOT/log.txt"

# -----------------------------
# Logging helper
# -----------------------------
log() {
    local msg="$1"
    local color="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local entry="[$timestamp] $msg"

    case "$color" in
        red) tput setaf 1 ;;
        green) tput setaf 2 ;;
        yellow) tput setaf 3 ;;
        cyan) tput setaf 6 ;;
        *) tput setaf 7 ;;
    esac
    echo -e "$entry"
    tput sgr0

    echo "$entry" >> "$LOG_FILE"
}

log "[INFO] Starting VS Code Link Updater for macOS..." "cyan"

# -----------------------------
# Detect installed VS Code .app bundles
# -----------------------------
INSTALLED_FOLDERS=()
while IFS= read -r folder; do
    INSTALLED_FOLDERS+=("$folder")
done < <(find "$BASE_PATH" -maxdepth 1 -type d -name "Visual Studio Code*.app")

if [[ "${#INSTALLED_FOLDERS[@]}" -eq 0 ]]; then
    log "[ERROR] No VS Code installations found in $BASE_PATH" "red"
    exit 1
fi

# -----------------------------
# Group installed by channel
# -----------------------------
declare -A CHANNELS
CHANNELS["stable"]=""
CHANNELS["insider"]=""

for folder in "${INSTALLED_FOLDERS[@]}"; do
    foldername="$(basename "$folder")"
    if [[ "$foldername" =~ Visual\ Studio\ Code\ ([^ ]+)? ]]; then
        channel="stable"
        [[ "$foldername" =~ Insiders ]] && channel="insider"
        version=$(defaults read "$folder/Contents/Info" CFBundleShortVersionString 2>/dev/null)
        if [[ -n "$version" ]]; then
            CHANNELS["$channel"]+="$folder:$version "
        fi
    fi
done
# -----------------------------
# Choose version (priority: targetVersion > stable > insider)
# -----------------------------
CHOSEN_PATH=""
CHOSEN_VERSION=""
CHOSEN_CHANNEL=""

# Helper to compare versions (returns 0 if v1 > v2)
version_gt() {
    [[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" ]]
}

# Check targetVersion first
if [[ -n "$TARGET_VERSION" ]]; then
    for channel in "${!CHANNELS[@]}"; do
        for item in ${CHANNELS[$channel]}; do
            IFS=":" read -r path version <<< "$item"
            if [[ "$version" == "$TARGET_VERSION" ]]; then
                CHOSEN_PATH="$path"
                CHOSEN_VERSION="$version"
                CHOSEN_CHANNEL="$channel"
                log "[INFO] Using targetVersion from config: $CHOSEN_VERSION ($CHOSEN_CHANNEL)" "green"
                break 2
            fi
        done
    done
fi

# If no target version, pick latest stable > insider
if [[ -z "$CHOSEN_PATH" ]]; then
    for channel in "stable" "insider"; do
        latest_version=""
        latest_path=""
        for item in ${CHANNELS[$channel]}; do
            IFS=":" read -r path version <<< "$item"
            if [[ -z "$latest_version" ]] || version_gt "$version" "$latest_version"; then
                latest_version="$version"
                latest_path="$path"
            fi
        done
        if [[ -n "$latest_path" ]]; then
            CHOSEN_PATH="$latest_path"
            CHOSEN_VERSION="$latest_version"
            CHOSEN_CHANNEL="$channel"
            log "[INFO] Selected latest $channel version: $CHOSEN_VERSION" "green"
            break
        fi
    done
fi

# Final fallback (any available version)
if [[ -z "$CHOSEN_PATH" ]]; then
    CHOSEN_PATH="${INSTALLED_FOLDERS[0]}"
    CHOSEN_VERSION=$(defaults read "$CHOSEN_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null)
    CHOSEN_CHANNEL="stable"
    log "[WARN] Falling back to first detected version: $CHOSEN_VERSION ($CHOSEN_CHANNEL)" "yellow"
fi

# -----------------------------
# Update launch-vscode.sh
# -----------------------------
LAUNCHER="$BASE_PATH/launch-vscode.sh"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
open -a "$CHOSEN_PATH" --args --user-data-dir="$DATA_FOLDER"
EOF
chmod +x "$LAUNCHER"
log "[OK] Updated launcher -> $CHOSEN_CHANNEL $CHOSEN_VERSION" "green"

# -----------------------------
# Update macOS alias (shortcut) in basePath
# -----------------------------
ALIAS_PATH="$BASE_PATH/VSCode"
if [[ -e "$ALIAS_PATH" ]]; then
    rm -f "$ALIAS_PATH"
fi
ln -s "$CHOSEN_PATH" "$ALIAS_PATH"
log "[OK] Updated shortcut -> VSCode alias ($CHOSEN_CHANNEL $CHOSEN_VERSION)" "green"

log "[DONE] Link updater finished successfully using $CHOSEN_CHANNEL $CHOSEN_VERSION" "green"
