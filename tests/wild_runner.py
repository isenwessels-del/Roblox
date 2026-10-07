#!/usr/bin/env python3
"""Run production wild offers and real balancing data with deterministic boundaries."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = (ROOT / "tests/wild.spec.luau").read_text()
for name, path in (
    ("Config", "shared/Config"),
    ("Wild", "server/WildHouseService"),
):
    marker = f'local {name} = require("../src/{path}")'
    assert spec.count(marker) == 1, marker
    source = (ROOT / f"src/{path}.luau").read_text()
    spec = spec.replace(marker, f"local {name} = (function()\n{source}\nend)()", 1)

with tempfile.TemporaryDirectory() as directory:
    script = Path(directory) / "wild.luau"
    script.write_text(spec)
    subprocess.run([str(ROOT / ".tools/luau"), str(script)], cwd=ROOT, check=True)
