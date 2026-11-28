"""Panggang ladang padang rumput LUAS (default 155x116 petak @32 px = 15x luas versi awal).
Tanah tidak dipanggang: tanah muncul di game saat pemain membuat jalan / mencangkul.
Hasil dipotong per 1024 px agar aman untuk GPU HP.
Pakai: python3 kit.py && python3 bake_luas.py [kolom] [baris] [seed]"""
from PIL import Image
import numpy as np, sys, os, json
from scipy.ndimage import gaussian_filter, zoom as nzoom
COLS=int(sys.argv[1]) if len(sys.argv)>1 else 155
ROWS=int(sys.argv[2]) if len(sys.argv)>2 else 116
SEED=int(sys.argv[3]) if len(sys.argv)>3 else 11
T=32; W,H=COLS*T,ROWS*T; CH=1024
rng=np.random.default_rng(SEED)
hx=lambda h: np.array([int(h[i:i+2],16) for i in (1,3,5)],np.uint8)
G_BASE,G_LIGHT,G_SHADE,G_DEEP=hx('#6EA427'),hx('#94BD1B'),hx('#4E912F'),hx('#2F6A32')
def L(role,kind='stamps'):
    out=[]
    for s in np.load(f'kit_{role}_{kind}.npy',allow_pickle=True):
        a=s[...,3]>0; h,w=a.shape
        if kind=='stamps' and h*w>=16 and a.mean()>0.72: continue
        px=s[a][:,:3].astype(int)
        lime=((np.abs(px-[0x94,0xBD,0x1B]).sum(1)<20)|(np.abs(px-[0xBF,0xE3,0x3E]).sum(1)<20)).mean() if len(px) else 0
        if kind=='stamps' and len(px)>=10 and lime>0.5: continue
        out.append(s)
    return out
ZONES=['rumput_dasar','rumput_rimbun','rumput_kalem','rumput_bunga','rumput_kering']
ST={z:L(z) for z in ZONES}
def is_flower(s):
    rgb=s[...,:3].astype(int); m=s[...,3]>0
    return bool((((rgb[...,0]>170)|(rgb[...,2]>160))&m).any())
