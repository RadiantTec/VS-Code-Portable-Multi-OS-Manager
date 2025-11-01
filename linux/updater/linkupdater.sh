#!/usr/bin/env bash
# ------------------------------------
# VS Code Linux Link Updater
# ------------------------------------

set -euo pipefail

# -----------------------------
# Load configuration
# -----------------------------
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_ROOT/config.txt"
declare -A CONFIG

if [[ -f "$CONFIG_PATH" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^\s*# ]] && continue
        if [[ "$line" =~ ^\s*([a-zA-Z0-9_]+)\s*=\s*(.*)$ ]]; then
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
    local color="${2:-}"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$ts] $msg" | tee -a "$LOG_FILE"
}

log "Starting VS Code Link Updater..." "cyan"

# -----------------------------
# Detect installed VS Code folders
# -----------------------------
INSTALLED_FOLDERS=()
while IFS= read -r -d $'\0' folder; do
    INSTALLED_FOLDERS+=("$folder")
done < <(find "$BASE_PATH" -maxdepth 1 -type d -name "vscode-*-*" -print0)

if [[ ${#INSTALLED_FOLDERS[@]} -eq 0 ]]; then
    log "No VS Code installations found in $BASE_PATH" "red"
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
    if [[ "$foldername" =~ ^vscode-([^-\ ]+)-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        ch="${BASH_REMATCH[1]}"
        ver="${BASH_REMATCH[2]}"
        CHANNELS["$ch"]+="$folder:$ver "
    fi
done

# -----------------------------
# Determine chosen version
# -----------------------------
CHOSEN_CHANNEL=""
CHOSEN_VERSION=""
CHOSEN_PATH=""
# -----------------------------
# Choose version (priority: stable > insider)
# -----------------------------

# Function to pick the latest version from a channel string "path:ver path:ver ..."
pick_latest_version() {
    local entries=($1)
    local latest_ver="0.0.0"
    local latest_path=""
    for entry in "${entries[@]}"; do
        IFS=':' read -r path ver <<< "$entry"
        if [[ "$(printf '%s\n' "$ver" "$latest_ver" | sort -V | tail -n1)" == "$ver" ]]; then
            latest_ver="$ver"
            latest_path="$path"
        fi
    done
    echo "$latest_path:$latest_ver"
}

# Check for targetVersion first
if [[ -n "$TARGET_VERSION" ]]; then
    for folder in "${INSTALLED_FOLDERS[@]}"; do
        if [[ "$folder" =~ $TARGET_VERSION$ ]]; then
            foldername="$(basename "$folder")"
            if [[ "$foldername" =~ ^vscode-([^-\ ]+)-([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
                CHOSEN_CHANNEL="${BASH_REMATCH[1]}"
                CHOSEN_VERSION="${BASH_REMATCH[2]}"
                CHOSEN_PATH="$folder"
                log "Using targetVersion from config: $CHOSEN_VERSION ($CHOSEN_CHANNEL)" "green"
                break
            fi
        fi
    done
    if [[ -z "$CHOSEN_PATH" ]]; then
        log "Target version $TARGET_VERSION not found. Falling back to latest available." "yellow"
    fi
fi

# Pick latest if targetVersion not set or not found
if [[ -z "$CHOSEN_PATH" ]]; then
    if [[ -n "${CHANNELS["stable"]}" ]]; then
        read CHOSEN_PATH CHOSEN_VERSION <<< $(pick_latest_version "${CHANNELS["stable"]}")
        CHOSEN_CHANNEL="stable"
        log "Selected latest stable version: $CHOSEN_VERSION" "green"
    elif [[ -n "${CHANNELS["insider"]}" ]]; then
        read CHOSEN_PATH CHOSEN_VERSION <<< $(pick_latest_version "${CHANNELS["insider"]}")
        CHOSEN_CHANNEL="insider"
        log "Stable not found; selected latest insider version: $CHOSEN_VERSION" "green"
    else
        # fallback: pick first installed
        CHOSEN_PATH="${INSTALLED_FOLDERS[0]}"
        foldername="$(basename "$CHOSEN_PATH")"
        CHOSEN_CHANNEL="${foldername%-*}"
        CHOSEN_VERSION="${foldername##*-}"
        log "Using fallback version: $CHOSEN_VERSION ($CHOSEN_CHANNEL)" "green"
    fi
fi

if [[ -z "$CHOSEN_PATH" ]]; then
    log "Could not determine version to link." "red"
    exit 1
fi

# -----------------------------
# Update launch-vscode.sh
# -----------------------------
LAUNCHER_FILE="$BASE_PATH/launch-vscode.sh"

cat > "$LAUNCHER_FILE" << EOF
#!/usr/bin/env bash
"$(realpath "$CHOSEN_PATH/Code")" --user-data-dir="$DATA_FOLDER" "\$@"
EOF

chmod +x "$LAUNCHER_FILE"
log "Updated launcher -> $CHOSEN_CHANNEL $CHOSEN_VERSION" "green"

# -----------------------------
# Finished
# -----------------------------
log "Link updater finished successfully using $CHOSEN_CHANNEL $CHOSEN_VERSION" "green"
