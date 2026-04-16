# AGENTS.md

## Purpose

This repo manages global pi coding agent setup and syncs repo-managed files into `~/.pi/agent` by default.

## Key Commands

- `just install` — sync repo-managed config, install missing shared packages, install missing external skills
- `just install-config` — sync only repo-managed files under `pi/agent`
- `just install-skills` — install only external skills from `skills-install.json`
- `just install-symlink` — sync config using symlinks instead of copies
- `just install-with-pi` — also install or update pi itself via npm
- `just install-full` — also update already-installed shared pi packages
- `just add-provider` — interactively add or replace an API-key provider entry in local `auth.json`
- `just check` — validate scripts and JSON config

## Important Files

- `install.sh` — main installer
- `justfile` — helper recipes
- `packages.json` — shared pi packages to install
- `skills-install.json` — external skills to install
- `scripts/install-skills.sh` — external skills sync helper
- `scripts/add-provider-api-key.sh` — local auth helper
- `scripts/merge-json.py` — JSON merge helper for managed config
- `pi/agent/` — repo-managed pi config content

## Repo Conventions

- Keep `AGENTS.md` aligned with the repo's real workflows, files, commands, and maintenance expectations whenever they change.
- Update this root `AGENTS.md` in the same unit of work when changes would otherwise make its instructions stale, misleading, or incomplete.
- Keep `README.md` aligned with actual installer behavior, commands, packages, skills, and prerequisites.
- Do not make the installer sync or modify `auth.json` or `sessions/`.
- `pi/agent/settings.json` is merged into the target `settings.json`; do not change this behavior in docs without changing the code.
- Prefer precise edits to existing files; use full rewrites only when necessary.
- Preserve existing shell style in scripts unless a broader refactor is explicitly requested.
- Keep changes minimal and focused on the requested behavior.

## Validation

Run `just check` after changing:

- `install.sh`
- anything under `scripts/`
- `packages.json`
- `skills-install.json`

When changing installer behavior or repo-managed config semantics, also update `README.md` in the same unit of work.
