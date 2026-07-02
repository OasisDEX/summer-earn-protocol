#!/usr/bin/env python3
"""NatSpec coverage auditor for Foundry packages.

Cross-references each contract's ABI against the solc-generated devdoc/userdoc
in forge build artifacts. solc resolves @inheritdoc and automatic NatSpec
inheritance at compile time, so implementations inheriting interface docs
count as covered.

Requires `extra_output = ["devdoc", "userdoc"]` in each package's
foundry.toml [profile.default] — without it forge omits the complete userdoc
(event/error notices, contract-level notice) from artifacts.

Method:
- Functions are audited per compiled contract (ABI vs devdoc/userdoc methods),
  filtered to names actually declared in the package's source tree so that
  inherited OpenZeppelin/LayerZero members don't pollute the gap list.
- Events/errors are deduplicated package-wide by signature (their docs live on
  the *defining* contract; inheritors expose them in the ABI undocumented).
- Items invisible to the ABI (internal/private functions, modifiers,
  structs/enums) are assessed with a source-level doc-comment heuristic and
  flagged `sourceHeuristic`.

Usage:
  python3 scripts/audit/natspec-coverage.py [--root DIR] [--packages a,b]
      [--out DIR] [--build] [--force] [--matrix] [--strict-returns]
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tomllib
from pathlib import Path

EXCLUDE_PATH_RE = re.compile(r"(^|/)(tests?|scripts?|mocks?|examples?)(/|$)", re.IGNORECASE)
EXCLUDE_FILE_RE = re.compile(r"(Mock|\.t\.sol$|\.s\.sol$)")
COMMENT_END_RE = re.compile(r"(\*/\s*$|^\s*///)")

FN_DECL_RE = re.compile(r"^\s*function\s+(\w+)\s*\(")
MOD_DECL_RE = re.compile(r"^\s*modifier\s+(\w+)")
STRUCT_ENUM_RE = re.compile(r"^\s*(struct|enum)\s+(\w+)\b")
EVENT_DECL_RE = re.compile(r"^\s*event\s+(\w+)\s*\(")
ERROR_DECL_RE = re.compile(r"^\s*error\s+(\w+)\s*\(")
PUBLIC_VAR_RE = re.compile(
    r"^\s*[\w\[\]().=>\s]+?\s+public\s+(?:constant\s+|immutable\s+|override\s+)*(\w+)\s*[=;]")


def find_packages(root: Path) -> dict[str, Path]:
    return {t.parent.name: t.parent for t in sorted(root.glob("packages/*/foundry.toml"))}


def profile_setting(toml_data: dict, key: str, default: str) -> str:
    prof = toml_data.get("profile", {}).get("default", {})
    return prof.get(key, toml_data.get(key, default))


def canonical_type(inp: dict) -> str:
    t = inp.get("type", "")
    if t.startswith("tuple"):
        inner = ",".join(canonical_type(c) for c in inp.get("components", []))
        return "(" + inner + ")" + t[len("tuple"):]
    return t


def signature(name: str, inputs: list[dict]) -> str:
    return f"{name}({','.join(canonical_type(i) for i in inputs)})"


def doc_entry(section: dict, sig: str):
    """devdoc/userdoc error entries are lists (same-sig redeclarations)."""
    entry = section.get(sig)
    if isinstance(entry, list):
        return entry[0] if entry else None
    return entry


def is_excluded(path: str) -> bool:
    return bool(EXCLUDE_PATH_RE.search(path) or EXCLUDE_FILE_RE.search(path))


def merged_docs(data: dict) -> tuple[list, dict, dict]:
    """Union top-level devdoc/userdoc (complete, needs extra_output) with the
    trimmed methods-only copies inside metadata.output (always present)."""
    meta = data.get("metadata")
    meta_out = meta.get("output", {}) if isinstance(meta, dict) else {}
    docs = {}
    for key in ("devdoc", "userdoc"):
        merged = dict(meta_out.get(key) or {})
        top = data.get(key)
        if isinstance(top, dict):
            for k, v in top.items():
                if isinstance(v, dict) and isinstance(merged.get(k), dict):
                    merged[k] = {**merged[k], **v}
                else:
                    merged[k] = v
        docs[key] = merged
    abi = data.get("abi") or meta_out.get("abi", [])
    return abi, docs["devdoc"], docs["userdoc"]


# ------------------------------------------------------------- source scan --

def has_doc_above(lines: list[str], idx: int) -> bool:
    j = idx - 1
    while j >= 0 and not lines[j].strip():
        j -= 1
    return j >= 0 and bool(COMMENT_END_RE.search(lines[j]))


def decl_visibility(lines: list[str], idx: int) -> str:
    buf = []
    for j in range(idx, min(idx + 12, len(lines))):
        buf.append(lines[j])
        if "{" in lines[j] or ";" in lines[j]:
            break
    header = " ".join(buf).split("{")[0].split(";")[0]
    for vis in ("external", "public", "internal", "private"):
        if re.search(rf"\b{vis}\b", header):
            return vis
    return "internal"


def scan_sources(pkg_dir: Path, src_dir: str):
    """One pass over src/*.sol: declared-name sets for ABI filtering plus
    doc-presence heuristic for ABI-invisible items."""
    declared = {"functions": set(), "publicVars": {}, "events": {}, "errors": {}}
    h_items, h_total, h_doc = [], 0, 0
    src_root = pkg_dir / src_dir
    if not src_root.is_dir():
        return declared, h_items, h_total, h_doc
    for sol in sorted(src_root.rglob("*.sol")):
        rel = str(sol.relative_to(pkg_dir))
        if is_excluded(rel):
            continue
        lines = sol.read_text(encoding="utf-8", errors="replace").splitlines()
        for i, line in enumerate(lines):
            if (m := EVENT_DECL_RE.match(line)):
                declared["events"].setdefault(m.group(1), rel)
                continue
            if (m := ERROR_DECL_RE.match(line)):
                declared["errors"].setdefault(m.group(1), rel)
                continue
            if (m := PUBLIC_VAR_RE.match(line)) and "function" not in line:
                declared["publicVars"].setdefault(m.group(1), rel)
                continue
            kind = name = None
            if (m := FN_DECL_RE.match(line)):
                name = m.group(1)
                declared["functions"].add(name)
                vis = decl_visibility(lines, i)
                if vis in ("internal", "private"):
                    kind = "internalFunction"
            elif (m := MOD_DECL_RE.match(line)):
                kind, name = "modifier", m.group(1)
            elif (m := STRUCT_ENUM_RE.match(line)):
                kind, name = m.group(1), m.group(2)
            if not kind:
                continue
            h_total += 1
            if has_doc_above(lines, i):
                h_doc += 1
            else:
                h_items.append({"file": rel, "kind": kind, "signature": name,
                                "missing": ["notice"], "sourceHeuristic": True})
    return declared, h_items, h_total, h_doc


# ---------------------------------------------------------------- artifact --

def audit_functions(path: str, contract: str, abi: list, devdoc: dict, userdoc: dict,
                    declared: dict, strict_returns: bool, var_map: dict):
    dd_methods = devdoc.get("methods", {})
    ud_methods = userdoc.get("methods", {})
    items = []
    c = {"total": 0, "noticeOk": 0, "paramsOk": 0, "returnsOk": 0, "fullyDocumented": 0}
    contract_doc = {"total": 1, "withTitleAndNotice": 0}

    if devdoc.get("title") and userdoc.get("notice"):
        contract_doc["withTitleAndNotice"] = 1
    else:
        missing = [k for k, ok in (("title", devdoc.get("title")),
                                   ("notice", userdoc.get("notice"))) if not ok]
        items.append({"file": path, "contract": contract, "kind": "contract",
                      "signature": contract, "missing": missing})

    for entry in abi:
        if entry.get("type") != "function":
            continue
        name = entry["name"]
        if name not in declared["functions"]:
            if name in declared["publicVars"]:
                # public state-var getter: @notice suffices; docs live on the
                # declaring contract, so dedupe package-wide like events
                sig = signature(name, entry.get("inputs", []))
                noticed = bool((ud_methods.get(sig) or {}).get("notice"))
                cur = var_map.setdefault(sig, {"documented": False,
                                               "file": declared["publicVars"][name]})
                if noticed:
                    cur["documented"] = True
            continue  # else: inherited from an external dependency; not actionable
        inputs = entry.get("inputs", [])
        outputs = entry.get("outputs", [])
        sig = signature(name, inputs)
        c["total"] += 1

        ud = ud_methods.get(sig) or {}
        dd = dd_methods.get(sig) or {}
        has_notice = bool(ud.get("notice"))
        dd_params = dd.get("params", {})
        params_ok = all(n in dd_params for n in (i["name"] for i in inputs if i.get("name")))
        dd_returns = dd.get("returns", {})
        if not outputs:
            returns_ok = True
        else:
            covered = sum((o.get("name") or f"_{idx}") in dd_returns
                          for idx, o in enumerate(outputs))
            returns_ok = covered == len(outputs)
            if not returns_ok and not strict_returns and has_notice \
                    and not any(o.get("name") for o in outputs):
                returns_ok = True  # unnamed returns: notice suffices unless --strict-returns

        c["noticeOk"] += has_notice
        c["paramsOk"] += params_ok
        c["returnsOk"] += returns_ok
        if has_notice and params_ok and returns_ok:
            c["fullyDocumented"] += 1
        else:
            missing = [k for k, ok in (("notice", has_notice), ("params", params_ok),
                                       ("returns", returns_ok)) if not ok]
            items.append({"file": path, "contract": contract, "kind": "function",
                          "signature": sig, "visibility": "public/external",
                          "missing": missing, "hasDev": bool(dd.get("details"))})
    return items, c, contract_doc


def collect_events_errors(abi: list, devdoc: dict, userdoc: dict,
                          declared: dict, ev_map: dict, er_map: dict):
    sections = {
        "event": (declared["events"], ev_map, userdoc.get("events", {}), devdoc.get("events", {})),
        "error": (declared["errors"], er_map, userdoc.get("errors", {}), devdoc.get("errors", {})),
    }  # names dicts map declared name -> declaring file
    for entry in abi:
        etype = entry.get("type")
        if etype not in sections:
            continue
        names, target, ud_sec, dd_sec = sections[etype]
        name = entry["name"]
        if name not in names:
            continue
        sig = signature(name, entry.get("inputs", []))
        ud = doc_entry(ud_sec, sig) or {}
        dd = doc_entry(dd_sec, sig) or {}
        documented = bool(ud.get("notice") or dd.get("details") or dd.get("params"))
        cur = target.setdefault(sig, {"documented": False, "file": names[name]})
        if documented:
            cur["documented"] = True


# ----------------------------------------------------------------- package --

def audit_package(pkg: str, pkg_dir: Path, build: bool, force: bool,
                  strict_returns: bool) -> dict:
    toml_data = tomllib.loads((pkg_dir / "foundry.toml").read_text())
    src_dir = profile_setting(toml_data, "src", "src")
    out_dir = profile_setting(toml_data, "out", "out")
    if not (pkg_dir / src_dir).is_dir() and (pkg_dir / "contracts").is_dir():
        src_dir = "contracts"  # forge auto-detects contracts/ when src/ is absent

    if build:
        cmd = ["forge", "build"] + (["--force"] if force else [])
        subprocess.run(cmd, cwd=pkg_dir, check=True, capture_output=True, text=True)

    declared, h_items, h_total, h_doc = scan_sources(pkg_dir, src_dir)

    totals = {
        "contracts": {"total": 0, "withTitleAndNotice": 0},
        "functions": {"total": 0, "noticeOk": 0, "paramsOk": 0, "returnsOk": 0,
                      "fullyDocumented": 0},
        "stateVars": {"total": 0, "documented": 0},
        "events": {"total": 0, "documented": 0},
        "errors": {"total": 0, "documented": 0},
        "internalItems": {"total": h_total, "documented": h_doc, "sourceHeuristic": True},
    }
    all_items = []
    seen = set()
    ev_map: dict = {}
    er_map: dict = {}
    var_map: dict = {}

    for artifact in sorted((pkg_dir / out_dir).rglob("*.json")):
        if artifact.parent.name == "build-info":
            continue
        try:
            data = json.loads(artifact.read_text())
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if not isinstance(data, dict):
            continue
        meta = data.get("metadata")
        if not isinstance(meta, dict):
            continue
        target = meta.get("settings", {}).get("compilationTarget", {})
        if len(target) != 1:
            continue
        path, contract = next(iter(target.items()))
        if not path.startswith(src_dir.rstrip("/") + "/") or is_excluded(path):
            continue
        if (path, contract) in seen:
            continue
        seen.add((path, contract))
        abi, devdoc, userdoc = merged_docs(data)
        items, c, cdoc = audit_functions(path, contract, abi, devdoc, userdoc,
                                         declared, strict_returns, var_map)
        all_items.extend(items)
        for k, v in c.items():
            totals["functions"][k] += v
        for k, v in cdoc.items():
            totals["contracts"][k] += v
        collect_events_errors(abi, devdoc, userdoc, declared, ev_map, er_map)

    for kind, mapping in (("event", ev_map), ("error", er_map), ("stateVar", var_map)):
        key = "stateVars" if kind == "stateVar" else kind + "s"
        totals[key]["total"] = len(mapping)
        for sig, info in sorted(mapping.items()):
            if info["documented"]:
                totals[key]["documented"] += 1
            else:
                all_items.append({"file": info["file"], "kind": kind,
                                  "signature": sig, "missing": ["notice"]})
    all_items.extend(h_items)

    covered = (totals["contracts"]["withTitleAndNotice"] + totals["functions"]["noticeOk"]
               + totals["events"]["documented"] + totals["errors"]["documented"]
               + totals["stateVars"]["documented"] + h_doc)
    surface = (totals["contracts"]["total"] + totals["functions"]["total"]
               + totals["events"]["total"] + totals["errors"]["total"]
               + totals["stateVars"]["total"] + h_total)
    pct = round(100 * covered / surface, 1) if surface else 100.0

    fn = totals["functions"]
    if surface == 0:
        verdict = "empty"
    elif pct >= 90 and (fn["total"] == 0 or fn["fullyDocumented"] / fn["total"] >= 0.85):
        verdict = "thorough"
    elif pct >= 55:
        verdict = "partial"
    else:
        verdict = "sparse"

    return {
        "package": pkg,
        "repo": "summer-earn-protocol",
        "language": "solidity",
        "srcDir": src_dir,
        "artifactsAudited": len(seen),
        "metrics": totals,
        "coveragePct": pct,
        "items": sorted(all_items, key=lambda i: (i["file"], i.get("contract", ""),
                                                  i["signature"])),
        "quality": {},
        "verdict": verdict,
    }


def render_matrix(reports: list[dict], out_path: Path):
    lines = [
        "# NatSpec coverage matrix — summer-earn-protocol",
        "",
        "Coverage = items with @notice (functions/events/errors/contract-level)",
        "plus doc-commented internal items, over the documentable surface of the",
        "package source dir (tests, scripts, mocks and inherited external-library",
        "members excluded). `full` additionally requires complete @param/@return.",
        "",
        "| Package | Contracts | Pub/ext fns (notice / full) | State vars | Events | Errors | Internal items | Coverage | Verdict |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for r in sorted(reports, key=lambda r: r["coveragePct"]):
        m = r["metrics"]
        fn, ev, er, ii, ct, sv = (m["functions"], m["events"], m["errors"],
                              m["internalItems"], m["contracts"], m["stateVars"])
        lines.append(
            f"| {r['package']} | {ct['withTitleAndNotice']}/{ct['total']} "
            f"| {fn['noticeOk']}/{fn['total']} ({fn['fullyDocumented']} full) "
            f"| {sv['documented']}/{sv['total']} "
            f"| {ev['documented']}/{ev['total']} | {er['documented']}/{er['total']} "
            f"| {ii['documented']}/{ii['total']} | {r['coveragePct']}% | {r['verdict']} |")
    out_path.write_text("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=None)
    ap.add_argument("--packages", default=None)
    ap.add_argument("--out", default="docs/audit/2026-06/coverage")
    ap.add_argument("--build", action="store_true", help="forge build per package first")
    ap.add_argument("--force", action="store_true", help="forge build --force (with --build)")
    ap.add_argument("--matrix", action="store_true")
    ap.add_argument("--strict-returns", action="store_true")
    args = ap.parse_args()

    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[2]
    pkgs = find_packages(root)
    if args.packages:
        wanted = args.packages.split(",")
        missing = [w for w in wanted if w not in pkgs]
        if missing:
            sys.exit(f"unknown packages: {missing}; available: {sorted(pkgs)}")
        pkgs = {k: pkgs[k] for k in wanted}

    out_dir = root / args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    reports = []
    for pkg, pkg_dir in pkgs.items():
        report = audit_package(pkg, pkg_dir, args.build, args.force, args.strict_returns)
        reports.append(report)
        (out_dir / f"{pkg}.json").write_text(json.dumps(report, indent=2) + "\n")
        m = report["metrics"]["functions"]
        print(f"{pkg}: {report['coveragePct']}% ({report['verdict']}) — "
              f"fns {m['noticeOk']}/{m['total']} notice, {m['fullyDocumented']} full; "
              f"{report['artifactsAudited']} artifacts")

    if args.matrix:
        render_matrix(reports, out_dir.parent / "coverage-matrix.md")
        print(f"matrix → {out_dir.parent / 'coverage-matrix.md'}")


if __name__ == "__main__":
    main()
