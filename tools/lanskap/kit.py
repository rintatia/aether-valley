"""Ekstraksi bahan dari 8 tileset + pemetaan ke palet 47."""
from PIL import Image
import numpy as np, json
from scipy.ndimage import label, binary_dilation, distance_transform_edt
T=32
PAL_HEX=[l.strip() for l in open('../../assets/palet/palet_47.txt') if l.strip()]
PAL=np.array([[int(h[i:i+2],16) for i in (1,3,5)] for h in PAL_HEX],float)
def to_lab(rgb):
    c=rgb/255.0; c=np.where(c>0.04045,((c+0.055)/1.055)**2.4,c/12.92)
    M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz=c@M.T/np.array([0.9505,1.0,1.089])
    f=np.where(xyz>0.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],-1)
PAL_LAB=to_lab(PAL)
def palmap(rgb):
    sh=rgb.shape; lab=to_lab(rgb.reshape(-1,3).astype(float))
    d=((lab[:,None,:]-PAL_LAB[None])**2).sum(2)
    return PAL[d.argmin(1)].reshape(sh).astype(np.uint8)
def nearest_hex(rgb):
    return PAL_HEX[int(((to_lab(np.array([rgb],float))[:,None,:]-PAL_LAB[None])**2).sum(2).argmin())]
ROLE={1:'tanah',2:'tanah_batu',3:'rumput_bunga',4:'rumput_kalem',5:'rumput_rimbun',6:'rumput_kering',7:'rumput_dasar',8:'pasir'}
def load(i): return np.array(Image.open(f'sumber/t{i}.png').convert('RGBA'))
def base_color(a):
    f=a[32:64,64:96,:3].reshape(-1,3); c,n=np.unique(f,axis=0,return_counts=True); return c[n.argmax()].astype(int)
def stamps(a,base,keep=7,tol=14,maxsz=12):
    out=[]; seen=set()
    for fr in range(16):
        r,c=fr//4,fr%4; f=a[r*T:(r+1)*T,c*T:(c+1)*T]; op=f[...,3]>0
        if not op.any(): continue
        dist=distance_transform_edt(np.pad(op,1,constant_values=True))[1:-1,1:-1]
        isb=np.abs(f[...,:3].astype(int)-base).sum(2)<=tol
        det=op&(dist>=keep)&~isb
        lab,k=label(binary_dilation(det,iterations=1),structure=np.ones((3,3)))
        for j in range(1,k+1):
            ys,xs=np.where((lab==j)&det)
            if len(ys)<2 or np.ptp(ys)>=maxsz or np.ptp(xs)>=maxsz: continue
            y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
            s=np.zeros((y1-y0,x1-x0,4),np.uint8); m=det[y0:y1,x0:x1]
            s[...,:3]=f[y0:y1,x0:x1,:3]; s[...,3]=m*255
            key=s.tobytes()
            if key in seen: continue
            seen.add(key); out.append(s)
    return out
def blades(a,base,tol=14):
    """helai pinggir dari bingkai 'atas terisi' (frame 9), pita y 4..22, dipotong tipis"""
    f=a[64:96,32:64]; op=f[...,3]>0
    isb=np.abs(f[...,:3].astype(int)-base).sum(2)<=tol
    rgb=f[...,:3].astype(int)
    green=(rgb[...,1]>=rgb[...,0])&(rgb[...,1]>=rgb[...,2])
    det=op&~isb&green; det[:4]=False; det[23:]=False
    out=[]; x=0; rng=np.random.default_rng(1)
    while x<32:
        w=int(rng.integers(2,5)); sl=det[:,x:x+w]; ys=np.where(sl.any(1))[0]
        if len(ys)>=3:
            y0,y1=ys.min(),ys.max()+1
            s=np.zeros((y1-y0,sl.shape[1],4),np.uint8); s[...,:3]=f[y0:y1,x:x+w,:3]; s[...,3]=sl[y0:y1]*255; out.append(s)
        x+=w
    return out
def pm_stamp(s):
    s=s.copy(); m=s[...,3]>0; s[m,:3]=palmap(s[m,:3]); return s
if __name__=='__main__':
    kit={}
    for i in range(1,9):
        a=load(i); b=base_color(a)
        st=[pm_stamp(s) for s in stamps(a,b)]
        bl=[pm_stamp(s) for s in blades(a,b)] if 3<=i<=7 else []
        kit[ROLE[i]]={'base':b.tolist(),'base_pal':nearest_hex(b),'n_stamps':len(st),'n_blades':len(bl)}
        np.save(f'kit_{ROLE[i]}_stamps.npy',np.array(st,dtype=object),allow_pickle=True)
        np.save(f'kit_{ROLE[i]}_blades.npy',np.array(bl,dtype=object),allow_pickle=True)
    for k,v in kit.items(): print(k,v)
    json.dump(kit,open('kit.json','w'))
