#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PI_DIR="$REPO_DIR/pi/agent"
TARGET_PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PACKAGES_FILE="$REPO_DIR/packages.txt"
SKILLS_INSTALL_FILE="$REPO_DIR/skills-install.json"
INSTALL_PI=0
SYNC_MODE="copy"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
PROTECTED_TARGETS=(
  "auth.json"
  "sessions"
)

log() {
  printf '[pi-setup] %s\n' "$*"
}

warn() {
  printf '[pi-setup] warning: %s\n' "$*" >&2
}

die() {
  printf '[pi-setup] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ./install.sh [options]

Bootstraps pi on this machine and syncs repo-managed config into:
  ${PI_CODING_AGENT_DIR:-~/.pi/agent}

Also installs optional external skills declared in skills-install.json via the skills CLI.

Options:
  --pi-dir <path>      Override target pi config dir
  --symlink            Symlink files instead of copying them
  --install-pi         Install/update @mariozechner/pi-coding-agent via npm
  -h, --help           Show this help

Examples:
  ./install.sh
  ./install.sh --install-pi
  ./install.sh --symlink
  ./install.sh --pi-dir ~/.config/pi/agent
EOF
}

abspath() {
  local path="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
from pathlib import Path
print(Path(${path@Q}).expanduser().resolve())
PY
  else
    mkdir -p "$path"
    (cd "$path" && pwd)
  fi
}

backup_existing() {
  local target="$1"
  local backup="${target}.bak.${BACKUP_SUFFIX}"
  mv "$target" "$backup"
  log "backed up $target -> $backup"
}

ensure_parent() {
  mkdir -p "$(dirname "$1")"
}

is_protected_target() {
  local relpath="$1"
  local protected
  for protected in "${PROTECTED_TARGETS[@]}"; do
    if [[ "$relpath" == "$protected" || "$relpath" == "$protected/"* ]]; then
      return 0
    fi
  done
  return 1
}

sync_entry() {
  local source="$1"
  local target="$2"
  local relpath="$3"

  if is_protected_target "$relpath"; then
    log "skipping protected target $target"
    return
  fi

  ensure_parent "$target"

  if [[ -L "$target" ]]; then
    local current_target=""
    current_target="$(readlink "$target" || true)"
    if [[ "$SYNC_MODE" == "symlink" && "$current_target" == "$source" ]]; then
      log "ok $target"
      return
    fi
    backup_existing "$target"
  elif [[ -f "$source" && -f "$target" ]]; then
    if cmp -s "$source" "$target" 2>/dev/null; then
      log "ok $target"
      return
    fi
    backup_existing "$target"
  elif [[ -e "$target" ]]; then
    backup_existing "$target"
  fi

  if [[ "$SYNC_MODE" == "symlink" ]]; then
    ln -s "$source" "$target"
    log "linked $target -> $source"
  elif [[ -d "$source" ]]; then
    cp -R "$source" "$target"
    log "copied $source -> $target"
  else
    cp "$source" "$target"
    log "copied $source -> $target"
  fi
}

install_pi() {
  if [[ "$INSTALL_PI" -ne 1 ]]; then
    log "pi npm install disabled by default; use --install-pi to enable it"
    return
  fi

  command -v node >/dev/null 2>&1 || die "node is required. Install Node.js first, then rerun ./install.sh"
  command -v npm >/dev/null 2>&1 || die "npm is required. Install npm first, then rerun ./install.sh"

  log "installing/updating @mariozechner/pi-coding-agent"
  npm install -g @mariozechner/pi-coding-agent@latest
}

sync_pi_config() {
  [[ -d "$SOURCE_PI_DIR" ]] || die "missing source config dir: $SOURCE_PI_DIR"

  mkdir -p "$TARGET_PI_DIR"

  while IFS= read -r relpath; do
    [[ -n "$relpath" ]] || continue
    local source="$SOURCE_PI_DIR/$relpath"
    local target="$TARGET_PI_DIR/$relpath"
    sync_entry "$source" "$target" "$relpath"
  done < <(cd "$SOURCE_PI_DIR" && find . -mindepth 1 -maxdepth 1 | sed 's#^./##' | sort)
}

