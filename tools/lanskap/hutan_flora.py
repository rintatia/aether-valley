"""Hutan batas ladang dari Flora musim semi (FL01-FL44, resolusi tinggi).
Acak (Poisson-disk), ukuran kecil/normal/besar tanpa pecah (gambar asli resolusi tinggi diperkecil),
rapat di tepi luar lalu makin jarang, semak/rumput/bunga di kaki pohon.
Hasil: data/maps/ladang_pohon.json (dibaca game sebagai sprite ber-urutan-Y).
Pakai (dari folder ini): python3 hutan_flora.py [seed]"""
import json
import sys
import numpy as np

rng = np.random.default_rng(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
m = json.load(open('../../data/maps/ladang.json'))
rows = m['rows']
R, C = len(rows), len(rows[0])
T = 32
W, H = C * T, R * T
F = json.load(open('../../data/flora_semi.json'))
A = F['aset']
BASE = F['skala_dunia']                       # 0.5: di zoom x2 satu titik gambar = satu piksel layar

# pohon hutan (kode, bobot). Sakura/apel/willow sesekali saja sebagai aksen musim semi.
TREES = [('FL03', .16), ('FL09', .14), ('FL04', .13), ('FL10', .12), ('FL17', .05), ('FL05', .09), ('FL11', .08),
         ('FL01', .05), ('FL07', .04), ('FL02', .05), ('FL08', .04), ('FL06', .025), ('FL12', .025)]
SIZES = [(0.72, .34), (1.0, .48), (1.22, .18)]   # kecil / normal / besar
UNDER = [('FL20', .10), ('FL23', .05), ('FL21', .04), ('FL22', .04), ('FL25', .03), ('FL26', .03),
         ('FL36', .10), ('FL37', .14), ('FL38', .14), ('FL39', .05), ('FL35', .06),
         ('FL30', .04), ('FL31', .04), ('FL33', .03), ('FL34', .03), ('FL40', .02), ('FL41', .02), ('FL43', .02), ('FL44', .02)]
UNDER_SCALE = 0.40
BAND = 190
gate = [y for y in range(R) if rows[y][C - 1] == '>']
gy0, gy1 = (min(gate) - 3) * T, (max(gate) + 4) * T

CELL = 64
bucket = {}


def near(x, y, r):
    cx, cy = int(x // CELL), int(y // CELL)
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            for (px, py, pr) in bucket.get((cx + dx, cy + dy), []):
                if (px - x) ** 2 + ((py - y) * 1.3) ** 2 < (1.1 * (pr + r)) ** 2:
                    return True
    return False


def wave(t, seed):
    r = np.random.default_rng(seed)
    k = r.uniform(0, 6.28, 6)
    return sum(np.sin(t * fr * 6.28 + kk) / fr ** 0.7 for fr, kk in zip([1, 2, 3, 5, 8, 13], k))


def pick(lst):
    return lst[int(rng.choice(len(lst), p=np.array([p for _, p in lst]) / sum(p for _, p in lst)))][0]


items = []
target = int(2 * (W + H) * BAND / 2900)
tries = 0
while sum(1 for t in items if t['obj'] in dict(TREES)) < target and tries < target * 80:
    tries += 1
    side = int(rng.integers(4))
    u = rng.uniform(0, 1)
    bw = BAND * (0.85 + 0.30 * wave(u, 100 + side) / 2.2)
    d = rng.exponential(bw * 0.28) if rng.random() < 0.97 else rng.uniform(bw * 0.5, bw)
    if d > bw:
        continue
    x, y = [(u * W, d), (u * W, H - d), (d, u * H), (W - d, u * H)][side]
    y = min(max(y, 4.0), H - 1.0)
    if x > W - BAND * 1.2 and gy0 < y < gy1:
        continue
    code = pick(TREES)
    s = BASE * float(rng.choice([s for s, _ in SIZES], p=[p for _, p in SIZES])) * rng.uniform(0.94, 1.06)
    r = A[code]['region'][2] * s * 0.42
    if near(x, y, r):
        continue
    items.append({"obj": code, "x": round(float(x)), "y": round(float(y)), "skala": round(float(s), 3), "cermin": bool(rng.random() < 0.5)})
    bucket.setdefault((int(x // CELL), int(y // CELL)), []).append((x, y, r))

trees = list(items)
for t in trees:
    if rng.random() > 0.7:
        continue
    for _ in range(int(rng.integers(1, 4))):
        ang = rng.uniform(0, 6.28)
        rad = rng.uniform(10, 26) * (t['skala'] / BASE)
        ux, uy = t['x'] + np.cos(ang) * rad * 1.4, t['y'] + abs(np.sin(ang)) * rad * 0.5 + rng.uniform(-2, 8)
        if 0 < ux < W and 0 < uy < H:
            items.append({"obj": pick(UNDER), "x": round(float(ux)), "y": round(float(uy)),
                          "skala": round(UNDER_SCALE * rng.uniform(0.85, 1.1), 3), "cermin": bool(rng.random() < 0.5)})

items.sort(key=lambda t: t["y"])
used = sorted({t['obj'] for t in items})
json.dump({"_note": "Hutan batas ladang dari Flora musim semi. x,y = pangkal (piksel dunia). Dibuat oleh tools/lanskap/hutan_flora.py",
           "atlas": F['atlas'],
           "region": {c: A[c]['region'] for c in used},
           "menghalangi": {c: A[c]['menghalangi'] for c in used},
           "pohon": items}, open('../../data/maps/ladang_pohon.json', 'w'), indent=0)
from collections import Counter
print(len(trees), 'pohon,', len(items) - len(trees), 'tanaman bawah')
print(Counter(A[t['obj']]['label'] for t in trees).most_common())
