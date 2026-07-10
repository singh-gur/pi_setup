# pi global setup

This repo is the source of truth for my global pi coding agent setup.

## What this manages

- syncs repo-managed global pi config from `pi/agent/` into `~/.pi/agent` by default
- merges repo-managed `settings.json` into the target `settings.json` instead of replacing it wholesale
- optionally installs or updates pi using the official `https://pi.dev/install.sh` installer when requested
- installs missing enabled shared pi packages listed in `packages.json`
- removes installed shared pi packages that are explicitly disabled in `packages.json`
- can cleanly reinstall repo-managed config targets and configured pi packages when requested
- optionally runs `pi update` after package sync when requested
- optionally updates pi itself and its extensions via `pi update` when requested
- installs missing enabled external skills declared in `skills-install.json` via the `skills` CLI
- removes installed external skills that are explicitly disabled in `skills-install.json`
- optionally runs a global skills update before syncing configured external skills
- includes a local helper for provider API keys and custom `models.json` entries

It intentionally does **not** touch local machine data like `auth.json`, `models.json`, or the `sessions/` folder in the target pi directory.

## Repo layout

```text
.
├── install.sh
├── justfile
├── packages.json
├── skills-install.json
├── scripts/
│   ├── add-provider-api-key.sh
│   ├── install-skills.sh
│   ├── merge-json.py
│   └── update-provider-config.py
└── pi/
    └── agent/
        ├── AGENTS.md
        ├── prompts/
        │   ├── clone-prompt.md
        │   ├── gitship.md
        │   ├── gityolo.md
        │   ├── init-just.md
        │   ├── plan-progress.md
        │   └── setup-ci.md
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

- `/clone-prompt` via `pi/agent/prompts/clone-prompt.md` for studying the current repo and generating reusable prompts for building a similar project
- `/gitship` via `pi/agent/prompts/gitship.md` for staging relevant work, creating a meaningful commit, and pushing while asking for confirmation when concerns are detected
- `/gityolo` via `pi/agent/prompts/gityolo.md` for a faster git ship flow that still checks repo state but only stops for clearly risky or ambiguous situations
- `/init-just` via `pi/agent/prompts/init-just.md` for creating a practical project `justfile` with documented tasks and a default task list
- `/plan-progress` via `pi/agent/prompts/plan-progress.md` for reviewing a plan file against current repository progress with evidence-backed status reporting
- `/setup-ci` via `pi/agent/prompts/setup-ci.md` for gathering CI requirements (Concourse or Forgejo CI) and scaffolding pipelines with testing and security gates

On install, each top-level item in `pi/agent/` is copied into `~/.pi/agent` by default.

`settings.json` is special-cased and deep-merged into the target file so existing local settings can coexist with repo-managed defaults. Other top-level items are copied or symlinked as requested.

Protected target paths that are never modified by the installer:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/models.json`
- `~/.pi/agent/sessions/`

The installer never changes provider auth or local model configuration. If you explicitly want to add an API-key provider entry or custom provider/model entry, use `./scripts/add-provider-api-key.sh`.

## Usage

From inside this repo:

```bash
chmod +x install.sh
./install.sh
```

Or use the helper `justfile`:

```bash
just                  # show available recipes
just install          # sync config, install missing packages, install missing skills
just install config   # sync only repo-managed files under pi/agent
just install skills   # install only external skills from skills-install.json
just install symlink  # sync config using symlinks instead of copies
just install update   # update pi, its extensions, and external skills while syncing
just install full     # install/update pi, then update packages and external skills
just install clean    # back up/reinstall repo-managed config and configured packages
just add-provider     # configure provider auth or custom models
just check            # validate scripts and JSON config
```

Options:

```bash
./install.sh --symlink            # symlink instead of copy
./install.sh --install-pi         # also install/update pi via the official installer
./install.sh --update             # update pi itself and its extensions via pi update
./install.sh --config-only        # sync only repo-managed config files
./install.sh --clean              # back up/reinstall repo-managed config and configured packages
./install.sh --update-packages    # run `pi update` after package sync
./install.sh --update-skills      # run `npx skills update -g` before syncing configured skills
./install.sh --pi-dir ~/.config/pi/agent
```

Configure provider auth or custom providers/models interactively:

```bash
./scripts/add-provider-api-key.sh          # choose auth, models, or both
./scripts/add-provider-api-key.sh --auth   # update ~/.pi/agent/auth.json
./scripts/add-provider-api-key.sh --models # update ~/.pi/agent/models.json
```

If `skills-install.json` exists, the installer also attempts to install each missing enabled external skill and remove each installed disabled external skill by calling `./scripts/install-skills.sh --optional`:

```bash
npx skills add <repo> --skill <skill> -g -y -a pi -a universal
npx skills remove <skill> -g -y -a pi -a universal
```

The `-a pi -a universal` flags scope each call to the `pi` agent and the universal canonical skills directory under `~/.agents/skills/`. This avoids agent entries in the `skills` CLI (such as the recently added project-only `PromptScript` entry) that fail with `does not support global skill installation` during auto-detection.

## Keeping machines in sync

On every machine:

```bash
git pull
./install.sh
```

That gives you:

- latest repo-managed config
- any missing enabled shared pi packages from `packages.json`
- removal of any installed shared pi packages explicitly disabled in `packages.json`
- any missing enabled external skills from `skills-install.json`
- removal of any installed external skills explicitly disabled in `skills-install.json`

If you also want to run `pi update` after package sync:

```bash
./install.sh --update-packages
```

If you want to cleanly reinstall the repo-managed config and configured pi packages without touching `auth.json`, `models.json`, or `sessions/`:

```bash
just install clean
```

If you also want to install or update pi itself:

```bash
./install.sh --install-pi
```

