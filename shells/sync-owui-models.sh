#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────
OWUI_URL="${OWUI_URL:-https://llm.jkr.digital}"
API_KEY="${OWUI_API_KEY:-${OPENAI_API_KEY:-}}"
CONFIG="$HOME/Library/Application Support/Code/User/chatLanguageModels.json"

# Ensure config directory exists
mkdir -p "$(dirname "$CONFIG")"

# ── Fetch models from OWUI ─────────────────────────────────────────────────
fetch_models() {
    local url="$1"
    local auth=""
    [[ -n "$API_KEY" ]] && auth="-H Authorization: Bearer ${API_KEY}"

    # shellcheck disable=SC2086
    curl -sSL --fail-with-body -w "\n%{http_code}" $auth "$url" 2>/dev/null || true
}

resp=$(fetch_models "${OWUI_URL%/}/v1/models")
http_code=$(echo "$resp" | tail -n1)
body=$(echo "$resp" | sed '$d')

if [[ "$http_code" != "200" || -z "$body" ]]; then
    # fallback to OWUI native endpoint
    resp=$(fetch_models "${OWUI_URL%/}/api/models")
    http_code=$(echo "$resp" | tail -n1)
    body=$(echo "$resp" | sed '$d')
fi

if [[ "$http_code" != "200" || -z "$body" ]]; then
    echo "Error: failed to fetch models from OWUI (HTTP $http_code)" >&2
    exit 1
fi

# ── Build JSON config ──────────────────────────────────────────────────────
# Requires python3 (ships with macOS)
python3 << 'PYEOF'
import json, sys, os

config_path = os.path.expanduser(
    "~/Library/Application Support/Code/User/chatLanguageModels.json"
)
body = sys.stdin.read()

base_url = os.environ.get("OWUI_URL", "https://llm.jkr.digital").rstrip("/")
api_key = os.environ.get("OWUI_API_KEY", os.environ.get("OPENAI_API_KEY", ""))
api_key_ref = "${input:chat.lm.secret.owui}" if api_key else ""

try:
    data = json.loads(body)
except json.JSONDecodeError as e:
    print(f"Error: invalid JSON from OWUI: {e}", file=sys.stderr)
    sys.exit(1)

# /v1/models returns {"data": [{"id": "...", "name": "..."}, ...]}
# /api/models returns [{"id": "...", "name": "..."}, ...]
raw_models = data.get("data") if isinstance(data, dict) else data
if not isinstance(raw_models, list):
    print("Error: unexpected response format", file=sys.stderr)
    sys.exit(1)

models = []
for m in raw_models:
    if not isinstance(m, dict):
        continue
    model_id = m.get("id") or m.get("model")
    name = m.get("name") or m.get("id") or m.get("model") or "Unknown"
    if not model_id:
        continue
    models.append({
        "id": model_id,
        "name": name,
        "url": f"{base_url}/api/chat/completions",
        "toolCalling": True,
        "vision": True,
        "maxInputTokens": 128000,
        "maxOutputTokens": 16000
    })

if not models:
    print("Warning: no models found in OWUI response", file=sys.stderr)
    sys.exit(1)

config = [{
    "name": "OWUI",
    "vendor": "customendpoint",
    "apiKey": api_key_ref,
    "apiType": "chat-completions",
    "models": models
}]

# Backup existing config
if os.path.exists(config_path):
    backup = config_path + ".backup"
    with open(config_path, "r") as f:
        with open(backup, "w") as b:
            b.write(f.read())
    print(f"Backed up existing config to {backup}")

with open(config_path, "w") as f:
    json.dump(config, f, indent="\t")

print(f"Synced {len(models)} model(s) to {config_path}")
print("Reload VS Code: (Command Palette → Developer: Reload Window) to apply.")
PYEOF
<<< "$body"
