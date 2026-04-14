set shell := ["bash", "-cu"]

# Show available helper recipes and their descriptions.
default:
    @just --list

# Show available helper recipes and their descriptions.
help:
    @just --list

# Sync repo-managed pi config, shared pi packages, and external skills.
install:
    ./install.sh

# Sync repo-managed pi config using symlinks instead of copying files.
install-symlink:
    ./install.sh --symlink

# Install or update pi itself, then sync repo-managed config, packages, and skills.
install-with-pi:
    ./install.sh --install-pi

# Interactively add or replace an API-key provider entry in ~/.pi/agent/auth.json.
add-provider:
    ./scripts/add-provider-api-key.sh

# Validate local helper files and JSON config without changing installed pi state.
check:
    bash -n install.sh
    bash -n scripts/add-provider-api-key.sh
    jq empty skills-install.json

# Print the current external skills config.
show-skills:
    jq . skills-install.json

# Print the current shared pi packages list with comments removed.
show-packages:
    grep -v '^[[:space:]]*#' packages.txt | sed '/^[[:space:]]*$/d'
