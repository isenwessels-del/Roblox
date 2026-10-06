#!/usr/bin/env python3
"""Execute current world and model modules against deterministic Roblox primitive mocks.

This checks generated object contracts, plot uniqueness, safe zones and bounded
item footprints. It does not simulate Roblox physics, replication or rendering.
"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def bundle():
    modules = []
    for key, name in (("Game", "Game"), ("Houses", "House"), ("Items", "Item"),
                      ("Rarities", "Rarity"), ("Security", "Security")):
        source = (ROOT / f"src/shared/Config/{name}Config.luau").read_text()
        modules.append(f"local {key}=(function()\n{source}\nend)()")
    source = (ROOT / "src/server/ModelFactory.luau").read_text()
    modules.append(f"local Factory=(function()\n{source}\nend)()")
    source = (ROOT / "src/server/WorldService.luau").read_text()
    dependency = "local Factory = require(script.Parent.ModelFactory)"
    assert dependency in source
    source = source.replace(dependency, "")
    modules.append(f"local World=(function()\n{source}\nend)()")
    template = (ROOT / "tests/world.spec.luau").read_text()
    marker = "-- EMBED WORLD MODULES HERE"
    assert template.count(marker) == 1
    return template.replace(marker, "\n".join(modules))


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="steal-house-world-") as directory:
        target = Path(directory) / "world.luau"
        target.write_text(bundle())
        subprocess.run([str(ROOT / ".tools/luau"), str(target)], cwd=ROOT, check=True)
