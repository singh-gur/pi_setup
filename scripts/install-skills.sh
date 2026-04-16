#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_INSTALL_FILE="$REPO_DIR/skills-install.json"
OPTIONAL=0
UPDATE_SKILLS=0

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
Usage: ./scripts/install-skills.sh [options]

Install external skills declared in skills-install.json via the skills CLI.

Options:
  --file <path>       Override skills-install.json path
  --optional          Skip with a warning when prerequisites or the config file are missing
  --update-skills     Run `npx skills update -g` before installing missing configured skills
  -h, --help          Show this help

Examples:
  ./scripts/install-skills.sh
  ./scripts/install-skills.sh --file ./skills-install.json
  ./scripts/install-skills.sh --optional
  ./scripts/install-skills.sh --update-skills
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        [[ $# -ge 2 ]] || die "--file requires a path"
        SKILLS_INSTALL_FILE="$2"
        shift 2
        ;;
      --optional)
        OPTIONAL=1
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

require_command() {
  local command_name="$1"
  local message="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$OPTIONAL" -eq 1 ]]; then
    warn "$message"
    exit 0
  fi

  die "$message"
}

list_installed_skills() {
  local output

  if command -v skills >/dev/null 2>&1; then
    output="$(skills list -g)"
  else
    output="$(npx --yes skills list -g)"
  fi

  printf '%s\n' "$output" \
    | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' \
    | awk '/^  [^[:space:]]+ / && $1 != "Agents:" { print $1 }'
}

main() {
  parse_args "$@"

  if [[ ! -f "$SKILLS_INSTALL_FILE" ]]; then
    if [[ "$OPTIONAL" -eq 1 ]]; then
      log "no skills-install.json found, skipping external skills"
      exit 0
    fi
    die "missing skills config: $SKILLS_INSTALL_FILE"
  fi

  require_command jq "jq is required to parse $SKILLS_INSTALL_FILE"
  require_command npx "npx is required to install external skills from $SKILLS_INSTALL_FILE"

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
    exit 0
  fi

  if [[ "$UPDATE_SKILLS" -eq 1 ]]; then
    log "npx skills update -g"
    if ! npx skills update -g </dev/null; then
      if [[ "$OPTIONAL" -eq 1 ]]; then
        warn "failed to update global skills, skipping external skills sync"
        exit 0
      fi
      die "failed to update global skills"
    fi
  fi

  local installed_skills_output
  if ! installed_skills_output="$(list_installed_skills)"; then
    if [[ "$OPTIONAL" -eq 1 ]]; then
      warn "failed to list global skills, skipping external skills sync"
      exit 0
    fi
    die "failed to list global skills"
  fi

  local skill_name
  declare -A installed_skills=()
  while IFS= read -r skill_name; do
    [[ -n "$skill_name" ]] || continue
    installed_skills["$skill_name"]=1
  done <<< "$installed_skills_output"

  local attempted=0
  local installed=0
  local skipped=0
  local failed=0
  local repo_url

  log "syncing external skills from $SKILLS_INSTALL_FILE"
  while IFS=$'\t' read -r repo_url skill_name; do
    [[ -n "$repo_url" ]] || continue

    attempted=$((attempted + 1))
    if [[ -n "${installed_skills[$skill_name]:-}" ]]; then
      skipped=$((skipped + 1))
      log "skipping installed external skill $skill_name"
      continue
    fi

    log "npx skills add $repo_url --skill $skill_name -g --agent pi -y"
    if npx --yes skills add "$repo_url" --skill "$skill_name" -g --agent pi -y </dev/null; then
      installed=$((installed + 1))
      installed_skills["$skill_name"]=1
    else
      failed=$((failed + 1))
      warn "failed to install external skill '$skill_name' from $repo_url, continuing"
    fi
  done <<< "$skill_entries"

  log "external skills installed: $installed/$attempted"
  if [[ "$skipped" -gt 0 ]]; then
    log "external skills skipped (already installed): $skipped"
  fi
  if [[ "$failed" -gt 0 ]]; then
    warn "external skill installs failed: $failed"
  fi
}

main "$@"
