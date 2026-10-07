#!/usr/bin/env python3
"""Run the production steal state machine against deterministic engine boundaries."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
service = (root / "src/server/StealService.luau").read_text()
spec = (root / "tests/steal.spec.luau").read_text()
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "steal.luau"
    path.write_text("local StealService = (function()\n" + service + "\nend)()\n" + spec)
    subprocess.run([str(root / ".tools/luau"), str(path)], check=True)
