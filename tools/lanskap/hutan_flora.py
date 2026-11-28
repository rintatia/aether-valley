"""Buat tata letak peta + hutan batas dari Flora musim semi (FL..).
- Sabuk hutan batas di semua sisi, TERTUTUP penuh: seluruh sabuk ditandai '#' (tak bisa dilewati),
  kecuali lorong gerbang.
- Peta 'hutan' juga berisi pohon tebang (bisa ditebang & tumbuh lagi) di bagian dalam.
Hasil: data/maps/<id>.json (baris petak) dan data/maps/<id>_pohon.json (sprite).
Sesudahnya panggang rumput: python3 bake_luas.py <id>
Pakai (dari folder ini): python3 hutan_flora.py <id>"""
import json
import sys
import numpy as np
from collections import Counter

CONFIG = {
    'ladang': dict(cols=155, rows=116, seed=7, gerbang={'kiri': 'hutan'}, nama='Ladang', tebang=False),
    'hutan': dict(cols=120, rows=90, seed=21, gerbang={'kanan': 'ladang'}, nama='Hutan Tebang', tebang=True),
}
MID = sys.argv[1] if len(sys.argv) > 1 else 'ladang'
cfg = CONFIG[MID]
rng = np.random.default_rng(cfg['seed'])
R, C = cfg['rows'], cfg['cols']
T = 32
W, H = C * T, R * T
F = json.load(open('../../data/flora_semi.json'))
A = F['aset']

TREES = [('FL03', .12), ('FL09', .11), ('FL04', .10), ('FL10', .09), ('FL05', .08), ('FL11', .08), ('FL13', .08), ('FL14', .05),
         ('FL01', .06), ('FL07', .05), ('FL02', .06), ('FL08', .05), ('FL06', .035), ('FL12', .035)]
SIZES = [(1.0, .30), (0.80, .42), (0.62, .28)]
UNDER = [('FL35', .15), ('FL36', .22), ('FL37', .25), ('FL38', .25), ('FL39', .13)]
UNDER_SCALE = 0.55
ROCKS = [('FL42', .25), ('FL43', .40), ('FL44', .35)]
RARE = [('FL15', .2), ('FL16', .2), ('FL17', .2), ('FL18', .2), ('FL19', .2)]
SOLID = {'FL15', 'FL16', 'FL18', 'FL19', 'FL42', 'FL43', 'FL44', 'FL17'} | {c for c, _ in TREES}
if MID == 'hutan':
    # aturan Hutan Tebang: hanya tunggul/kayu (FL15, FL16, FL18, FL19) + pohon yang tak bisa dilewati
    SOLID = {'FL15', 'FL16', 'FL18', 'FL19', 'FL17'} | {c for c, _ in TREES}
BATU = {'FL42', 'FL43', 'FL44'}
CHOP = [('FL03', .12), ('FL09', .11), ('FL04', .11), ('FL10', .10), ('FL05', .09), ('FL11', .09), ('FL06', .06), ('FL12', .06), ('FL13', .09), ('FL14', .08), ('FL17', .09)]
BAND = 190
GY = R // 2                                   # gerbang di tengah sisi
CORR = (GY - 1, GY + 1)                       # lorong 3 petak


def in_corridor(x, y, pad=1.0):
    gy0, gy1 = (CORR[0] - 2 * pad) * T, (CORR[1] + 1 + 2 * pad) * T
    if not (gy0 < y < gy1):
        return False
    if 'kiri' in cfg['gerbang'] and x < BAND * 1.3:
        return True
    if 'kanan' in cfg['gerbang'] and x > W - BAND * 1.3:
        return True
    return False


CELL = 64
bucket = {}


