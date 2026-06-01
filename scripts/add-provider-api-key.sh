#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
AUTH_FILE="$TARGET_PI_DIR/auth.json"
MODELS_FILE="$TARGET_PI_DIR/models.json"
PROVIDER_CONFIG_SCRIPT="$SCRIPT_DIR/update-provider-config.py"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
SUPPORTED_PROVIDERS=(
  "anthropic"
  "azure-openai-responses"
  "openai"
  "google"
  "mistral"
  "groq"
  "cerebras"
  "cursor"
  "xai"
  "openrouter"
  "vercel-ai-gateway"
  "zai"
  "opencode"
  "opencode-go"
  "huggingface"
  "kimi-coding"
  "minimax"
  "minimax-cn"
)
SUPPORTED_MODEL_APIS=(
  "openai-completions"
  "openai-responses"
  "anthropic-messages"
  "google-generative-ai"
)

log() {
  printf '[pi-provider] %s\n' "$*"
}

warn() {
  printf '[pi-provider] warning: %s\n' "$*" >&2
}

die() {
  printf '[pi-provider] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ./scripts/add-provider-api-key.sh [--auth|--models|--both]

Interactively configure local pi provider state under:
  ${PI_CODING_AGENT_DIR:-~/.pi/agent}

Modes:
  --auth    Add or replace an API-key-based built-in provider entry in auth.json
  --models  Add or update a custom provider/model entry in models.json
  --both    Run both setup flows

With no mode, the script asks what to configure.

Supported auth provider keys:
  ${SUPPORTED_PROVIDERS[*]}

models.json supports custom providers and models using the pi models docs:
  https://pi.dev/docs/latest/models
EOF
}

trim() {
  local value="$*"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

require_python() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  [[ -f "$PROVIDER_CONFIG_SCRIPT" ]] || die "missing provider config helper: $PROVIDER_CONFIG_SCRIPT"
}

is_supported_provider() {
  local candidate="$1"
  local provider
  for provider in "${SUPPORTED_PROVIDERS[@]}"; do
    if [[ "$provider" == "$candidate" ]]; then
      return 0
    fi
  done
  return 1
}

is_supported_model_api() {
  local candidate="$1"
  local api
  for api in "${SUPPORTED_MODEL_APIS[@]}"; do
    if [[ "$api" == "$candidate" ]]; then
      return 0
    fi
  done
  return 1
}

prompt_setup_mode() {
  local choice=""
  printf 'What do you want to configure?\n' >&2
  printf '  1) Built-in provider API key in auth.json\n' >&2
  printf '  2) Custom provider/models in models.json\n' >&2
  printf '  3) Both\n' >&2
  printf '\n' >&2
  read -r -p 'Choice [1]: ' choice
  choice="$(trim "$choice")"
  case "${choice:-1}" in
    1|auth|api-key) printf 'auth' ;;
    2|models|custom) printf 'models' ;;
    3|both) printf 'both' ;;
    *) die "unknown choice: $choice" ;;
  esac
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-n}"
  local answer=""
  local suffix="[y/N]"
  if [[ "$default" == "y" ]]; then
    suffix="[Y/n]"
  fi

  read -r -p "$prompt $suffix: " answer
  answer="$(trim "$answer")"
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    n|N|no|NO|No) return 1 ;;
    *) die "expected yes or no for: $prompt" ;;
  esac
}

prompt_auth_provider() {
  local provider=""

  printf 'Supported auth provider keys:\n' >&2
  local item
  for item in "${SUPPORTED_PROVIDERS[@]}"; do
    printf '  - %s\n' "$item" >&2
  done
  printf '\n' >&2

  read -r -p 'Provider name: ' provider
  provider="$(trim "$provider")"
  [[ -n "$provider" ]] || die "provider name cannot be empty"

  if ! is_supported_provider "$provider"; then
    die "unsupported auth provider '$provider'; use one of the documented auth.json keys above"
  fi

  printf '%s' "$provider"
}

prompt_api_key() {
  local api_key=""
  read -r -s -p 'API key: ' api_key
  printf '\n' >&2
  [[ -n "$api_key" ]] || die "API key cannot be empty"
  printf '%s' "$api_key"
}

