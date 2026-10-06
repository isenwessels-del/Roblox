#!/usr/bin/env python3
"""Bundle Roblox module dependencies for pure CLI validation, then run the cases.

Only require expressions for the test's three known dependencies are replaced;
all configuration, migrations, validators and utility implementation come from
current source files rather than copies or implementation-shaped mocks.
"""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "src/shared"
CONFIG_MODULES = {
    "Game": "GameConfig", "Economy": "EconomyConfig", "Items": "ItemConfig",
    "Rarities": "RarityConfig", "Houses": "HouseConfig", "Backpacks": "BackpackConfig",
    "Security": "SecurityConfig", "Tools": "ToolConfig", "Quests": "QuestConfig",
    "Events": "EventConfig", "Monetization": "MonetizationConfig",
}

def bundle():
    parts = []

    def embed(name, filename, replacements=None):
        source = (SHARED / filename).read_text()
        for expression, replacement in (replacements or {}).items():
            assert expression in source, f"Expected dependency missing: {expression}"
            source = source.replace(expression, replacement)
        parts.append(f"local {name} = (function()\n{source}\nend)()\n")

    for key, module in CONFIG_MODULES.items():
        embed("Config" + key, f"Config/{module}.luau")
    parts.append("local Config = {" + ",".join(
        key + "=Config" + key for key in CONFIG_MODULES) + "}\n")
    for name in ("TableUtils", "Validation", "WeightedRandom", "FormatNumber"):
        embed(name, f"Utilities/{name}.luau")
    embed("ProfileSchema", "ProfileSchema.luau", {
        "local Config = require(script.Parent.Config)": "",
        "local TableUtils = require(script.Parent.Utilities.TableUtils)": "",
        "local Validation = require(script.Parent.Utilities.Validation)": "",
    })
    parts.append((ROOT / "tests/shared.spec.luau").read_text())
    return "\n".join(parts)

if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="steal-house-shared-") as directory:
        target = Path(directory) / "shared.luau"
        target.write_text(bundle())
        subprocess.run([str(ROOT / ".tools/luau"), str(target)], cwd=ROOT, check=True)
