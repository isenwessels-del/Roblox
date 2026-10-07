#!/usr/bin/env python3
"""Execute production house economy + canonical ledger with injected boundaries."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
spec = (ROOT / "tests/house.spec.luau").read_text()
config = (ROOT / "src/shared/Config.luau").read_text()
schema = (ROOT / "src/shared/ProfileSchema.luau").read_text()
lookup = "local Config = require(script.Parent.Config)"
assert schema.count(lookup) == 1
schema = schema.replace(lookup, "local Config = Config", 1)
modules = {
    "Config": ("shared/Config", config),
    "Schema": ("shared/ProfileSchema", schema),
    "Ownership": ("server/OwnershipService", (ROOT / "src/server/OwnershipService.luau").read_text()),
    "Houses": ("server/HouseService", (ROOT / "src/server/HouseService.luau").read_text()),
    "Progression": ("server/ProgressionService", (ROOT / "src/server/ProgressionService.luau").read_text()),
}
for name, (path, source) in modules.items():
    marker = f'local {name} = require("../src/{path}")'
    assert spec.count(marker) == 1, marker
    spec = spec.replace(marker, f"local {name} = (function()\n{source}\nend)()", 1)
(ROOT / "build").mkdir(exist_ok=True)
with tempfile.NamedTemporaryFile(mode="w", suffix=".luau", dir=ROOT / "build") as script:
    script.write(spec)
    script.flush()
    subprocess.run([str(ROOT / ".tools/luau"), script.name], cwd=ROOT, check=True)
