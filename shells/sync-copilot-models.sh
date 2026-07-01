#!/usr/bin/env bash
#
# Sync Open WebUI (OWUI) models into VS Code Copilot's custom language models.
#
# Fetches the model list from an Open WebUI instance and writes a `customendpoint`
# provider entry into VS Code's `chatLanguageModels.json` so the models appear in
# the Copilot model picker. Tries the OpenAI-compatible `/v1/models` endpoint
# first and falls back to OWUI's native `/api/models`.
#
# Per-model context windows are read from OWUI metadata; VS Code treats
# maxInputTokens + maxOutputTokens as the total window, so the reported window is
# split between input and output. Models without metadata use the fallback envs.
#
# Configuration (environment variables):
#   OWUI_URL                Base URL of Open WebUI. Default: https://llm.jkr.digital
#   OWUI_API_KEY            API key (falls back to OPENAI_API_KEY if unset)
#   OWUI_GROUP              Display/group name in the picker. Default: "OWUI"
#   OWUI_MAX_INPUT_TOKENS   Fallback when OWUI reports no window. Default: 128000
#   OWUI_MAX_OUTPUT_TOKENS  Fallback max output tokens. Default: 16000
#   OWUI_TOOL_CALLING       "true"/"false". Default: true
#   OWUI_VISION             "true"/"false". Default: true
#   COPILOT_MODELS_FILE     Override path to chatLanguageModels.json
#
# Exit codes: 0 ok, 1 config error, 2 network/API error.

set -euo pipefail

err() { printf 'sync-copilot-models: %s\n' "$1" >&2; }

command -v jq >/dev/null 2>&1 || { err "jq is required but not installed"; exit 1; }
command -v curl >/dev/null 2>&1 || { err "curl is required but not installed"; exit 1; }

# ── Configuration ──────────────────────────────────────────────────────────
BASE="${OWUI_URL:-https://llm.jkr.digital}"
BASE="${BASE%/}"
API_KEY="${OWUI_API_KEY:-${OPENAI_API_KEY:-}}"
GROUP="${OWUI_GROUP:-OWUI}"
DEF_IN="${OWUI_MAX_INPUT_TOKENS:-128000}"
DEF_OUT="${OWUI_MAX_OUTPUT_TOKENS:-16000}"
CONFIG="${COPILOT_MODELS_FILE:-$HOME/Library/Application Support/Code/User/chatLanguageModels.json}"

to_bool() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        1 | true | yes | on) echo true ;;
        *) echo false ;;
    esac
}
TOOL_CALLING="$(to_bool "${OWUI_TOOL_CALLING:-true}")"
VISION="$(to_bool "${OWUI_VISION:-true}")"

[ -n "$API_KEY" ] || { err "OWUI_API_KEY (or OPENAI_API_KEY) is not set"; exit 1; }

# ── Fetch models ───────────────────────────────────────────────────────────
fetch() {
    local url="$1" auth=()
    [ -n "$API_KEY" ] && auth=(-H "Authorization: Bearer $API_KEY")
    curl -sS -m 20 -w $'\n%{http_code}' "${auth[@]}" "$url" 2>/dev/null || true
}

is_model_list() { jq -e '(.data // .) | type == "array" and length > 0' >/dev/null 2>&1; }

body=""
for path in /v1/models /api/models; do
    resp="$(fetch "$BASE$path")"
    code="$(printf '%s' "$resp" | tail -n1)"
    candidate="$(printf '%s' "$resp" | sed '$d')"
    if [ "$code" = "200" ] && printf '%s' "$candidate" | is_model_list; then
        body="$candidate"
        break
    fi
done

[ -n "$body" ] || { err "failed to fetch models from $BASE (/v1/models and /api/models)"; exit 2; }

# ── Load + validate existing config ────────────────────────────────────────
if [ -s "$CONFIG" ]; then
    existing="$(cat "$CONFIG")"
    printf '%s' "$existing" | jq -e 'type == "array"' >/dev/null 2>&1 \
        || { err "existing $CONFIG is not a JSON array"; exit 1; }
else
    existing="[]"
fi

# Back up an existing non-empty config before overwriting.
if [ "$(printf '%s' "$existing" | jq 'length')" -gt 0 ]; then
    cp "$CONFIG" "$CONFIG.backup"
    err "backed up existing config to $CONFIG.backup"
fi

# ── Build the new config with jq ───────────────────────────────────────────
new_config="$(
    jq -n \
        --argjson models "$body" \
        --argjson existing "$existing" \
        --arg group "$GROUP" \
        --arg apikey "$API_KEY" \
        --arg completions "$BASE/api/chat/completions" \
        --argjson din "$DEF_IN" \
        --argjson dout "$DEF_OUT" \
        --argjson tool "$TOOL_CALLING" \
        --argjson vision "$VISION" '
        def pick($arr): $arr | map(select(type == "number" and . > 0) | floor) | (.[0] // null);

        ($models.data // $models) as $list
        | (
            $list
            | map(
                . as $m
                | (($m.id // $m.model) | select(. != null)) as $id
                | pick([
                    $m.context_length,
                    $m.capabilities.limits.max_context_window_tokens,
                    $m.openai.context_length,
                    $m.openai.capabilities.limits.max_context_window_tokens
                  ]) as $w
                | pick([
                    $m.max_output_tokens,
                    $m.capabilities.limits.max_output_tokens,
                    $m.openai.max_output_tokens,
                    $m.openai.capabilities.limits.max_output_tokens
                  ]) as $om
                | (
                    if $w == null then { mi: $din, mo: $dout }
                    else
                      (if $om != null then $om else ([$dout, (($w / 4) | floor)] | min) end) as $o0
                      | ([$o0, ($w - 1)] | min) as $o1
                      | ([$o1, 1] | max) as $o
                      | { mi: ($w - $o), mo: $o }
                    end
                  ) as $lim
                | {
                    id: $id,
                    name: ($m.name // $id),
                    url: $completions,
                    toolCalling: $tool,
                    vision: $vision,
                    maxInputTokens: $lim.mi,
                    maxOutputTokens: $lim.mo
                  }
              )
            | reduce .[] as $x ([]; if any(.[]; .id == $x.id) then . else . + [$x] end)
          ) as $entries
        | if ($entries | length) == 0 then error("no models returned by Open WebUI") else . end
        | {
            name: $group,
            vendor: "customendpoint",
            apiKey: $apikey,
            apiType: "chat-completions",
            models: $entries
          } as $provider
        | ($existing | map(select(.name != $group))) + [$provider]
    '
)"

# ── Write atomically ───────────────────────────────────────────────────────
mkdir -p "$(dirname "$CONFIG")"
tmp="$(mktemp)"
printf '%s\n' "$new_config" >"$tmp"
mv "$tmp" "$CONFIG"

count="$(printf '%s' "$new_config" | jq --arg g "$GROUP" '[.[] | select(.name == $g)][0].models | length')"
err "wrote $count model(s) to $CONFIG under group '$GROUP'. Reload VS Code (Developer: Reload Window) to apply."
