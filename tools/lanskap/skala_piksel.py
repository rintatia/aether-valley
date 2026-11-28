"""Perbesaran khusus pixel art (Scale2x / Scale3x, keluarga EPX/AdvMAME).
Tidak menambah warna baru dan tidak membuat buram; hanya merapikan tepi bergerigi."""
import numpy as np


def _eq(a, b):
    return np.all(a == b, axis=-1)


def scale2x(img):
    p = np.pad(img, ((1, 1), (1, 1), (0, 0)), mode='edge')
    E = p[1:-1, 1:-1]
    B, D, F, H = p[:-2, 1:-1], p[1:-1, :-2], p[1:-1, 2:], p[2:, 1:-1]
    c = ~_eq(B, H) & ~_eq(D, F)
    out = np.repeat(np.repeat(E, 2, 0), 2, 1).copy()
    e0 = np.where((c & _eq(D, B))[..., None], D, E)
    e1 = np.where((c & _eq(B, F))[..., None], F, E)
    e2 = np.where((c & _eq(D, H))[..., None], D, E)
    e3 = np.where((c & _eq(H, F))[..., None], F, E)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = e0, e1, e2, e3
    return out


def scale3x(img):
    p = np.pad(img, ((1, 1), (1, 1), (0, 0)), mode='edge')
    E = p[1:-1, 1:-1]
    A, B, C = p[:-2, :-2], p[:-2, 1:-1], p[:-2, 2:]
    D, F = p[1:-1, :-2], p[1:-1, 2:]
    G, H, I = p[2:, :-2], p[2:, 1:-1], p[2:, 2:]
    c = (~_eq(B, H) & ~_eq(D, F))[..., None]
    db, bf, dh, hf = _eq(D, B)[..., None], _eq(B, F)[..., None], _eq(D, H)[..., None], _eq(H, F)[..., None]
    ne = lambda x, y: ~_eq(x, y)[..., None]
    e0 = np.where(c & db, D, E)
    e1 = np.where(c & ((db & ne(E, C)) | (bf & ne(E, A))), B, E)
    e2 = np.where(c & bf, F, E)
    e3 = np.where(c & ((db & ne(E, G)) | (dh & ne(E, A))), D, E)
    e4 = E
    e5 = np.where(c & ((bf & ne(E, I)) | (hf & ne(E, C))), F, E)
    e6 = np.where(c & dh, D, E)
    e7 = np.where(c & ((dh & ne(E, I)) | (hf & ne(E, G))), H, E)
    e8 = np.where(c & hf, F, E)
    h, w = E.shape[:2]
    out = np.zeros((h * 3, w * 3, E.shape[2]), E.dtype)
    for k, e in enumerate([e0, e1, e2, e3, e4, e5, e6, e7, e8]):
        out[k // 3::3, k % 3::3] = e
    return out
