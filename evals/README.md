# Eval Scenarios

E2E testy competitive intelligence skillu přes [apify-evals runner](https://console.apify.com/actors/8HNZVMFvg1S4E71KG) actor.

## Jak to funguje

1. **Init script** (`initBashScript` v JSON) klonuje toto repo a nakopíruje plugin (`.claude-plugin/` + `skills/`) do eval workspace
2. **Runner auto-detekuje** `.claude-plugin/plugin.json` a předá `--plugin-dir` Claude Code CLI
3. **Agent** vidí skill jako normální plugin, může ho invokovat přes `Skill` tool
4. **Checkpointy** ověří výstup — deterministické (contains, regex, script) + LLM judge

## Setup

```bash
cp .env.example .env
# Doplň tokeny:
#   APIFY_TOKEN        — Apify API token (pro actor calls)
#   CLAUDE_CODE_OAUTH_TOKEN — z `claude setup-token` (platí 1 rok)
```

## Spuštění

```bash
# Jeden test
./run.sh pricing-deep-dive.json

# Nebo přímo přes apify CLI
apify call pavel242242/agent-evals-runner -f <(./resolve.sh pricing-deep-dive.json)
```

## Scénáře

| Soubor | Co testuje | Budget | Turns |
|--------|-----------|--------|-------|
| `competitor-snapshot.json` | Snapshot Oxylabs — SWOT, positioning, pricing | $5 | 30 |
| `review-intelligence.json` | Sentiment Bright Data — G2, Capterra, Reddit | $5 | 30 |
| `pricing-deep-dive.json` | Pricing Apify vs ScrapingBee vs Crawlbase | $5 | 30 |
| `hiring-signals.json` | Hiring Bright Data — LinkedIn jobs, strategy | $5 | 30 |
| `non-ci-query.json` | Corner case: Python kód, skill se nesmí triggerovat | $0.50 | 5 |

## Auth v actoru

Claude Code v Docker kontejneru potřebuje `CLAUDE_CODE_OAUTH_TOKEN` (long-lived, z `claude setup-token`).

Kritické env vars v `envVariables`:
- `CLAUDE_CODE_OAUTH_TOKEN` — povinný
- `CLAUDE_CODE=0` — povinný (jinak OAuth nefunguje)
- `APIFY_TOKEN` — povinný (pro `apify actors call`)
- `ANTHROPIC_API_KEY` — **nesmí být nastaven** (ani prázdný string — přebíjí OAuth)

## Jak se plugin dostane k agentovi

Init script v každém JSON inputu:
```bash
git clone --depth 1 https://github.com/chocholous/apify-easy-competitive-intelligence.git _plugin
cp -r _plugin/.claude-plugin .claude-plugin
cp -r _plugin/skills skills
rm -rf _plugin
```

Runner po init scriptu automaticky detekuje `.claude-plugin/plugin.json` v workspace a přidá `--plugin-dir <workspace>` k Claude Code CLI. Agent pak vidí skill v seznamu dostupných skills.
