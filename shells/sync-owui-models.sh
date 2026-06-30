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
    local -a curl_args=(-sSL --fail-with-body -w "\n%{http_code}")
    [[ -n "$API_KEY" ]] && curl_args+=(-H "Authorization: Bearer ${API_KEY}")

    curl "${curl_args[@]}" "$url" 2>/dev/null || true
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

# ── Validate JSON ──────────────────────────────────────────────────────────
# ── Validate & fallback ────────────────────────────────────────────────────
if [[ "$(echo "$body" | head -c1)" != "{" && "$(echo "$body" | head -c1)" != "[" ]]; then
    resp=$(fetch_models "${OWUI_URL%/}/api/models")
    http_code=$(echo "$resp" | tail -n1)
    body=$(echo "$resp" | sed '$d')
fi

if ! echo "$body" | jq -e . >/dev/null 2>&1; then
    echo "Error: invalid JSON from OWUI (HTTP $http_code)" >&2
    exit 1
fi

# ── Build JSON config with jq ──────────────────────────────────────────────
if [[ -n "$API_KEY" ]]; then
    API_KEY_REF='${input:chat.lm.secret.owui}'
else
    API_KEY_REF=''
fi

MODELS_JSON=$(echo "$body" | jq '{
    error: (if has("detail") then .detail else null end),
    models: (
        if type == "array" then
            map({ id: (.id // .model), name: (.name // .id // .model // "Unknown") } | select(.id != null))
        elif has("data") and (.data | type == "array") then
            .data | map({ id: (.id // .model), name: (.name // .id // .model // "Unknown") } | select(.id != null))
        else empty end
    )
}')

MODEL_COUNT=$(echo "$MODELS_JSON" | jq '.models | length')
if [[ "$MODEL_COUNT" -eq 0 ]]; then
    echo "Warning: no models found in OWUI response" >&2
    exit 1
fi

CONFIG_JSON=$(jq -n \
    --arg base_url "${OWUI_URL%/}" \
    --arg api_key "$API_KEY_REF" \
    --argjson models "$(echo "$MODELS_JSON" | jq '.models')" \
    '[{
        "name": "OWUI",
        "vendor": "customendpoint",
        "apiKey": $api_key,
        "apiType": "chat-completions",
        "models": [
            $models[] | {
                "id": .id,
                "name": .name,
                "url": "\($base_url)/api/chat/completions",
                "toolCalling": true,
                "vision": true,
                "maxInputTokens": 128000,
                "maxOutputTokens": 16000
            }
        ]
    }]')

# ── Write config ─────────────────────────────────────────────────────────────
if [[ -f "$CONFIG" ]]; then
    cp "$CONFIG" "$CONFIG.backup"
    echo "Backed up existing config to $CONFIG.backup"
fi

echo "$CONFIG_JSON" > "$CONFIG"

echo "Synced ${MODEL_COUNT} model(s) to $CONFIG"
echo "Reload VS Code: (Command Palette → Developer: Reload Window) to apply."
