#!/bin/bash
# ============================================
# VS Code Portable Updater / Version Manager (macOS)
# ============================================

# -----------------------------
# Configuration
# -----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.txt"

BASE_PATH="$SCRIPT_DIR"
CHANNEL="stable"
ARCH="darwin-universal"
MAX_VERSIONS_KEEP=0
DEFAULT_VERSION=""
AUTO_CHECK_UPDATE=false

log_file="$SCRIPT_DIR/log.txt"

# -----------------------------
# Logging function
# -----------------------------
log() {
    local msg="$1"
    local color="${2:-gray}"

    # Map color name to tput code
    case "$color" in
        red) tput setaf 1 ;;
        green) tput setaf 2 ;;
        yellow) tput setaf 3 ;;
        cyan) tput setaf 6 ;;
        *) tput setaf 7 ;;
    esac

    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[$timestamp] $msg"
    tput sgr0

    # Append to log
    echo "[$timestamp] $msg" >> "$log_file"
}

# -----------------------------
# Read configuration
# -----------------------------
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        case "$key" in
            basePath) BASE_PATH="$value" ;;
            channel) CHANNEL="$value" ;;
            arch) ARCH="$value" ;;
            maxVersionsToKeep) MAX_VERSIONS_KEEP="$value" ;;
            defaultVersion) DEFAULT_VERSION="$value" ;;
            auto_check_for_update) AUTO_CHECK_UPDATE="$value" ;;
        esac
    done < "$CONFIG_FILE"
fi

DATA_FOLDER="$BASE_PATH/data"
mkdir -p "$DATA_FOLDER"

# -----------------------------
# User-friendly instructions
# -----------------------------
echo "==============================================="
echo " VS Code Portable Updater / Version Manager (macOS) "
echo "==============================================="
echo
echo "Controls while downloading:"
echo "  P : Pause download"
echo "  R : Resume download"
echo "  Q or Ctrl+C : Cancel download (can resume later)"
echo
read -n1 -s -r -p "Press any key to start..."
echo
# -----------------------------
# Fetch latest VS Code version
# -----------------------------
get_latest_version() {
    local channel="$1"
    local url="https://update.code.visualstudio.com/latest/$ARCH/$channel"
    local latest

    latest=$(curl -sI "$url" | grep -i "X-Release-Version" | awk '{print $2}' | tr -d $'\r')
    if [[ -z "$latest" ]]; then
        log "❌ Cannot get latest version." red
        exit 1
    fi
    echo "$latest"
}

# -----------------------------
# Compute SHA256 of file
# -----------------------------
compute_sha256() {
    local file="$1"
    shasum -a 256 "$file" | awk '{print $1}'
}

# -----------------------------
# Download file with pause/resume
# -----------------------------
download_file() {
    local url="$1"
    local out_file="$2"
    local part_file="${out_file}.part"

    local start=0
    [[ -f "$part_file" ]] && start=$(stat -f%z "$part_file")

    log "⬇ Starting download from $url (resume offset $start bytes)..."

    paused=false

    while :; do
        # Use curl with resume
        curl -C "$start" -# -o "$part_file" "$url" &
        pid=$!

        # Monitor progress and handle pause/resume
        while kill -0 "$pid" 2>/dev/null; do
            if $paused; then
                kill -STOP "$pid"
            else
                kill -CONT "$pid" 2>/dev/null
            fi

            if read -t 0.2 -n1 key; then
                case "$key" in
                    [Pp]) 
                        paused=true
                        echo -e "\n⏸ Download paused. Press R to resume."
                        ;;
                    [Rr])
                        paused=false
                        echo -e "\n▶️ Download resumed."
                        ;;
                    [Qq])
                        kill -TERM "$pid" 2>/dev/null
                        echo -e "\n❌ Download canceled. You can resume later."
                        return 1
                        ;;
                esac
            fi
        done

        wait "$pid"
        [[ $? -eq 0 ]] && break
    done

    mv "$part_file" "$out_file"
    log "✅ Download complete: $out_file" green
}

# -----------------------------
# Install VS Code
# -----------------------------
install_vscode() {
    local version="$1"
    local version_dir="$BASE_PATH/vscode-$CHANNEL-$version"
    local zip_file="$BASE_PATH/vscode-$CHANNEL-$version.zip"
    local url="https://update.code.visualstudio.com/$version/$ARCH/$CHANNEL"

    if [[ ! -d "$version_dir" ]]; then
        log "⬇ Downloading VS Code $version ($CHANNEL)…"
        download_file "$url" "$zip_file" || exit 1

        if [[ "$CHECK_SHA" == "true" ]]; then
            expected_sha=$(curl -s "https://update.code.visualstudio.com/api/versions/$version/$ARCH/$CHANNEL" | grep -Po '(?<="sha256hash":")[^"]*')
            actual_sha=$(compute_sha256 "$zip_file")
            log "📊 Expected SHA256 = $expected_sha"
            log "📊 Actual   SHA256 = $actual_sha"

            [[ "$expected_sha" != "$actual_sha" ]] && { log "❌ SHA256 mismatch! Aborting." red; exit 1; }
            log "✅ SHA256 verified." green
        fi

        log "📦 Extracting…"
        unzip -q "$zip_file" -d "$version_dir"
        rm "$zip_file"
        log "✅ Extracted to $version_dir"
    else
        log "✅ VS Code $version ($CHANNEL) already exists."
    fi

    # Cleanup old versions
    if (( MAX_VERSIONS_KEEP > 0 )); then
        versions=($(ls -1d "$BASE_PATH"/vscode-"$CHANNEL"-* 2>/dev/null | sort -r))
        if (( ${#versions[@]} > MAX_VERSIONS_KEEP )); then
            for ((i=MAX_VERSIONS_KEEP; i<${#versions[@]}; i++)); do
                log "🧹 Removing old version: ${versions[i]}"
                rm -rf "${versions[i]}"
            done
        fi
    fi

    # Link data folder
    [[ ! -d "$DATA_FOLDER" ]] && mkdir -p "$DATA_FOLDER"
    ln -sfn "$DATA_FOLDER" "$version_dir/data"

    echo "$version_dir"
}

# -----------------------------
# Update launcher
# -----------------------------
update_launcher() {
    local version_dir="$1"
    local launcher="$BASE_PATH/launch-vscode.sh"

    cat > "$launcher" <<EOF
#!/bin/bash
"$version_dir/Visual Studio Code.app/Contents/MacOS/Electron" --user-data-dir="$DATA_FOLDER"
EOF

    chmod +x "$launcher"
    log "✅ Launcher updated: $launcher"
}

# -----------------------------
# Main workflow
# -----------------------------
if $AUTO_CHECK_UPDATE; then
    latest=$(get_latest_version "$CHANNEL")
    log "🔔 Latest version available = $latest"
    installed=($(ls -1d "$BASE_PATH"/vscode-"$CHANNEL"-* 2>/dev/null | awk -F'-' '{print $NF}'))
    if (( ${#installed[@]} > 0 )); then
        highest_installed=$(printf '%s\n' "${installed[@]}" | sort -V | tail -1)
        log "✅ Highest installed version = $highest_installed"
        [[ "$latest" == "$highest_installed" ]] && { log "ℹ️ No update needed." green; exit 0; }
    fi
    version_to_install="$latest"
else
    version_to_install="${DEFAULT_VERSION:-$(get_latest_version "$CHANNEL")}"
fi

version_path=$(install_vscode "$version_to_install")
update_launcher "$version_path"

log "🎉 VS Code portable ready. Launch via launch-vscode.sh" green
