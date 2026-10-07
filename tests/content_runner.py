#!/usr/bin/env python3
"""Run actual configuration/schema modules with a Roblox require lookup adapter."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
config = (ROOT / 'src/shared/Config.luau').read_text()
schema = (ROOT / 'src/shared/ProfileSchema.luau').read_text()
spec = (ROOT / 'tests/content.spec.luau').read_text()
config_require = 'local Config = require("../src/shared/Config")'
schema_require = 'local Schema = require("../src/shared/ProfileSchema")'
lookup = 'local Config = require(script.Parent.Config)'
assert spec.count(config_require) == 1
assert spec.count(schema_require) == 1
assert schema.count(lookup) == 1
schema = schema.replace(lookup, 'local Config = Config', 1)
adapted = spec.replace(config_require, 'local Config = (function()\n' + config + '\nend)()', 1)
adapted = adapted.replace(schema_require, 'local Schema = (function()\n' + schema + '\nend)()', 1)
(ROOT / 'build').mkdir(exist_ok=True)
with tempfile.NamedTemporaryFile(mode='w', suffix='.luau', dir=ROOT / 'build') as script:
    script.write(adapted)
    script.flush()
    subprocess.run([str(ROOT / '.tools/luau'), script.name], cwd=ROOT, check=True)
