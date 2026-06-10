#!/usr/bin/env python3
"""Verify a NatSpec-only change: compiled code must be byte-identical.

Compares deployedBytecode between two forge `out/` dirs after stripping the
trailing CBOR metadata section (its hash covers source text, so comment-only
edits legitimately change it; everything before it must be identical).

Usage: python3 check-comment-only.py <baseline-out-dir> <changed-out-dir>
Exit 0 = all matching artifacts have identical executable bytecode.
"""

import json
import sys
from pathlib import Path


def strip_metadata(code: str) -> str:
    """Drop the CBOR metadata tail: last 2 bytes encode its length."""
    if not code or code in ("0x", ""):
        return code
    h = code[2:] if code.startswith("0x") else code
    if len(h) < 4:
        return h
    cbor_len = int(h[-4:], 16) * 2
    if cbor_len + 4 > len(h):
        return h
    return h[: -(cbor_len + 4)]


def collect(out_dir: Path) -> dict[str, str]:
    result = {}
    for artifact in out_dir.rglob("*.json"):
        if artifact.parent.name == "build-info":
            continue
        try:
            data = json.loads(artifact.read_text())
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        meta = data.get("metadata")
        if not isinstance(meta, dict):
            continue
        target = meta.get("settings", {}).get("compilationTarget", {})
        if len(target) != 1:
            continue
        key = "{}:{}".format(*next(iter(target.items())))
        deployed = (data.get("deployedBytecode") or {}).get("object", "")
        result[key] = strip_metadata(deployed)
    return result


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    base = collect(Path(sys.argv[1]))
    changed = collect(Path(sys.argv[2]))
    failures = []
    for key, code in sorted(changed.items()):
        if key not in base:
            failures.append(f"NEW artifact (not in baseline): {key}")
        elif base[key] != code:
            failures.append(f"BYTECODE CHANGED: {key}")
    missing = sorted(set(base) - set(changed))
    for key in missing:
        failures.append(f"artifact disappeared: {key}")
    if failures:
        print("\n".join(failures))
        sys.exit(1)
    print(f"OK: {len(changed)} artifacts, executable bytecode identical")


if __name__ == "__main__":
    main()