def noise(sig,seed):
    """noise halus; frekuensi rendah dihitung di resolusi kecil lalu diperbesar (cepat & hemat memori)"""
    r=np.random.default_rng(seed)
    f=1
    while sig/f>=8 and f<16: f*=2
    h,w=-(-H//f),-(-W//f)
    n=gaussian_filter(r.standard_normal((h,w)).astype(np.float32),sig/f,mode='wrap')
    if f>1: n=nzoom(n,f,order=1)[:H,:W]
    # dinormalkan dengan simpangan baku (bukan nilai maks) agar kepadatan bercak sama di peta sebesar apa pun
    return (n/(n.std()*3.4)).astype(np.float32)
RND=np.random.default_rng(SEED+99).random((H,W),dtype=np.float32)
def dith(f,thr,band): return f>thr+(RND-0.5)*2*band
yy=np.arange(H,dtype=np.float32)[:,None]; xx=np.arange(W,dtype=np.float32)[None,:]
border=np.minimum(np.minimum(xx,W-1-xx),np.minimum(yy,H-1-yy))      # jarak ke batas peta
edge=np.clip(1-border/420.0,0,1)                                      # pinggir hutan ~13 petak
img=np.empty((H,W,3),np.uint8); img[:]=G_BASE
light_f=noise(28,16)+0.35*noise(5,17)-edge*0.8
shade_f=noise(30,14)+0.35*noise(6,15)+edge*1.4
img[dith(light_f,0.55,0.10)]=G_LIGHT
img[dith(shade_f,0.62,0.10)]=G_SHADE
img[dith(shade_f,1.15,0.08)&(noise(4,18)>0.2)]=G_DEEP
del light_f
# helai di batas nada teduh agar tidak licin (diambil acak, bukan semua)
for f_,thr,tone in ((shade_f,0.62,G_SHADE),):
    ys=rng.integers(0,H,400000); xs=rng.integers(0,W,400000)
    ok=np.abs(f_[ys,xs]-thr)<0.012
    for y,x in zip(ys[ok],xs[ok]):
        h=int(rng.integers(2,5))
        if y-h>0: img[y-h:y,x]=tone
del shade_f
# ---- tekstur helai rumput rapat di seluruh permukaan (bukan polos) ----
LADDER=np.array([[0x1E,0x3F,0x2B],[0x2F,0x6A,0x32],[0x4E,0x91,0x2F],[0x6E,0xA4,0x27],[0x94,0xBD,0x1B],[0xBF,0xE3,0x3E]],np.uint8)
def tone_index(px):
    d=np.abs(px[:,None,:].astype(int)-LADDER[None].astype(int)).sum(2); return d.argmin(1)
def blades_texture(n_per_px,dark):
    n=int(W*H*n_per_px)
    ys=rng.integers(4,H,n); xs=rng.integers(1,W-1,n)
    L=rng.integers(2,5 if dark else 4,n)              # panjang helai 2-4 px
    lean=rng.choice([-1,0,0,0,1],n)                    # sebagian ujung miring
    ti=tone_index(img[ys,xs])
    ti=np.clip(ti+(-1 if dark else 1),0,len(LADDER)-1)
    if dark:  # jangan pakai hijau paling gelap kecuali di area teduh pekat
        ti=np.where(ti==0,1,ti)
    col=LADDER[ti]
    for k in range(4):
        m=L>k
        yk=ys[m]-k; xk=xs[m]+np.where(k==L[m]-1,lean[m],0)
        img[yk,xk]=col[m]
def tufts(n_per_px):
    """rumpun helai: 4-7 helai mekar dari satu pangkal; helai belakang gelap, depan terang"""
    n=int(W*H*n_per_px)
    cy=rng.integers(6,H,n); cx=rng.integers(4,W-4,n)
    base_t=tone_index(img[cy,cx])
    for b in range(7):
        use=rng.random(n)<(1.0 if b<4 else 0.5)
        off=rng.integers(-3,4,n)                       # posisi helai di sekitar pangkal
        L=rng.integers(2,6,n)
        lean=np.sign(off)*(rng.random(n)<0.6)          # helai pinggir condong keluar
        front=(np.abs(off)<=1)&(rng.random(n)<0.55)
        ti=np.clip(base_t+np.where(front,1,-1),1,len(LADDER)-1)
        col=LADDER[ti]
        yb=cy-rng.integers(0,2,n)
        for k in range(5):
            m=use&(L>k)
            yk=yb[m]-k; xk=cx[m]+off[m]+np.where(k>=L[m]-2,lean[m],0)
            img[yk,np.clip(xk,0,W-1)]=col[m]
blades_texture(1/14,True)      # sela gelap tipis di antara rumpun
tufts(1/34)                    # rumpun-rumpun helai
blades_texture(1/40,False)     # kilau terang sesekali

def stamp(s,x,y):
    h,w=s.shape[:2]
    if x<0 or y<0 or x+w>W or y+h>H: return
    m=s[...,3]>0; img[y:y+h,x:x+w][m]=s[m,:3]
# zona: tiap tileset rumput menguasai wilayahnya, berbaur di perbatasan
zbest=None; zarg=None
for i,z in enumerate(ZONES):
    f=noise(45,30+i)+0.25*noise(8,40+i)
    if z=='rumput_rimbun': f=f+edge*1.2
    if z=='rumput_kering': f=f+(noise(28,16)>0.3)*0.5
    if zbest is None: zbest=f; zarg=np.zeros((H,W),np.uint8)
    else:
        b=f>zbest; zbest=np.where(b,f,zbest); zarg[b]=i
del zbest
for i,z in enumerate(ZONES):
    pool=ST[z]; fl=[is_flower(s) for s in pool]
    green=[s for s,f in zip(pool,fl) if not f]; flw=[s for s,f in zip(pool,fl) if f]
    fclust=noise(7,50+i)
    area=int((zarg==i).sum())
    for group,dens,clust in ((green,1/170,None),(flw,1/(360 if z=='rumput_bunga' else 900),fclust)):
        if not group: continue
        n=int(area*dens); ys=rng.integers(0,H,n*4); xs=rng.integers(0,W,n*4); placed=0
        for y,x in zip(ys,xs):
            if placed>=n: break
            if zarg[y,x]!=i: continue
            if clust is not None and rng.random()>np.clip(clust[y,x]*2.2,0,1): continue
            s=group[rng.integers(len(group))]
            if rng.random()<0.5: s=s[:,::-1]
            stamp(s,int(x)-s.shape[1]//2,int(y)-s.shape[0]//2); placed+=1
# batas peta: semak rimbun berlapis di tepi luar (pinggir hutan yang tak bisa dilewati)
bush=[s for s in ST['rumput_rimbun']+ST['rumput_dasar'] if not is_flower(s) and s.shape[0]>=5 and s.shape[1]>=5]
for _ in range(int((W+H)*2*0.9)):
    side=rng.integers(4); d=int(abs(rng.normal(0,40)))
    if side==0: x,y=rng.integers(0,W),d
    elif side==1: x,y=rng.integers(0,W),H-1-d
    elif side==2: x,y=d,rng.integers(0,H)
    else: x,y=W-1-d,rng.integers(0,H)
    s=bush[rng.integers(len(bush))]; stamp(s,int(x)-s.shape[1]//2,int(y)-s.shape[0]//2)
out='../../assets/lanskap/ladang'
os.makedirs(out,exist_ok=True)
for f in os.listdir(out):
    if f.endswith('.png'): os.remove(os.path.join(out,f))
nx,ny=-(-W//CH),-(-H//CH)
for cy in range(ny):
    for cx in range(nx):
        Image.fromarray(img[cy*CH:(cy+1)*CH,cx*CH:(cx+1)*CH]).save(f'{out}/c_{cx}_{cy}.png',optimize=True)
json.dump({"cols":COLS,"rows":ROWS,"tile":T,"chunk":CH,"nx":nx,"ny":ny},open(f'{out}/info.json','w'))
Image.fromarray(img).resize((W//8,H//8),Image.BOX).save('pratinjau_ladang_luas.png')
Image.fromarray(img[H//2-180:H//2+180,W//2-320:W//2+320]).resize((1280,720),Image.NEAREST).save('pratinjau_tengah_x2.png')
print('selesai',W,H,'potongan',nx,ny)
