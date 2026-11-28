"""Panggang lanskap starter Aether Valley dari bahan 8 tileset (palet 47)."""
from PIL import Image
import numpy as np, json, sys
from scipy.ndimage import gaussian_filter, distance_transform_edt
SEED=int(sys.argv[1]) if len(sys.argv)>1 else 11
# Padang rumput murni: tanah hanya muncul saat pemain membuat jalan / mencangkul (di dalam game)
PURE_GRASS='--dengan-jalan' not in sys.argv
rng=np.random.default_rng(SEED)
W,H=1280,960          # piksel seni = 40x30 petak @32
hx=lambda h: np.array([int(h[i:i+2],16) for i in (1,3,5)],np.uint8)
G_BASE,G_LIGHT,G_SHADE,G_DEEP=hx('#6EA427'),hx('#94BD1B'),hx('#4E912F'),hx('#2F6A32')
D_BASE,D_DARK,D_LIGHT=hx('#EDBB78'),hx('#DE9A4C'),hx('#F5D0B0')
S_BASE,S_EDGE=hx('#F5D0B0'),hx('#E8B28A')
def L(role,kind='stamps'):
    out=[]
    for s in np.load(f'kit_{role}_{kind}.npy',allow_pickle=True):
        a=s[...,3]>0; h,w=a.shape
        if kind=='stamps' and h*w>=16 and a.mean()>0.72: continue   # buang potongan kotak penuh
        px=s[a][:,:3].astype(int)
        lime=((np.abs(px-[0x94,0xBD,0x1B]).sum(1)<20)|(np.abs(px-[0xBF,0xE3,0x3E]).sum(1)<20)).mean() if len(px) else 0
        if kind=='stamps' and len(px)>=10 and lime>0.5: continue    # buang 'daun' limau polos
        out.append(s)
    return out
ST={r:L(r) for r in ['tanah','tanah_batu','rumput_bunga','rumput_kalem','rumput_rimbun','rumput_kering','rumput_dasar','pasir']}
BL=sum([L(r,'blades') for r in ['rumput_bunga','rumput_kalem','rumput_rimbun','rumput_kering','rumput_dasar']],[])
def is_flower(s):
    rgb=s[...,:3].astype(int); m=s[...,3]>0
    return bool((((rgb[...,0]>170)|(rgb[...,2]>160))&m).any())
def noise(sig,seed):
    n=gaussian_filter(np.random.default_rng(seed).standard_normal((H,W)),sig,mode='wrap'); return n/np.abs(n).max()
yy,xx=np.mgrid[0:H,0:W].astype(float)
RND=np.random.default_rng(SEED+99).random((H,W))
def dith(f,thr,band):
    # batas berbintik: dekat ambang, piksel acak memilih sisi -> peralihan khas pixel art
    return f>thr+(RND-0.5)*2*band
def seg_dist(pts):
    d=np.full((H,W),1e9)
    for (ax,ay),(bx,by) in zip(pts[:-1],pts[1:]):
        abx,aby=bx-ax,by-ay; t=np.clip(((xx-ax)*abx+(yy-ay)*aby)/(abx*abx+aby*aby),0,1)
        d=np.minimum(d,np.hypot(xx-(ax+t*abx),yy-(ay+t*aby)))
    return d
def smooth_path(pts,n=8):
    # Catmull-Rom agar jalan melengkung halus
    P=[pts[0]]+pts+[pts[-1]]; out=[]
    for i in range(1,len(P)-2):
        p0,p1,p2,p3=map(np.array,(P[i-1],P[i],P[i+1],P[i+2]))
        for t in np.linspace(0,1,n,endpoint=False):
            out.append(0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t**3))
    out.append(np.array(P[-2])); return [tuple(p) for p in out]
# ---------------- TATA LETAK ----------------
HOUSE=(430,230)                       # titik depan rumah (rumah sendiri menyusul sebagai aset)
yard_f=np.hypot((xx-430)/165,(yy-335)/88)+0.22*noise(16,1)+0.10*noise(5,2)+0.04*noise(1.5,20)
yard=yard_f<1.0                       # halaman pasir depan rumah
main=smooth_path([(430,380),(470,470),(600,540),(800,560),(1000,600),(1150,590),(1290,600)])
south=smooth_path([(600,540),(620,640),(590,760),(640,880),(700,970)])
west=smooth_path([(330,360),(230,420),(140,430),(-10,470)])
dp=np.minimum(np.minimum(seg_dist(main),seg_dist(south)+2),seg_dist(west)+6)
width=24+6*noise(40,3)
road=(dp+5*noise(6,4)+2.2*noise(1.6,5))<width
# lahan bakal ladang (tanah terbuka berbatu, khas ladang awal yang perlu dibersihkan)
field_f=(np.abs(xx-870)/215)**3+(np.abs(yy-775)/120)**3+0.30*noise(12,6)+0.10*noise(3,7)+0.04*noise(1.4,21)
field=field_f<1.0
dirt=road|field
if PURE_GRASS:
    yard[:]=False; dirt[:]=False; road[:]=False; field[:]=False
grass=~(dirt|yard)
# ---------------- TANAH & PASIR ----------------
img=np.zeros((H,W,3),np.uint8)
img[:]=D_BASE
ground=dirt|yard
dn=noise(16,8)+0.3*noise(4,9)
img[ground&dith(dn,0.62,0.12)]=D_DARK
img[ground&~dith(dn,-0.62,0.12)]=D_LIGHT
sp=np.random.default_rng(SEED+7).random((H,W))
img[ground&(sp<0.020)]=D_DARK          # bintik tanah
img[ground&(sp>0.985)]=D_LIGHT
img[yard&dith(noise(12,22),0.35,0.15)]=S_BASE   # bercak pasir padat di halaman
def stamp(s,x,y,mask=None):
    h,w=s.shape[:2]; x=int(x); y=int(y)
    if x<0 or y<0 or x+w>W or y+h>H: return False
    if mask is not None and not mask[y:y+h,x:x+w][s[...,3]>0].all(): return False
    m=s[...,3]>0; img[y:y+h,x:x+w][m]=s[m,:3]; return True
