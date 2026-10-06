#!/usr/bin/env python3
"""Prepare source/place ZIP and a verified self-contained offline Windows transfer."""
from pathlib import Path
import base64
import gzip
import hashlib
import json
import textwrap
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
place = BUILD / 'StealAHouse.rbxlx'
if not place.is_file():
    raise SystemExit('Run python scripts/check.py before packaging.')
raw = place.read_bytes()
checksum = hashlib.sha256(raw).hexdigest()
payload = '\n'.join(textwrap.wrap(base64.b64encode(gzip.compress(raw, mtime=0)).decode('ascii'), 100))
assert gzip.decompress(base64.b64decode(payload)) == raw
script = """& {
    $ErrorActionPreference = 'Stop'
    $payload = @'
""" + payload + """
'@
    $inputStream = [IO.MemoryStream]::new([Convert]::FromBase64String($payload))
    $gzip = [IO.Compression.GzipStream]::new($inputStream, [IO.Compression.CompressionMode]::Decompress)
    $outputStream = [IO.MemoryStream]::new()
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $gzip.CopyTo($outputStream)
        $bytes = $outputStream.ToArray()
        $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
        if ($hash -ne '""" + checksum + """') {
            throw 'File verification failed. Nothing has been saved.'
        }
        $name = 'StealAHouse-launch-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.rbxlx'
        $path = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) $name
        if ([IO.File]::Exists($path)) { throw 'File already exists. Try again.' }
        [IO.File]::WriteAllBytes($path, $bytes)
        Write-Host "Success! Open in Roblox Studio: $path"
    }
    finally {
        $gzip.Dispose()
        $inputStream.Dispose()
        $outputStream.Dispose()
        $sha.Dispose()
    }
}
"""
transfer = BUILD / 'StealAHouse-Windows.ps1'
transfer.write_text(script, encoding='utf-8')
archive_path = BUILD / 'StealAHouse-launch.zip'
manifest = {}
with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path, name in [(place, 'StealAHouse/StealAHouse.rbxlx'),
                       (transfer, 'StealAHouse/StealAHouse-Windows.ps1')]:
        archive.write(path, name)
        manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ['.gitignore', 'README.md', 'default.project.json']:
        path = ROOT / name
        key = 'StealAHouse/project/' + name
        archive.write(path, key)
        manifest[key] = hashlib.sha256(path.read_bytes()).hexdigest()
    for directory in ['src', 'scripts', 'tests', 'docs']:
        for path in sorted((ROOT / directory).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc':
                key = 'StealAHouse/project/' + path.relative_to(ROOT).as_posix()
                archive.write(path, key)
                manifest[key] = hashlib.sha256(path.read_bytes()).hexdigest()
    archive.writestr('StealAHouse/SHA256.json', json.dumps(manifest, indent=2))
with zipfile.ZipFile(archive_path) as archive:
    assert archive.testzip() is None
    for key, digest in manifest.items():
        assert hashlib.sha256(archive.read(key)).hexdigest() == digest, key
print(f'Created ZIP with {len(manifest)} verified files: {archive_path}')
print(f'Place: {len(raw)} bytes; SHA-256: {checksum}')
print(f'Complete offline Windows transfer: {transfer}')
