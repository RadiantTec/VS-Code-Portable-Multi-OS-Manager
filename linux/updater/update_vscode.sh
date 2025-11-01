#!/usr/bin/env bash
# ============================================
# VS Code Portable Updater / Version Manager (Linux)
# ============================================

# -----------------------------
# Load configuration
# -----------------------------
CONFIG_FILE="$(dirname "$0")/config.txt"
declare -A config

if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        [[ -n "$key" ]] && config["$key"]="$value"
    done < "$CONFIG_FILE"
fi

BASE_PATH="${config[basePath]:-$(dirname "$0")/..}"
CHANNEL="${config[channel]:-stable}"
ARCH="${config[arch]:-linux-x64}"
MAX_VERSIONS="${config[maxVersionsToKeep]:-0}"
DEFAULT_VERSION="${config[defaultVersion]:-}"
CHECK_SHA="${config[check_sha]:-false}"
AUTO_UPDATE="${config[auto_check_for_update]:-false}"

DATA_FOLDER="$BASE_PATH/data"
LOG_FILE="$(dirname "$0")/log.txt"

# -----------------------------
# Logging helper
# -----------------------------
log() {
    local msg="$1"
    local color="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local entry="[$timestamp] $msg"

    case "$color" in
        red) echo -e "\e[31m$entry\e[0m" ;;
        green) echo -e "\e[32m$entry\e[0m" ;;
        yellow) echo -e "\e[33m$entry\e[0m" ;;
        cyan) echo -e "\e[36m$entry\e[0m" ;;
        *) echo "$entry" ;;
    esac

    echo "$entry" >> "$LOG_FILE"
}

# -----------------------------
# User-friendly startup instructions
# -----------------------------
echo -e "\e[36m===============================================\e[0m"
echo -e "\e[36m VS Code Portable Updater / Version Manager \e[0m"
echo -e "\e[36m===============================================\e[0m"
echo ""
echo -e "\e[33mControls while downloading:\e[0m"
echo -e "  P : Pause download"
echo -e "  R : Resume download"
echo -e "  Ctrl+C : Cancel download (you can resume later)"
echo ""
read -n 1 -s -r -p "Press any key to start..."
echo ""

# -----------------------------
# Fetch SHA256 from metadata API
# -----------------------------
get_sha256() {
    local version="$1"
    log "🔍 Fetching SHA256 hash metadata for version $version"
    local url="https://update.code.visualstudio.com/api/versions/$version/$ARCH/$CHANNEL"
    local sha
    sha=$(curl -s "$url" | jq -r '.sha256hash // .hash // empty')
    if [[ -z "$sha" ]]; then
        log "❌ No SHA256 hash field found in metadata." red
        echo ""
    else
        echo "$sha"
    fi
}

# -----------------------------
# Download with pause/resume + progress
# -----------------------------
download_file() {
    local url="$1"
    local out="$2"
    local part="$out.part"

    mkdir -p "$(dirname "$out")"

    # Resume from existing partial file
    local resume=0
    if [[ -f "$part" ]]; then
        resume=$(stat -c%s "$part")
    fi

    log "⬇ Starting download from $url (resume offset $resume bytes)..."

    # Start download in background
    (
        if [[ $resume -gt 0 ]]; then
            curl -C - -L "$url" -o "$part"
        else
            curl -L "$url" -o "$part"
        fi
    ) &
    local pid=$!

    # Show progress bar
    local last_size=$resume
    local paused=false
    while kill -0 "$pid" 2>/dev/null; do
        if [[ -t 0 ]]; then
            # Check for user keypress
            read -rsn1 -t 0.2 key
            case "$key" in
                p|P)
                    if [[ "$paused" == false ]]; then
                        log "⏸ Download paused. Press R to resume." yellow
                        kill -STOP "$pid"
                        paused=true
                    fi
                    ;;
                r|R)
                    if [[ "$paused" == true ]]; then
                        log "▶️ Download resumed." green
                        kill -CONT "$pid"
                        paused=false
                    fi
                    ;;
                q|Q|$'\x03')  # Ctrl+C
                    log "⚠️ Download canceled by user. You can resume later." yellow
                    kill -KILL "$pid"
                    exit 1
                    ;;
            esac
        fi

        # Progress calculation
        if [[ -f "$part" ]]; then
            local current_size=$(stat -c%s "$part")
            local diff=$((current_size - last_size))
            local mb_diff=$(awk "BEGIN {printf \"%.2f\", $diff/1024/1024}")
            local mb_total=$(awk "BEGIN {printf \"%.2f\", $current_size/1024/1024}")
            printf "\rDownloaded: %6s MB | Increment: %6s MB" "$mb_total" "$mb_diff"
            last_size=$current_size
        fi

        sleep 0.5
    done
    wait "$pid"

    # Rename completed file
    mv -f "$part" "$out"
    log "✅ Download complete: $out" green
    echo
}

