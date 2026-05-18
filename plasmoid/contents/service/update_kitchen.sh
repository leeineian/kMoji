#!/usr/bin/env bash
# ==============================================================================
# update_kitchen.sh
#
# Description:
#   Downloads the latest Emoji Kitchen metadata, optimizes it by removing
#   redundant fields, and generates kitchen-metadata.js.
#
# Requirements:
#   - curl
#   - jq
#   - date
# ==============================================================================

set -euo pipefail

# Logging helpers
_log() { echo "[$(date +"%H:%M:%S")] $*"; }
_err() { echo "[$(date +"%H:%M:%S")] Error: $*" >&2; }

# Configuration
URL="https://emojikitchen.dev/metadata.json"
SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$(cd "$SERVICE_DIR/../assets" && pwd)"
JS_FILE_PATH="$ASSETS_DIR/kitchen-metadata.js"

# Dependency Checks
for cmd in curl jq date; do
  if ! command -v "$cmd" >/dev/null; then
    _err "$cmd is required but not installed."
    exit 1
  fi
done

_log "Downloading Emoji Kitchen metadata (approx 10MB)..."

# We download and process in one pipe to avoid large temp files
# Structure is .data["base"].combinations["other"] = [ { date, ... } ]
if ! curl -sSL "$URL" | jq -c '
  .data | to_entries | map({
    key: .key,
    value: .value.combinations | to_entries | map({
      e: .key,
      d: (.value | map(select(.isLatest == true)) | .[0].date // .value[0].date)
    })
  }) | from_entries
' > "$ASSETS_DIR/kitchen-metadata.json"; then
  _err "Failed to download or process Emoji Kitchen metadata."
  exit 2
fi

# Wrap in a JS constant for easy QML import
echo "const kitchenMetadata = $(cat "$ASSETS_DIR/kitchen-metadata.json")" > "$JS_FILE_PATH"
rm "$ASSETS_DIR/kitchen-metadata.json"

_log "Optimization complete: $JS_FILE_PATH"
