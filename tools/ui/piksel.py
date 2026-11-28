"""Kembalikan gambar UI pixel art (hasil generator, sudah diperbesar & agak halus) ke grid piksel aslinya.
Ukuran piksel diperkirakan dari periode tepi (FFT), fase grid dicari agar garis grid jatuh di tepi warna,
lalu tiap sel diambil warna tengahnya. Hasil kecil ini ditampilkan game dengan filter NEAREST (tajam).
Pakai: python3 piksel.py masuk.png keluar.png [ukuran_piksel]"""
import sys
import numpy as np
from PIL import Image


def period(a):
    lum = a[..., :3].astype(float).sum(-1) + a[..., 3].astype(float) * 2
    res = []
    for ax in (1, 0):
        g = np.abs(np.diff(lum, axis=ax)).sum(0 if ax == 1 else 1)
        s = g - g.mean()
        f = np.abs(np.fft.rfft(s))
        fr = np.fft.rfftfreq(len(s))
        m = (fr > 1 / 40) & (fr < 1 / 1.8)
        res.append(1 / fr[np.argmax(f * m)])
    return res


def phase(a, p, ax):
    lum = a[..., :3].astype(float).sum(-1) + a[..., 3].astype(float) * 2
    g = np.abs(np.diff(lum, axis=ax)).sum(0 if ax == 1 else 1)
    best, bo = -1, 0.0
    for o in np.linspace(0, p, 24, endpoint=False):
        idx = np.round(np.arange(o, len(g), p)).astype(int)
        idx = idx[(idx >= 0) & (idx < len(g))]
        v = g[idx].mean()
        if v > best:
            best, bo = v, o
    return bo


def pikselkan(im, p=None):
    a = np.array(im.convert('RGBA'))
    if p is None:
        px, py = period(a)
        p = float(np.median([px, py]))
    px = py = p
    ox, oy = phase(a, px, 1), phase(a, py, 0)
    H, W = a.shape[:2]
    xs = np.arange(ox + px / 2, W, px)
    ys = np.arange(oy + py / 2, H, py)
    if ox > px * 0.25:
        xs = np.concatenate([[max(0, ox / 2)], xs])
    if oy > py * 0.25:
        ys = np.concatenate([[max(0, oy / 2)], ys])
    xi = np.clip(np.round(xs).astype(int), 0, W - 1)
    yi = np.clip(np.round(ys).astype(int), 0, H - 1)
    out = np.zeros((len(yi), len(xi), 4), np.uint8)
    # warna tengah sel = median 3x3 di sekitar titik tengah (tahan derau)
    for j, y in enumerate(yi):
        for i, x in enumerate(xi):
            blk = a[max(0, y - 1):y + 2, max(0, x - 1):x + 2].reshape(-1, 4)
            op = blk[blk[:, 3] > 0]
            if (blk[:, 3] > 127).mean() < 0.5 or len(op) == 0:
                continue
            out[j, i, :3] = np.median(op[:, :3], axis=0)
            out[j, i, 3] = 255
    return Image.fromarray(out), p


if __name__ == '__main__':
    p = float(sys.argv[3]) if len(sys.argv) > 3 else None
    o, p = pikselkan(Image.open(sys.argv[1]), p)
    o.save(sys.argv[2])
    print(sys.argv[2], o.size, 'piksel', round(p, 2))
