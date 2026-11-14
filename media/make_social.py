# Zeichnet media/social-preview.png (1280×640, GitHub „Social preview“) aus logo.png.
# Aufruf: python media/make_social.py     (braucht Pillow und die Windows-Schriften Georgia/Segoe UI)
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1280, 640
img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img)
for y in range(H):                       # derselbe Nachtkarten-Verlauf wie im Logo
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(18 + 26 * t), int(44 + 36 * t), int(62 - 8 * t)))

# gestrichelte Wegstrecke quer über das Bild
for i, x in enumerate(range(520, 1240, 26)):
    y = 520 + int(34 * ((i % 8) - 4) ** 2 / 16) - 30
    d.ellipse([x, y, x + 12, y + 12], fill=(86, 122, 110))

logo = Image.open(os.path.join(HERE, "logo.png")).convert("RGBA").resize((420, 420), Image.LANCZOS)
img.paste(logo, (80, 110), logo)

def font(name, size):
    return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", name), size)

d.text((560, 150), "Roadbook", font=font("georgiab.ttf", 120), fill=(246, 220, 140))
d.text((564, 300), "Turn-in routes by travel time", font=font("segoeuib.ttf", 46), fill=(240, 236, 220))
d.text((564, 366), "TomTom waypoints · flight paths", font=font("segoeui.ttf", 38), fill=(196, 206, 196))
d.text((564, 418), "notebook · macro library", font=font("segoeui.ttf", 38), fill=(196, 206, 196))
d.text((564, 560), "World of Warcraft addon · WoW Forever", font=font("segoeui.ttf", 28), fill=(150, 170, 160))
img.save(os.path.join(HERE, "social-preview.png"))
print("social-preview.png geschrieben")
