#!/usr/bin/env python3
"""Build, compile, and execute reproducible tests. Engine adapters are labelled."""
from collections import Counter
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / '.tools'

def run(*args):
    subprocess.run([str(arg) for arg in args], cwd=ROOT, check=True)

(ROOT / 'build').mkdir(exist_ok=True)
run(TOOLS / 'rojo', 'build', 'default.project.json', '-o', 'build/StealAHouse.rbxlx')
place = ET.parse(ROOT / 'build/StealAHouse.rbxlx').getroot()
exported = []
classes = Counter()
for item in place.iter('Item'):
    if item.get('class') in {'Script', 'LocalScript', 'ModuleScript'}:
        props = item.find('Properties')
        source = next((p.text for p in props if p.get('name') == 'Source'), None)
        assert source, 'Built script has no source'
        exported.append(source)
        classes[item.get('class')] += 1
sources = sorted((ROOT / 'src').rglob('*.luau'))
assert Counter(exported) == Counter(path.read_text() for path in sources), 'Rojo source export mismatch'
assert classes['Script'] == 1 and classes['LocalScript'] == 1, 'Duplicate/missing bootstrap'
for path in sources:
    subprocess.run([str(TOOLS / 'luau-compile'), str(path)], cwd=ROOT,
                   stdout=subprocess.DEVNULL, check=True)
print(f'PASS: {len(sources)} game scripts compiled and exported; one server/client bootstrap each.', flush=True)
run(sys.executable, 'tests/content_runner.py')
run(TOOLS / 'luau', 'tests/data.spec.luau')
run(TOOLS / 'luau', 'tests/ownership.spec.luau')
run(TOOLS / 'luau', 'tests/progression.spec.luau')
run(sys.executable, 'tests/steal_runner.py')
run(sys.executable, 'tests/house_runner.py')
run(TOOLS / 'luau', 'tests/network.spec.luau')
run(sys.executable, 'tests/wild_runner.py')
run(TOOLS / 'luau', 'tests/player.spec.luau')
run(sys.executable, 'tests/world_runner.py')
print('All automated checks passed. Roblox engine/multiplayer/device tests remain Studio checks.', flush=True)
