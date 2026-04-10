# pi global setup

This repo is the source of truth for my global pi coding agent setup.

## What this manages

- syncs repo-managed global pi config into `~/.pi/agent`
- optionally installs or updates `@mariozechner/pi-coding-agent` when requested
- optionally installs shared pi packages listed in `packages.txt`

It intentionally does **not** touch local machine data like `auth.json` or the `sessions/` folder in the target pi directory.

## Repo layout

```text
.
├── install.sh
├── packages.txt
└── pi/
    └── agent/
        ├── AGENTS.md
        └── settings.json
```

Add more global pi files under `pi/agent/`, for example:

- `pi/agent/keybindings.json`
- `pi/agent/SYSTEM.md`
- `pi/agent/prompts/...`
- `pi/agent/skills/...`
- `pi/agent/extensions/...`
- `pi/agent/themes/...`

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

- Default pi global config dir: `~/.pi/agent`
- Override with `PI_CODING_AGENT_DIR` or `./install.sh --pi-dir ...`
- Existing conflicting files are backed up with a `.bak.TIMESTAMP` suffix
