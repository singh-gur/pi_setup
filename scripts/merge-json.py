#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def die(message: str) -> None:
    print(f"[pi-setup] error: {message}", file=sys.stderr)
    raise SystemExit(1)


def merge(existing, managed):
    if isinstance(existing, dict) and isinstance(managed, dict):
        result = dict(existing)
        for key, value in managed.items():
            if key in result:
                result[key] = merge(result[key], value)
            else:
                result[key] = value
        return result
    return managed


def load_json(path: Path):
    try:
        with path.open() as file:
            return json.load(file)
    except json.JSONDecodeError as exc:
        die(f"failed to parse JSON from {path}: {exc}")
    except OSError as exc:
        die(f"failed to read {path}: {exc}")


if len(sys.argv) != 4:
    die("usage: merge-json.py <source-json> <target-json> <output-json>")

source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])

source_data = load_json(source_path)
target_data = load_json(target_path) if target_path.exists() else {}

if not isinstance(source_data, dict):
    die(f"expected top-level JSON object in {source_path}")
if not isinstance(target_data, dict):
    die(f"expected top-level JSON object in {target_path}")

merged = merge(target_data, source_data)

try:
    with out_path.open("w") as file:
        json.dump(merged, file, indent=2)
        file.write("\n")
except OSError as exc:
    die(f"failed to write {out_path}: {exc}")
