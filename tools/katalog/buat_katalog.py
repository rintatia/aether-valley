"""Potong lembar aset pengguna -> objek satuan bersih + data/katalog.json (kategori, ukuran dunia, tapak, harga).
Sumber: /tmp/claude-0/work/set/<lembar>.png, kotak objek di kotak.json (hasil deteksi, urutan = nomor di pratinjau).
- Lembar besar (props, bangunan, rumah, pagar, alam): latar buram dibuang (alfa > 200), resolusi asli dipertahankan.
- Lembar pixel kecil (bibit, tanaman, tumbuh, panen, hewan, hasil): diperbesar 4x (Scale4x) -> tajam & beresolusi tinggi.
Pakai: python3 buat_katalog.py"""
import json, os, re
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = '/tmp/claude-0/work/set/'
ROOT = '../../'
K = json.load(open('kotak.json'))
T = 32
os.makedirs(ROOT + 'assets/katalog', exist_ok=True)
os.makedirs(ROOT + 'assets/tani', exist_ok=True)
os.makedirs(ROOT + 'assets/ternak', exist_ok=True)


def slug(s):
    return re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')


def bersih(sheet, b, thr=200):
    a = np.array(Image.open(SRC + sheet + '.png').convert('RGBA'))
    x0, y0, x1, y1 = b
    p = 6
    c = a[max(0, y0 - p):y1 + p, max(0, x0 - p):x1 + p].copy()
    m = c[..., 3] > thr
    m = nd.binary_opening(m, np.ones((2, 2)))
    lab, k = nd.label(m)
    if k == 0:
        return None
    sz = nd.sum(m, lab, range(1, k + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sz) if s >= max(30, sz.max() * 0.02)])
    holes = nd.binary_fill_holes(keep) & ~keep
    hl, hk = nd.label(holes)
    if hk:
        hs = nd.sum(holes, hl, range(1, hk + 1))
        keep |= np.isin(hl, [i + 1 for i, s in enumerate(hs) if s < 40])
    c[..., 3] = np.where(keep, 255, 0)
    im = Image.fromarray(c)
    return im.crop(im.getbbox())


def scale2x(a):
    H, W = a.shape[:2]
    P = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode='edge')
    E = P[1:-1, 1:-1]; B = P[:-2, 1:-1]; D = P[1:-1, :-2]; F = P[1:-1, 2:]; Hh = P[2:, 1:-1]
    eq = lambda x, y: (x == y).all(-1)
    c = (~eq(B, Hh) & ~eq(D, F))[..., None]
    out = np.zeros((H * 2, W * 2, 4), a.dtype)
    out[0::2, 0::2] = np.where(c & eq(D, B)[..., None], D, E)
    out[0::2, 1::2] = np.where(c & eq(B, F)[..., None], F, E)
    out[1::2, 0::2] = np.where(c & eq(D, Hh)[..., None], D, E)
    out[1::2, 1::2] = np.where(c & eq(Hh, F)[..., None], F, E)
    return out


def px4(im):
    a = np.array(im.convert('RGBA'))
    a[..., 3] = np.where(a[..., 3] > 60, 255, 0)
    a[a[..., 3] == 0] = 0
    return Image.fromarray(scale2x(scale2x(a)))


def sel(sheet, cols, rows, c, r, trim=True):
    im = Image.open(SRC + sheet + '.png').convert('RGBA')
    W, H = im.size
    cw, ch = W / cols, H / rows
    cell = im.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
    a = np.array(cell)
    m = a[..., 3] > 60
    lab, k = nd.label(m, np.ones((3, 3)))
    if k > 1:   # buang serpihan tetangga di tepi sel
        sz = nd.sum(m, lab, range(1, k + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sz) if s >= sz.max() * 0.08])
        a[~keep] = 0
        cell = Image.fromarray(a)
    return cell.crop(cell.getbbox()) if trim else cell


ITEMS = {}


