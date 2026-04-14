# pi global setup

This repo is the source of truth for my global pi coding agent setup.

## What this manages

- syncs repo-managed global pi config into `~/.pi/agent`
- optionally installs or updates `@mariozechner/pi-coding-agent` when requested
- optionally installs shared pi packages listed in `packages.txt`
- optionally installs external skills declared in `skills-install.json` via the `skills` CLI

It intentionally does **not** touch local machine data like `auth.json` or the `sessions/` folder in the target pi directory.

## Repo layout

```text
.
├── install.sh
├── packages.txt
├── skills-install.json
└── pi/
    └── agent/
        ├── AGENTS.md
        ├── prompts/
        │   └── gitship.md
        └── settings.json
```

Add more global pi files under `pi/agent/`, for example:

- `pi/agent/keybindings.json`
- `pi/agent/SYSTEM.md`
- `pi/agent/prompts/...`
- `pi/agent/skills/...`
- `pi/agent/extensions/...`
- `pi/agent/themes/...`

Current repo-managed prompts include:

- `/gitship` via `pi/agent/prompts/gitship.md` for staging relevant work, creating a meaningful commit, and pushing while asking for confirmation when concerns are detected

On install, each top-level item in `pi/agent/` is copied into `~/.pi/agent` by default.

Protected target paths that are never modified by the installer:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/sessions/`

## Usage

From inside this repo:

```bash
chmod +x install.sh
./install.sh
```

Options:

```bash
./install.sh --symlink            # symlink instead of copy
./install.sh --install-pi         # also install/update pi via npm
./install.sh --pi-dir ~/.config/pi/agent
```

If `skills-install.json` exists, the installer also attempts to install each configured external skill with:

```bash
npx skills add <repo> --skill <skill> -g --agent pi -y
```

## Keeping machines in sync

On every machine:

```bash
git pull
./install.sh
```

That gives you:

- latest repo-managed config
- latest unpinned pi packages from `packages.txt`

If you also want to install or update pi itself:

```bash
./install.sh --install-pi
```

## External skills

Declare external skills in `skills-install.json` as a JSON object mapping repository URLs to skill name arrays:

```json
{
  "https://github.com/anthropics/skills": ["frontend-design"],
  "https://github.com/vercel-labs/skills": ["find-skills"]
}
```

During `./install.sh`, each configured skill is installed globally for the `pi` agent via the `skills` CLI. If `jq` or `npx` is missing, external skill installation is skipped with a warning.

## Shared pi packages

Put one package source per line in `packages.txt`, e.g.

```text
# npm packages
npm:@foo/pi-tools
npm:@bar/pi-theme@1.2.3

# git packages
git:github.com/user/pi-package
https://github.com/user/another-pi-package
```

Then rerun:

```bash
./install.sh
```

## Notes

- `skills-install.json` is optional; an empty object means no external skills are installed
- `jq` is required to parse `skills-install.json`
- `npx` is required to run the `skills` CLI installer

- Default pi global config dir: `~/.pi/agent`
- Override with `PI_CODING_AGENT_DIR` or `./install.sh --pi-dir ...`
- Existing conflicting files are backed up with a `.bak.TIMESTAMP` suffix
- External skill install failures are reported, but the installer continues with other configured skills
