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

# ==============================================================================
# Configuration
# ==============================================================================
URL="https://unicode.org/Public/emoji/latest/emoji-test.txt"
SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$(cd "$SERVICE_DIR/../assets" && pwd)"

RAW_FILE_PATH="$(mktemp)"
JS_FILE_PATH="$ASSETS_DIR/emoji-list.js"

trap 'rm -f "$RAW_FILE_PATH"' EXIT

echo "SYNC_STARTED"

# ==============================================================================
# Dependency Checks
# ==============================================================================
for cmd in curl awk date; do
  if ! command -v "$cmd" >/dev/null; then
    echo "Error: $cmd is required." >&2
    exit 1
  fi
done

if [ ! -d "$ASSETS_DIR" ]; then
  echo "Error: assets directory does not exist: $ASSETS_DIR" >&2
  exit 1
fi

# ==============================================================================
# Download
# ==============================================================================
echo "Downloading $URL to $RAW_FILE_PATH ..."

if ! curl --compressed -fsSL "$URL" -o "$RAW_FILE_PATH"; then
  echo "SYNC_NET_ERROR: failed to download $URL"
  exit 2
fi

echo "Download complete."

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

echo "SHA256 checksum: $checksum"

# ==============================================================================
# Parse and Generate JS
# ==============================================================================
echo "Parsing and generating JSON..."

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

      # Find " E<version> "
      # Regex: space + E + digits/dots + space
      match(rest, / E[0-9.]+ /);

      if (RSTART > 0) {
        # emoji is before the match
        emoji = substr(rest, 1, RSTART - 1);
        
        # name is after the match
        # RLENGTH is length of " E1.0 "
        name = substr(rest, RSTART + RLENGTH);

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

echo "Write complete."
echo "SYNC_COMPLETE"
