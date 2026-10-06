#!/usr/bin/env python3
"""Run police gameplay regressions against the current service implementation.

The Luau template supplies only engine-boundary adapters and behavioral cases.
Every invocation inserts current repository source rather than a saved copy.
"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MARKER = "-- EMBED POLICE SERVICE SOURCE HERE"


def bundle():
    template = (ROOT / "tests/police.spec.luau").read_text()
    assert template.count(MARKER) == 1, "Expected one police source placeholder"
    source = (ROOT / "src/server/PoliceService.luau").read_text()
    return template.replace(MARKER, source)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="steal-house-police-") as directory:
        target = Path(directory) / "police.luau"
        target.write_text(bundle())
        subprocess.run([str(ROOT / ".tools/luau"), str(target)], cwd=ROOT, check=True)
