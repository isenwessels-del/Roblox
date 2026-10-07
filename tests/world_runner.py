#!/usr/bin/env python3
"""Run current neighborhood world/factory/guards against primitive engine mocks.

Checks source object contracts and state changes, not actual rendering or physics.
"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
modules = []
for name, path in (("Config", "src/shared/Config.luau"),
                   ("Factory", "src/server/ModelFactory.luau"),
                   ("World", "src/server/WorldService.luau"),
                   ("Guard", "src/server/GuardService.luau")):
    source = (ROOT / path).read_text()
    if name == "World":
        lookup = "local Factory = require(script.Parent.ModelFactory)"
        assert source.count(lookup) == 1
        source = source.replace(lookup, "", 1)
    modules.append(f"local {name}=(function()\n{source}\nend)()")
spec = (ROOT / "tests/world.spec.luau").read_text()
assert spec.count("-- EMBED WORLD MODULES HERE") == 1
spec = spec.replace("-- EMBED WORLD MODULES HERE", "\n".join(modules))
spec += "\n" + (ROOT / "tests/guard.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="house-neighborhood-world-") as directory:
    path = Path(directory) / "world.luau"
    path.write_text(spec)
    subprocess.run([str(ROOT / ".tools/luau"), str(path)], cwd=ROOT, check=True)
