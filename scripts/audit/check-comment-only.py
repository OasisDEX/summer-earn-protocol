#!/usr/bin/env python3
"""Verify a NatSpec-only change: compiled code must be byte-identical.

Compares deployedBytecode between two forge `out/` dirs after stripping the
trailing CBOR metadata section (its hash covers source text, so comment-only
edits legitimately change it; everything before it must be identical).

Usage: python3 check-comment-only.py <baseline-out-dir> <changed-out-dir>
Exit 0 = all matching artifacts have identical executable bytecode.
"""

import json
import re
import sys
from pathlib import Path

# Solidity appends a CBOR metadata blob to each contract's bytecode. A factory's
# runtime bytecode also embeds the *creation* bytecode of every child contract
# it deploys, so a single deployedBytecode can contain MULTIPLE metadata blobs.
# Each blob's trailing hash is derived from the source text, so it changes on
# any comment/formatting edit even when the executable opcodes are identical.
# Strip every blob (ipfs or bzzr0/bzzr1 variants) so the comparison sees only
# executable code.
_META_RE = re.compile(
    r"a264697066735822[0-9a-f]{68}64736f6c6343[0-9a-f]{6}0033"  # ipfs CID v0
    r"|a265627a7a72(?:58|31)[0-9a-f]{2}[0-9a-f]{64}64736f6c6343[0-9a-f]{6}0032",  # bzzr
    re.IGNORECASE,
)


def strip_metadata(code: str) -> str:
    """Remove all CBOR metadata blobs (trailing + factory-embedded children)."""
    if not code or code in ("0x", ""):
        return code
    h = code[2:] if code.startswith("0x") else code
    return _META_RE.sub("", h)


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
