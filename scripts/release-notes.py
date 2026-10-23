#!/usr/bin/env python3
"""Print one CHANGELOG section for a GitHub Release; never publishes anything."""
import argparse
import pathlib
import re
parser = argparse.ArgumentParser()
parser.add_argument('version')
args = parser.parse_args()
if not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
    raise SystemExit('Use a stable version such as 1.1.0')
root = pathlib.Path(__file__).resolve().parents[1]
source = root / 'CHANGELOG.md'
text = source.read_text()
match = re.search(r'^## ' + re.escape(args.version) + r'(?:\s[^\n]*)?\n(.*?)(?=^## |\Z)', text, re.M | re.S)
if not match:
    raise SystemExit(f'No CHANGELOG section for {args.version}')
print(match[1].strip())
