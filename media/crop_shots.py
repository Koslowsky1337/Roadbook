# Schneidet die Bilder von „/rb shots“ auf das jeweilige Fenster zu (für die CurseForge-Gallery).
#
# Aufruf: python media/crop_shots.py <Screenshots-Ordner> <SavedVariables/Roadbook.lua> <Zielordner>
#
# Vorher im Spiel: /rb shots, danach /reload (erst dann stehen die Zuschnitt-Daten in der Datei).
# Genommen werden die neuesten Screenshots, so viele wie RoadbookDB.shots Einträge hat.
# Braucht Pillow und lupa.
import os, sys
from PIL import Image
from lupa.lua51 import LuaRuntime

shots_dir, saved, out_dir = sys.argv[1:4]
MARGIN = 12   # Pixel Rand um das Fenster

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(saved, encoding="utf-8").read())
shots = lua.globals().RoadbookDB.shots
if not shots or not shots.list:
    sys.exit("Keine Zuschnitt-Daten: im Spiel /rb shots und danach /reload ausführen.")
rects = [shots.list[i] for i in range(1, len(shots.list) + 1)]

files = [os.path.join(shots_dir, f) for f in os.listdir(shots_dir)
         if f.lower().startswith("wowscrnshot") and f.lower().endswith((".jpg", ".jpeg", ".png", ".tga"))]
files.sort(key=os.path.getmtime)
files = files[-len(rects):]
if len(files) < len(rects):
    sys.exit(f"Nur {len(files)} Screenshots gefunden, erwartet {len(rects)}.")
# Die Bilder müssen nach der Tour entstanden sein (kleine Toleranz für Uhrabweichungen)
if os.path.getmtime(files[0]) < shots.at - 120:
    sys.exit("Die neuesten Screenshots sind älter als die Zuschnitt-Daten – bitte /rb shots noch einmal laufen lassen.")

os.makedirs(out_dir, exist_ok=True)
for n, (path, r) in enumerate(zip(files, rects), 1):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    box = (max(0, int(r.l * w) - MARGIN), max(0, int(r.t * h) - MARGIN),
           min(w, int(r.r * w) + MARGIN), min(h, int(r.b * h) + MARGIN))
    out = os.path.join(out_dir, f"{n:02d}-{r.name}.png")
    img.crop(box).save(out)
    print(f"{os.path.basename(path)} -> {os.path.basename(out)}  {box[2] - box[0]}x{box[3] - box[1]}")
