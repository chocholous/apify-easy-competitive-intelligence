#!/usr/bin/env zsh
# Run eval scenarios via Apify API with parallel batches.
# Usage: ./run-all-api.sh [PARALLEL=3]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
fi

if [[ -z "${APIFY_TOKEN:-}" ]] || [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    echo "Error: APIFY_TOKEN and CLAUDE_CODE_OAUTH_TOKEN must be set in .env"
    exit 1
fi

ACTOR_ID="pavel242242~agent-evals-runner"
API_BASE="https://api.apify.com/v2"
PARALLEL="${1:-3}"
TIMEOUT=1800
MEMORY=1024

SCENARIOS=(
    competitor-snapshot.json
    competitor-snapshot-timed.json
    review-intelligence.json
    review-intelligence-timed.json
    pricing-deep-dive.json
    pricing-deep-dive-timed.json
    hiring-signals.json
    hiring-signals-timed.json
)

resolve_env() {
    python3 -c "
import os, re, sys
text = sys.stdin.read()
def replace_env(m):
    return os.environ.get(m.group(1), m.group(0))
text = re.sub(r'\\\$\{(\w+)\}', replace_env, text)
sys.stdout.write(text)
"
}

SUMMARY_FILE="$RESULTS_DIR/summary.json"
echo '[]' > "$SUMMARY_FILE"

# Collect results for a finished run
collect_results() {
    local NAME="$1" RUN_ID="$2"
    local STATUS_RESPONSE
    STATUS_RESPONSE=$(curl -s "$API_BASE/actor-runs/$RUN_ID?token=$APIFY_TOKEN")
    local STATUS=$(echo "$STATUS_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)

    echo "$STATUS_RESPONSE" | python3 -m json.tool > "$RESULTS_DIR/$NAME-run.json" 2>/dev/null

    local DATASET_ID=$(echo "$STATUS_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['defaultDatasetId'])" 2>/dev/null)
    if [[ -n "$DATASET_ID" ]]; then
        curl -s "$API_BASE/datasets/$DATASET_ID/items?token=$APIFY_TOKEN" | \
            python3 -m json.tool > "$RESULTS_DIR/$NAME-result.json" 2>/dev/null
    fi

    local KVS_ID=$(echo "$STATUS_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['defaultKeyValueStoreId'])" 2>/dev/null)
    if [[ -n "$KVS_ID" ]]; then
        for key in eval-checkpoint eval-check-results OUTPUT; do
            curl -s "$API_BASE/key-value-stores/$KVS_ID/records/$key?token=$APIFY_TOKEN" > "/tmp/kvs-$NAME-$key.json" 2>/dev/null
            if [[ -s "/tmp/kvs-$NAME-$key.json" ]] && python3 -c "import json; json.load(open('/tmp/kvs-$NAME-$key.json'))" 2>/dev/null; then
                cp "/tmp/kvs-$NAME-$key.json" "$RESULTS_DIR/$NAME-$key.json"
            fi
        done
    fi

    python3 -c "
import json, fcntl
with open('$SUMMARY_FILE', 'r+') as f:
    fcntl.flock(f, fcntl.LOCK_EX)
    summary = json.load(f)
    run = json.load(open('$RESULTS_DIR/$NAME-run.json'))['data']
    summary.append({
        'scenario': '$NAME',
        'status': run['status'],
        'runId': run['id'],
        'runtime_secs': run.get('stats', {}).get('runTimeSecs', 0),
        'cost_usd': run.get('usageTotalUsd', 0),
        'memPeakMb': run.get('stats', {}).get('memMaxBytes', 0) / 1024 / 1024,
        'datasetId': run.get('defaultDatasetId', ''),
        'kvsId': run.get('defaultKeyValueStoreId', '')
    })
    f.seek(0); f.truncate()
    json.dump(summary, f, indent=2)
    fcntl.flock(f, fcntl.LOCK_UN)
"
    echo "DONE: $NAME → $STATUS"
}

# Run a single scenario: start, poll, collect
run_scenario() {
    local SCENARIO="$1"
    local INPUT_FILE="$SCRIPT_DIR/$SCENARIO"
    local NAME="${SCENARIO%.json}"

    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "SKIP: $INPUT_FILE not found"
        return
    fi

    echo "START: $NAME (timeout=${TIMEOUT}s, mem=${MEMORY}MB) at $(date '+%H:%M:%S')"

    local RESOLVED=$(cat "$INPUT_FILE" | resolve_env)
    local RUN_RESPONSE=$(curl -s -X POST \
        "$API_BASE/acts/$ACTOR_ID/runs?token=$APIFY_TOKEN&timeout=$TIMEOUT&memory=$MEMORY" \
        -H "Content-Type: application/json" \
        -d "$RESOLVED")

    local RUN_ID=$(echo "$RUN_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['id'])" 2>/dev/null)

    if [[ -z "$RUN_ID" ]]; then
        echo "ERROR: $NAME — failed to start"
        return
    fi

    echo "RUNNING: $NAME → $RUN_ID"

    while true; do
        sleep 30
        local STATUS=$(curl -s "$API_BASE/actor-runs/$RUN_ID?token=$APIFY_TOKEN" | \
            python3 -c "import json,sys; print(json.load(sys.stdin)['data']['status'])" 2>/dev/null)
        case "$STATUS" in
            SUCCEEDED|FAILED|TIMED-OUT|ABORTED)
                echo "FINISHED: $NAME → $STATUS at $(date '+%H:%M:%S')"
                collect_results "$NAME" "$RUN_ID"
                return
                ;;
            *)
                local LOG_INFO=$(curl -s "$API_BASE/actor-runs/$RUN_ID/log?token=$APIFY_TOKEN" | tail -1 | grep -oE '\[turn [0-9]+\].*' | head -1)
                local RUNTIME=$(curl -s "$API_BASE/actor-runs/$RUN_ID?token=$APIFY_TOKEN" | python3 -c "import json,sys; print(f'{json.load(sys.stdin)[\"data\"].get(\"stats\",{}).get(\"runTimeSecs\",0):.0f}s')" 2>/dev/null)
                echo "POLL: $NAME ${RUNTIME} ${LOG_INFO}"
                ;;
        esac
    done
}