validate_provider_key() {
  local provider="$1"
  [[ "$provider" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "provider key must start with a letter/number and contain only letters, numbers, dots, underscores, or dashes"
}

prompt_models_provider() {
  local provider=""
  read -r -p 'Provider key for models.json (for example ollama or my-openai): ' provider
  provider="$(trim "$provider")"
  [[ -n "$provider" ]] || die "provider key cannot be empty"
  validate_provider_key "$provider"
  printf '%s' "$provider"
}

prompt_base_url() {
  local base_url=""
  read -r -p 'Base URL (for example http://localhost:11434/v1): ' base_url
  base_url="$(trim "$base_url")"
  [[ -n "$base_url" ]] || die "base URL cannot be empty for custom model setup"
  printf '%s' "$base_url"
}

prompt_model_api() {
  local choice=""
  local index=1
  local api

  printf 'Supported models.json API types:\n' >&2
  for api in "${SUPPORTED_MODEL_APIS[@]}"; do
    printf '  %d) %s\n' "$index" "$api" >&2
    index=$((index + 1))
  done
  printf '\n' >&2

  read -r -p 'API type [1]: ' choice
  choice="$(trim "$choice")"
  case "${choice:-1}" in
    1) printf '%s' "${SUPPORTED_MODEL_APIS[0]}" ;;
    2) printf '%s' "${SUPPORTED_MODEL_APIS[1]}" ;;
    3) printf '%s' "${SUPPORTED_MODEL_APIS[2]}" ;;
    4) printf '%s' "${SUPPORTED_MODEL_APIS[3]}" ;;
    *)
      if is_supported_model_api "$choice"; then
        printf '%s' "$choice"
      else
        die "unsupported API type: $choice"
      fi
      ;;
  esac
}

default_api_key_ref() {
  local provider="$1"
  if [[ "$provider" == "ollama" ]]; then
    printf 'ollama'
    return
  fi

  printf '%s_API_KEY' "$provider" \
    | tr '[:lower:].-' '[:upper:]__' \
    | sed 's/[^A-Z0-9_]/_/g; s/^/$/'
}

prompt_models_api_key_value() {
  local default_value="$1"
  local api_key_value=""

  printf 'models.json apiKey supports literals, $ENV_VAR, ${ENV_VAR}, and !command values.\n' >&2
  printf 'Prefer an environment reference instead of storing secrets directly.\n' >&2
  read -r -p "API key config value [$default_value]: " api_key_value
  api_key_value="$(trim "$api_key_value")"
  printf '%s' "${api_key_value:-$default_value}"
}

prompt_model_ids() {
  local model_ids=""
  read -r -p 'Model id(s), comma-separated: ' model_ids
  model_ids="$(trim "$model_ids")"
  [[ -n "$model_ids" ]] || die "at least one model id is required"
  printf '%s' "$model_ids"
}

prompt_positive_int() {
  local prompt="$1"
  local default_value="$2"
  local value=""

  read -r -p "$prompt [$default_value]: " value
  value="$(trim "$value")"
  value="${value:-$default_value}"

  [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "$prompt must be a positive integer"
  printf '%s' "$value"
}

prompt_model_token_limits() {
  local choice=""
  local context_window=""
  local max_tokens=""

  printf 'Model token presets:\n' >&2
  printf '  1) Standard coding (128k context, 16k output)\n' >&2
  printf '  2) Small/local (32k context, 4k output)\n' >&2
  printf '  3) Large coding (200k context, 32k output)\n' >&2
  printf '  4) Huge context (1M context, 64k output)\n' >&2
  printf '  5) Custom values\n' >&2
  printf '\n' >&2

  read -r -p 'Token preset [1]: ' choice
  choice="$(trim "$choice")"
  case "${choice:-1}" in
    1|standard|coding)
      context_window=128000
      max_tokens=16384
      ;;
    2|small|local)
      context_window=32000
      max_tokens=4096
      ;;
    3|large)
      context_window=200000
      max_tokens=32000
      ;;
    4|huge|very-large)
      context_window=1000000
      max_tokens=65536
      ;;
    5|custom)
      context_window="$(prompt_positive_int 'Context window tokens' 128000)"
      max_tokens="$(prompt_positive_int 'Max output tokens' 16384)"
      ;;
    *)
      die "unknown token preset: $choice"
      ;;
  esac

  printf '%s %s\n' "$context_window" "$max_tokens"
}

