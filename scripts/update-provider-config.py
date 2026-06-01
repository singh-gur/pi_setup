#!/usr/bin/env python3
"""Update local pi provider auth and custom model configuration files."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import tempfile
from pathlib import Path
from typing import Any

LOG_PREFIX = "[pi-provider]"


def parse_bool(value: str) -> bool:
    if value == "1":
        return True
    if value == "0":
        return False
    raise argparse.ArgumentTypeError("expected 0 or 1")


def parse_positive_int(value: str) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("expected a positive integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("expected a positive integer")
    return parsed


def load_object(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}

    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{LOG_PREFIX} error: {path} is not valid JSON: {exc}") from exc

    if not isinstance(data, dict):
        raise SystemExit(f"{LOG_PREFIX} error: {path} must contain a JSON object")

    return data


def backup_existing(path: Path, backup_suffix: str) -> None:
    if not path.exists():
        return

    backup_path = path.with_name(f"{path.name}.bak.{backup_suffix}")
    shutil.copy2(path, backup_path)
    print(f"{LOG_PREFIX} backed up {path} -> {backup_path}")


def atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=str(path.parent),
    )
    try:
        os.fchmod(fd, stat.S_IRUSR | stat.S_IWUSR)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, sort_keys=True)
            f.write("\n")
        os.replace(tmp_path, path)
        os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def update_auth(args: argparse.Namespace) -> None:
    api_key = os.environ.get("API_KEY_VALUE")
    if not api_key:
        raise SystemExit(f"{LOG_PREFIX} error: API_KEY_VALUE environment variable is required")

    auth_path = Path(args.file).expanduser()
    auth_path.parent.mkdir(parents=True, exist_ok=True)

    data = load_object(auth_path)
    backup_existing(auth_path, args.backup_suffix)

    data[args.provider] = {"type": "api_key", "key": api_key}
    atomic_write_json(auth_path, data)

    print(f"{LOG_PREFIX} wrote auth provider '{args.provider}' to {auth_path}")
    print(f"{LOG_PREFIX} permissions set to 0600")


def parse_model_ids(value: str) -> list[str]:
    model_ids = [item.strip() for item in value.split(",") if item.strip()]
    if not model_ids:
        raise SystemExit(f"{LOG_PREFIX} error: at least one model id is required")
    return model_ids


def update_models(args: argparse.Namespace) -> None:
    api_key_value = os.environ.get("API_KEY_CONFIG_VALUE")
    if api_key_value is None:
        raise SystemExit(f"{LOG_PREFIX} error: API_KEY_CONFIG_VALUE environment variable is required")

    model_ids = parse_model_ids(args.model_ids)
    models_path = Path(args.file).expanduser()
    models_path.parent.mkdir(parents=True, exist_ok=True)

    data = load_object(models_path)
    backup_existing(models_path, args.backup_suffix)

    providers = data.setdefault("providers", {})
    if not isinstance(providers, dict):
        raise SystemExit(f"{LOG_PREFIX} error: {models_path} providers must be a JSON object")

    existing_provider = providers.get(args.provider, {})
    if existing_provider is None:
        existing_provider = {}
    if not isinstance(existing_provider, dict):
        raise SystemExit(
            f"{LOG_PREFIX} error: provider '{args.provider}' in {models_path} must be a JSON object"
        )

    provider_config = dict(existing_provider)
    provider_config["baseUrl"] = args.base_url
    provider_config["api"] = args.api
    provider_config["apiKey"] = api_key_value

    if args.auth_header:
        provider_config["authHeader"] = True

    if args.local_compat:
        compat = provider_config.get("compat", {})
        if compat is None:
            compat = {}
        if not isinstance(compat, dict):
            raise SystemExit(
                f"{LOG_PREFIX} error: provider '{args.provider}' compat must be a JSON object"
            )
        compat.setdefault("supportsDeveloperRole", False)
        compat.setdefault("supportsReasoningEffort", False)
        provider_config["compat"] = compat

    existing_models = provider_config.get("models", [])
    if existing_models is None:
        existing_models = []
    if not isinstance(existing_models, list):
        raise SystemExit(
            f"{LOG_PREFIX} error: provider '{args.provider}' models must be a JSON array"
        )

    merged_models: list[Any] = []
    positions: dict[str, int] = {}
    for model in existing_models:
        if isinstance(model, dict) and isinstance(model.get("id"), str):
            positions[model["id"]] = len(merged_models)
        merged_models.append(model)

    existing_model_count = len(merged_models)
    added_model_count = 0
    updated_model_count = 0
    for model_id in model_ids:
        model_config: dict[str, Any] = {"id": model_id}
        if args.reasoning:
            model_config["reasoning"] = True
        if args.image_input:
            model_config["input"] = ["text", "image"]
        model_config["contextWindow"] = args.context_window
        model_config["maxTokens"] = args.max_tokens

        if model_id in positions and isinstance(merged_models[positions[model_id]], dict):
            updated = dict(merged_models[positions[model_id]])
            updated.update(model_config)
            merged_models[positions[model_id]] = updated
            updated_model_count += 1
        else:
            positions[model_id] = len(merged_models)
            merged_models.append(model_config)
            added_model_count += 1

    provider_config["models"] = merged_models
    providers[args.provider] = provider_config
    atomic_write_json(models_path, data)

    preserved_model_count = existing_model_count - updated_model_count
    print(f"{LOG_PREFIX} wrote models provider '{args.provider}' to {models_path}")
    print(f"{LOG_PREFIX} model ids: {', '.join(model_ids)}")
    print(
        f"{LOG_PREFIX} merged models: preserved {preserved_model_count}, "
        f"updated {updated_model_count}, added {added_model_count}"
    )
    print(f"{LOG_PREFIX} permissions set to 0600")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    auth_parser = subparsers.add_parser("auth", help="update auth.json")
    auth_parser.add_argument("--file", required=True)
    auth_parser.add_argument("--backup-suffix", required=True)
    auth_parser.add_argument("--provider", required=True)
    auth_parser.set_defaults(func=update_auth)

    models_parser = subparsers.add_parser("models", help="update models.json")
    models_parser.add_argument("--file", required=True)
    models_parser.add_argument("--backup-suffix", required=True)
    models_parser.add_argument("--provider", required=True)
    models_parser.add_argument("--base-url", required=True)
    models_parser.add_argument("--api", required=True)
    models_parser.add_argument("--model-ids", required=True)
    models_parser.add_argument("--auth-header", type=parse_bool, required=True)
    models_parser.add_argument("--local-compat", type=parse_bool, required=True)
    models_parser.add_argument("--reasoning", type=parse_bool, required=True)
    models_parser.add_argument("--image-input", type=parse_bool, required=True)
    models_parser.add_argument("--context-window", type=parse_positive_int, required=True)
    models_parser.add_argument("--max-tokens", type=parse_positive_int, required=True)
    models_parser.set_defaults(func=update_models)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
