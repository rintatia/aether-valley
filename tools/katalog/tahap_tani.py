"""Tahap tumbuh unik per tanaman (untuk tanaman tanpa gambar tahap dari pengguna), semua di bedeng yang sama:
0 bibit ditabur (biji berwarna sesuai kantong bibit) -> 1 kecambah -> 2 setengah tumbuh (tanaman itu sendiri, lebih kecil,
buah/bunga masih hijau) -> 3 matang (gambar asli). Dikerjakan di ukuran piksel asli (sel 25x30), lalu Scale4x."""
import colorsys
import numpy as np
from PIL import Image
from buat_katalog import px4, SRC, ROOT, CROPS, OWN, slug

a = np.array(Image.open(SRC + 'tanaman.png').convert('RGBA')).astype(int)
cells = [a[r * 30:(r + 1) * 30, c * 25:(c + 1) * 25].copy() for r in range(5) for c in range(6)]
BOX_TOP = 12


def hsv(p):
    return colorsys.rgb_to_hsv(*(np.array(p[:3]) / 255.0))


def is_box(p, y):
    if p[3] < 60 or y < BOX_TOP:
        return False
    h, s, v = hsv(p)
    h *= 360
    return (12 <= h <= 36 and s > 0.65 and v < 0.82) or (5 <= h <= 40 and v < 0.36 and s > 0.4)


# bedeng kosong: median piksel bedeng dari semua sel
empty = np.zeros((30, 25, 4), np.uint8)
for y in range(30):
    for x in range(25):
        ps = [c[y, x] for c in cells if is_box(c[y, x], y)]
        if len(ps) >= 3:
            empty[y, x] = np.median(np.array(ps), axis=0).astype(np.uint8)
            empty[y, x, 3] = 255
# isi lubang kecil di bedeng dengan tetangga
for _ in range(3):
    for y in range(BOX_TOP, 30):
        for x in range(25):
            if empty[y, x, 3] == 0:
                nb = [empty[yy, xx] for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1))
                      if 0 <= yy < 30 and 0 <= xx < 25 and empty[yy, xx, 3] > 0]
                if len(nb) >= 3:
                    empty[y, x] = nb[0]
# bagian tengah bedeng (di antara dua garis papan) masih membawa sisa batang: isi ulang dengan warna papan polos
# dari sisi kiri baris yang sama (bedeng simetris, papan tengah polos)
for y in range(BOX_TOP + 1, 28):
    src = [empty[y, x] for x in (2, 3, 4) if empty[y, x, 3] > 0]
    if src:
        fill = np.median(np.array(src), axis=0).astype(np.uint8)
        for x in range(8, 17):
            empty[y, x] = fill
bibit = np.array(Image.open(SRC + 'bibit.png').convert('RGBA')).astype(int)


def bag_colour(idx):
    c, r = idx % 6, idx // 6
    W, H = bibit.shape[1] / 6, bibit.shape[0] / 5
    cell = bibit[int(r * H):int((r + 1) * H), int(c * W):int((c + 1) * W)]
    px = cell[cell[..., 3] > 200][:, :3]
    sat = np.array([hsv(p)[1] * hsv(p)[2] for p in px])
    return px[np.argsort(sat)[-len(px) // 4:]].mean(0)


def put(dst, src, ox, oy):
    for y in range(src.shape[0]):
        for x in range(src.shape[1]):
            if src[y, x, 3] > 0 and 0 <= y + oy < dst.shape[0] and 0 <= x + ox < dst.shape[1]:
                dst[y + oy, x + ox] = src[y, x]


SPROUT = ["..g.g..", ".gGgGg.", "..gGg..", "...s...", "...s..."]
PAL = {'g': (88, 160, 52, 255), 'G': (140, 205, 80, 255), 's': (60, 110, 40, 255)}
for idx, nm in enumerate(CROPS):
    if nm in OWN:
        continue
    s = slug(nm)
    cell = cells[idx]
    plant = cell.copy()
    for y in range(30):
        for x in range(25):
            if is_box(cell[y, x], y):
                plant[y, x] = 0
    # 0: biji ditabur, warna sesuai kantong bibit
    st0 = empty.copy()
    col = bag_colour(idx)
    for (x, y) in [(8, 17), (12, 16), (16, 17), (10, 20), (14, 20), (12, 23)]:
        st0[y, x, :3] = (col * 0.75).astype(np.uint8)
        st0[y, x, 3] = 255
        st0[y, x + 1, :3] = np.clip(col * 1.05, 0, 255).astype(np.uint8)
    # 1: kecambah
    st1 = empty.copy()
    spr = np.zeros((len(SPROUT), len(SPROUT[0]), 4), np.uint8)
    for y, row in enumerate(SPROUT):
        for x, ch in enumerate(row):
            if ch in PAL:
                spr[y, x] = PAL[ch]
    put(st1, spr, 9, BOX_TOP + 1)
    # 2: setengah tumbuh = tanaman ini diperkecil 62%, buah/bunga masih hijau
    half = plant.copy()
    for y in range(30):
        for x in range(25):
            p = half[y, x]
            if p[3] == 0:
                continue
            h, sa, v = hsv(p)
            if not (0.17 <= h <= 0.47) and v > 0.3 and sa > 0.2:
                g = colorsys.hsv_to_rgb(0.27, 0.6, min(1.0, v * 0.95))
                half[y, x, :3] = [int(c * 255) for c in g]
    ys, xs = np.where(half[..., 3] > 0)
    small = Image.fromarray(half.astype(np.uint8)).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    w, h = small.size
    small = np.array(small.resize((max(3, round(w * 0.62)), max(3, round(h * 0.62))), Image.NEAREST)).astype(int)
    st2 = empty.copy()
    put(st2, small, 12 - small.shape[1] // 2, 22 - small.shape[0])
    for k, im in enumerate([st0, st1, st2]):
        px4(Image.fromarray(im.astype(np.uint8))).save(ROOT + 'assets/tani/%s_%d.png' % (s, k))
print('ok')
