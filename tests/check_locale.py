# Übersetzungen prüfen, ohne das Addon zu starten – Aufruf: python tests/check_locale.py <Addon-Ordner>
# 1. Jeder Text aus dem Code (L["..."]) hat eine deutsche Übersetzung – außer den bewusst gleichen.
# 2. deDE.lua enthält keine Einträge, die der Code nicht mehr benutzt.
# 3. Platzhalter (%s, %d …), Farbcodes und Zeilenumbrüche stimmen in beiden Sprachen überein.
import os, re, sys

ADDON = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIT = r'"((?:[^"\\\n]|\\.)*)"'
# Im Deutschen gleich
SAME_IN_GERMAN = {"Export: ", "Export", "%s · %s · %d/255", "Zeppelin %s – %s", "Tracker ", "Name:"}

toc = open(os.path.join(ADDON, "Roadbook.toc"), encoding="utf-8").read()
files = [l.strip().replace("\\", "/") for l in toc.splitlines() if l.strip() and not l.startswith("#")]
used = {}
for f in files:
    if f.endswith("deDE.lua"):
        continue
    for no, line in enumerate(open(os.path.join(ADDON, f), encoding="utf-8").read().splitlines(), 1):
        for m in re.finditer(r"\bL\[" + LIT + r"\]", line):
            used.setdefault(m.group(1), f"{f}:{no}")

de = {}
fails = passes = 0
def check(cond, msg):
    global fails, passes
    if cond:
        passes += 1
    else:
        fails += 1
        print("FEHLER: " + msg)

for no, line in enumerate(open(os.path.join(ADDON, "Locales", "deDE.lua"), encoding="utf-8").read().splitlines(), 1):
    m = re.match(r"^L\[" + LIT + r"\]\s*=\s*" + LIT + r"\s*$", line)
    if m:
        check(m.group(1) not in de, f"deDE.lua:{no} doppelter Eintrag {m.group(1)[:50]!r}")
        de[m.group(1)] = (m.group(2), no)
    else:
        check(not line.startswith("L["), f"deDE.lua:{no} Zeile nicht lesbar: {line[:60]}")

def marks(s):
    s = s.replace("%%", "")
    return re.findall(r"%[-+ #0]*\d*(?:\.\d+)?[sdifxXcq]", s), re.findall(r"\|c[0-9a-fA-F]{8}", s), s.count("|r"), s.count("\\n")

for key, where in sorted(used.items()):
    check(key in de or key in SAME_IN_GERMAN, f"{where}: keine deutsche Übersetzung für {key[:60]!r}")
for key, (value, no) in sorted(de.items(), key=lambda kv: kv[1][1]):
    check(key in used, f"deDE.lua:{no} wird im Code nicht mehr benutzt: {key[:60]!r}")
    check(marks(key) == marks(value), f"deDE.lua:{no} Platzhalter, Farbcodes oder Zeilenumbrüche weichen ab: {key[:50]!r}")
    check((key[:1] == " ") == (value[:1] == " ") and (key[-1:] == " ") == (value[-1:] == " "),
          f"deDE.lua:{no} Leerzeichen am Rand weichen ab: {key[:50]!r}")
for key in sorted(SAME_IN_GERMAN):
    check(key in used and key not in de, f"Ausnahmeliste SAME_IN_GERMAN ist veraltet: {key!r}")
print(f"Sprach-Tests: {passes} ok, {fails} Fehler")
