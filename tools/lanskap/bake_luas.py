"""Panggang ladang padang rumput LUAS (default 155x116 petak @32 px = 15x luas versi awal).
Tanah tidak dipanggang: tanah muncul di game saat pemain membuat jalan / mencangkul.
Hasil dipotong per 1024 px agar aman untuk GPU HP.
Pakai: python3 kit.py && python3 bake_luas.py [kolom] [baris] [seed]"""
from PIL import Image
import numpy as np, sys, os, json
from scipy.ndimage import gaussian_filter, zoom as nzoom
MID=sys.argv[1] if len(sys.argv)>1 else 'ladang'
MAP=json.load(open(f'../../data/maps/{MID}.json'))
ROWS=len(MAP['rows']); COLS=len(MAP['rows'][0])
SEED={'ladang':11,'hutan':23}.get(MID,5)
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
# sabuk hutan tertutup ('#') -> rumput lebih gelap, peralihan halus ke padang
mask=np.array([[c=='#' for c in r] for r in MAP['rows']],np.float32)
mask=gaussian_filter(nzoom(mask,T,order=0)[:H,:W],18)
edge=np.clip(mask*1.15,0,1)
img=np.empty((H,W,3),np.uint8); img[:]=G_BASE
light_f=noise(28,16)+0.35*noise(5,17)-edge*1.0
shade_f=noise(30,14)+0.35*noise(6,15)+edge*1.35
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
        L=rng.integers(2,5,n)
        lean=np.sign(off)*(rng.random(n)<0.6)          # helai pinggir condong keluar
        front=(np.abs(off)<=1)&(rng.random(n)<0.55)
        ti=np.clip(base_t+np.where(front,1,-1),1,len(LADDER)-1)
        col=LADDER[ti]
        yb=cy-rng.integers(0,2,n)
        for k in range(5):
            m=use&(L>k)
            yk=yb[m]-k; xk=cx[m]+off[m]+np.where(k>=L[m]-2,lean[m],0)
            img[yk,np.clip(xk,0,W-1)]=col[m]
# tekstur halus: cukup terasa sebagai rumput, tapi tidak menenggelamkan taburan detail
blades_texture(1/60,True)      # sela gelap tipis, jarang
tufts(1/150)                   # rumpun kecil sesekali
blades_texture(1/170,False)    # kilau terang sesekali

def stamp(s,x,y):
    h,w=s.shape[:2]
    if x<0 or y<0 or x+w>W or y+h>H: return
    m=s[...,3]>0; img[y:y+h,x:x+w][m]=s[m,:3]