def scatter(region,density,pool,weight=None,flip=True,cluster=None,tries_mult=3):
    pts=np.argwhere(region); 
    if len(pts)==0: return
    n=int(len(pts)*density)
    for _ in range(n*tries_mult):
        if n<=0: break
        y,x=pts[rng.integers(len(pts))]
        if cluster is not None and rng.random()>cluster[y,x]: continue
        s=pool[rng.integers(len(pool))] if weight is None else pool[rng.choice(len(pool),p=weight)]
        if flip and rng.random()<0.5: s=s[:,::-1]
        if stamp(s,x-s.shape[1]//2,y-s.shape[0]//2,region): n-=1
# kerikil/retakan tanah: lebih rapat di pinggir jalan & di lahan; batu dari tanah_batu menggerombol
dout_road=distance_transform_edt(~grass)  # dalam tanah: jarak ke rumput
edge_band=np.clip(1.0-distance_transform_edt(dirt)/18.0,0,1)
scatter(dirt,1/900,ST['tanah'],cluster=0.35+0.65*edge_band)
rocky=np.clip(noise(22,12)*1.8,0,1)
scatter(field,1/220,ST['tanah_batu'],cluster=0.15+0.85*rocky)
scatter(road,1/2600,ST['tanah_batu'],cluster=np.clip(noise(22,13)*2,0,1))
scatter(yard,1/420,ST['pasir'])
scatter(yard,1/1600,ST['tanah'])
# ---------------- RUMPUT ----------------
# satu hijau dasar; bercak terang (terik) & teduh (dekat tepi peta = pinggir hutan)
border=np.minimum.reduce([xx,yy,W-1-xx,H-1-yy])
shade_f=noise(30,14)+0.35*noise(6,15)+np.clip(1-border/170,0,1)*0.9
light_f=noise(28,16)+0.35*noise(5,17)
G=np.zeros((H,W,3),np.uint8); G[:]=G_BASE
G[dith(light_f,0.55,0.10)]=G_LIGHT
G[dith(shade_f,0.62,0.10)]=G_SHADE
G[dith(shade_f,1.15,0.08)&(noise(4,18)>0.2)]=G_DEEP
img[grass]=G[grass]
din=distance_transform_edt(grass)
# helai di batas nada terang/teduh agar tidak licin
for tone,f,thr in ((G_LIGHT,light_f,0.55),(G_SHADE,shade_f,0.62)):
    pts=np.argwhere(grass&(np.abs(f-thr)<0.012)); rng.shuffle(pts)
    for y,x in pts[:len(pts)//5]:
        h=int(rng.integers(2,5))
        if y-h>0: img[y-h:y,x]=tone
# bibir tepi: piksel teduh putus-putus di batas, tanpa garis luar tegas
img[grass&(din<=1.0)&(noise(0.7,19)>-0.15)]=G_SHADE
# zona detail: tiap tileset rumput menguasai wilayahnya sendiri, berbaur di perbatasan
zones=['rumput_dasar','rumput_rimbun','rumput_kalem','rumput_bunga','rumput_kering']
zf=np.stack([noise(45,30+i)+0.25*noise(8,40+i) for i in range(5)])
zf[1]+=np.clip(1-border/220,0,1)*0.8            # rimbun di pinggir hutan
zf[3]+=np.exp(-(((xx-470)/330)**2+((yy-250)/220)**2))*0.9   # padang bunga sekitar rumah
zf[4]+=(light_f>0.3)*0.5                         # kering di area terik
zone=zf.argmax(0)
inner=grass&(din>3)
for i,z in enumerate(zones):
    pool=ST[z]; fl=np.array([is_flower(s) for s in pool])
    # bunga tumbuh menggerombol, bukan rata
    fclust=np.clip(noise(7,50+i)*2.2,0,1)
    green=[s for s,f in zip(pool,fl) if not f]; flw=[s for s,f in zip(pool,fl) if f]
    reg=inner&(zone==i)
    if green: scatter(reg,1/170,green)
    if flw: scatter(reg,1/(900 if z!='rumput_bunga' else 360),flw,cluster=fclust)
# helai pinggir tegak di sepanjang batas rumput (pangkal di batas)
bpts=np.argwhere(grass&(din<=1.0)); rng.shuffle(bpts)
for y,x in bpts[:len(bpts)//14]:
    b=BL[rng.integers(len(BL))]; b=b[-int(rng.integers(4,9)):]
    if rng.random()<0.5: b=b[:,::-1]
    stamp(b,x-b.shape[1]//2,y-b.shape[0]+int(rng.integers(1,4)))
# helai & gumpal liar di tanah dekat rumput (makin jauh makin jarang)
dsoil=distance_transform_edt(~grass)
tuft_pool=[s for s in ST['rumput_dasar']+ST['rumput_rimbun'] if not is_flower(s) and s.shape[0]<=6 and s.shape[1]<=7]
near=(~grass)&(dsoil>2)&(dsoil<16)
scatter(near,1/300,tuft_pool,cluster=np.clip(1-(dsoil-2)/14,0,1),tries_mult=4)
Image.fromarray(img).save(f'lanskap_{SEED}.png')
np.save(f'walk_{SEED}.npy',np.ones((H,W),bool))
print('selesai',img.shape)
