#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_PI_DIR="$REPO_DIR/pi/agent"
TARGET_PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PACKAGES_FILE="$REPO_DIR/packages.json"
SKILLS_INSTALL_FILE="$REPO_DIR/skills-install.json"
MERGE_JSON_SCRIPT="$REPO_DIR/scripts/merge-json.py"
INSTALL_PI=0
CONFIG_ONLY=0
UPDATE_PACKAGES=0
UPDATE_SKILLS=0
SYNC_MODE="copy"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
PROTECTED_TARGETS=(
  "auth.json"
  "sessions"
)
MERGED_JSON_TARGETS=(
  "settings.json"
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
  --config-only        Sync only repo-managed pi config files
  --update-packages    Run pi update once after package sync to update installed pi packages
  --update-skills      Run npx skills update -g before installing missing configured skills
  -h, --help           Show this help

Examples:
  ./install.sh
  ./install.sh --install-pi
  ./install.sh --symlink
  ./install.sh --config-only
  ./install.sh --update-packages
  ./install.sh --update-skills
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

is_merged_json_target() {
  local relpath="$1"
  local merged
  for merged in "${MERGED_JSON_TARGETS[@]}"; do
    if [[ "$relpath" == "$merged" ]]; then
      return 0
    fi
  done
  return 1
}

merge_json_file() {
  local source="$1"
  local target="$2"

  command -v python3 >/dev/null 2>&1 || die "python3 is required to merge $target"
  [[ -f "$MERGE_JSON_SCRIPT" ]] || die "missing JSON merge helper: $MERGE_JSON_SCRIPT"

  local temp_file
  temp_file="$(mktemp)"

  python3 "$MERGE_JSON_SCRIPT" "$source" "$target" "$temp_file"

  if [[ -f "$target" ]] && cmp -s "$temp_file" "$target" 2>/dev/null; then
    rm -f "$temp_file"
    log "ok $target"
    return
  fi

  if [[ -e "$target" ]]; then
    backup_existing "$target"
  fi

  mv "$temp_file" "$target"
  log "merged $source -> $target"
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

  if is_merged_json_target "$relpath"; then
    if [[ -L "$target" ]]; then
      backup_existing "$target"
    fi
    merge_json_file "$source" "$target"
    return
  fi

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
    log "no packages.json found, skipping shared pi packages"
    return
  fi

  if ! command -v pi >/dev/null 2>&1; then
    warn "pi is not available on PATH yet; skipping packages.json install"
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq is required to parse $PACKAGES_FILE; skipping shared pi packages"
    return
  fi

  local installed_packages_output
  if ! installed_packages_output="$(pi list)"; then
    warn "failed to list installed pi packages; skipping packages.json sync"
    return
  fi

  local package_entries
  if ! package_entries="$(jq -r '
    if type != "object" then
      error("packages.json must contain a JSON object")
    elif (.packages | type) != "object" then
      error("packages.json must contain a packages object")
    else
      .packages
      | to_entries[]?
      | .key as $pkg
      | .value as $enabled
      | if ($pkg | type) != "string" then
          error("package names must be strings")
        elif ($enabled | type) != "boolean" then
          error("package flags must be booleans")
        else
          ($pkg | gsub("^\\s+|\\s+$"; "")) as $trimmed_pkg
          | if ($trimmed_pkg | length) == 0 then
              error("package names must not be empty")
            else
              [$trimmed_pkg, ($enabled | tostring)]
              | @tsv
            end
        end
    end
  ' "$PACKAGES_FILE")"; then
    warn "failed to parse $PACKAGES_FILE; skipping shared pi packages"
    return
  fi

  local package_name
  local package_enabled
  declare -A installed_packages=()
  declare -A enabled_packages=()
  declare -A disabled_packages=()
  while IFS= read -r package_name; do
    [[ -n "$package_name" ]] || continue
    installed_packages["$package_name"]=1
  done < <(printf '%s\n' "$installed_packages_output" | sed -n 's/^  \([^[:space:]].*\)$/\1/p')

  while IFS=$'\t' read -r package_name package_enabled; do
    [[ -n "$package_name" ]] || continue

    if [[ "$package_enabled" == "true" ]]; then
      enabled_packages["$package_name"]=1
    else
      disabled_packages["$package_name"]=1
    fi
  done <<< "$package_entries"

  log "syncing shared pi packages from $PACKAGES_FILE"

  for package_name in "${!disabled_packages[@]}"; do
    if [[ -n "${installed_packages[$package_name]:-}" ]]; then
      log "pi remove $package_name"
      pi remove "$package_name"
      unset 'installed_packages[$package_name]'
    else
      log "skipping absent disabled package $package_name"
    fi
  done

  for package_name in "${!enabled_packages[@]}"; do
    if [[ -n "${installed_packages[$package_name]:-}" ]]; then
      log "skipping installed package $package_name"
    else
      log "pi install $package_name"
      pi install "$package_name"
    fi
  done

  if [[ "$UPDATE_PACKAGES" -eq 1 ]]; then
    log "pi update"
    pi update
  fi
}

sync_external_skills() {
  local args=(--file "$SKILLS_INSTALL_FILE" --optional)
  if [[ "$UPDATE_SKILLS" -eq 1 ]]; then
    args+=(--update-skills)
  fi
  "$REPO_DIR/scripts/install-skills.sh" "${args[@]}"
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
      --config-only)
        CONFIG_ONLY=1
        shift
        ;;
      --update-packages)
        UPDATE_PACKAGES=1
        shift
        ;;
      --update-skills)
        UPDATE_SKILLS=1
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

  if [[ "$CONFIG_ONLY" -ne 1 ]]; then
    sync_pi_packages
    sync_external_skills
  fi

  log "done"
  log "next steps: run 'pi', then '/login' or export your provider API key(s)"
}

main "$@"
