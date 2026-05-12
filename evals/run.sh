#!/usr/bin/env bash
# Run a single eval scenario against apify-evals actor.
# Usage: ./run.sh competitor-snapshot.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <scenario.json>"
    echo "Available scenarios:"
    ls "$SCRIPT_DIR"/*.json 2>/dev/null | xargs -n1 basename
    exit 1
fi

INPUT_FILE="$SCRIPT_DIR/$1"
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found"
    exit 1
fi

# Load .env if present
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# Check required tokens
if [ -z "${APIFY_TOKEN:-}" ] || [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "Error: APIFY_TOKEN and CLAUDE_CODE_OAUTH_TOKEN must be set."
    echo "Copy .env.example to .env and fill in your tokens."
    exit 1
fi

# Substitute ${VAR} placeholders in JSON with actual env values
RESOLVED=$(python3 -c "
import json, os, re, sys
with open('$INPUT_FILE') as f:
    text = f.read()
def replace_env(m):
    return os.environ.get(m.group(1), m.group(0))
text = re.sub(r'\\\$\{(\w+)\}', replace_env, text)
sys.stdout.write(text)
")

echo "$RESOLVED" | apify call pavel242242/agent-evals-runner -f -
