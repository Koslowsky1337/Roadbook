# Zeichnet media/logo.png (400×400, CurseForge-Logo): Buchseite mit Wegstrecke und Ziel-Nadel.
# Aufruf: python media/make_logo.py     (braucht Pillow)
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 4                      # Überabtastung
W = 400 * S
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
r = lambda *v: [x * S for x in v]

# Rahmen: dunkel, Gold, dunkel (wie das Pastime-Logo)
d.rounded_rectangle(r(4, 4, 396, 396), 48 * S, fill=(36, 23, 11))
for i in range(40):        # Goldverlauf
    t = i / 39
    c = tuple(int(a + (b - a) * t) for a, b in zip((246, 220, 140), (125, 90, 28)))
    d.rounded_rectangle(r(10 + i * 0.0, 10 + i * 9.5, 390, 390), 43 * S, fill=c) if i == 0 else \
        d.rectangle(r(10, 10 + i * 9.5, 390, 10 + (i + 1) * 9.5), fill=c)
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle(r(10, 10, 390, 390), 43 * S, fill=255)
gold = img.copy()
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle(r(4, 4, 396, 396), 48 * S, fill=(36, 23, 11))
img.paste(gold, (0, 0), mask)
d = ImageDraw.Draw(img)
d.rounded_rectangle(r(19, 19, 381, 381), 36 * S, fill=(43, 29, 14))

# Hintergrund: dunkles Grün-Blau (Karte bei Nacht)
bg = Image.new("RGBA", (W, W))
bd = ImageDraw.Draw(bg)
for y in range(W):
    t = y / W
    bd.line([(0, y), (W, y)], fill=(int(22 + 30 * t), int(52 + 38 * t), int(70 - 10 * t)))
m2 = Image.new("L", (W, W), 0)
ImageDraw.Draw(m2).rounded_rectangle(r(22, 22, 378, 378), 34 * S, fill=255)
img.paste(bg, (0, 0), m2)
d = ImageDraw.Draw(img)

# Buchseite (Pergament), leicht gedreht
page = Image.new("RGBA", (W, W), (0, 0, 0, 0))
pd = ImageDraw.Draw(page)
pd.rounded_rectangle(r(92, 70, 318, 336), 10 * S, fill=(60, 40, 20))
pd.rounded_rectangle(r(84, 62, 310, 328), 10 * S, fill=(236, 215, 170))
pd.rectangle(r(84, 62, 104, 328), fill=(150, 98, 52))               # Buchrücken
for y in (96, 170, 244, 300):                                        # Bindung
    pd.rectangle(r(84, y, 104, y + 6), fill=(110, 70, 36))
pd.polygon(r(270, 62, 294, 62, 294, 118, 282, 106, 270, 118), fill=(176, 44, 40))   # Lesezeichen
page = page.rotate(-6, resample=Image.BICUBIC, center=(200 * S, 200 * S))
shadow = page.split()[3].filter(ImageFilter.GaussianBlur(6 * S))
img.paste((0, 0, 0, 120), (3 * S, 5 * S), shadow)
img.alpha_composite(page)
d = ImageDraw.Draw(img)

# Wegstrecke: gestrichelte Kurve über die Seite mit drei Punkten
def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return tuple(u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * e for a, b, c, e in zip(p0, p1, p2, p3))
P = [(138, 292), (250, 280), (120, 190), (232, 150)]
pts = [bez(*P, i / 60) for i in range(61)]
for i in range(0, 60, 4):
    a, b = pts[i], pts[min(i + 2, 60)]
    d.line(r(a[0], a[1], b[0], b[1]), fill=(96, 62, 30), width=7 * S)
for (x, y), col in ((pts[0], (52, 110, 60)), (pts[30], (52, 110, 60))):
    d.ellipse(r(x - 13, y - 13, x + 13, y + 13), fill=(60, 40, 20))
    d.ellipse(r(x - 9, y - 9, x + 9, y + 9), fill=col)
    d.line(r(x - 5, y, x - 1, y + 4, x + 5, y - 4), fill=(236, 240, 220), width=3 * S, joint="curve")   # Häkchen

# Ziel-Nadel
x, y = pts[60]
d.polygon(r(x, y + 4, x - 24, y - 44, x + 24, y - 44), fill=(120, 26, 22))
d.ellipse(r(x - 30, y - 82, x + 30, y - 22), fill=(120, 26, 22))
d.polygon(r(x, y - 2, x - 19, y - 44, x + 19, y - 44), fill=(214, 60, 48))
d.ellipse(r(x - 25, y - 77, x + 25, y - 27), fill=(214, 60, 48))
d.ellipse(r(x - 10, y - 62, x + 10, y - 42), fill=(250, 236, 200))

out = img.resize((400, 400), Image.LANCZOS)
out.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "logo.png"))
print("logo.png geschrieben")
