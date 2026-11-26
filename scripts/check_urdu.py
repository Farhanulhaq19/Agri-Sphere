"""Lists English phrases used with tr('...') in the app that have no Urdu translation yet.

Run from the project root:  python scripts/check_urdu.py
Writes docs/urdu-missing.txt and prints a summary.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')
UR = os.path.join(LIB, 'core', 'i18n', 'ur.dart')

key_re = re.compile(r"^\s*'((?:[^'\\]|\\.)*)'\s*:", re.M)
# tr('...') or tr("...") with a plain literal (no ${} interpolation)
tr_re = re.compile(r"""\btr\(\s*(?:'((?:[^'\\$]|\\.)*)'|"((?:[^"\\$]|\\.)*)")\s*\)""")
# common UI helpers that call tr() on their first string argument internally
helper_re = re.compile(
    r"""\b(?:field|LiveField|SectionTitle|Pill|PrimaryButton\(label:|_tile\([^,]+,|switchRow|EmptyAction|snack\(context,)\s*\(?\s*'((?:[^'\\$]|\\.)*)'"""
)

have = set(key_re.findall(open(UR, encoding='utf-8').read()))
used = {}
for d, _, files in os.walk(LIB):
    for f in files:
        if not f.endswith('.dart') or f == 'ur.dart':
            continue
        p = os.path.join(d, f)
        text = open(p, encoding='utf-8').read()
        for m in tr_re.finditer(text):
            s = m.group(1) if m.group(1) is not None else m.group(2)
            if s and s.strip():
                used.setdefault(s, os.path.relpath(p, ROOT))
        for m in helper_re.finditer(text):
            s = m.group(1)
            if s and s.strip():
                used.setdefault(s, os.path.relpath(p, ROOT))

# ignore numbers, hints like 03001234567 and code fragments
used = {k: v for k, v in used.items() if re.search(r'[A-Za-z]{2}', k) and ':' not in k[:3] and '(' not in k}
missing = sorted(k for k in used if k not in have)
out = os.path.join(ROOT, 'docs', 'urdu-missing.txt')
with open(out, 'w', encoding='utf-8') as fh:
    for k in missing:
        fh.write(f"{k}\t{used[k]}\n")
pct = 100 * (len(used) - len(missing)) / max(1, len(used))
print(f"Phrases used: {len(used)}  translated: {len(used) - len(missing)}  missing: {len(missing)}  coverage: {pct:.0f}%")
print(f"Missing list written to {os.path.relpath(out, ROOT)}")