def tambah(id_, nama, kat, im, k, tapak, harga, desk, lewat=False, musim='', krist=0):
    path = 'assets/katalog/%s.png' % id_
    im.save(ROOT + path)
    w, h = im.size
    ITEMS[id_] = {"nama": nama, "kategori": kat, "musim": musim, "gambar": 'res://' + path,
                  "ukuran": [round(w * k, 1), round(h * k, 1)], "tapak": tapak, "lewat": lewat,
                  "harga": harga, "kristal": krist, "desk": desk}


def tapak_auto(w, h, k, fw=0.8, depth=1):
    return [max(1, round(w * k * fw / T)), depth]


# ---------------- dekorasi (props) ----------------
PROPS = {0: ('Treasure Chest', 'Stores your treasures in style.', 1200), 1: ('Mushroom Mailbox', 'A cute toadstool mailbox for letters.', 900),
         2: ('Arrow Signpost', 'Points visitors the right way.', 300), 3: ('Scarecrow', 'Keeps crows away from your crops.', 800),
         4: ('Compost Bin', 'Turns scraps into rich soil.', 700), 5: ('Beehive', 'Home for friendly honeybees.', 2500),
         6: ('Log Pond', 'A hollow log filled with lilies.', 1800), 7: ('Feed Trough', 'Hay trough for your animals.', 900),
         8: ('Hay Roll', 'A big round bale of hay.', 400), 9: ('Hay Stack', 'Stacked bales tied with vines.', 600),
         10: ('Pumpkin Wheelbarrow', 'A harvest wheelbarrow full of flowers.', 1500), 14: ('Apple Crate', 'A crate of fresh apples.', 350),
         11: ('Heart Barrel', 'A sturdy barrel with a heart mark.', 500), 12: ('Leaf Barrel', 'A sturdy barrel with a leaf mark.', 500),
         13: ('Rain Barrel', 'Collects rainwater for the garden.', 700), 16: ('Firewood Shed', 'Keeps firewood dry.', 2200),
         17: ('Vine Lantern Post', 'A glowing lantern wrapped in vines.', 1100), 18: ('Twin Lantern Post', 'Two lanterns light the path.', 1400),
         19: ('Dog House', 'A cozy house for a loyal dog.', 2000), 20: ('Garden Bench', 'A carved bench to rest on.', 1300),
         21: ('Pet Bowl', 'A food bowl for pets.', 200), 22: ('Small Rock', 'A small decorative rock.', 100),
         23: ('Rock Pile', 'A pile of grey stones.', 250), 24: ('Rope Bench', 'A rustic bench between rope posts.', 1000),
         25: ('Hanging Sign', 'A wooden sign with a heart.', 450), 26: ('Tool Shelter', 'Keeps your tools tidy.', 1600),
         27: ('Seed Sack Decor', 'A burlap sack of seeds.', 250)}
LEWAT_PROPS = {21, 22, 27}
for i, (nm, ds, pr) in PROPS.items():
    im = bersih('props', K['props'][i]); k = 0.3
    tambah(slug(nm), nm, 'Decor', im, k, tapak_auto(im.width, im.height, k), pr, ds, lewat=i in LEWAT_PROPS)

# ---------------- bangunan ----------------
BANG = [('bangunan', 0, 'Windmill', 'Grinds wheat into flour.', 0, 200), ('bangunan', 1, 'Greenhouse', 'Grow crops in any season.', 0, 300),
        ('bangunan', 2, 'Silo', 'Stores hay for your animals.', 45000, 0), ('bangunan', 3, 'Kitchen Hut', 'A stone kitchen for cooking recipes.', 60000, 0),
        ('bangunan', 4, 'Blacksmith', 'Upgrade and repair tools.', 80000, 0), ('bangunan', 5, 'Storehouse', 'Extra storage for your goods.', 40000, 0),
        ('bangunan', 6, 'Stable', 'A home for horses.', 90000, 0), ('bangunan', 7, 'Well', 'Refill your watering can here.', 12000, 0),
        ('bangunan', 8, 'Root Cellar', 'A hillside cellar that keeps food cool.', 55000, 0),
        ('rumah', 3, 'Big Barn', 'A large barn for cows and sheep.', 150000, 0), ('rumah', 4, 'Cow Barn', 'A barn for cows. Comes with milk cans.', 110000, 0),
        ('rumah', 5, 'Chicken Coop', 'A cozy coop for chickens.', 35000, 0), ('rumah', 6, 'Duck House', 'A pond hut for ducks.', 30000, 0),
        ('rumah', 7, 'Goose House', 'A mossy hut for geese.', 30000, 0)]
