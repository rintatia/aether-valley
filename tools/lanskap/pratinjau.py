import sys, json
from PIL import Image
MID=sys.argv[1]
info=json.load(open(f'../../assets/lanskap/{MID}/info.json'))
W,H=info['cols']*32,info['rows']*32; cs=info['chunk']
im=Image.new('RGB',(W,H))
for cy in range(info['ny']):
    for cx in range(info['nx']):
        im.paste(Image.open(f'../../assets/lanskap/{MID}/c_{cx}_{cy}.png'),(cx*cs,cy*cs))
im=im.convert('RGBA'); d=json.load(open(f'../../data/maps/{MID}_pohon.json')); at=Image.open('../../assets/'+d['atlas'])
for t in sorted(d['pohon']+d['tebang'],key=lambda t:t['y']):
    x0,y0,w,h=d['region'][t['obj']]; sw,sh=max(1,round(w*t['skala'])),max(1,round(h*t['skala']))
    s=at.crop((x0,y0,x0+w,y0+h)).resize((sw,sh),Image.LANCZOS)
    if t['cermin']: s=s.transpose(Image.FLIP_LEFT_RIGHT)
    im.alpha_composite(s,(t['x']-sw//2,t['y']-sh))
# overlay petak tertutup (merah tipis) untuk cek
rows=json.load(open(f'../../data/maps/{MID}.json'))['rows']
ov=Image.new('RGBA',(W,H),(0,0,0,0)); px=ov.load()
from PIL import ImageDraw
dr=ImageDraw.Draw(ov)
for y,r in enumerate(rows):
    for x,c in enumerate(r):
        if c=='#': dr.rectangle([x*32,y*32,x*32+31,y*32+31],fill=(255,0,0,60))
        if c in '<>': dr.rectangle([x*32,y*32,x*32+31,y*32+31],fill=(0,0,255,140))
im.resize((W//6,H//6),Image.BOX).save(f'/tmp/claude-0/work/flora/{MID}_full.png')
im2=im.copy(); im2.alpha_composite(ov); im2.resize((W//6,H//6),Image.BOX).save(f'/tmp/claude-0/work/flora/{MID}_mask.png')
im.crop((W//2-640,H//2-360,W//2+640,H//2+360)).save(f'/tmp/claude-0/work/flora/{MID}_tengah.png')
