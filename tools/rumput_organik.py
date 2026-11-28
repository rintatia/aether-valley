from PIL import Image
import numpy as np, json
from scipy.ndimage import gaussian_filter, distance_transform_edt, label, binary_dilation, zoom
rng=np.random.default_rng(5)
T=32
A=np.array(Image.open('assets/uji_spritecook/sc9_rumput.png').convert('RGBA'))
BASE=np.array([0x6F,0xA7,0x38])
# --- stempel helai tepi: piksel non-dasar di pita tepi frame 9 (atas terisi), y 6..22
f9=A[64:96,32:64]
isb=np.abs(f9[...,:3].astype(int)-BASE).sum(2)<=12
band=np.zeros_like(isb); band[6:22,:]=True
det=(f9[...,3]>0)&~isb&band
rgb=f9[...,:3].astype(int)
det&=~((rgb[...,0]>150))                      # buang bunga
blades=[]
x=0
while x<32:
    w=int(rng.integers(2,6)); sl=det[:,x:x+w]
    ys=np.where(sl.any(1))[0]
    if len(ys)>=3:
        y0,y1=ys.min(),ys.max()+1
        s=np.zeros((y1-y0,sl.shape[1],4),np.uint8); s[...,:3]=f9[y0:y1,x:x+w,:3]; s[...,3]=sl[y0:y1]*255
        blades.append(s)
    x+=w
print('helai tepi',len(blades),[b.shape[:2] for b in blades])
# warna garis bibir tepi (piksel non-dasar paling gelap di pita)
dk=f9[det][:,:3]; lip_dark=dk[np.argsort(dk.sum(1))[len(dk)//5]]; lip_mid=dk[np.argsort(dk.sum(1))[len(dk)//2]]
print('bibir', lip_dark, lip_mid)
st=np.array(Image.open('sc9_stempel.png').convert('RGBA')); sd=json.load(open('sc9_stempel.json'))
def stamp(img,s,x,y):
    h,w=s.shape[:2]
    if x<0 or y<0 or x+w>img.shape[1] or y+h>img.shape[0]: return
    m=s[...,3]>0; img[y:y+h,x:x+w][m]=s[m]
d0=json.load(open('data/uji_tileset.json'))
C,R=d0['cols'],d0['rows']; cells=np.array(d0['layers'][0]['cells']).reshape(R,C).astype(float)
W,H=C*T,R*T
# bentuk organik: nilai petak diperhalus + noise, ambang 0.5
up=zoom(cells,T,order=1)[:H,:W]
up=gaussian_filter(up,10)
def noise(s,seed):
    n=gaussian_filter(np.random.default_rng(seed).standard_normal((H,W)),s); return n/np.abs(n).max()
field=up+0.22*noise(14,1)+0.13*noise(4,2)+0.10*noise(1.3,3)
grass=field>0.5
img=np.zeros((H,W,4),np.uint8)
img[grass,:3]=BASE; img[grass,3]=255
din=distance_transform_edt(grass)
light=grass&(noise(18,7)+0.25*noise(3,8)>0.35)&(din>4)
img[light,:3]=np.clip(BASE+np.array([14,12,4]),0,255)
# bibir: 1 px gelap di batas, 1-2 px tengah
img[grass&(din<=1.0)&(noise(0.7,9)>0.0),:3]=lip_mid
img[grass&(din>1.0)&(din<=2.0)&(noise(0.8,4)>0.25),:3]=lip_mid
# helai tepi tegak berjajar acak di sepanjang batas (bagian bawah helai di batas)
bpts=np.argwhere(grass&(din<=1.0))
rng.shuffle(bpts)
for y,x in bpts[:len(bpts)//16]:
    b=blades[int(rng.integers(len(blades)))]
    b=b[-int(rng.integers(4,9)):]
    if rng.random()<0.5: b=b[:,::-1]
    h,w=b.shape[:2]
    stamp(img,b,int(x-w//2),int(y-h+int(rng.integers(1,4))))
# stempel isi acak di rumput dalam
inner=np.argwhere(din>6)
rects=sd['rects']; wts=np.array(sd['weights']); p=wts/wts.sum()
for y,x in inner[rng.choice(len(inner),size=int(len(inner)/150),replace=False)]:
    r=rects[rng.choice(len(rects),p=p)]; s=st[r[1]:r[1]+r[3],r[0]:r[0]+r[2]]
    if rng.random()<0.5: s=s[:,::-1]
    stamp(img,s,int(x),int(y))
# helai liar di tanah dekat rumput
dout=distance_transform_edt(~grass)
near=np.argwhere((dout>2)&(dout<14))
tuf=[r for r,w in zip(rects,sd['weights']) if w==1.0]
for y,x in near[rng.choice(len(near),size=len(near)//260,replace=False)]:
    r=tuf[int(rng.integers(len(tuf)))]; s=st[r[1]:r[1]+r[3],r[0]:r[0]+r[2]]
    stamp(img,s,int(x),int(y))
Image.fromarray(img).save('organic_rumput.png')
bg=Image.new('RGBA',(W,H),(0xC8,0x7D,0x38,255)); bg.alpha_composite(Image.fromarray(img))
bg=bg.crop((0,0,1280,720)); bg.save('org_z1.png'); bg.crop((480,240,800,420)).resize((1280,720),Image.NEAREST).save('org_z4.png')