for sh, i, nm, ds, pr, kr in BANG:
    im = bersih(sh, K[sh][i]); k = 0.62
    w, h = im.size
    tambah(slug(nm), nm, 'Buildings', im, k, [max(2, round(w * k * 0.85 / T)), max(2, round(h * k * 0.32 / T))], pr, ds, krist=kr)
HOUSES = [(0, 'Cottage', 'A small ivy-covered cottage.', 80000, 0), (1, 'Farmhouse', 'A warm family farmhouse with roses.', 180000, 0),
          (2, 'Manor', 'A grand manor with a moon weathervane.', 0, 500)]
for i, nm, ds, pr, kr in HOUSES:
    im = bersih('rumah', K['rumah'][i]); k = 0.62
    w, h = im.size
    tambah(slug(nm), nm, 'Houses', im, k, [max(2, round(w * k * 0.85 / T)), max(2, round(h * k * 0.32 / T))], pr, ds, krist=kr)

# ---------------- pagar ----------------
PAGAR = {0: ('Vine Log Fence', 'Long log fence with vines.', 600), 1: ('Log Fence Post', 'A tall log post section.', 250),
         6: ('Log Arch Gate', 'An arched gateway made of logs.', 1500), 8: ('Log Fence', 'Medium log fence.', 400),
         9: ('Short Log Fence', 'Short log fence.', 250), 10: ('Heart Picket Fence', 'Long white picket fence with hearts.', 600),
         11: ('Arrow Sign Board', 'A post full of arrow signs.', 500), 17: ('Picket Fence', 'Medium picket fence.', 400),
         18: ('Short Picket Fence', 'Short picket fence.', 250), 19: ('Picket Gate', 'A double gate with lanterns.', 1800),
         20: ('Long Stone Wall', 'Mossy stone wall.', 900), 21: ('Stone Wall Post', 'A narrow stone wall section.', 300),
         22: ('Stone Wall Corner', 'Stone wall corner.', 500), 23: ('Stone Wall End', 'Stone wall end piece.', 500),
         24: ('Stone Arch', 'An open stone archway.', 2200), 25: ('Stone Gate', 'A stone arch with an iron gate.', 2800),
         26: ('Stone Wall', 'Medium stone wall.', 700), 27: ('Short Stone Wall', 'Short stone wall.', 350),
         28: ('Stone Wall Tower', 'Stone wall with a raised end.', 550), 29: ('Stone Wall Step', 'Stepped stone wall.', 550),
         30: ('Low Stone Wall', 'Low stone wall.', 400), 31: ('Mushroom Fence', 'Long fence topped with mushrooms.', 700),
         32: ('Mushroom Post', 'Tall mushroom fence post.', 300), 33: ('Mushroom Post Pair', 'Two mushroom posts.', 350),
         34: ('Mushroom Fence Corner', 'Mushroom fence corner.', 450), 35: ('Short Mushroom Fence', 'Short mushroom fence.', 300),
         37: ('Mushroom Gate', 'A magical mushroom gate.', 2500), 38: ('Mushroom Fence Piece', 'Mushroom fence piece.', 300),
         39: ('Mushroom Fence Rail', 'Mushroom fence rail.', 300), 40: ('Mushroom Fence Bend', 'Mushroom fence bend.', 350),
         41: ('Mushroom Fence Bit', 'Small mushroom fence.', 300)}