# zona: tiap tileset rumput menguasai wilayahnya, berbaur di perbatasan
zbest=None; zarg=None
for i,z in enumerate(ZONES):
    f=noise(45,30+i)+0.25*noise(8,40+i)
    if z=='rumput_rimbun': f=f+edge*0.6
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
for _ in range(int((W+H)*2*0.25)):
    side=rng.integers(4); d=int(abs(rng.normal(0,40)))
    if side==0: x,y=rng.integers(0,W),d
    elif side==1: x,y=rng.integers(0,W),H-1-d
    elif side==2: x,y=d,rng.integers(0,H)
    else: x,y=W-1-d,rng.integers(0,H)
    s=bush[rng.integers(len(bush))]; stamp(s,int(x)-s.shape[1]//2,int(y)-s.shape[0]//2)
# ---------- bercak tanah / tanah berbatu / pasir: tepi bergerigi alami + helai rumput menjorok ----------
from scipy.ndimage import distance_transform_edt
PET={'tanah':dict(base='#EDBB78',dark='#DE9A4C',light='#F5D0B0',stamps=['tanah']),
     'tanah_batu':dict(base='#DE9A4C',dark='#C87D38',light='#EDBB78',stamps=['tanah','tanah_batu']),
     'pasir':dict(base='#F5D0B0',dark='#E8B28A',light='#F5D0B0',stamps=['pasir'])}
SOIL={k:L(k) for k in ('tanah','tanah_batu','pasir')}
BLADES=sum([L(z,'blades') for z in ZONES],[])
GRASS_TUFT=[s for s in ST['rumput_dasar']+ST['rumput_rimbun'] if not is_flower(s) and s.shape[0]<=6 and s.shape[1]<=7]
for p in MAP.get('petak_tanah',[]):
    pr=np.random.default_rng(p['seed']); cfgp=PET[p['jenis']]
    R0=int(p['r']*1.6)+24; x0,y0=int(p['x'])-R0,int(p['y'])-R0; S=2*R0
    if x0<0 or y0<0 or x0+S>W or y0+S>H: continue
    yy2,xx2=np.mgrid[0:S,0:S].astype(np.float32)
    def n2(sig,sd):
        z=gaussian_filter(np.random.default_rng(sd).standard_normal((S,S)).astype(np.float32),sig); return z/(z.std()*3.4)
    d=np.hypot((xx2-R0)/p['r'],(yy2-R0)/(p['r']*0.78))
    f=d+0.55*n2(p['r']/4,p['seed'])+0.20*n2(4,p['seed']+1)+0.10*n2(1.3,p['seed']+2)
    rnd=pr.random((S,S)).astype(np.float32)
    m=f<1.0+(rnd-0.5)*0.10                       # tepi bergerigi (dither halus)
    from scipy.ndimage import label as _lab
    lb,kk=_lab(m)
    if kk==0: continue
    sz=np.bincount(lb.ravel()); sz[0]=0; m=lb==sz.argmax()   # satu bercak utama
    sub=img[y0:y0+S,x0:x0+S]
    sub[m]=hx(cfgp['base'])
    tn=n2(10,p['seed']+3)+0.4*n2(3,p['seed']+4)
    sub[m&(tn>0.48)]=hx(cfgp['dark']); sub[m&(tn<-0.52)]=hx(cfgp['light'])
    sp=pr.random((S,S))
    sub[m&(sp<0.03)]=hx(cfgp['dark']); sub[m&(sp>0.975)]=hx(cfgp['light'])
    din=distance_transform_edt(m)
    # tanah dekat tepi sedikit lebih gelap (lembap di bawah rumput)
    sub[m&(din<=2.2)&(pr.random((S,S))<0.55)]=hx(cfgp['dark'])
    # stempel kerikil/retakan dari tileset
    pool=sum([SOIL[k] for k in cfgp['stamps']],[])
    pts=np.argwhere(m&(din>5))
    for y,x in pts[pr.choice(len(pts),size=min(len(pts),max(2,len(pts)//520)),replace=False)] if len(pts) else []:
        st=pool[pr.integers(len(pool))]; h,w=st.shape[:2]
        if y+h<S and x+w<S:
            mm=st[...,3]>0; sub[y:y+h,x:x+w][mm]=st[mm,:3]
    # helai rumput menjorok ke tanah sepanjang tepi (pangkal di rumput)
    edge=np.argwhere(m&(din<=1.0)); pr.shuffle(edge)
    for y,x in edge[:len(edge)//4]:
        b=BLADES[pr.integers(len(BLADES))]; b=b[-int(pr.integers(3,8)):]
        if pr.random()<0.5: b=b[:,::-1]
        h,w=b.shape[:2]; yy0=y-h+int(pr.integers(2,5)); xx0=x-w//2
        if 0<=yy0 and yy0+h<S and 0<=xx0 and xx0+w<S:
            mm=b[...,3]>0; sub[yy0:yy0+h,xx0:xx0+w][mm]=b[mm,:3]
    # beberapa gumpal rumput kecil tumbuh di dalam tanah dekat tepi
    inner=np.argwhere(m&(din>2)&(din<10)); pr.shuffle(inner)
    for y,x in inner[:max(2,len(inner)//380)]:
        t=GRASS_TUFT[pr.integers(len(GRASS_TUFT))]; h,w=t.shape[:2]
        if y+h<S and x+w<S:
            mm=t[...,3]>0; sub[y:y+h,x:x+w][mm]=t[mm,:3]
out=f'../../assets/lanskap/{MID}'
os.makedirs(out,exist_ok=True)
for f in os.listdir(out):
    if f.endswith('.png'): os.remove(os.path.join(out,f))
nx,ny=-(-W//CH),-(-H//CH)
for cy in range(ny):
    for cx in range(nx):
        Image.fromarray(img[cy*CH:(cy+1)*CH,cx*CH:(cx+1)*CH]).save(f'{out}/c_{cx}_{cy}.png',optimize=True)
json.dump({"cols":COLS,"rows":ROWS,"tile":T,"chunk":CH,"nx":nx,"ny":ny},open(f'{out}/info.json','w'))
Image.fromarray(img).resize((W//8,H//8),Image.BOX).save(f'pratinjau_{MID}.png')
Image.fromarray(img[0:360,W//3:W//3+640]).resize((1280,720),Image.NEAREST).save(f'pratinjau_{MID}_tepi.png')
print('selesai',W,H,'potongan',nx,ny)
