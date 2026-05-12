#!/bin/bash
# Inject competitive-intel plugin into agent workspace + user plugins dir
set -e

WORKSPACE=$(find /tmp -type d -name "eval-workspace-*" 2>/dev/null | head -1)
if [ -z "$WORKSPACE" ]; then
  echo "ERROR: eval workspace not found"
  exit 1
fi

cd "$WORKSPACE"

git clone --depth 1 https://github.com/chocholous/apify-easy-competitive-intelligence.git _plugin

# Copy into workspace (for CLAUDE.md/reference access)
cp -r _plugin/.claude-plugin .claude-plugin
cp -r _plugin/skills skills

# Also register as user-scope plugin so Claude Code discovers it
PLUGIN_DIR="$HOME/.claude/plugins/local/competitive-intel"
mkdir -p "$PLUGIN_DIR"
cp -r _plugin/.claude-plugin "$PLUGIN_DIR/"
cp -r _plugin/skills "$PLUGIN_DIR/"

rm -rf _plugin

echo "Plugin injected into workspace + $PLUGIN_DIR"
find .claude-plugin skills -type f