GATES = {6, 19, 24, 25, 37}
for i, (nm, ds, pr) in PAGAR.items():
    im = bersih('pagar', K['pagar'][i]); k = 0.32
    tambah(slug(nm), nm, 'Fences', im, k, [max(1, round(im.width * k / T)), 1], pr, ds, lewat=i in GATES)

# ---------------- alam musiman ----------------
POHON = 'tree'
NAT = {
 'spring': {0: ('Cherry Blossom Tree', POHON, 3000), 1: ('White Blossom Tree', POHON, 2800), 2: ('Oak Tree', POHON, 2000), 3: ('Pine Tree', POHON, 1800),
            4: ('Birch Tree', POHON, 2000), 5: ('Willow Tree', POHON, 3200), 12: ('Young Tree', POHON, 900), 16: ('Sapling', 'pass', 300),
            17: ('Tree Stump', 'solid', 300), 13: ('Mossy Flower Log', 'wide', 800), 14: ('Small Pine', POHON, 900), 15: ('Sprouting Stump', 'solid', 400),
            18: ('Blossom Log', 'wide', 800), 23: ('Green Bush', 'solid', 400), 24: ('Pink Flower Bush', 'solid', 600), 25: ('White Flower Bush', 'solid', 600),
            26: ('Round Bush', 'solid', 500), 19: ('Azalea Bush', 'solid', 800), 20: ('Hydrangea Bush', 'solid', 800), 21: ('Blossom Shrub', 'solid', 700),
            22: ('Tall Blossom Shrub', 'solid', 700), 27: ('Yellow Tulip', 'pass', 120), 28: ('Red Tulip', 'pass', 120), 29: ('Daisies', 'pass', 120),
            30: ('Dandelions', 'pass', 100), 31: ('Crocus', 'pass', 120), 32: ('Bluebells', 'pass', 120), 33: ('Lily of the Valley', 'pass', 150),
            34: ('Clover', 'pass', 80), 35: ('Fern Sprout', 'pass', 100), 36: ('Tall Grass', 'pass', 80), 37: ('Short Grass', 'pass', 60),
            38: ('Cattails', 'pass', 150), 39: ('Pink Flower Patch', 'pass', 300), 40: ('Yellow Flower Patch', 'pass', 300),
            41: ('Mossy Boulder', 'wide', 900), 42: ('Mossy Rock', 'solid', 400), 43: ('Pebbles', 'pass', 80)},
 'autumn': {6: ('Red Maple', POHON, 2800), 7: ('Orange Tree', POHON, 2600), 1: ('Golden Tree', POHON, 2600), 2: ('Turning Oak', POHON, 2400),
            3: ('Golden Birch', POHON, 2400), 4: ('Autumn Pine', POHON, 1800), 5: ('Bare Tree', POHON, 1500), 15: ('Small Maple', POHON, 1000),
            17: ('Maple Sapling', 'pass', 400), 18: ('Red Sapling', 'pass', 400), 19: ('Leafy Stump', 'solid', 400), 20: ('Mushroom Log', 'wide', 900),
            25: ('Little Stump', 'solid', 250), 26: ('Old Stump', 'solid', 350), 27: ('Mossy Log', 'wide', 800), 21: ('Orange Bush', 'solid', 500),
            22: ('Crimson Bush', 'solid', 500), 23: ('Yellow Bush', 'solid', 500), 24: ('Berry Bush', 'solid', 700), 35: ('Marigolds', 'pass', 150),
            36: ('Asters', 'pass', 150), 37: ('Yellow Marigolds', 'pass', 150), 33: ('Spider Lily', 'pass', 200), 34: ('Autumn Cattails', 'pass', 150),
            38: ('Golden Grass', 'pass', 80), 39: ('Dry Grass', 'pass', 60), 43: ('Red Daisies', 'pass', 150), 44: ('Brown Grass', 'pass', 60),
            45: ('Dry Tuft', 'pass', 50), 46: ('Autumn Fern', 'pass', 120), 47: ('Toadstools', 'pass', 120), 48: ('Brown Mushrooms', 'pass', 120),
            49: ('Acorns and Leaves', 'pass', 80), 50: ('Big Toadstool', 'pass', 150), 51: ('Mushroom Cluster', 'pass', 150), 52: ('Acorns', 'pass', 60),
            40: ('Leaf Pile', 'pass', 200), 42: ('Golden Leaf Pile', 'pass', 180), 54: ('Leafy Boulder', 'wide', 900), 56: ('Autumn Pebbles', 'pass', 80)},
 'winter': {5: ('Snowy Pine', POHON, 2000), 6: ('Frosted Pine', POHON, 2000), 0: ('Dark Snowy Pine', POHON, 2200), 1: ('Snowy Oak', POHON, 2000),
            2: ('Snowy Birch', POHON, 2000), 3: ('Holly Tree', POHON, 2800), 4: ('Frost Tree', POHON, 3200), 18: ('Small Snowy Pine', POHON, 800),
            14: ('Young Snowy Pine', POHON, 1000), 19: ('Snowy Stump', 'solid', 250), 20: ('Snow Capped Stump', 'solid', 350), 15: ('Big Snowy Stump', 'solid', 400),
            16: ('Snowy Log', 'wide', 700), 17: ('Long Snowy Log', 'wide', 800), 21: ('Snowy Bush', 'solid', 500), 22: ('Holly Bush', 'solid', 700),
            23: ('Frosty Twigs', 'pass', 300), 24: ('Winterberry Twigs', 'pass', 400), 25: ('Snow Bush', 'solid', 500), 26: ('Berry Holly Bush', 'solid', 700),
            27: ('Bare Twigs', 'pass', 250), 28: ('Red Berry Bush', 'solid', 700), 29: ('Snowdrops', 'pass', 150), 30: ('Camellias', 'pass', 200),
            31: ('Hellebores', 'pass', 200), 32: ('Frost Grass', 'pass', 80), 33: ('Winter Grass', 'pass', 60), 34: ('Snowy Cattails', 'pass', 150),
            37: ('Holly Sprig', 'pass', 120), 38: ('Frost Fern', 'pass', 150), 39: ('Snow Mushrooms', 'pass', 120), 40: ('Snow Pile', 'pass', 100),
            41: ('Snowdrift', 'pass', 150), 42: ('Icicle Branch', 'pass', 250), 43: ('Frozen Branch', 'pass', 250), 44: ('Snowy Boulder', 'wide', 900),
            45: ('Snowy Rocks', 'solid', 400), 46: ('Snowy Rock', 'solid', 400), 47: ('Frosty Pebbles', 'pass', 80)},
}
SEASON_NAME = {'spring': 'Spring', 'autumn': 'Autumn', 'winter': 'Winter'}
for sh, d in NAT.items():
    for i, (nm, kind, pr) in d.items():
        im = bersih(sh, K[sh][i]); k = 0.6
        w, h = im.size
        id_ = slug(nm)
        if id_ in ITEMS:
            id_ = slug(nm + ' ' + sh)
        if kind == POHON:
            tp, lw, ds = [1, 1], False, 'A decorative tree.'
        elif kind == 'wide':
            tp, lw, ds = tapak_auto(w, h, k, 0.8), False, 'A natural decoration.'
        elif kind == 'solid':
            tp, lw, ds = tapak_auto(w, h, k, 0.7), False, 'A natural decoration.'
        else:
            tp, lw, ds = [1, 1], True, 'A small plant you can walk through.'
        tambah(id_, nm, 'Nature', im, k, tp, pr, ds + ' Best in %s.' % SEASON_NAME[sh], lewat=lw, musim=SEASON_NAME[sh])

