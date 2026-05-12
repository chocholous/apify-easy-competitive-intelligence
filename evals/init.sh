#!/bin/bash
# Inject competitive-intel plugin into agent workspace
set -e

WORKSPACE=$(find /tmp -type d -name "eval-workspace-*" 2>/dev/null | head -1)
if [ -z "$WORKSPACE" ]; then
  echo "ERROR: eval workspace not found"
  exit 1
fi

cd "$WORKSPACE"

git clone --depth 1 https://github.com/chocholous/apify-easy-competitive-intelligence.git _skill

# Copy entire plugin structure so Claude Code auto-detects it
cp -r _skill/.claude-plugin .claude-plugin
cp -r _skill/skills skills

rm -rf _skill

echo "Plugin injected:"
find .claude-plugin skills -type f
