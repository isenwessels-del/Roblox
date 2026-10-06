#!/usr/bin/env python3
"""Exercise actual game services with deterministic engine-boundary adapters."""
from pathlib import Path
import subprocess
import tempfile
from shared_runner import bundle, ROOT

shared = bundle()
shared_cases = (ROOT / 'tests/shared.spec.luau').read_text()
assert shared.endswith(shared_cases)
shared = shared[:-len(shared_cases)]
parts = [(ROOT / 'tests/core-harness.luau').read_text(), shared]
modules = ['EconomyService', 'InventoryService', 'HouseService', 'HeatService',
           'SecurityService', 'AntiExploitService', 'ItemService', 'RobberyService',
           'QuestService', 'NetworkService']
for module in modules:
    source = (ROOT / f'src/server/{module}.luau').read_text()
    parts.append(f'local {module} = (function()\n{source}\nend)()')
parts.append((ROOT / 'tests/core-cases.luau').read_text())
with tempfile.TemporaryDirectory(prefix='steal-house-core-') as directory:
    target = Path(directory) / 'core.luau'
    target.write_text('\n'.join(parts))
    subprocess.run([str(ROOT / '.tools/luau'), str(target)], cwd=ROOT, check=True)
