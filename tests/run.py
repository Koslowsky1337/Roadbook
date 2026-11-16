# Aufruf: python tests/run.py <Addon-Ordner> tests/<suite>.lua   (Sprache: LOCALE=enUS, Standard deDE)
import sys, os, locale
from lupa.lua51 import LuaRuntime

locale.setlocale(locale.LC_ALL, "C")   # wie WoW: sonst verbiegt string.lower() UTF-8 unter Windows
ADDON_DIR, SCENARIO = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
read = lambda p: open(p, encoding="utf-8").read()

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(read(os.path.join(HERE, "mockwow.lua")))
lua.execute(read(os.path.join(HERE, "layoutsim.lua")))
lua.execute('GetLocale = function() return "%s" end' % os.environ.get("LOCALE", "deDE"))
if os.environ.get("FACTION") == "Alliance":
    lua.execute('UnitFactionGroup = function() return "Alliance", "Alliance" end')
lua.execute("RB_NS = {}")
lua.execute(read(os.path.join(HERE, "strict.lua")))
toc = read(os.path.join(ADDON_DIR, "Roadbook.toc"))
files = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
loader = lua.eval("function(src, name) local fn, err = loadstring(src, name); if not fn then error(err) end; return fn end")
for f in files:
    loader(read(os.path.join(ADDON_DIR, *f.split("\\"))), "@" + f)("Roadbook", lua.globals().RB_NS)
lua.execute(read(os.path.join(HERE, "post_fixture.lua")))   # feste Test-Post (wie das Zusatz-Addon Roadbook_Post)
lua.execute(read(os.path.join(HERE, "links_fixture.lua")))   # Linien und Flugnetz der Testwelt
lua.execute(read(SCENARIO))
print("Unbekannte Globals:", sorted(k for k in lua.globals().UNKNOWN.keys()))
