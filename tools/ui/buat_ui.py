"""Bangun ulang semua gambar UI sebagai pixel art asli (grid kecil, tampil NEAREST di game).
Sumber: /tmp/claude-0/work/... (gambar asli dari pengguna). Pakai: python3 buat_ui.py"""
import json
import numpy as np
from PIL import Image
from scipy import ndimage as nd
from piksel import pikselkan

U = '../../assets/ui/'
A = '/mnt/user-data/attachments/4bf2e11d-311f-5249-9a11-d51f461a13f8/'
S1 = '/tmp/claude-0/work/ui/src/'
S2 = '/tmp/claude-0/work/ui2/src/'
DATE = np.array([250, 220, 189])


def trim(im):
    return im.crop(im.getbbox())


def save(im, name):
    im.save(U + name + '.png')
    print(name, im.size)


# --- alat baru (piksel 3) ---
ALAT = {'penyiram': 'af9ea048', 'jaring': '5791d0ab', 'pancing': '6e11dabd', 'pedang': '978419c5', 'kapak': 'a3d4d3cf',
        'beliung': 'be2a0fb5', 'pisau': '7b3de5d0', 'sekop': 'a929d21e', 'arit': '19179ae7', 'cangkul': 'c5b0f5e7'}
for k, f in ALAT.items():
    save(trim(pikselkan(Image.open(A + f + '-image.png'), 3)[0]), 'alat_' + k)

# --- bar shortcut 15 slot ---
bar = trim(pikselkan(Image.open(A + '3ec78aef-image.png'), 8.5)[0])
save(bar, 'bar_shortcut')
b = np.array(bar).astype(int)
cream = (b[..., 3] > 0) & (b[..., 0] > 225) & (b[..., 1] > 190)
lab, n = nd.label(cream)
boxes = []
for sl in nd.find_objects(lab):
    h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
    if h > b.shape[0] * 0.3 and w > 4:
        boxes.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
boxes.sort()
print('kotak shortcut', len(boxes))
H, W = b.shape[:2]
lay = json.load(open(U + 'tata_letak.json'))
lay['shortcut'] = {'slot': [[round(x0 / W, 4), round(y0 / H, 4), round(x1 / W, 4), round(y1 / H, 4)] for x0, y0, x1, y1 in boxes]}

# --- bingkai (isi diwarnai warna kotak day.date) ---
bk = {}
for n_ in ['bingkai_15', 'bingkai_11', 'bingkai_21']:
    im = trim(pikselkan(Image.open(S2 + n_ + '.png'))[0])
    a = np.array(im).astype(int)
    h, w = a.shape[:2]
    base = a[int(h * .3):int(h * .7), int(w * .3):int(w * .7), :3].reshape(-1, 3).mean(0)
    near = (np.abs(a[..., :3] - base).sum(-1) < 40) & (a[..., 3] > 0)
    lb, _ = nd.label(near)
    m = lb == lb[h // 2, w // 2]
    a[m, :3] = DATE
    ys, xs = np.where(m)
    bk[n_] = [round(xs.min() / w, 4), round(ys.min() / h, 4), round((xs.max() + 1) / w, 4), round((ys.max() + 1) / h, 4)]
    save(Image.fromarray(a.astype(np.uint8)), n_)
lay['bingkai'] = bk

# --- lencana musim ---
L = pikselkan(Image.open(S2 + 'lencana.png'))[0]
la = np.array(L)
col = (la[..., 3] > 0).any(0)
segs, s = [], None
for x, v in enumerate(col):
    if v and s is None:
        s = x
    if not v and s is not None:
        segs.append((s, x))
        s = None
if s is not None:
    segs.append((s, len(col)))
segs = [g for g in segs if g[1] - g[0] > 10]
print('lencana', len(segs))
for nm, (x0, x1) in zip(['spring', 'summer', 'autumn', 'rainy', 'winter'], segs):
    c = trim(L.crop((x0, 0, x1, L.height)))
    w, h = c.size
    sq = Image.new('RGBA', (max(w, h),) * 2)
    sq.alpha_composite(c, ((max(w, h) - w) // 2, (max(w, h) - h) // 2))
    save(sq, 'lencana_' + nm)

# --- status bar siang/malam (potongan sama seperti dulu -> tata letak pecahan tetap) ---
for n_ in ['status_siang', 'status_malam']:
    src = Image.open(S1 + n_ + '.png').crop((22, 0, 2137, 666))
    im = pikselkan(src)[0]
    save(im, n_)
st = [Image.open(U + n_ + '.png') for n_ in ['status_siang', 'status_malam']]
if st[0].size != st[1].size:
    st[1].resize(st[0].size, Image.NEAREST).save(U + 'status_malam.png')

# --- ikon HUD ---
for n_ in ['ikon_buku', 'ikon_peta', 'ikon_setting', 'ikon_tas']:
    save(trim(pikselkan(Image.open(S1 + n_ + '.png'))[0]), n_)

# --- tombol, kartu, kayu ---
for n_ in ['tombol_kosong', 'tombol_confirm', 'kartu_male', 'kartu_female', 'item_kayu']:
    save(trim(pikselkan(Image.open(U + n_ + '.png'))[0]), n_)
json.dump(lay, open(U + 'tata_letak.json', 'w'), indent=1)
