#!/usr/bin/env bash
set -euo pipefail

TARGET_PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
AUTH_FILE="$TARGET_PI_DIR/auth.json"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
SUPPORTED_PROVIDERS=(
  "anthropic"
  "azure-openai-responses"
  "openai"
  "google"
  "mistral"
  "groq"
  "cerebras"
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

log() {
  printf '[pi-auth] %s\n' "$*"
}

warn() {
  printf '[pi-auth] warning: %s\n' "$*" >&2
}

die() {
  printf '[pi-auth] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ./scripts/add-provider-api-key.sh

Interactively add or replace an API-key-based provider entry in:
  ${PI_CODING_AGENT_DIR:-~/.pi/agent/auth.json}

This script prompts for:
  - provider name
  - API key (hidden input)

Supported provider keys:
  ${SUPPORTED_PROVIDERS[*]}
EOF
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

prompt_provider() {
  local provider=""

  printf 'Supported provider keys:\n' >&2
  local item
  for item in "${SUPPORTED_PROVIDERS[@]}"; do
    printf '  - %s\n' "$item" >&2
  done
  printf '\n' >&2

  read -r -p 'Provider name: ' provider
  provider="$(printf '%s' "$provider" | xargs 2>/dev/null || true)"
  [[ -n "$provider" ]] || die "provider name cannot be empty"

  if ! is_supported_provider "$provider"; then
    die "unsupported provider '$provider'; use one of the documented auth.json keys above"
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

write_auth_file() {
  local provider="$1"
  local api_key="$2"

  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  mkdir -p "$TARGET_PI_DIR"

  PROVIDER_NAME="$provider" \
  API_KEY_VALUE="$api_key" \
  AUTH_FILE_PATH="$AUTH_FILE" \
  BACKUP_SUFFIX="$BACKUP_SUFFIX" \
  python3 - <<'PY'
import json
import os
import shutil
import stat
import tempfile
from pathlib import Path

provider = os.environ["PROVIDER_NAME"]
api_key = os.environ["API_KEY_VALUE"]
auth_path = Path(os.environ["AUTH_FILE_PATH"]).expanduser()
backup_suffix = os.environ["BACKUP_SUFFIX"]

auth_path.parent.mkdir(parents=True, exist_ok=True)

data = {}
if auth_path.exists():
    try:
        with auth_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"[pi-auth] error: {auth_path} is not valid JSON: {exc}")

    if not isinstance(data, dict):
        raise SystemExit(f"[pi-auth] error: {auth_path} must contain a JSON object")

    backup_path = auth_path.with_name(f"{auth_path.name}.bak.{backup_suffix}")
    shutil.copy2(auth_path, backup_path)
    print(f"[pi-auth] backed up {auth_path} -> {backup_path}")

# pi provider docs use type=api_key in auth.json
entry = {"type": "api_key", "key": api_key}
data[provider] = entry

fd, tmp_path = tempfile.mkstemp(prefix=f".{auth_path.name}.", suffix=".tmp", dir=str(auth_path.parent))
try:
    os.fchmod(fd, stat.S_IRUSR | stat.S_IWUSR)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp_path, auth_path)
    os.chmod(auth_path, stat.S_IRUSR | stat.S_IWUSR)
finally:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)

print(f"[pi-auth] wrote provider '{provider}' to {auth_path}")
print(f"[pi-auth] permissions set to 0600")
PY
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    "")
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac

  local provider
  local api_key
  provider="$(prompt_provider)"
  api_key="$(prompt_api_key)"

  write_auth_file "$provider" "$api_key"
  warn "keep auth.json local; this repo's installer still does not sync auth.json"
}

main "$@"