write_auth_file() {
  local provider="$1"
  local api_key="$2"

  require_python
  mkdir -p "$TARGET_PI_DIR"

  API_KEY_VALUE="$api_key" \
  python3 "$PROVIDER_CONFIG_SCRIPT" auth \
    --file "$AUTH_FILE" \
    --backup-suffix "$BACKUP_SUFFIX" \
    --provider "$provider"
}

write_models_file() {
  local provider="$1"
  local base_url="$2"
  local api_type="$3"
  local api_key_value="$4"
  local auth_header="$5"
  local local_compat="$6"
  local model_ids="$7"
  local reasoning="$8"
  local image_input="$9"
  local context_window="${10}"
  local max_tokens="${11}"

  require_python
  mkdir -p "$TARGET_PI_DIR"

  API_KEY_CONFIG_VALUE="$api_key_value" \
  python3 "$PROVIDER_CONFIG_SCRIPT" models \
    --file "$MODELS_FILE" \
    --backup-suffix "$BACKUP_SUFFIX" \
    --provider "$provider" \
    --base-url "$base_url" \
    --api "$api_type" \
    --model-ids "$model_ids" \
    --auth-header "$auth_header" \
    --local-compat "$local_compat" \
    --reasoning "$reasoning" \
    --image-input "$image_input" \
    --context-window "$context_window" \
    --max-tokens "$max_tokens"
}

setup_auth_provider() {
  local provider
  local api_key
  provider="$(prompt_auth_provider)"
  api_key="$(prompt_api_key)"
  write_auth_file "$provider" "$api_key"
}

setup_models_provider() {
  local provider
  local base_url
  local api_type
  local api_key_value
  local auth_header=0
  local local_compat=0
  local model_ids
  local reasoning=0
  local image_input=0
  local context_window
  local max_tokens

  log "configuring local models.json; this is machine-local and is not synced by install.sh"
  provider="$(prompt_models_provider)"
  base_url="$(prompt_base_url)"
  api_type="$(prompt_model_api)"
  api_key_value="$(prompt_models_api_key_value "$(default_api_key_ref "$provider")")"

  if prompt_yes_no 'Set authHeader=true to send Authorization: Bearer <apiKey>?' n; then
    auth_header=1
  fi

  if [[ "$api_type" == "openai-completions" ]]; then
    if prompt_yes_no 'Apply common local OpenAI-compatible settings (no developer role/reasoning_effort)?' n; then
      local_compat=1
    fi
  fi

  model_ids="$(prompt_model_ids)"
  if prompt_yes_no 'Do these model(s) support pi extended thinking/reasoning?' n; then
    reasoning=1
  fi
  if prompt_yes_no 'Do these model(s) support image input?' n; then
    image_input=1
  fi
  read -r context_window max_tokens < <(prompt_model_token_limits)

  write_models_file "$provider" "$base_url" "$api_type" "$api_key_value" "$auth_header" "$local_compat" "$model_ids" "$reasoning" "$image_input" "$context_window" "$max_tokens"
}

main() {
  local mode=""
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --auth|--api-key)
      mode="auth"
      ;;
    --models|--custom-models)
      mode="models"
      ;;
    --both)
      mode="both"
      ;;
    "")
      mode="$(prompt_setup_mode)"
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac

  case "$mode" in
    auth)
      setup_auth_provider
      ;;
    models)
      setup_models_provider
      ;;
    both)
      setup_auth_provider
      setup_models_provider
      ;;
    *)
      die "unknown setup mode: $mode"
      ;;
  esac

  warn "keep auth.json and models.json local; this repo's installer still does not sync machine-specific provider state"
}

main "$@"
