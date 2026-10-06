#!/usr/bin/env python3
"""Install pinned official Linux x86_64 tools with TLS and SHA-256 verification."""
from pathlib import Path
import hashlib
import platform
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
if platform.system() != 'Linux' or platform.machine() != 'x86_64':
    raise SystemExit('This helper targets Linux x86_64. Install Rojo 7.6.1 and Luau 0.699 from their official releases for your platform.')
assets = [
    ('https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-linux-x86_64.zip',
     'a9542a713036897fdbd0173e7a105ea409658333133c949025fcb6f1a7ca909d', ['rojo']),
    ('https://github.com/luau-lang/luau/releases/download/0.699/luau-ubuntu.zip',
     '4169f04aa66c8f5039d5cb2257aab9e81674ec152a8d84bda96c12cdb9fa973a', ['luau', 'luau-compile']),
]
tools = ROOT / '.tools'
tools.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='steal-house-tools-') as directory:
    for index, (url, expected, names) in enumerate(assets):
        target = Path(directory) / f'{index}.zip'
        subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error',
                        '--retry', '2', '--max-time', '120', url, '-o', str(target)], check=True)
        if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
            raise SystemExit(f'SHA-256 verification failed: {url}')
        with zipfile.ZipFile(target) as archive:
            for name in names:
                output = tools / name
                output.write_bytes(archive.read(name))
                output.chmod(0o755)
print('Installed Rojo 7.6.1 and Luau 0.699 in .tools/')
