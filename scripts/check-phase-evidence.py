#!/usr/bin/env python3
"""Summarize BeeNut phase evidence from validation run directories."""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_VALIDATION_DIR = ROOT / "build" / "phase-validation"


@dataclass(frozen=True)
class Requirement:
    phase: str
    item: str
    target: str
    automated_checks: tuple[str, ...]
    manual_evidence: tuple[str, ...] = ()


@dataclass(frozen=True)
class ManualEvidence:
    item: str
    covers: tuple[str, ...]
    files: tuple[Path, ...]
    notes: str
    source: Path


REQUIREMENTS: tuple[Requirement, ...] = (
    Requirement(
        "Phase 1",
        "M15 camera formats",
        "camera target",
        ("camera-inventory", "gstreamer-inventory"),
        ("capabilities.json or backend capability snapshot",),
    ),
    Requirement(
        "Phase 1",
        "N8 libgpiod support",
        "Pi/SBC GPIO target",
        ("gpio-inventory",),
        ("backend GPIO ready/blocked diagnostic event",),
    ),
    Requirement(
        "Phase 3",
        "Capability-driven platform model",
        "each target class",
        ("camera-inventory", "gstreamer-inventory", "ai-runtime-inventory"),
        ("backend capabilities.json for the target class",),
    ),
    Requirement(
        "Phase 3",
        "Desktop fallback behavior",
        "macOS/Linux desktop package",
        ("flutter-analyze", "flutter-test", "native-service-tests"),
        ("camera permission denial/retry observation", "camera handle released after app close"),
    ),
    Requirement(
        "Phase 3",
        "Pi/SBC primary path",
        "Raspberry Pi or supported SBC",
        ("camera-inventory", "gpio-inventory", "systemd-units"),
        ("boot-to-kiosk preview observation",),
    ),
    Requirement(
        "Phase 3",
        "Windows/Android/iOS future ports",
        "future platform target",
        (),
        ("native camera adapter validation", "preview transport validation"),
    ),
    Requirement(
        "Phase 5",
        "Image builder skeleton",
        "appliance image build host",
        ("package-inventory",),
        ("image manifest from full bootable image build",),
    ),
    Requirement(
        "Phase 5",
        "First boot service",
        "fresh appliance image",
        ("systemd-units",),
        ("/etc/beenut/device.json after first boot",),
    ),
    Requirement(
        "Phase 5",
        "Boot branding",
        "fresh appliance image",
        (),
        ("photo or console capture of BeeNut boot branding",),
    ),
    Requirement(
        "Phase 5",
        "Auto-start service/kiosk",
        "installed appliance",
        ("systemd-units",),
        ("journal-beenut-kiosk.log after reboot",),
    ),
    Requirement(
        "Phase 5",
        "Power button shutdown",
        "installed appliance with button path",
        ("systemd-units",),
        ("backend shutdown event", "system journal shutdown evidence"),
    ),
    Requirement(
        "Phase 5",
        "Factory reset",
        "installed appliance",
        ("diagnostics-bundle",),
        ("factory reset log", "post-reset config snapshot"),
    ),
    Requirement(
        "Phase 6",
        "Permission denied UX",
        "packaged desktop/mobile app",
        (),
        ("denial/retry screen recording or QA note", "app logs without crash"),
    ),
    Requirement(
        "Phase 6",
        "systemd crash restart",
        "installed Debian/Pi package",
        ("systemd-restart-policy",),
        ("journal evidence after forced service crash",),
    ),
    Requirement(
        "Phase 7",
        "Thermal throttling",
        "Raspberry Pi 5 soak target",
        ("thermal-sample",),
        ("backend thermal status metrics during sustained preview/inference",),
    ),
    Requirement(
        "Phase 7",
        "USB offline update",
        "installed Debian/Pi package",
        ("package-inventory",),
        ("offline update log", "post-reboot package version", "rollback test evidence"),
    ),
)


def load_summary(path: Path) -> dict:
    summary_path = path / "summary.json" if path.is_dir() else path
    data = json.loads(summary_path.read_text(encoding="utf-8"))
    return {
        "path": str(summary_path),
        "items": data.get("items", []),
        "passed": bool(data.get("passed", False)),
    }