# ---------------- tanaman ----------------
CROPS = ['Wheat', 'Carrot', 'Turnip', 'Bellflower', 'Potato', 'Strawberry', 'Cabbage', 'Radish', 'Peas', 'Tulip', 'Tomato', 'Corn',
         'Melon', 'Blueberry', 'Sunflower', 'Pumpkin', 'Eggplant', 'Sweet Potato', 'Grape', 'Cranberry', 'Garlic', 'Onion', 'Daikon', 'Snowdrop',
         'Rose', 'Lavender', 'Apple', 'Cherry', 'Herbs', 'Wildflowers']
DAYS = [4, 3, 3, 4, 4, 5, 5, 2, 4, 4, 6, 7, 8, 6, 5, 8, 6, 5, 8, 6, 4, 4, 5, 3, 6, 5, 10, 10, 3, 4]
SEED = [20, 25, 20, 40, 30, 60, 50, 15, 35, 40, 60, 80, 100, 80, 60, 120, 70, 60, 120, 80, 30, 30, 45, 50, 90, 70, 200, 200, 25, 40]
# skala gambar (x4) -> dunia: kotak tanah 37 px (lembar tumbuh) / 24 px (lembar tanaman) = 30 px dunia
KT = round(30 / (37 * 4), 4)
KM = round(30 / (24 * 4), 4)
OWN = {'Blueberry': 0, 'Carrot': 1, 'Sunflower': 3, 'Wheat': 4, 'Eggplant': 5}
TANI = {}
for idx, nm in enumerate(CROPS):
    c, r = idx % 6, idx // 6
    s = slug(nm)
    px4(sel('bibit', 6, 5, c, r)).save(ROOT + 'assets/tani/bibit_%s.png' % s)
    px4(sel('panen', 6, 6, c, r)).save(ROOT + 'assets/tani/panen_%s.png' % s)
    stages = []
    if nm in OWN:
        rr = OWN[nm]
        n = 6 if nm == 'Eggplant' else 5
        for st in range(n):
            px4(sel('tumbuh', 6, 6, st, rr)).save(ROOT + 'assets/tani/%s_%d.png' % (s, st))
            stages.append({"p": 'res://assets/tani/%s_%d.png' % (s, st), "k": KT})
    else:
        for st in range(3):   # dibuat tahap_tani.py (bedeng sama dengan gambar matang)
            stages.append({"p": 'res://assets/tani/%s_%d.png' % (s, st), "k": KM})
        px4(sel('tanaman', 6, 5, c, r)).save(ROOT + 'assets/tani/%s_matang.png' % s)
        stages.append({"p": 'res://assets/tani/%s_matang.png' % s, "k": KM})
    TANI[s] = {"nama": nm, "hari": DAYS[idx], "bibit": 'bibit_' + s, "hasil": s, "tahap": stages,
               "jual": round(SEED[idx] * 1.6 + DAYS[idx] * 5)}
    ITEMS['bibit_' + s] = {"nama": nm + ' Seeds', "kategori": 'Seeds', "ikon": 'res://assets/tani/bibit_%s.png' % s, "harga": SEED[idx],
                           "kristal": 0, "desk": 'Sow on tilled soil. Water daily. Ready in %d days.' % DAYS[idx], "tumpuk": 99}
    ITEMS[s] = {"nama": nm, "kategori": 'Crops', "ikon": 'res://assets/tani/panen_%s.png' % s, "harga": 0, "kristal": 0,
                "jual": TANI[s]['jual'], "desk": 'Harvested from %s Seeds after %d days.' % (nm, DAYS[idx]), "tumpuk": 999}

