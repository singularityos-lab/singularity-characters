#!/usr/bin/env python3
import re
import sys

UCD = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/unicode"
OUT = sys.argv[2] if len(sys.argv) > 2 else "data/characters.tsv"

GROUPS = {
    "Smileys & Emotion": "smileys",
    "People & Body": "people",
    "Animals & Nature": "nature",
    "Food & Drink": "food",
    "Travel & Places": "travel",
    "Activities": "activities",
    "Objects": "objects",
    "Symbols": "symbols",
    "Flags": "flags",
}
SKIN = {0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF}

SYMBOL_SETS = [
    ("punctuation", [(0x0021, 0x002F), (0x003A, 0x0040), (0x005B, 0x0060), (0x007B, 0x007E), (0x00A1, 0x00BF), (0x2010, 0x205E), (0x2E00, 0x2E4F)]),
    ("arrows", [(0x2190, 0x21FF), (0x27F0, 0x27FF), (0x2900, 0x297F), (0x2B00, 0x2B2F), (0x2B45, 0x2B73)]),
    ("math", [(0x00B1, 0x00B1), (0x00D7, 0x00D7), (0x00F7, 0x00F7), (0x2070, 0x209C), (0x2150, 0x218B), (0x2200, 0x22FF), (0x27C0, 0x27EF), (0x2980, 0x29FF), (0x2A00, 0x2AFF)]),
    ("currency", [(0x0024, 0x0024), (0x00A2, 0x00A5), (0x058F, 0x058F), (0x060B, 0x060B), (0x09F2, 0x09F3), (0x0E3F, 0x0E3F), (0x20A0, 0x20C0)]),
    ("latin", [(0x00C0, 0x00FF), (0x0100, 0x024F), (0x1E00, 0x1EFF), (0x0250, 0x02AF)]),
    ("greek", [(0x0370, 0x03FF)]),
    ("cyrillic", [(0x0400, 0x04FF)]),
    ("letterlike", [(0x2100, 0x214F), (0x2460, 0x24FF), (0x3251, 0x325F)]),
    ("technical", [(0x2300, 0x23FF), (0x2500, 0x259F), (0x25A0, 0x25FF), (0x2600, 0x26FF), (0x2700, 0x27BF), (0x2800, 0x28FF)]),
]

names = {}
cats = {}
with open(f"{UCD}/UnicodeData.txt", encoding="utf-8") as f:
    for line in f:
        parts = line.split(";")
        cp = int(parts[0], 16)
        name = parts[1]
        if name.startswith("<"):
            name = parts[10] if len(parts) > 10 and parts[10] else ""
        names[cp] = name
        cats[cp] = parts[2]

rows = []
emoji_cps = set()
group = sub = None
base_of = {}
with open(f"{UCD}/emoji/emoji-test.txt", encoding="utf-8") as f:
    for line in f:
        m = re.match(r"# group: (.*)", line)
        if m:
            group = GROUPS.get(m.group(1).strip())
            continue
        m = re.match(r"# subgroup: (.*)", line)
        if m:
            sub = m.group(1).strip()
            continue
        if not line.strip() or line.startswith("#") or group is None:
            continue
        seq, rest = line.split(";", 1)
        if "fully-qualified" not in rest:
            continue
        cps = [int(x, 16) for x in seq.split()]
        name = re.sub(r"^.*?E\d+\.\d+\s+", "", rest.split("#", 1)[1].strip())
        base_cps = [c for c in cps if c not in SKIN]
        base = " ".join(f"{c:X}" for c in base_cps)
        key = " ".join(f"{c:X}" for c in cps)
        if len(base_cps) != len(cps):
            rows.append(("variant", sub, key, name, base))
        else:
            rows.append((group, sub, key, name, ""))
            if len(cps) == 1:
                emoji_cps.add(cps[0])

for cat, ranges in SYMBOL_SETS:
    for lo, hi in ranges:
        for cp in range(lo, hi + 1):
            if cp not in names or cp in emoji_cps:
                continue
            gc = cats[cp]
            if gc.startswith("C") or gc.startswith("Z") or gc.startswith("M"):
                continue
            name = names[cp]
            if not name:
                continue
            rows.append((cat, "", f"{cp:X}", name.lower(), ""))

with open(OUT, "w", encoding="utf-8") as f:
    for r in rows:
        f.write("\t".join(r) + "\n")
print(f"{len(rows)} rows written to {OUT}")