echo "=========================================="
echo "Running ${#SCENARIOS[@]} scenarios, ${PARALLEL} parallel, timeout=${TIMEOUT}s, mem=${MEMORY}MB"
echo "Time: $(date '+%H:%M:%S')"
echo "=========================================="

# Process in batches of PARALLEL
for ((i = 0; i < ${#SCENARIOS[@]}; i += PARALLEL)); do
    BATCH=("${SCENARIOS[@]:$i:$PARALLEL}")
    echo ""
    echo "--- Batch $((i / PARALLEL + 1)): ${BATCH[*]} ---"

    PIDS=()
    for scenario in "${BATCH[@]}"; do
        run_scenario "$scenario" &
        PIDS+=($!)
    done

    for pid in "${PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    echo "--- Batch $((i / PARALLEL + 1)) complete ---"
done

echo ""
echo "=========================================="
echo "ALL DONE at $(date '+%H:%M:%S')"
echo "=========================================="
python3 -c "
import json
summary = json.load(open('$SUMMARY_FILE'))
total_cost = sum(s['cost_usd'] for s in summary)
total_time = sum(s['runtime_secs'] for s in summary)
print(f'Total: {len(summary)} runs, \${total_cost:.2f}, {total_time:.0f}s wall-clock')
print()
for s in summary:
    mem = s.get('memPeakMb', 0)
    print(f\"  {s['scenario']:40s} {s['status']:10s} \${s['cost_usd']:.2f}  {s['runtime_secs']:.0f}s  {mem:.0f}MB\")
"