def near(x, y, r, k=0.85):
    cx, cy = int(x // CELL), int(y // CELL)
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            for (px, py, pr) in bucket.get((cx + dx, cy + dy), []):
                if (px - x) ** 2 + ((py - y) * 1.3) ** 2 < (k * (pr + r)) ** 2:
                    return True
    return False


def add(x, y, r):
    bucket.setdefault((int(x // CELL), int(y // CELL)), []).append((x, y, r))


def wave(t, seed):
    r = np.random.default_rng(seed)
    k = r.uniform(0, 6.28, 6)
    return sum(np.sin(t * fr * 6.28 + kk) / fr ** 0.7 for fr, kk in zip([1, 2, 3, 5, 8, 13], k))


def pick(lst):
    return lst[int(rng.choice(len(lst), p=np.array([p for _, p in lst]) / sum(p for _, p in lst)))][0]


def side_pos(side, u, d):
    return [(u * W, d), (u * W, H - d), (d, u * H), (W - d, u * H)][side]


items = []
depth = {s: [] for s in range(4)}             # (u, d) pohon per sisi -> profil sabuk tertutup
target = int(2 * (W + H) * BAND / 3300)


def place_tree(code):
    for _ in range(60):
        side = int(rng.integers(4))
        u = rng.uniform(0, 1)
        bw = BAND * (0.85 + 0.30 * wave(u, 100 + side) / 2.2)
        d = rng.exponential(bw * 0.28) if rng.random() < 0.97 else rng.uniform(bw * 0.5, bw)
        if d > bw:
            continue
        x, y = side_pos(side, u, d)
        y = min(max(y, 4.0), H - 1.0)
        if in_corridor(x, y):
            continue
        s_ = float(rng.choice([s for s, _ in SIZES], p=[p for _, p in SIZES])) * rng.uniform(0.94, 1.06)
        r = A[code]['region'][2] * s_ * 0.40
        if near(x, y, r):
            continue
        items.append({"obj": code, "x": round(float(x)), "y": round(float(y)), "skala": round(float(s_), 3), "cermin": bool(rng.random() < 0.5)})
        add(x, y, r)
        depth[side].append((u, d))
        return True
    return False


fails = 0
while len(items) < target and fails < 400:
    if not place_tree(pick(TREES)):
        fails += 1
trees = list(items)

for t in trees:
    if rng.random() > 0.75:
        continue
    ux = t['x'] + rng.uniform(-0.25, 0.25) * A[t['obj']]['region'][2] * t['skala']
    uy = t['y'] + rng.uniform(1, 7)
    if 0 < ux < W and 0 < uy < H:
        items.append({"obj": pick(UNDER), "x": round(float(ux)), "y": round(float(uy)),
                      "skala": round(UNDER_SCALE * rng.uniform(0.8, 1.1), 3), "cermin": bool(rng.random() < 0.5)})


def scatter(pool, n, lo, hi, band_mul):
    placed = 0
    for _ in range(n * 400):
        if placed >= n:
            break
        side = int(rng.integers(4))
        u = rng.uniform(0, 1)
        d = min(rng.exponential(BAND * 0.38), BAND * band_mul)
        x, y = side_pos(side, u, d)
        y = min(max(y, 4.0), H - 1.0)
        if in_corridor(x, y):
            continue
        code = pick(pool)
        s_ = rng.uniform(lo, hi)
        r = A[code]['region'][2] * s_ * 0.30
        if near(x, y, r):
            continue
        items.append({"obj": code, "x": round(float(x)), "y": round(float(y)), "skala": round(float(s_), 3), "cermin": bool(rng.random() < 0.5)})
        add(x, y, r)
        depth[side].append((u, d))
        placed += 1


scatter(ROCKS, int(len(trees) * 0.22), 0.45, 0.7, 1.05)
for code, _ in RARE:
    scatter([(code, 1.0)], max(2, int(3 * (W * H) / (4960 * 3712))), 0.5, 0.65, 1.4)

# ---------- sabuk tertutup: profil kedalaman per sisi dari pohon terdalam di sekitarnya ----------
grid = [['.'] * C for _ in range(R)]
NB = 200
for side in range(4):
    prof = np.full(NB, 2.0 * T)
    for u, d in depth[side]:
        b = int(u * NB)
        for k in range(max(0, b - 2), min(NB, b + 3)):
            prof[k] = max(prof[k], d + T * 0.9)
    prof = np.convolve(np.pad(prof, 3, mode='edge'), np.ones(7) / 7, mode='valid')
    prof = np.maximum(prof, 2.5 * T)
    for y in range(R):
        for x in range(C):
            px, py = (x + 0.5) * T, (y + 0.5) * T
            dist, u = [(py, px / W), (H - py, px / W), (px, py / H), (W - px, py / H)][side]
            if dist < prof[min(NB - 1, int(u * NB))]:
                grid[y][x] = '#'
# lorong gerbang
for side, target_map in cfg['gerbang'].items():
    for y in range(CORR[0], CORR[1] + 1):
        rng_x = range(0, C // 4) if side == 'kiri' else range(C - C // 4, C)
        for x in rng_x:
            if grid[y][x] == '#':
                grid[y][x] = '.'
        grid[y][0 if side == 'kiri' else C - 1] = '<' if side == 'kiri' else '>'
grid[R // 2][C // 2] = 'P'

# ---------- pohon tebang (bagian dalam peta 'hutan') ----------
tebang = []
if cfg['tebang']:
    sp = (C // 2 * T, R // 2 * T)
    from scipy.ndimage import gaussian_filter
    clear = gaussian_filter(rng.standard_normal((R, C)), 6)
    clear = clear / clear.std()
    for _ in range(120000):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        cx, cy = int(x // T), int(y // T)
        # jauh dari sabuk tertutup & lorong, tidak di titik muncul
        if any(grid[yy][xx] in '#<>' for yy in range(max(0, cy - 1), min(R, cy + 1)) for xx in range(max(0, cx - 1), min(C, cx + 2))):
            continue
        if in_corridor(x, y, pad=0.5) or (x - sp[0]) ** 2 + (y - sp[1]) ** 2 < (2 * T) ** 2:
            continue
        if rng.random() > np.clip(0.85 + 0.15 * clear[cy, cx], 0.6, 1.0):
            continue                      # padang terbuka & kepadatan berubah-ubah (rumpun dan celah alami)
        code = pick(CHOP)
        s_ = rng.uniform(0.78, 1.0)
        r = A[code]['region'][2] * s_ * 0.50
        if near(x, y, r, k=1.0):
            continue
        tebang.append({"obj": code, "x": round(float(x)), "y": round(float(y)), "skala": round(float(s_), 3), "cermin": bool(rng.random() < 0.5)})
        add(x, y, r)
    # sedikit rumput/pakis liar di sela pohon tebang (bisa dilewati)
    for t in list(tebang):
        if rng.random() < 0.35:
            items.append({"obj": pick(UNDER), "x": t['x'] + int(rng.integers(-14, 15)), "y": t['y'] + int(rng.integers(2, 8)),
                          "skala": round(UNDER_SCALE * rng.uniform(0.8, 1.05), 3), "cermin": bool(rng.random() < 0.5)})

# ---------- bercak tanah / pasir: DIMATIKAN (ladang harus bisa ditanami) ----------
petak = []
if False:
    jenis = ['tanah', 'tanah_batu', 'pasir', 'tanah', 'tanah_batu', 'pasir', 'tanah', 'tanah_batu', 'pasir', 'tanah']
    sp = (C // 2 * T, R // 2 * T)
    for jn in jenis:
        for _ in range(400):
            r = float(rng.uniform(45, 120))
            x, y = rng.uniform(0, W), rng.uniform(0, H)
            cx, cy = int(x // T), int(y // T)
            pad = int(r // T) + 3
            if any(grid[yy][xx] in '#<>' for yy in range(max(0, cy - pad), min(R, cy + pad + 1)) for xx in range(max(0, cx - pad), min(C, cx + pad + 1))):
                continue
            if (x - sp[0]) ** 2 + (y - sp[1]) ** 2 < (r + 5 * T) ** 2 or in_corridor(x, y, pad=2):
                continue
            if any((x - p['x']) ** 2 + (y - p['y']) ** 2 < (r + p['r'] + 260) ** 2 for p in petak):
                continue
            petak.append({"x": round(float(x)), "y": round(float(y)), "r": round(r), "jenis": jn, "seed": int(rng.integers(1, 10 ** 6))})
            break


def on_petak(x, y, extra=14):
    return any((x - p['x']) ** 2 + ((y - p['y']) * 1.25) ** 2 < (p['r'] * 1.25 + extra) ** 2 for p in petak)


# ---------- taburan flora: Hutan Tebang saja (ladang dibiarkan kosong untuk bercocok tanam) ----------
if cfg['tebang']:
    DENS = 1.0
    SEMAK = ['FL20', 'FL21', 'FL22', 'FL23', 'FL24', 'FL25', 'FL26', 'FL27']
    BUNGA = ['FL28', 'FL29', 'FL30', 'FL31', 'FL32', 'FL33', 'FL34', 'FL40', 'FL41']
    RUMPUT = ['FL35', 'FL36', 'FL37', 'FL38', 'FL39']
    KAYU = ['FL15', 'FL16', 'FL18', 'FL19']
    SC = {**{c: (0.42, 0.55) for c in SEMAK}, **{c: (0.38, 0.5) for c in BUNGA}, **{c: (0.45, 0.6) for c in RUMPUT},
          **{c: (0.42, 0.62) for c in BATU}, **{c: (0.5, 0.65) for c in KAYU}}

    def free_spot(x, y, r):
        cx, cy = int(x // T), int(y // T)
        if not (0 <= cx < C and 0 <= cy < R) or grid[cy][cx] in '#<>':
            return False
        if in_corridor(x, y, pad=0.3) or on_petak(x, y):
            return False
        return not near(x, y, r, k=0.7)

    def put(code, x, y, solid_r=None):
        lo, hi = SC[code]
        s_ = rng.uniform(lo, hi)
        items.append({"obj": code, "x": round(float(x)), "y": round(float(y)), "skala": round(float(s_), 3),
                      "cermin": bool(rng.random() < 0.5), "goyang": code not in KAYU and code not in BATU,
                      "lewat": code not in KAYU})
        if solid_r:
            add(x, y, solid_r)

    # rumpun: 4-7 tanaman melingkar dengan CELAH di tengah (bisa diterobos lewat tengah)
    n_rumpun = int(C * R / 55 * DENS)
    tema = [SEMAK + RUMPUT, RUMPUT + BUNGA, BUNGA + RUMPUT, SEMAK + BUNGA]
    placed = 0
    for _ in range(n_rumpun * 30):
        if placed >= n_rumpun:
            break
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        if not free_spot(x, y, 26):
            continue
        pool = tema[int(rng.integers(len(tema)))]
        k = int(rng.integers(4, 8))
        rad = rng.uniform(18, 30)
        a0 = rng.uniform(0, 6.28)
        for j in range(k):
            ang = a0 + j * 6.28 / k + rng.uniform(-0.3, 0.3)
            put(pool[int(rng.integers(len(pool)))], x + np.cos(ang) * rad * 1.3, y + np.sin(ang) * rad * 0.7)
        add(x, y, 20)
        placed += 1
    # tanaman tunggal & batu kecil di sela-sela
    singles = SEMAK + BUNGA + RUMPUT + list(BATU)
    for _ in range(int(C * R / 7 * DENS)):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        if free_spot(x, y, 10):
            put(singles[int(rng.integers(len(singles)))], x, y)
    # tunggul & kayu tumbang (tak bisa dilewati) - jarang, hanya Hutan Tebang
    for _ in range(int(C * R / 260) * 20 if cfg['tebang'] else 0):
        if sum(1 for t in items if t['obj'] in KAYU and t.get('goyang') is False) >= int(C * R / 260):
            break
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        code = KAYU[int(rng.integers(len(KAYU)))]
        if free_spot(x, y, 36):
            put(code, x, y, solid_r=30)

items.sort(key=lambda t: t["y"])
used = sorted({t['obj'] for t in items} | {t['obj'] for t in tebang} | {'FL15'})
json.dump({"_note": f"Peta {cfg['nama']}: '#' = sabuk hutan tertutup, '<'/'>' = gerbang. Dibuat oleh tools/lanskap/hutan_flora.py",
           "nama": cfg['nama'], "chunks": MID, "pohon": f"{MID}_pohon", "gerbang": cfg['gerbang'],
           "petak_tanah": petak,
           "rows": [''.join(r) for r in grid]}, open(f'../../data/maps/{MID}.json', 'w'), indent=0)
json.dump({"_note": "Sprite peta. x,y = pangkal (piksel dunia). 'tebang' = pohon yang bisa ditebang & tumbuh lagi.",
           "atlas": F['atlas'],
           "region": {c: A[c]['region'] for c in used},
           "menghalangi": {c: (c in SOLID) for c in used},
           "tapak": {c: (0.25 if (c in dict(TREES) or c == 'FL17') else 0.6) for c in used},
           "tunggul": "FL15",
           "pohon": items, "tebang": tebang}, open(f'../../data/maps/{MID}_pohon.json', 'w'), indent=0)
blocked = sum(r.count('#') for r in grid)
print(MID, C, 'x', R, '|', len(trees), 'pohon batas,', len(items) - len(trees), 'lainnya,', len(tebang), 'pohon tebang | petak tertutup', blocked)
