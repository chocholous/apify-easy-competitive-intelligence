#!/bin/bash
# Inject competitive-intel skill into agent workspace as CLAUDE.md + references
set -e

WORKSPACE=$(find /tmp -type d -name "eval-workspace-*" 2>/dev/null | head -1)
if [ -z "$WORKSPACE" ]; then
  echo "ERROR: eval workspace not found"
  exit 1
fi

cd "$WORKSPACE"

git clone --depth 1 https://github.com/chocholous/apify-easy-competitive-intelligence.git _skill

# CLAUDE.md = SKILL.md so the agent picks it up automatically
cp _skill/skills/apify-easy-competitive-intelligence/SKILL.md CLAUDE.md
cp -r _skill/skills/apify-easy-competitive-intelligence/reference reference

rm -rf _skill

echo "Skill injected: CLAUDE.md + references/"
ls -la CLAUDE.md references/