def load_manual_evidence(path: Path) -> list[ManualEvidence]:
    data = json.loads(path.read_text(encoding="utf-8"))
    evidence: list[ManualEvidence] = []
    for entry in data.get("evidence", []):
        item = str(entry.get("item", "")).strip()
        covers = tuple(str(value).strip() for value in entry.get("covers", []) if str(value).strip())
        files = tuple((path.parent / value).resolve() for value in entry.get("files", []))
        notes = str(entry.get("notes", "")).strip()
        if item:
            evidence.append(
                ManualEvidence(
                    item=item,
                    covers=covers,
                    files=files,
                    notes=notes,
                    source=path,
                )
            )
    return evidence


def discover_manual_evidence(paths: Iterable[Path]) -> list[Path]:
    manifests: list[Path] = []
    for path in paths:
        base = path if path.is_dir() else path.parent
        manifest = base / "manual-evidence.json"
        if manifest.exists():
            manifests.append(manifest)
    return manifests


def load_evidence_set(path: Path) -> tuple[list[Path], list[Path]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    base = path.parent
    runs = [
        (base / value).resolve()
        for value in data.get("runs", [])
        if str(value).strip()
    ]
    manual = [
        (base / value).resolve()
        for value in data.get("manual_evidence", [])
        if str(value).strip()
    ]
    return runs, manual


def latest_summary_dirs() -> list[Path]:
    if not DEFAULT_VALIDATION_DIR.exists():
        return []
    dirs = [
        path
        for path in DEFAULT_VALIDATION_DIR.iterdir()
        if path.is_dir() and (path / "summary.json").exists()
    ]
    return sorted(dirs)[-1:]


def merged_status(summaries: Iterable[dict]) -> dict[str, dict]:
    by_name: dict[str, dict] = {}
    rank = {"pass": 3, "warn": 2, "fail": 1}
    for summary in summaries:
        for item in summary["items"]:
            name = item.get("name", "")
            status = item.get("status", "fail")
            previous = by_name.get(name)
            if previous is None or rank.get(status, 0) > rank.get(previous["status"], 0):
                by_name[name] = {
                    "status": status,
                    "log": item.get("log", ""),
                    "summary": summary["path"],
                }
    return by_name


def manual_matches(
    requirement: Requirement,
    manual_evidence: Iterable[ManualEvidence],
) -> tuple[list[dict], list[str]]:
    entries = [entry for entry in manual_evidence if entry.item == requirement.item]
    covered: set[str] = set()
    attached: list[dict] = []
    for entry in entries:
        existing_files = [path for path in entry.files if path.exists()]
        missing_files = [path for path in entry.files if not path.exists()]
        for cover in entry.covers:
            if cover in requirement.manual_evidence and not missing_files:
                covered.add(cover)
        attached.append(
            {
                "source": str(entry.source),
                "covers": list(entry.covers),
                "files": [str(path) for path in entry.files],
                "missing_files": [str(path) for path in missing_files],
                "notes": entry.notes,
                "usable": bool(existing_files) and not missing_files,
            }
        )

    missing_manual = [
        evidence for evidence in requirement.manual_evidence if evidence not in covered
    ]
    return attached, missing_manual


def evaluate_requirement(
    requirement: Requirement,
    checks: dict[str, dict],
    manual_evidence: Iterable[ManualEvidence],
) -> dict:
    missing = [
        name
        for name in requirement.automated_checks
        if checks.get(name, {}).get("status") != "pass"
    ]
    warnings = [
        name
        for name in requirement.automated_checks
        if checks.get(name, {}).get("status") == "warn"
    ]
    passed_checks = [
        name
        for name in requirement.automated_checks
        if checks.get(name, {}).get("status") == "pass"
    ]

    attached_manual, missing_manual = manual_matches(requirement, manual_evidence)

    if missing:
        status = "missing"
    elif missing_manual:
        status = "manual_required"
    else:
        status = "pass"

    return {
        "phase": requirement.phase,
        "item": requirement.item,
        "target": requirement.target,
        "status": status,
        "passed_checks": passed_checks,
        "missing_or_nonpassing_checks": missing,
        "warning_checks": warnings,
        "manual_evidence": list(requirement.manual_evidence),
        "attached_manual_evidence": attached_manual,
        "missing_manual_evidence": missing_manual,
    }


def print_table(rows: list[dict]) -> None:
    widths = {
        "phase": max(len("Phase"), *(len(row["phase"]) for row in rows)),
        "item": max(len("Item"), *(len(row["item"]) for row in rows)),
        "status": max(len("Status"), *(len(row["status"]) for row in rows)),
    }
    print(f'{"Phase":<{widths["phase"]}}  {"Status":<{widths["status"]}}  Item')
    print(f'{"-" * widths["phase"]}  {"-" * widths["status"]}  {"-" * widths["item"]}')
    for row in rows:
        print(f'{row["phase"]:<{widths["phase"]}}  {row["status"]:<{widths["status"]}}  {row["item"]}')


def placeholder_path(item: str, evidence: str) -> str:
    slug = "-".join(
        "".join(char.lower() if char.isalnum() else "-" for char in f"{item}-{evidence}").split()
    )
    while "--" in slug:
        slug = slug.replace("--", "-")
    return f"evidence/{slug.strip('-')}.txt"


def write_manual_template(rows: list[dict], output: Path) -> None:
    entries = []
    for row in rows:
        missing_manual = row.get("missing_manual_evidence", [])
        if not missing_manual:
            continue
        entries.append(
            {
                "item": row["item"],
                "covers": missing_manual,
                "files": [
                    placeholder_path(row["item"], evidence)
                    for evidence in missing_manual
                ],
                "notes": f"Attach field evidence for {row['target']}.",
            }
        )

    template = {
        "schema_version": 1,
        "target": "replace-with-target-id",
        "captured_at": "replace-with-utc-timestamp",
        "captured_by": "replace-with-operator-or-station",
        "evidence": entries,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(template, indent=2) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Summarize phase evidence from build/phase-validation runs."
    )
    parser.add_argument(
        "runs",
        nargs="*",
        type=Path,
        help="Validation run directories or summary.json files. Defaults to the latest run.",
    )
    parser.add_argument(
        "--evidence-set",
        action="append",
        type=Path,
        default=[],
        help="JSON file listing validation runs and manual-evidence manifests to combine.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Write report JSON to this path. Defaults to <latest-run>/phase-evidence-report.json.",
    )
    parser.add_argument(
        "--manual-evidence",
        action="append",
        type=Path,
        default=[],
        help=(
            "manual-evidence.json file to include. By default, each validation "
            "run directory is scanned for this file."
        ),
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when any item is missing or still needs manual evidence.",
    )
    parser.add_argument(
        "--write-manual-template",
        type=Path,
        help="Write a manual-evidence.json template for remaining manual items.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    run_paths = list(args.runs)
    manual_manifest_paths = list(args.manual_evidence)
    for evidence_set in args.evidence_set:
        set_runs, set_manual = load_evidence_set(evidence_set)
        run_paths.extend(set_runs)
        manual_manifest_paths.extend(set_manual)
    if not run_paths:
        run_paths = latest_summary_dirs()
    if not run_paths:
        raise SystemExit("No validation summary found. Run scripts/validate-phase-gates.sh first.")

    summaries = [load_summary(path) for path in run_paths]
    checks = merged_status(summaries)
    manifest_paths = manual_manifest_paths + discover_manual_evidence(run_paths)
    manual_evidence: list[ManualEvidence] = []
    for manifest_path in dict.fromkeys(manifest_paths):
        manual_evidence.extend(load_manual_evidence(manifest_path))

    rows = [
        evaluate_requirement(requirement, checks, manual_evidence)
        for requirement in REQUIREMENTS
    ]
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["status"]] = counts.get(row["status"], 0) + 1

    report = {
        "schema_version": 1,
        "evidence_sets": [str(path) for path in args.evidence_set],
        "summaries": [summary["path"] for summary in summaries],
        "manual_evidence_manifests": [str(path) for path in manifest_paths],
        "counts": counts,
        "items": rows,
    }

    output = args.output
    if output is None:
        last = run_paths[-1]
        output = (last if last.is_dir() else last.parent) / "phase-evidence-report.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if args.write_manual_template:
        write_manual_template(rows, args.write_manual_template)

    print_table(rows)
    print()
    print(f"Report: {output}")
    if args.write_manual_template:
        print(f"Manual template: {args.write_manual_template}")
    print("Summary:", ", ".join(f"{key}={value}" for key, value in sorted(counts.items())))

    if args.strict and any(row["status"] != "pass" for row in rows):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