# -----------------------------
# Compute SHA256 of file
# -----------------------------
compute_sha256() {
    local file="$1"
    log "🔁 Computing SHA256 for $file"
    sha256sum "$file" | awk '{print $1}'
}

# -----------------------------
# Remove old versions
# -----------------------------
remove_old_versions() {
    local base="$1"
    local keep="$2"

    local dirs=($(ls -d "$base"/vscode-"$CHANNEL"-* 2>/dev/null | sort -r))
    local count=${#dirs[@]}
    if [[ $keep -ge $count ]]; then
        return
    fi

    local to_remove=("${dirs[@]:$keep}")
    for dir in "${to_remove[@]}"; do
        log "🧹 Removing old version: $dir"
        rm -rf "$dir"
    done
}

# -----------------------------
# Install VS Code
# -----------------------------
install_vscode() {
    local version="$1"
    local version_path="$BASE_PATH/vscode-$CHANNEL-$version"
    local zip_file="$BASE_PATH/vscode-$CHANNEL-$version.tar.gz"
    local download_url="https://update.code.visualstudio.com/$version/$ARCH/$CHANNEL"

    if [[ ! -d "$version_path" ]]; then
        log "⬇ Downloading VS Code $version ($CHANNEL)…"
        download_file "$download_url" "$zip_file"

        if [[ "$CHECK_SHA" == "true" ]]; then
            expected_sha=$(get_sha256 "$version")
            if [[ -z "$expected_sha" ]]; then
                log "❌ Expected SHA256 not found; aborting installation." red
                exit 1
            fi
            actual_sha=$(compute_sha256 "$zip_file")
            log "📊 Expected SHA256 = $expected_sha"
            log "📊 Actual   SHA256 = $actual_sha"
            if [[ "$actual_sha" != "$expected_sha" ]]; then
                log "❌ SHA256 mismatch! Aborting." red
                exit 1
            else
                log "✅ SHA256 verified." green
            fi
        fi

        mkdir -p "$version_path"
        tar -xzf "$zip_file" -C "$version_path" --strip-components=1
        rm -f "$zip_file"
        log "✅ Extracted to $version_path" green
    else
        log "✅ VS Code $version ($CHANNEL) already exists." green
    fi

    if [[ "$MAX_VERSIONS" -gt 0 ]]; then
        remove_old_versions "$BASE_PATH" "$MAX_VERSIONS"
    fi

    # Data folder
    mkdir -p "$DATA_FOLDER"
    if [[ -L "$version_path/data" || -d "$version_path/data" ]]; then
        rm -rf "$version_path/data"
    fi
    ln -s "$DATA_FOLDER" "$version_path/data"
    log "🔗 Linked data folder: $version_path/data -> $DATA_FOLDER" green

    echo "$version_path"
}

# -----------------------------
# Update launcher script
# -----------------------------
update_launcher() {
    local version_path="$1"
    local launcher="$BASE_PATH/launch-vscode.sh"
    local shortcut="$BASE_PATH/vscode.sh"

    cat > "$launcher" <<EOL
#!/usr/bin/env bash
"$version_path/Code" --user-data-dir="$DATA_FOLDER" "\$@"
EOL
    chmod +x "$launcher"
    log "✅ Launcher updated: $launcher" green

    cat > "$shortcut" <<EOL
#!/usr/bin/env bash
"$version_path/Code" --user-data-dir="$DATA_FOLDER" "\$@"
EOL
    chmod +x "$shortcut"
    log "✅ Shortcut updated: $shortcut" green
}

# -----------------------------
# Get latest VS Code version
# -----------------------------
get_latest_version() {
    local url="https://update.code.visualstudio.com/latest/$ARCH/$CHANNEL"
    local latest
    latest=$(curl -sI "$url" | grep -Fi "X-Release-Version" | awk '{print $2}' | tr -d $'\r')
    if [[ -z "$latest" ]]; then
        log "❌ Cannot get latest version." red
        exit 1
    fi
    echo "$latest"
}

# -----------------------------
# Main workflow
# -----------------------------
main() {
    if [[ "$AUTO_UPDATE" == "true" ]]; then
        latest=$(get_latest_version)
        log "🔔 Latest version available = $latest"
        installed_versions=($(ls -d "$BASE_PATH"/vscode-"$CHANNEL"-* 2>/dev/null | awk -F"-" '{print $NF}'))
        if [[ ${#installed_versions[@]} -gt 0 ]]; then
            highest_installed=$(printf '%s\n' "${installed_versions[@]}" | sort -V | tail -n1)
            log "✅ Highest installed version = $highest_installed"
            if [[ "$latest" == "$highest_installed" || "$latest" < "$highest_installed" ]]; then
                log "ℹ️ No update needed." green
                exit 0
            fi
        fi
        version_to_install="$latest"
    else
        version_to_install="${DEFAULT_VERSION:-$(get_latest_version)}"
    fi

    version_path=$(install_vscode "$version_to_install")
    update_launcher "$version_path"
    log "🎉 VS Code portable ready. Launch via launch-vscode.sh or vscode.sh" green
}

main
