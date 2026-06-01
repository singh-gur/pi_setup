set shell := ["bash", "-cu"]

# Show available recipes.
default:
    @just --list

# Sync repo-managed pi config, packages, and skills.
# Modes: (none), config, skills, symlink, full, clean, update
install mode="":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ mode }}" in
      "") ./install.sh ;;
      config) ./install.sh --config-only ;;
      skills) ./scripts/install-skills.sh ;;
      symlink) ./install.sh --symlink ;;
      update) ./install.sh --update-packages --update-skills ;;
      full) ./install.sh --install-pi --update-packages --update-skills ;;
      clean) ./install.sh --clean ;;
      *) echo "Unknown install mode: {{ mode }}"; exit 1 ;;
    esac

# Interactively configure provider auth and custom models in ~/.pi/agent.
add-provider:
    ./scripts/add-provider-api-key.sh

# Validate local helper files and JSON config without changing installed pi state.
check:
    bash -n install.sh
    bash -n scripts/add-provider-api-key.sh
    bash -n scripts/install-skills.sh
    python3 scripts/update-provider-config.py --help >/dev/null
    jq empty packages.json
    jq empty skills-install.json