# ---------------- ternak ----------------
ANIM = [('cow', 'Cow', 4, 3000, 'milk'), ('chicken', 'Chicken', 2, 800, 'egg'), ('duck', 'Duck', 2, 900, 'duck_egg'),
        ('sheep', 'Sheep', 3, 2500, 'wool'), ('goose', 'Goose', 3, 1200, 'goose_egg')]
VIEWS = ['bayi', 'depan', 'samping', 'belakang', 'duduk']
TERNAK = {}
for r, (s, nm, hari, harga, hasil) in enumerate(ANIM):
    for c, v in enumerate(VIEWS):
        px4(sel('hewan', 6, 5, c, r)).save(ROOT + 'assets/ternak/%s_%s.png' % (s, v))
    TERNAK[s] = {"nama": nm, "dewasa": hari, "hasil": hasil, "k": {'cow': 0.5, 'sheep': 0.46, 'goose': 0.36, 'duck': 0.3, 'chicken': 0.29}[s]}
    ITEMS['ternak_' + s] = {"nama": 'Baby ' + nm, "kategori": 'Animals', "ikon": 'res://assets/ternak/%s_bayi.png' % s, "harga": harga,
                            "kristal": 0, "desk": 'A young %s. Grows up in %d days, then gives %s every day.' % (nm.lower(), hari, hasil.replace('_', ' ')),
                            "tumpuk": 9, "hewan": s}
