#!/usr/bin/env python3
"""Build index.html from src/template.html + src/data.json.  Run: python3 tools/build.py"""
import json, os, re, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tpl = open(os.path.join(ROOT, 'src', 'template.html'), encoding='utf-8').read()
data = open(os.path.join(ROOT, 'src', 'data.json'), encoding='utf-8').read().strip()
json.loads(data)
head_end = tpl.index('</style>') + len('</style>')
head, body = tpl[:head_end], tpl[head_end:]
doc = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
       '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
       '<meta name="color-scheme" content="light dark">\n'
       '<meta name="description" content="Build a He Who Fights With Monsters essence user: three essences, a confluence, awakening stones, and powers written by your own AI.">\n'
       + head + '\n</head>\n<body>\n' + body + '\n</body>\n</html>\n')
doc = doc.replace('__DATA__', data)
open(os.path.join(ROOT, 'index.html'), 'w', encoding='utf-8').write(doc)
m = re.search(r'<script>(.*)</script>', doc, re.S)
chk = os.path.join(ROOT, 'tools', '.check.js')
open(chk, 'w', encoding='utf-8').write(m.group(1))
r = subprocess.run(['node', '--check', chk], capture_output=True, text=True)
os.remove(chk)
if r.returncode:
    print(r.stderr); sys.exit(1)
print('built index.html', len(doc), 'bytes; syntax ok')