If you prefer to update pi itself and its extensions via `pi update` without the official installer reinstall:

```bash
./install.sh --update
```

## External skills

Declare external skills in `skills-install.json` as a JSON object mapping repository URLs to skill-name booleans. `true` means the skill should be installed if missing; `false` means the skill should be removed if it is currently installed.

```json
{
  "https://github.com/anthropics/skills": {
    "frontend-design": true,
    "old-skill": false
  },
  "https://github.com/vercel-labs/skills": {
    "find-skills": true
  }
}
```

Current external skills config:

```json
{
  "https://github.com/singh-gur/agent_skills": {
    "super-plan": true,
    "simple-plan": true,
    "caveman": true
  }
}
```

During `./install.sh`, each configured missing skill is installed globally for the `pi` agent via the `skills` CLI through `./scripts/install-skills.sh --optional`. If you only want to refresh external skills, run `just install skills` or `./scripts/install-skills.sh`. Add `--update-skills` if you want to run `npx skills update -g` first. If `jq` or `npx` is missing, external skill installation is skipped with a warning.

## Shared pi packages

Declare package sources in `packages.json` as a JSON object mapping package names to booleans. `true` means the package should be installed if missing; `false` means the package should be removed if it is currently installed, e.g.

```json
{
  "packages": {
    "npm:@foo/pi-tools": true,
    "npm:@bar/pi-theme@1.2.3": false,
    "git:github.com/user/pi-package": true,
    "https://github.com/user/another-pi-package": true
  }
}
```

Current shared package config:

```json
{
  "packages": {
    "npm:@ifi/oh-pi-themes": true,
    "npm:@eliemessiecode/pi-code-theme": true,
    "npm:@haispeed/pi-deck": true,
    "npm:pi-ask-user": false,
    "npm:@juicesharp/rpiv-ask-user-question": true,
    "npm:pi-subagents": true,
    "npm:@ifi/pi-plan": false,
    "npm:pi-mono-clear": false,
    "npm:@zenobius/pi-worktrees": true,
    "npm:@codexstar/pi-listen": false,
    "npm:@sherif-fanous/pi-catppuccin": false,
    "npm:pi-lens": false,
    "npm:@juicesharp/rpiv-todo": false,
    "npm:pi-cursor-sdk": true,
    "npm:pi-hud": true,
    "npm:@juicesharp/rpiv-advisor": true
  }
}
```

Then rerun:

```bash
./install.sh
```

## Provider setup helper

`./scripts/add-provider-api-key.sh` can configure local provider auth and custom model definitions without making them repo-managed. It delegates JSON updates to `scripts/update-provider-config.py`.

- `--auth` prompts for a documented provider key and a hidden API key, then updates `~/.pi/agent/auth.json` using the `api_key` auth type expected by pi.
- `--models` prompts for a provider key, base URL, API type, API key config value, model IDs, and a human-friendly token preset (or custom context/output token values), then updates `~/.pi/agent/models.json` using the pi models config format from <https://pi.dev/docs/latest/models>.
- `--both` runs both flows.

Supported auth provider keys currently include:

- `anthropic`
- `azure-openai-responses`
- `openai`
- `google`
- `mistral`
- `groq`
- `cerebras`
- `cursor`
- `xai`
- `openrouter`
- `vercel-ai-gateway`
- `zai`
- `opencode`
- `opencode-go`
- `huggingface`
- `kimi-coding`
- `minimax`
- `minimax-cn`

The script preserves other auth entries, backs up any existing `auth.json`, and writes the file with `0600` permissions.

For custom providers/models, the script writes `~/.pi/agent/models.json` like this:

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "http://localhost:11434/v1",
      "api": "openai-completions",
      "apiKey": "ollama",
      "models": [
        {
          "id": "llama3.1:8b",
          "contextWindow": 128000,
          "maxTokens": 16384
        }
      ]
    }
  }
}
```

The `models.json` helper supports the documented API types `openai-completions`, `openai-responses`, `anthropic-messages`, and `google-generative-ai`. It offers token presets: Standard coding (`contextWindow: 128000`, `maxTokens: 16384`), Small/local (`32000`, `4096`), Large coding (`200000`, `32000`), Huge context (`1000000`, `65536`), or custom positive integer values. It preserves existing providers/models, upserts model IDs for the selected provider, and does not remove other existing models when rerun with the same provider key. It backs up any existing `models.json` and writes the file with `0600` permissions. Prefer `$ENV_VAR`, `${ENV_VAR}`, or `!command` API key config values instead of storing raw secrets in `models.json`.

## Notes

- `skills-install.json` is optional; an empty object means no external skills are installed or removed
- `packages.json` is optional; missing or invalid package config is skipped with a warning
- `packages.json` must contain a `packages` object of `"package-name": true|false` entries
- `skills-install.json` should map repository URLs to `"skill-name": true|false` entries; legacy skill name arrays are still treated as enabled skills
- `jq` is required to parse `packages.json` and `skills-install.json`
- `npx` is required to run the `skills` CLI installer
- `python3` is required for `settings.json` merges and the provider setup helper
- `models.json` is treated as machine-local provider configuration and is protected from installer syncs like `auth.json`
- Default pi global config dir: `~/.pi/agent`
- Override with `PI_CODING_AGENT_DIR` or `./install.sh --pi-dir ...`
- Existing conflicting files are removed before being replaced
- `--clean` removes repo-managed config targets before reinstalling them, skips `auth.json`, `models.json`, and `sessions/`, removes configured pi packages, and installs enabled packages again
- External skill install and removal failures are reported, but the installer continues with other configured skills
- Shared package installs and removals are skipped when `pi` is not yet on `PATH`
- `--update-packages` now runs a single `pi update` after package sync instead of updating configured packages one by one