PROD = {(0, 0): ('small_milk', 'Small Milk', 60), (0, 1): ('milk', 'Milk', 120), (0, 2): ('milk_pail', 'Milk Pail', 300), (0, 3): ('cheese', 'Cheese', 350),
        (0, 4): ('butter', 'Butter', 300), (1, 0): ('egg', 'Egg', 50), (1, 1): ('brown_egg', 'Brown Egg', 55), (1, 2): ('large_egg', 'Large Brown Egg', 90),
        (1, 3): ('golden_egg', 'Golden Egg', 1000), (1, 4): ('feather', 'Feather', 40), (2, 0): ('duck_egg', 'Duck Egg', 90), (2, 1): ('goose_egg', 'Goose Egg', 140),
        (2, 2): ('quail_egg', 'Speckled Egg', 70), (2, 3): ('goose_feather', 'Goose Feather', 60), (2, 4): ('down', 'Down Fluff', 120),
        (3, 0): ('wool', 'Wool', 250), (3, 1): ('fine_wool', 'Fine Wool', 500), (3, 2): ('yarn', 'Yarn', 400), (3, 3): ('goat_milk', 'Goat Milk', 200),
        (3, 4): ('goat_cheese', 'Goat Cheese', 450)}
SOURCE = {'small_milk': 'Cows (young adults)', 'milk': 'Cows, every day', 'milk_pail': 'Cows, sometimes', 'cheese': 'Recipe: Milk x2',
          'butter': 'Recipe: Milk x2', 'egg': 'Chickens, every day', 'brown_egg': 'Chickens, every day', 'large_egg': 'Chickens, sometimes',
          'golden_egg': 'Chickens, very rare', 'feather': 'Ducks, sometimes', 'duck_egg': 'Ducks, every day', 'goose_egg': 'Geese, every day',
          'quail_egg': 'Geese, sometimes', 'goose_feather': 'Geese, sometimes', 'down': 'Geese, sometimes', 'wool': 'Sheep, every day',
          'fine_wool': 'Sheep, sometimes', 'yarn': 'Recipe: Wool x2', 'goat_milk': 'Coming soon (goats)', 'goat_cheese': 'Coming soon (goats)'}
for (r, c), (s, nm, jual) in PROD.items():
    px4(sel('produk', 5, 4, c, r)).save(ROOT + 'assets/ternak/hasil_%s.png' % s)
    ITEMS[s] = {"nama": nm, "kategori": 'Animal Products', "ikon": 'res://assets/ternak/hasil_%s.png' % s, "harga": 0, "kristal": 0,
                "jual": jual, "desk": 'From: ' + SOURCE[s], "tumpuk": 999}

# ---------------- ikon toko musiman ----------------
for nm, i in zip(['spring', 'winter', 'summer', 'autumn'], range(4)):
    b = K['toko'][i]
    im = Image.open(SRC + 'toko.png').convert('RGBA').crop(tuple(b))
    a = np.array(im); a[..., 3] = np.where(a[..., 3] > 110, 255, 0); a[a[..., 3] == 0] = 0
    im = Image.fromarray(a); im = im.crop(im.getbbox()); im.thumbnail((256, 256), Image.LANCZOS)
    im.save(ROOT + 'assets/ui/toko_%s.png' % nm)

