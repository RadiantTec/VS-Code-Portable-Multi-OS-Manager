#!/bin/bash
# ============================================
# VS Code Settings Sync Script
# ============================================
# Sync settings.json across OSes according to versions_sync configuration.
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/settings_sync_config.txt"
SYNC_DIR="$SCRIPT_DIR"
LOG_FILE="$SCRIPT_DIR/settings_sync.log"

# -----------------------------
# Logging helper
# -----------------------------
log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "$LOG_FILE"
}

# -----------------------------
# Read versions_sync from config
# -----------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Read versions_sync array
versions_sync_raw=$(grep -oP 'versions_sync\s*=\s*\[\K.*(?=\])' "$CONFIG_FILE")
IFS='],[' read -ra SYNC_PAIRS <<< "${versions_sync_raw//[\[\]]/}"

# -----------------------------
# Define OS folders
# -----------------------------
WIN_DIR="$SCRIPT_DIR/../win"
LINUX_DIR="$SCRIPT_DIR/../linux"
MAC_DIR="$SCRIPT_DIR/../mac"
DATA_SUBPATH="data/User"

# -----------------------------
# Helper to resolve source path
# -----------------------------
get_source_path() {
    local src="$1"
    local resolved=""

    case "$src" in
        self)
            if [[ -f "$SCRIPT_DIR/settings.json" ]]; then
                resolved="$SCRIPT_DIR/settings.json"
            else
                log "⚠️ Source 'self' settings.json not found in $SCRIPT_DIR. Skipping any sync from self."
                resolved=""
            fi
            ;;
        latest)
            latest_time=0
            latest_file=""
            for os in "$WIN_DIR" "$LINUX_DIR" "$MAC_DIR"; do
                if [[ -f "$os/$DATA_SUBPATH/settings.json" ]]; then
                    file_time=$(stat -c %Y "$os/$DATA_SUBPATH/settings.json" 2>/dev/null || stat -f %m "$os/$DATA_SUBPATH/settings.json")
                    if (( file_time > latest_time )); then
                        latest_time=$file_time
                        latest_file="$os/$DATA_SUBPATH/settings.json"
                    fi
                fi
            done
            # Also compare with master self if exists
            if [[ -f "$SCRIPT_DIR/settings.json" ]]; then
                file_time=$(stat -c %Y "$SCRIPT_DIR/settings.json" 2>/dev/null || stat -f %m "$SCRIPT_DIR/settings.json")
                if (( file_time > latest_time )); then
                    latest_file="$SCRIPT_DIR/settings.json"
                fi
            fi
            if [[ -z "$latest_file" ]]; then
                log "⚠️ No settings.json found for 'latest'. Skipping this sync pair."
            fi
            resolved="$latest_file"
            ;;
        win)
            resolved="$WIN_DIR/$DATA_SUBPATH/settings.json"
            ;;
        linux)
            resolved="$LINUX_DIR/$DATA_SUBPATH/settings.json"
            ;;
        mac)
            resolved="$MAC_DIR/$DATA_SUBPATH/settings.json"
            ;;
        *)
            log "⚠️ Unknown source: $src"
            resolved=""
            ;;
    esac

    echo "$resolved"
}

# -----------------------------
# Helper to resolve destination path
# -----------------------------
get_dest_path() {
    local dest="$1"

    case "$dest" in
        self)
            echo "$SCRIPT_DIR/settings.json"
            ;;
        win)
            mkdir -p "$WIN_DIR/$DATA_SUBPATH"
            echo "$WIN_DIR/$DATA_SUBPATH/settings.json"
            ;;
        linux)
            mkdir -p "$LINUX_DIR/$DATA_SUBPATH"
            echo "$LINUX_DIR/$DATA_SUBPATH/settings.json"
            ;;
        mac)
            mkdir -p "$MAC_DIR/$DATA_SUBPATH"
            echo "$MAC_DIR/$DATA_SUBPATH/settings.json"
            ;;
        *)
            log "⚠️ Unknown destination: $dest"
            echo ""
            ;;
    esac
}

# -----------------------------
# Perform sync
# -----------------------------
for pair in "${SYNC_PAIRS[@]}"; do
    IFS=',' read -r src dest <<< "$pair"
    src=$(echo "$src" | xargs)   # trim
    dest=$(echo "$dest" | xargs) # trim

    src_path=$(get_source_path "$src")
    dest_path=$(get_dest_path "$dest")

    if [[ -z "$src_path" || ! -f "$src_path" ]]; then
        log "⚠️ Skipping sync from $src to $dest because source is missing."
        continue
    fi

    if [[ -z "$dest_path" ]]; then
        log "⚠️ Destination path invalid for: $dest"
        continue
    fi

    cp -f "$src_path" "$dest_path"
    log "✅ Synced $src -> $dest ($src_path -> $dest_path)"
done

log "🎉 Settings sync completed."
