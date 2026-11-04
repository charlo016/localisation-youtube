# Génère les icônes et l'écran de démarrage (python3 make_images.py)
from PIL import Image, ImageDraw, ImageFont
BG, ACC, FG = (20, 20, 31), (255, 201, 77), (255, 255, 255)
def font(size, bold=True):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        try: return ImageFont.truetype(p, size)
        except OSError: pass
    return ImageFont.load_default()
def die(d, cx, cy, s):
    r = s // 2
    d.rounded_rectangle([cx - r, cy - r, cx + r, cy + r], radius=s // 6, fill=ACC)
    pr = max(2, s // 12)
    for dx, dy in [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)]:
        x, y = cx + dx * s // 4, cy + dy * s // 4
        d.ellipse([x - pr, y - pr, x + pr, y + pr], fill=BG)
def make(w, h, path, title_size, sub=None):
    im = Image.new("RGB", (w, h), BG); d = ImageDraw.Draw(im)
    s = int(h * 0.38); die(d, w // 2, int(h * 0.36), s)
    f = font(title_size); t = "What2Watch"
    tw = d.textlength(t, font=f); d.text(((w - tw) / 2, int(h * 0.62)), t, font=f, fill=FG)
    if sub:
        f2 = font(title_size // 2, False); sw = d.textlength(sub, font=f2)
        d.text(((w - sw) / 2, int(h * 0.62) + title_size * 1.4), sub, font=f2, fill=(154, 154, 176))
    im.save(path)
make(290, 218, "images/icon_hd.png", 30)
make(246, 140, "images/icon_sd.png", 22)
make(1920, 1080, "images/splash_fhd.png", 110, "Films  ·  Séries  ·  Animés")
make(1280, 720, "images/splash_hd.png", 74, "Films  ·  Séries  ·  Animés")
