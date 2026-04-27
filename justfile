set shell := ["bash", "-cu"]

# Show available helper recipes and their descriptions.
default:
    @just --list

# Show available helper recipes and their descriptions.
help:
    @just --list

# Sync repo-managed pi config, install missing shared pi packages, and install external skills.
install:
    ./install.sh

# Sync only the repo-managed files under pi/agent.
install-config:
    ./install.sh --config-only

# Install only the external skills listed in skills-install.json.
install-skills:
    ./scripts/install-skills.sh

# Sync repo-managed pi config using symlinks instead of copying files.
install-symlink:
    ./install.sh --symlink

# Install or update pi itself, then sync repo-managed config, packages, and skills.
install-with-pi:
    ./install.sh --install-pi

# Sync repo-managed pi config, install missing packages, run `pi update`, and install external skills.
install-full:
    ./install.sh --update-packages --update-skills

# Back up and replace repo-managed config targets, reinstall configured packages, and sync external skills.
install-clean:
    ./install.sh --clean

# Interactively add or replace an API-key provider entry in ~/.pi/agent/auth.json.
add-provider:
    ./scripts/add-provider-api-key.sh

# Validate local helper files and JSON config without changing installed pi state.
check:
    bash -n install.sh
    bash -n scripts/add-provider-api-key.sh
    bash -n scripts/install-skills.sh
    jq empty packages.json
    jq empty skills-install.json

# Print the current external skills config.
show-skills:
    jq . skills-install.json

# Print the current shared pi packages list.
show-packages:
    jq -r '.packages[]' packages.json
