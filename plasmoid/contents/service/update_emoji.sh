#!/usr/bin/env bash
# ==============================================================================
# update_emoji.sh
#
# Description:
#   Downloads the latest emoji-test.txt from Unicode, parses it to extract
#   fully-qualified emojis (excluding the Component group), and generates
#   emoji-list.js in the assets directory.
#
# Requirements:
#   - curl
#   - awk
#   - date
#
# Usage:
#   bash update_emoji.sh
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Logging helpers
_log() { echo "[$(date +"%H:%M:%S")] $*"; }
_err() { echo "[$(date +"%H:%M:%S")] Error: $*" >&2; }

# ==============================================================================
# Configuration
# ==============================================================================
URL="https://unicode.org/Public/emoji/latest/emoji-test.txt"
SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$(cd "$SERVICE_DIR/../assets" && pwd)"

RAW_FILE_PATH="$(mktemp)"
JS_FILE_PATH="$ASSETS_DIR/emoji-list.js"

trap 'rm -f "$RAW_FILE_PATH"' EXIT

# ==============================================================================
# Dependency Checks
# ==============================================================================
for cmd in curl awk date; do
  if ! command -v "$cmd" >/dev/null; then
    _err "$cmd is required but not installed."
    exit 1
  fi
done

if [ ! -d "$ASSETS_DIR" ]; then
  _err "Assets directory not found: $ASSETS_DIR"
  exit 1
fi

if [ ! -w "$ASSETS_DIR" ]; then
  _err "Assets directory is not writable: $ASSETS_DIR"
  exit 3
fi

# ==============================================================================
# Download
# ==============================================================================
_log "Downloading emoji data from Unicode..."

if ! curl --compressed -fsSL "$URL" -o "$RAW_FILE_PATH"; then
  _err "Failed to download emoji data."
  exit 2
fi

_log "Download complete."

# ==============================================================================
# Checksum Calculation
# ==============================================================================
checksum="unknown"

if command -v sha256sum >/dev/null; then
  checksum=$(sha256sum "$RAW_FILE_PATH" | awk '{print $1}')
elif command -v shasum >/dev/null; then
  checksum=$(shasum -a 256 "$RAW_FILE_PATH" | awk '{print $1}')
elif command -v openssl >/dev/null; then
  checksum=$(openssl dgst -sha256 "$RAW_FILE_PATH" | awk '{print $NF}')
fi

_log "SHA256: ${checksum:0:12}..."

# ==============================================================================
# Parse and Generate JS
# ==============================================================================
_log "Building emoji list..."

DATE_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HEADER="// Generated from: $URL\n// Generated on: $DATE_ISO\n// SHA256: $checksum\n\nconst emojiList = "

printf "%b" "$HEADER" > "$JS_FILE_PATH"

awk \
  '
  BEGIN {
    group = "";
    skip = 0;
    first_group = 1;
    printf "{";
  }

  # Handle Group Headers
  /^# group:/ {
    # Extract group name: "# group: Smileys & Emotion" -> "Smileys & Emotion"
    # index($0, ":") finds the colon. + 2 skips ": "
    g = substr($0, index($0, ":") + 2);
    
    if (g == "Component") {
      skip = 1;
      group = "";
    } else {
      if (!first_group) printf "],"; else first_group = 0;
      group = g;
      skip = 0;
      printf "\"%s\":[", group;
      first = 1;
    }
    next;
  }

  # Skip empty lines and comments that are not group headers
  /^$/ { next; }
  /^#/ { next; }

  # Process Emoji Lines
  {
    if (skip || group == "") next;

    if ($0 ~ /; fully-qualified/) {
      # Line format:
      # 1F600 ; fully-qualified     # 😀 E1.0 grinning face
      
      # Find the comment start #
      idx = index($0, "#");
      if (idx == 0) next;

      # content after "# " is "😀 E1.0 grinning face"
      rest = substr($0, idx + 2);

      # Robust parsing: split by whitespace.
      # Field 1 is emoji. Field 2 might be version (E1.0). Rest is name.
      n = split(rest, parts, " ");

      if (n >= 2) {
        emoji = parts[1];

        # Determine where the name starts
        # Check if parts[2] looks like a version (E1.0, E12.1, etc.)
        if (parts[2] ~ /^E[0-9.]+$/) {
          name_start = 3;
        } else {
          name_start = 2;
        }

        # Reconstruct name
        name = "";
        for (i = name_start; i <= n; i++) {
          name = (name == "" ? "" : name " ") parts[i];
        }

        # Generate Alias
        alias = tolower(name);
        gsub(/[ -]/, "_", alias);
        gsub(/[:.]/, "", alias);
        # Remove non-alphanumeric characters from start and end
        gsub(/^[^a-z0-9]+|[^a-z0-9]+$/, "", alias);

        # Escape for JSON (backslashes first, then quotes)
        # Note: In awk strings, we need 8 backslashes to get 2 in output (for JSON \\)
        gsub(/\\/, "\\\\\\\\", name);
        # And 3 backslashes to get \" in output (for JSON \")
        gsub(/"/, "\\\"", name);

        if (!first) printf ",";
        first = 0;

        printf "{\"emoji\":\"%s\",\"name\":\"%s\",\"aliases\":[\"%s\"]}", emoji, name, alias;
      }
    }
  }

  END {
    if (group != "") printf "]";
    print "}"
  }
' "$RAW_FILE_PATH" >> "$JS_FILE_PATH"

# ==============================================================================
# Cleanup
# ==============================================================================

_log "Emoji list updated."
