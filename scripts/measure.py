"""Measure production code only; exclude examples, tests and generated interfaces."""
from pathlib import Path
import json
root = Path(__file__).resolve().parent.parent
files = []
for path in sorted(root.glob('*.mbt')):
    if path.name.endswith(('_test.mbt', '_wbtest.mbt')):
        continue
    lines = path.read_text(encoding='utf-8-sig').splitlines()
    count = sum(bool(line.strip()) and not line.lstrip().startswith('//') for line in lines)
    files.append({'path': path.name, 'physical': len(lines), 'nonblank_noncomment': count})
result = {'files': files, 'physical': sum(f['physical'] for f in files),
          'nonblank_noncomment': sum(f['nonblank_noncomment'] for f in files)}
print(json.dumps(result, indent=2))
assert result['nonblank_noncomment'] >= 1500