# ---------------- resep ----------------
RESEP = [
    {"nama": 'Cheese', "hasil": 'cheese', "bahan": {'milk': 2}, "desk": 'Aged milk, rich and creamy.'},
    {"nama": 'Butter', "hasil": 'butter', "bahan": {'milk': 2}, "desk": 'Churned from fresh milk.'},
    {"nama": 'Yarn', "hasil": 'yarn', "bahan": {'wool': 2}, "desk": 'Spun from soft wool.'},
    {"nama": 'Pumpkin Soup', "bahan": {'pumpkin': 1, 'milk': 1}, "desk": 'Warm autumn soup. Restores lots of energy.'},
    {"nama": 'Omelet', "bahan": {'egg': 2, 'milk': 1}, "desk": 'Fluffy eggs cooked with milk.'},
    {"nama": 'Veggie Salad', "bahan": {'cabbage': 1, 'tomato': 1, 'carrot': 1}, "desk": 'Fresh and crunchy.'},
    {"nama": 'Baked Potato', "bahan": {'potato': 1, 'butter': 1}, "desk": 'Golden potato with butter.'},
    {"nama": 'Strawberry Jam', "bahan": {'strawberry': 3}, "desk": 'Sweet jam for bread.'},
    {"nama": 'Blueberry Pie', "bahan": {'blueberry': 3, 'wheat': 1, 'butter': 1}, "desk": 'A classic farm pie.'},
    {"nama": 'Apple Pie', "bahan": {'apple': 2, 'wheat': 1, 'egg': 1}, "desk": 'Cinnamon apple pie.'},
    {"nama": 'Corn Chowder', "bahan": {'corn': 2, 'milk': 1, 'onion': 1}, "desk": 'Creamy corn soup.'},
    {"nama": 'Tomato Soup', "bahan": {'tomato': 2, 'garlic': 1}, "desk": 'Simple and comforting.'},
    {"nama": 'Grilled Eggplant', "bahan": {'eggplant': 1, 'garlic': 1}, "desk": 'Smoky grilled eggplant.'},
    {"nama": 'Sweet Potato Fries', "bahan": {'sweet_potato': 2}, "desk": 'Crispy and sweet.'},
    {"nama": 'Cranberry Sauce', "bahan": {'cranberry': 3}, "desk": 'Tart winter sauce.'},
    {"nama": 'Cherry Tart', "bahan": {'cherry': 2, 'wheat': 1, 'egg': 1}, "desk": 'A bright red tart.'},
    {"nama": 'Grape Juice', "bahan": {'grape': 3}, "desk": 'Fresh-pressed grapes.'},
    {"nama": 'Herb Bread', "bahan": {'wheat': 2, 'herbs': 1}, "desk": 'Fragrant homemade bread.'},
    {"nama": 'Melon Smoothie', "bahan": {'melon': 1, 'milk': 1}, "desk": 'Cool summer smoothie.'},
    {"nama": 'Lavender Tea', "bahan": {'lavender': 2}, "desk": 'Calming floral tea.'},
    {"nama": 'Pea Soup', "bahan": {'peas': 2, 'onion': 1}, "desk": 'Hearty green soup.'},
    {"nama": 'Pickled Radish', "bahan": {'radish': 2, 'daikon': 1}, "desk": 'Crunchy pickles.'},
    {"nama": 'Turnip Stew', "bahan": {'turnip': 2, 'carrot': 1, 'potato': 1}, "desk": 'A thick farmhouse stew.'},
    {"nama": 'Custard', "bahan": {'egg': 2, 'milk': 2}, "desk": 'Silky sweet custard.'},
]
for it in ITEMS.values():
    it.setdefault('tumpuk', 99)
    it.setdefault('ikon', it.get('gambar', ''))
json.dump({"items": ITEMS, "tanaman": TANI, "ternak": TERNAK, "resep": RESEP}, open(ROOT + 'data/katalog.json', 'w'), indent=1)
from collections import Counter
print(len(ITEMS), Counter(v['kategori'] for v in ITEMS.values()))
