#!/usr/bin/env bash
set -u
set -o pipefail

REPO_BASE="${REPO_BASE:-https://staff.www.ltu.se/~deventer/rpiExec}"
SYSTEMS_FILE="${1:-systems.txt}"
LOG_FILE="download_errors.log"

# Clear log at start
: > "$LOG_FILE"

if [[ ! -f "$SYSTEMS_FILE" ]]; then
    echo "Error: systems file '$SYSTEMS_FILE' not found."
    exit 1
fi

download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$output" "$url"
    else
        echo "Error: neither curl nor wget is installed." | tee -a "$LOG_FILE"
        return 1
    fi
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

echo "Using systems list: $SYSTEMS_FILE"
echo

while IFS= read -r system || [[ -n "$system" ]]; do
    # Trim leading/trailing whitespace
    system="$(echo "$system" | xargs)"

    # Skip blanks and comments
    [[ -z "$system" ]] && continue
    [[ "${system:0:1}" == "#" ]] && continue

    system_dir="$system"
    exe_name="${system}_rpi64"
    exe_url="${REPO_BASE}/${system}/${exe_name}"
    readme_url="${REPO_BASE}/${system}/README.md"

    tmp_exe="$(mktemp)"
    tmp_readme="$(mktemp)"

    echo "Processing: $system"

    mkdir -p "$system_dir" || {
        echo "  Failed to create directory: $system_dir"
        log_error "Failed to create directory '$system_dir'"
        rm -f "$tmp_exe" "$tmp_readme"
        continue
    }

    # Download executable to temp file first
    echo "  Downloading executable..."
    if download_file "$exe_url" "$tmp_exe"; then
        if [[ -f "${system_dir}/${exe_name}" ]]; then
            rm -f "${system_dir}/${exe_name}" || {
                echo "  Failed to remove old executable"
                log_error "Failed to remove old executable '${system_dir}/${exe_name}'"
                rm -f "$tmp_exe" "$tmp_readme"
                continue
            }
        fi

        mv "$tmp_exe" "${system_dir}/${exe_name}" || {
            echo "  Failed to install new executable"
            log_error "Failed to move new executable into '${system_dir}/${exe_name}'"
            rm -f "$tmp_exe" "$tmp_readme"
            continue
        }

        chmod +x "${system_dir}/${exe_name}" || {
            echo "  Failed to make executable"
            log_error "Failed to chmod +x '${system_dir}/${exe_name}'"
        }

        echo "  Installed ${system_dir}/${exe_name}"
    else
        echo "  Failed to download executable"
        log_error "Failed to download executable from '$exe_url'"
        rm -f "$tmp_exe" "$tmp_readme"
        continue
    fi

    # Download README to temp file and replace only if changed
    echo "  Checking README.md..."
    if download_file "$readme_url" "$tmp_readme"; then
        if [[ -f "${system_dir}/README.md" ]]; then
            if cmp -s "$tmp_readme" "${system_dir}/README.md"; then
                echo "  README.md unchanged"
                rm -f "$tmp_readme"
            else
                mv "$tmp_readme" "${system_dir}/README.md" || {
                    echo "  Failed to update README.md"
                    log_error "Failed to update README.md in '$system_dir'"
                }
                echo "  README.md updated"
            fi
        else
            mv "$tmp_readme" "${system_dir}/README.md" || {
                echo "  Failed to install README.md"
                log_error "Failed to install README.md in '$system_dir'"
            }
            echo "  README.md installed"
        fi
    else
        echo "  Failed to download README.md"
        log_error "Failed to download README.md from '$readme_url'"
        rm -f "$tmp_readme"
    fi

    echo
done < "$SYSTEMS_FILE"

echo "Finished."
if [[ -s "$LOG_FILE" ]]; then
    echo "Some errors occurred. See: $LOG_FILE"
else
    echo "No errors logged."
fi