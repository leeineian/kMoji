#!/usr/bin/env bash
# ==============================================================================
# emoji_metadata.sh
#
# Description:
#   1. Downloads the latest emoji-test.txt from Unicode, parses it to extract
#      fully-qualified emojis (excluding the Component group), and generates
#      emoji-list.js in the assets directory.
#   2. Downloads the latest Emoji Kitchen metadata from emojikitchen.dev,
#      optimizes it by removing redundant fields, and generates kitchen-metadata.js.
#
# Requirements:
#   - curl
#   - awk
#   - jq
#   - date
#
# Usage:
#   bash emoji_metadata.sh
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Logging helpers
_log() { echo "[$(date +"%H:%M:%S")] $*" >&2; }
_err() { echo "[$(date +"%H:%M:%S")] Error: $*" >&2; }

# ==============================================================================
# Configuration
# ==============================================================================
EMOJI_URL="https://unicode.org/Public/emoji/latest/emoji-test.txt"
KITCHEN_URL="https://emojikitchen.dev/metadata.json"

SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$(cd "$SERVICE_DIR/../assets" && pwd)"

RAW_FILE_PATH="$(mktemp)"
JS_FILE_PATH="$ASSETS_DIR/emoji-list.js"
KITCHEN_JS_FILE_PATH="$ASSETS_DIR/kitchen-metadata.js"

trap 'rm -f "$RAW_FILE_PATH"' EXIT

# ==============================================================================
# Dependency Checks
# ==============================================================================
for cmd in curl awk jq date; do
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
# 1. Update Emoji List
# ==============================================================================
_log "Downloading emoji data from Unicode..."

if ! curl --compressed -fsSL "$EMOJI_URL" -o "$RAW_FILE_PATH"; then
  _err "Failed to download emoji data."
  exit 2
fi

_log "Unicode download complete."

# Checksum Calculation
checksum="unknown"
if command -v sha256sum >/dev/null; then
  checksum=$(sha256sum "$RAW_FILE_PATH" | awk '{print $1}')
elif command -v shasum >/dev/null; then
  checksum=$(shasum -a 256 "$RAW_FILE_PATH" | awk '{print $1}')
elif command -v openssl >/dev/null; then
  checksum=$(openssl dgst -sha256 "$RAW_FILE_PATH" | awk '{print $NF}')
fi

_log "SHA256: ${checksum:0:12}..."
_log "Building emoji list..."

DATE_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HEADER="// Generated from: $EMOJI_URL\n// Generated on: $DATE_ISO\n// SHA256: $checksum\n\nconst emojiList = "

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
      idx = index($0, "#");
      if (idx == 0) next;

      rest = substr($0, idx + 2);
      n = split(rest, parts, " ");

      if (n >= 2) {
        emoji = parts[1];

        if (parts[2] ~ /^E[0-9.]+$/) {
          name_start = 3;
        } else {
          name_start = 2;
        }

        name = "";
        for (i = name_start; i <= n; i++) {
          name = (name == "" ? "" : name " ") parts[i];
        }

        alias = tolower(name);
        gsub(/[ -]/, "_", alias);
        gsub(/[:.]/, "", alias);
        gsub(/^[^a-z0-9]+|[^a-z0-9]+$/, "", alias);

        gsub(/\\/, "\\\\\\\\", name);
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

_log "Emoji list updated: $JS_FILE_PATH"

# ==============================================================================
# 2. Update Emoji Kitchen Metadata
# ==============================================================================
_log "Downloading Emoji Kitchen metadata (approx 10MB)..."

if ! curl -sSL "$KITCHEN_URL" | jq -c '
  .data | to_entries | map({
    key: .key,
    value: .value.combinations | to_entries | map({
      e: .key,
      d: (.value | map(select(.isLatest == true)) | .[0].date // .value[0].date)
    })
  }) | from_entries
' > "$ASSETS_DIR/kitchen-metadata.json"; then
  _err "Failed to download or process Emoji Kitchen metadata."
  exit 4
fi

_log "Optimization complete: $KITCHEN_JS_FILE_PATH"

# Wrap in a JS constant for easy QML import
echo "const kitchenMetadata = $(cat "$ASSETS_DIR/kitchen-metadata.json")" > "$KITCHEN_JS_FILE_PATH"
rm "$ASSETS_DIR/kitchen-metadata.json"

_log "Emoji Kitchen metadata updated: $KITCHEN_JS_FILE_PATH"
_log "All metadata updates completed successfully!"
