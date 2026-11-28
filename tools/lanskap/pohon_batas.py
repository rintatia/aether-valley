"""Sebar pohon OB01-OB03 sebagai batas alami di sekeliling ladang.
Acak (Poisson-disk, tanpa grid), ukuran x1/x2/x3, cermin acak, rapat di tepi dan makin jarang ke dalam.
Hasil: data/maps/ladang_pohon.json -> dibaca game sebagai sprite (bukan dipanggang),
supaya karakter bisa berdiri di depan/belakang pohon dengan benar.
Pakai (dari folder ini): python3 pohon_batas.py [seed]"""
import json
import sys
import numpy as np

rng = np.random.default_rng(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
m = json.load(open('../../data/maps/ladang.json'))
rows = m['rows']
R, C = len(rows), len(rows[0])
T = 32
W, H = C * T, R * T
TYPES = [('obj_pohon_ek', 0.40), ('obj_pohon_pinus', 0.35), ('obj_pohon_birch', 0.25)]
SCALES = [(1, 0.28), (2, 0.50), (3, 0.22)]          # kecil / normal / besar-tinggi
BAND = 260                                            # lebar sabuk hutan (px) dari tepi
gate = [y for y in range(R) if rows[y][C - 1] == '>']
gy0, gy1 = (min(gate) - 3) * T, (max(gate) + 4) * T   # celah jalan ke kota

# grid bantu untuk cek jarak cepat
CELL = 48
bucket = {}


def near(x, y, r):
    cx, cy = int(x // CELL), int(y // CELL)
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            for (px, py, pr) in bucket.get((cx + dx, cy + dy), []):
                if (px - x) ** 2 + (py - y) ** 2 < (0.8 * (pr + r)) ** 2:
                    return True
    return False


# lebar sabuk hutan berubah-ubah sepanjang tepi (menjorok masuk/keluar), bukan garis lurus
def wave(t, seed):
    r = np.random.default_rng(seed)
    k = r.uniform(0, 6.28, 6)
    f = [1, 2, 3, 5, 8, 13]
    return sum(np.sin(t * fr * 6.28 + kk) / fr ** 0.7 for fr, kk in zip(f, k))


def band_at(side, u):
    return BAND * (0.85 + 0.30 * wave(u, 100 + side) / 2.2)


trees = []
target = int(2 * (W + H) * BAND / 1250)
tries = 0
while len(trees) < target and tries < target * 60:
    tries += 1
    side = int(rng.integers(4))
    u = rng.uniform(0, 1)
    bw = band_at(side, u)
    d = abs(rng.normal(0, bw * 0.42))
    if d > bw:
        continue
    if side == 0:
        x, y = u * W, d
    elif side == 1:
        x, y = u * W, H - d
    elif side == 2:
        x, y = d, u * H
    else:
        x, y = W - d, u * H
    y = min(max(y, 4.0), H - 1.0)
    if x > W - BAND and gy0 < y < gy1:
        continue
    sc = int(rng.choice([s for s, _ in SCALES], p=[p for _, p in SCALES]))
    r = 8 * sc + rng.uniform(0, 5)
    if near(x, y, r):
        continue
    key = TYPES[int(rng.choice(len(TYPES), p=[p for _, p in TYPES]))][0]
    trees.append({"obj": key, "x": round(float(x)), "y": round(float(y)), "skala": sc, "cermin": bool(rng.random() < 0.5)})
    bucket.setdefault((int(x // CELL), int(y // CELL)), []).append((x, y, r))

trees.sort(key=lambda t: t["y"])
json.dump({"_note": "Pohon batas ladang (OB01-OB03). x,y = titik pangkal batang (piksel). Dibuat oleh tools/lanskap/pohon_batas.py",
           "pohon": trees}, open('../../data/maps/ladang_pohon.json', 'w'), indent=0)
from collections import Counter
print(len(trees), 'pohon', Counter(t['obj'] for t in trees), Counter(t['skala'] for t in trees))

# ---- atlas: ketiga pohon dalam satu gambar (satu tekstur = digambar sekaligus, ringan di HP) ----
from PIL import Image
reg = json.load(open('../../data/assets.json'))
x = 0
parts = {}
ims = []
for key, _ in TYPES:
    im = Image.open('../../assets/' + reg[key]['file']).convert('RGBA')
    parts[key] = [x, 0, im.width, im.height]
    ims.append((x, im))
    x += im.width + 2
atlas = Image.new('RGBA', (x, max(i.height for _, i in ims)), (0, 0, 0, 0))
for px, im in ims:
    atlas.paste(im, (px, 0))
atlas.save('../../assets/objek/atlas_pohon_batas.png')
d = json.load(open('../../data/maps/ladang_pohon.json'))
d['atlas'] = 'objek/atlas_pohon_batas.png'
d['region'] = parts
json.dump(d, open('../../data/maps/ladang_pohon.json', 'w'), indent=0)
print('atlas', atlas.size)
