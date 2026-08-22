#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./download_systems.sh systems.txt
#
# Example systems.txt:
#   esr
#   thermostat
#   collector

REPO_BASE="https://raw.githubusercontent.com/sdoque/rpiExec/main"

SYSTEMS_FILE="${1:-systems.txt}"

if [[ ! -f "$SYSTEMS_FILE" ]]; then
    echo "Error: systems file '$SYSTEMS_FILE' not found."
    exit 1
fi

# Pick downloader: curl preferred, fallback to wget
download_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$output" "$url"
    else
        echo "Error: neither curl nor wget is installed."
        exit 1
    fi
}

echo "Using systems list: $SYSTEMS_FILE"
echo

while IFS= read -r system || [[ -n "$system" ]]; do
    # Trim whitespace
    system="$(echo "$system" | xargs)"

    # Skip empty lines and comments
    [[ -z "$system" ]] && continue
    [[ "${system:0:1}" == "#" ]] && continue

    exe_name="${system}_rpi64"
    system_dir="$system"
    exe_url="${REPO_BASE}/${system}/${exe_name}"
    readme_url="${REPO_BASE}/README.md"

    echo "Processing system: $system"

    mkdir -p "$system_dir"

    echo "  Downloading executable: $exe_name"
    if download_file "$exe_url" "${system_dir}/${exe_name}"; then
        chmod +x "${system_dir}/${exe_name}"
        echo "  Executable saved to ${system_dir}/${exe_name}"
    else
        echo "  Warning: failed to download ${exe_url}"
        continue
    fi

    echo "  Downloading README.md"
    if download_file "$readme_url" "${system_dir}/README.md"; then
        echo "  README saved to ${system_dir}/README.md"
    else
        echo "  Warning: failed to download README.md"
    fi

    echo
done < "$SYSTEMS_FILE"

echo "Done."