sync_pi_packages() {
  if [[ ! -f "$PACKAGES_FILE" ]]; then
    log "no packages.txt found, skipping shared pi packages"
    return
  fi

  if ! command -v pi >/dev/null 2>&1; then
    warn "pi is not available on PATH yet; skipping packages.txt install"
    return
  fi

  log "syncing shared pi packages from $PACKAGES_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | xargs 2>/dev/null || true)"
    [[ -n "$line" ]] || continue
    log "pi install $line"
    pi install "$line"
  done < "$PACKAGES_FILE"

  log "running pi update"
  pi update
}

sync_external_skills() {
  if [[ ! -f "$SKILLS_INSTALL_FILE" ]]; then
    log "no skills-install.json found, skipping external skills"
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq is not installed; skipping external skills from $SKILLS_INSTALL_FILE"
    return
  fi

  if ! command -v npx >/dev/null 2>&1; then
    warn "npx is not available; skipping external skills from $SKILLS_INSTALL_FILE"
    return
  fi

  local skill_entries
  if ! skill_entries="$(jq -r '
    if type != "object" then
      error("skills-install.json must contain a JSON object")
    else
      to_entries[]?
      | .key as $url
      | if (.value | type) != "array" then
          error("Expected an array of skills for \($url)")
        else
          .value[]?
          | if type != "string" then
              error("Invalid skill name for \($url)")
            else
              . as $skill
              | ($skill | gsub("^\\s+|\\s+$"; "")) as $trimmed_skill
              | if ($trimmed_skill | length) == 0 then
                  error("Invalid skill name for \($url)")
                else
                  "\($url)\t\($trimmed_skill)"
                end
            end
        end
    end
  ' "$SKILLS_INSTALL_FILE")"; then
    die "failed to parse $SKILLS_INSTALL_FILE"
  fi

  if [[ -z "$skill_entries" ]]; then
    log "no external skills configured in $SKILLS_INSTALL_FILE"
    return
  fi

  local attempted=0
  local installed=0
  local failed=0
  local repo_url
  local skill_name

  log "syncing external skills from $SKILLS_INSTALL_FILE"
  while IFS=$'\t' read -r repo_url skill_name; do
    [[ -n "$repo_url" ]] || continue

    attempted=$((attempted + 1))
    log "npx skills add $repo_url --skill $skill_name -g --agent pi -y"
    if npx --yes skills add "$repo_url" --skill "$skill_name" -g --agent pi -y </dev/null; then
      installed=$((installed + 1))
    else
      failed=$((failed + 1))
      warn "failed to install external skill '$skill_name' from $repo_url, continuing"
    fi
  done <<< "$skill_entries"

  log "external skills installed: $installed/$attempted"
  if [[ "$failed" -gt 0 ]]; then
    warn "external skill installs failed: $failed"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pi-dir)
        [[ $# -ge 2 ]] || die "--pi-dir requires a path"
        TARGET_PI_DIR="$2"
        shift 2
        ;;
      --symlink)
        SYNC_MODE="symlink"
        shift
        ;;
      --install-pi)
        INSTALL_PI=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  TARGET_PI_DIR="$(abspath "$TARGET_PI_DIR")"

  log "repo dir: $REPO_DIR"
  log "source pi dir: $SOURCE_PI_DIR"
  log "target pi dir: $TARGET_PI_DIR"
  log "mode: $SYNC_MODE"

  install_pi
  sync_pi_config
  sync_pi_packages
  sync_external_skills

  log "done"
  log "next steps: run 'pi', then '/login' or export your provider API key(s)"
}

main "$@"
