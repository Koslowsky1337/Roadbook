local ns = RB_NS
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
local function fire(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function turnIn(q) QS.onQuest[q] = nil; QS.complete[q] = nil; QS.flagged[q] = true; fire("QUEST_TURNED_IN", q, 0, 0); RunTimers() end
local function joined(t) return table.concat(t, " ; ") end

-- Makros wie im Spiel
local snapMacros = {
  { "Angriff", 132369, "#showtooltip Automatischer Schuss\n/petattack [harm,nodead]\n/castsequence [harm,nodead] reset=target Mal des Jägers, null\n/cast [harm,nodead] !Automatischer Schuss\n" },
  { "Angriff NK", 132223, "#showtooltip [mod:ctrl] Zurechtstutzen; Raptorstoß\n/startattack\n/cast [mod:ctrl] Zurechtstutzen\n/cast [nomod] Mungobiss\n/cast [nomod] Raptorstoß\n" },
  { "Arkaner Schuss", 132218, "#showtooltip Arkaner Schuss\n/petattack [harm,nodead]\n/cast [harm,nodead] !Automatischer Schuss\n/cast [harm,nodead] Arkaner Schuss\n" },
  { "Aspekt", 132159, "#showtooltip\n/cast [mod:shift] !Aspekt des Geparden; [mod:ctrl] !Aspekt des Affen; !Aspekt des Falken\n" },
  { "Falle", 135813, "#showtooltip Feuerbrandfalle\n/cast Feuerbrandfalle\n" },
  { "HF", 132165, "#showtooltip\n/cast [@pet,dead] Tier wiederbeleben; [nopet] Tier rufen; [combat][mod:shift] Tier heilen; Tier füttern\n/use [pet,nocombat,nomod] Zähes Stockfleisch\n" },
  { "Multi", 132330, "#showtooltip Mehrfachschuss\n/petattack [harm,nodead]\n/cast [harm,nodead] !Automatischer Schuss\n/cast [harm,nodead] Mehrfachschuss\n" },
  { "Ängstigen", 132118, "#showtooltip Wildtier ängstigen\n/cast [@mouseover,harm,nodead][] Wildtier ängstigen\n" },
}
for i, m in ipairs(snapMacros) do MACROS[120 + i] = { name = m[1], icon = m[2], body = m[3] } end
MACROS[1] = { name = "ForeverXPBarData", icon = 134400, body = "#fxpb x" }

-- Quests: alle abgabebereit im Log
for _, q in ipairs({ 894, 6541, 97003, 872, 6401, 6421, 1095, 1064, 6562, 264, 5722 }) do
    QS.onQuest[q] = true; QS.complete[q] = true
end

-- Start
OLDPOST = RoadbookPost
fire("ADDON_LOADED", "Roadbook")
fire("PLAYER_LOGIN")
RunTimers()
check(ns.postError == nil, "Post ohne Fehler: " .. tostring(ns.postError))
check(#ns.post.plans == 3, "3 Pläne, sind " .. #ns.post.plans)
check(#ns.post.macros == 9, "9 Makros, sind " .. #ns.post.macros)
check(#ns.post.notes == 3, "3 Post-Notizen (Post, Fluffy, Anleitung), sind " .. #ns.post.notes)
check(ns.CountPendingMacros() == 1, "1 Makro ausstehend (Roadbook), sind " .. ns.CountPendingMacros())
local chat = joined(LOG)
check(chat:find("Neue Post", 1, true), "Login-Meldung neue Post")
check(ns.HasNewPost(), "Post gilt als neu")

-- Plan laden: Route
ns.ActivatePlan("brachland-abgabe")
RunTimers()
check(joined(TT_List()) == "Steuerkonsole – Samophlang|Roadbook", "Route: nur Konsole gesetzt: " .. joined(TT_List()))
check(TomTom.arrow and TomTom.arrow.title == "Steuerkonsole – Samophlang", "Pfeil auf Konsole")

-- Abgabe -> nächster Schritt
LOG = {}
turnIn(894)
check(joined(TT_List()) == "Kadrak – Meldung bei Kadrak|Roadbook", "Nach Abgabe: Kadrak: " .. joined(TT_List()))
check(joined(LOG):find("Nächster Schritt", 1, true), "Meldung nächster Schritt")

-- Planwechsel auf 'Alle Punkte'
ns.ActivatePlan("unterwegs")
RunTimers()
local l = TT_List()
check(#l == 3, "Unterwegs: 3 Punkte (Instanz ohne Punkt), sind " .. #l .. ": " .. joined(l))
check(not joined(l):find("Kadrak", 1, true), "Brachland-Punkte entfernt")

-- Abgabe eines Brachland-Schritts während anderer Plan aktiv
turnIn(6541)
ns.ActivatePlan("brachland-abgabe")
RunTimers()
check(joined(TT_List()) == "Gur'ak – Chol'aruk der Verschlinger|Roadbook", "Planübergreifend: Kadrak schon erledigt -> Gur'ak: " .. joined(TT_List()))
local brach = ns.GetPlan("brachland-abgabe")
local d, t = ns.PlanProgress(brach)
check(d == 2 and t == 4, ("Fortschritt 2/4, ist %d/%d"):format(d, t))

-- Überspringen (nur in diesem Plan)
local gurak = brach.steps[3]
ns.ToggleSkip(brach, gurak); RunTimers()
check(joined(TT_List()) == "Thork – Das Ende der Unterbrechungen|Roadbook", "Übersprungen -> Thork")
ns.ToggleSkip(brach, gurak); RunTimers()
check(joined(TT_List()) == "Gur'ak – Chol'aruk der Verschlinger|Roadbook", "Wieder aufgenommen -> Gur'ak")

-- Fokus per Klick
ns.FocusStep(brach, brach.steps[4]); RunTimers()
check(joined(TT_List()) == "Thork – Das Ende der Unterbrechungen|Roadbook", "Fokus auf Thork")
ns.C.focus[brach.id] = nil; ns.Refresh()

-- Eigener TomTom-Punkt bleibt beim Entladen
TomTom:AddWaypoint(1413, 0.5, 0.5, { title = "Mein Punkt", from = "TomTom/way" })
ns.DeactivatePlan(); RunTimers()
check(joined(TT_List()) == "Mein Punkt|TomTom/way", "Nur eigener Punkt bleibt: " .. joined(TT_List()))

-- Von Hand entfernt -> nicht sofort neu setzen
ns.ActivatePlan("brachland-abgabe"); RunTimers()
local uid
for u in pairs(ns.wp.uids) do uid = u end
TomTom:RemoveWaypoint(uid)
fire("QUEST_LOG_UPDATE"); RunTimers()
check(not joined(TT_List()):find("Gur'ak", 1, true), "Von Hand entfernter Punkt bleibt weg")

-- Plan abschließen
turnIn(97003); turnIn(872)
check(joined(LOG):find("abgeschlossen", 1, true), "Meldung Plan abgeschlossen")

-- Eigener Plan aus TomTom
ns.CreatePlanFromTomTom("Test")
local own
for _, p in ipairs(ns.GetPlans()) do if p.source == "eigen" then own = p end end
check(own and #own.steps == 1 and own.steps[1].title == "Mein Punkt", "Eigener Plan aus TomTom")
check(own and own.steps[1].x == 50 and own.steps[1].y == 50, "Koordinaten 50/50")
ns.ActivatePlan(own.id); RunTimers()
check(ns.wp.byKey[own.steps[1].key] == nil, "Vorhandener Nutzerpunkt wird nicht doppelt gesetzt")
ns.DeleteOwnPlan(own)
check(ns.GetPlan(own.id) == nil, "Eigener Plan gelöscht")

-- Ankunft bei Hingehen-Schritt
ns.C.plans["p99"] = { id = "p99", title = "Gehen", mode = "route", created = 1,
    steps = { { type = "goto", map = 1413, x = 10, y = 10, title = "A" }, { type = "goto", map = 1413, x = 20, y = 20, title = "B" } } }
ns.ActivatePlan("e:p99"); RunTimers()
local a
for u, k in pairs(ns.wp.uids) do a = u end
check(a and a.title == "A", "Hingehen: A gesetzt")
a.callbacks.distance[15]("distance", a, 15, 10, 30)
RunTimers()
check(joined(TT_List()):find("B|Roadbook", 1, true), "Nach Ankunft: B: " .. joined(TT_List()))

-- Notizen
local n = ns.CreateNote("Testnotiz")
check(ns.C.notes[n.id] ~= nil, "Notiz beim Charakter")
ns.SetNoteAccount(n, true)
check(ns.DB.notes[n.id] ~= nil and ns.C.notes[n.id] == nil, "Notiz für alle Charaktere verschoben")
ns.SetNoteAccount(n, false)
check(ns.C.notes[n.id] ~= nil, "Zurück zum Charakter")
local pn = ns.GetPlanNote(brach, true)
check(pn.plan == brach.id and ns.GetPlanNote(brach, false) == pn, "Plan-Notiz")
ns.DeleteNote(n.id)
check(ns.FindNote(n.id) == nil, "Notiz gelöscht")
local copy = ns.CopyPostNote("c:fluffy")
check(copy and copy.body:find("Beißen", 1, true), "Post-Notiz kopiert")

-- Makros
local wb
for _, m in ipairs(ns.post.macros) do if m.name == "Roadbook" then wb = m end end
check(ns.MacroStatus(wb) == "new", "Roadbook neu")
ns.ApplyMacro(wb)
check(ns.MacroStatus(wb) == "same", "Roadbook created")
local hf
for _, m in ipairs(ns.post.macros) do if m.name == "HF" then hf = m end end
check(ns.MacroStatus(hf) == "same", "HF aktuell (Zeilenende egal)")
MACROS[126].body = "#showtooltip\n/cast Tier füttern"
check(ns.MacroStatus(hf) == "changed", "HF geändert erkannt")
COMBAT = true; ns.ApplyMacro(hf); COMBAT = false
check(ns.MacroStatus(hf) == "changed", "Im Kampf nichts geändert")
ns.ApplyMacro(hf)
check(ns.MacroStatus(hf) == "same", "HF übernommen")
ns.UndoMacro(hf)
check(MACROS[126].body == "#showtooltip\n/cast Tier füttern", "HF zurückgesetzt")

-- Oberfläche durchspielen
ns.ShowFrame("plans")
check(not ns.HasNewPost(), "Post nach Öffnen gelesen")
ns.C.selectedPlan = "brachland-abgabe"; ns.UpdateUI()
ns.ShowTab("notes"); ns.SelectNote("c:anleitung"); ns.UpdateUI()
ns.SelectNote(pn.id); ns.UpdateUI()
ns.ShowTab("macros"); ns.UpdateUI()
ns.ShowTab("plans"); ns.UpdateUI()
ns.ShowCopy("x", "y")
ns.HandleSlash("hilfe"); ns.HandleSlash("plan steinkrallen"); RunTimers()
check(ns.C.activePlan == "steinkrallen-abgabe", "/rb plan steinkrallen")
ns.HandleSlash("weiter"); ns.HandleSlash("aus"); ns.HandleSlash("notiz Einkauf"); ns.HandleSlash("minimap")
-- Buttons im UI anklicken (Grundprüfung, dass Skripte laufen)
local clicked = 0
for _, f in ipairs(ALLFRAMES) do
    if f.__kind == "Button" and f.scripts.OnClick and f.shown and f.enabled and f.template == "UIPanelButtonTemplate" then
        local ok, err = pcall(f.scripts.OnClick, f, "LeftButton")
        if not ok then check(false, "Klick-Fehler: " .. tostring(err)) else clicked = clicked + 1 end
    end
end
for _, f in ipairs(ALLFRAMES) do
    if f.scripts.OnEnter and f.shown then
        local ok, err = pcall(f.scripts.OnEnter, f)
        if not ok then check(false, "Tooltip-Fehler: " .. tostring(err)) end
    end
end
ns.UpdateUI()

-- Fehlerhafte Post
RoadbookPost = "return {"
ns.LoadPost()
check(ns.postError ~= nil and #ns.GetPlans() >= 0, "Kaputte Post -> Fehlermeldung statt Absturz")
ns.ShowFrame("plans"); ns.UpdateUI()


-- Protokoll ------------------------------------------------------------------
local function logHas(level, pat)
    for _, e in ipairs(RoadbookDB.log) do
        if (not level or e.l == level) and e.m:find(pat, 1, true) then return e end
    end
end
check(logHas("I", "Roadbook v4.4.1"), "Startzeile im Protokoll")
check(logHas("I", "loaded: 3 plans"), "Post-Zusammenfassung im Protokoll")
check(logHas("I", "Quest 894 turned in"), "Questabgabe protokolliert")
check(logHas("I", "Plan loaded: brachland-abgabe"), "Plan laden protokolliert")
check(logHas("I", "Waypoint removed by hand"), "Von Hand entfernt protokolliert")
check(logHas("I", "Roadbook created"), "Makro angelegt protokolliert")
check(logHas("W", "refused in combat"), "Kampfsperre protokolliert")
check(logHas("E", "Post is broken"), "Kaputte Post als Fehler protokolliert")
check(logHas("I", "→ done"), "Schrittwechsel auf erledigt protokolliert")
check(not logHas("D", ""), "Ohne Debug keine Debug-Einträge")

-- Debug an
ns.HandleSlash("debug")
check(RoadbookDB.debug == true, "Debug an")
RoadbookPost = OLDPOST; ns.LoadPost()
ns.ActivatePlan("unterwegs"); RunTimers()
check(logHas("D", "Waypoint set"), "Debug: Wegpunkt gesetzt")
check(logHas("D", "Sync unterwegs"), "Debug: Abgleich")

-- TomTom wirft Fehler
local orig = TomTom.AddWaypoint
TomTom.AddWaypoint = function() error("TomTom kaputt") end
ns.DeactivatePlan(); ns.ActivatePlan("steinkrallen-abgabe"); RunTimers()
TomTom.AddWaypoint = orig
check(logHas("E", "AddWaypoint failed"), "TomTom-Fehler protokolliert")

-- Lua-Fehler in einem Klick
local before = #ERRORS_FORWARDED
local b = ns.CreateButton(UIParent, "Test", 50, function() error("Absichtlicher Fehler") end)
b.scripts.OnClick(b, "LeftButton")
local e = logHas("E", "Absichtlicher Fehler")
check(e and e.st == "[mock stack]", "Klickfehler mit Stack protokolliert")
check(#ERRORS_FORWARDED == before + 1, "Fehler an BugSack weitergereicht")
check(ns.SessionErrors() >= 3, "Fehlerzähler der Sitzung")

-- Fehlerhafte Schritte -> Warnungen
RoadbookPost = [==[ return { version = "t", chars = { Tester = { plans = {
  { id = "kaputt", title = "Kaputt", steps = {
     { type = "turnin", title = "Ohne Quest" },
     { type = "goto", map = 1413, x = 150, y = 20, title = "Zu weit" },
     { type = "fliegen", title = "Unbekannt" },
  } } } } } } ]==]
ns.LoadPost()
check(logHas("W", "quest ID missing"), "Warnung Quest-ID fehlt")
check(logHas("W", "outside 0–100"), "Warnung Koordinaten")
check(logHas("W", "unknown type fliegen"), "Warnung Typ")

local txt = ns.FormatLog(50)
check(txt:find("Sitzung", 1, true) and txt:find("ERROR", 1, true), "Protokoll-Text formatiert")
ns.HandleSlash("log")
ns.HandleSlash("debug")
check(RoadbookDB.debug == false, "Debug aus")

-- Automatische Abgaberunde ----------------------------------------------------
RoadbookPost = OLDPOST; ns.LoadPost()
QS.log = {}
for _, q in ipairs({ { 894, "Samophlang" }, { 6541, "Meldung bei Kadrak" }, { 97003, "Chol'aruk" }, { 872, "Das Ende" },
                     { 6401, "Kaya lebt" }, { 5722, "Ranzen" }, { 999, "Fraktionstest" }, { 998, "Ohne Abgabe" }, { 777, "Noch offen" } }) do
    table.insert(QS.log, { id = q[1], title = q[2] })
    QS.flagged[q[1]] = nil; QS.onQuest[q[1]] = true; QS.complete[q[1]] = (q[1] ~= 777)
    ns.C.turnedIn[q[1]] = nil
end
table.insert(QS.log, 1, { header = true, title = "Brachland" })
ns.CreateTurnInPlan(); RunTimers()
local auto = ns.GetPlan("e:auto-abgabe")
check(auto ~= nil, "Abgaberunde angelegt")
local order = {}
for _, st in ipairs(auto and auto.steps or {}) do table.insert(order, st.title) end
-- Reisezeit statt gieriger Luftlinie: die Gesamtstrecke ist kürzer als „immer zum Nächsten“
check(joined(order) == "Kadrak ; Steuerkonsole ; Gur'ak ; Thork ; Hordler ; Tammra Windfield ; Maur Grimmtotem ; Abgabe",
      "Reihenfolge nach Reisezeit: " .. joined(order))
do
    local start = ns.PlayerPos()
    local function costOf(titles)
        local pts = {}
        for _, t in ipairs(titles) do for _, st in ipairs(auto.steps) do if st.title == t then pts[#pts + 1] = ns.StepPos(st) end end end
        return ns.PathCost(start, pts)
    end
    local new = costOf({ "Kadrak", "Steuerkonsole", "Gur'ak", "Thork", "Hordler", "Tammra Windfield" })
    local greedy = costOf({ "Gur'ak", "Thork", "Steuerkonsole", "Kadrak", "Hordler", "Tammra Windfield" })
    check(new < greedy, ("Neue Reihenfolge kürzer als die gierige (%.1f < %.1f)"):format(new, greedy))
end
check(auto.steps[1].zone == "Karte1413" and auto.steps[1].quest == 6541, "Zone/Quest am Schritt")
check(ns.C.activePlan == "e:auto-abgabe", "Abgaberunde ist geladen")
check(joined(TT_List()):find("Kadrak – Meldung bei Kadrak|Roadbook", 1, true), "Pfeil/Punkt auf erstem Schritt: " .. joined(TT_List()))
local ae = logHas("I", "Turn-in round created")
check(ae and ae.m:find("8 quests, 6 with waypoint, 2 without", 1, true), "Abgaberunde protokolliert: " .. tostring(ae and ae.m))
check(logHas("W", "Quest 998"), "Quest ohne Abgabe-NPC gewarnt")
check(auto.auto == true, "als automatisch markiert")
turnIn(6541)
check(joined(TT_List()):find("Steuerkonsole", 1, true), "Nach Abgabe weiter zur Steuerkonsole")
ns.HandleSlash("abgabe"); RunTimers()
local auto2 = ns.GetPlan("e:auto-abgabe")
check(#auto2.steps == 7, "Neu erstellt ohne abgegebene Quest, sind " .. #auto2.steps)
OLDQDB = QuestDB
QuestDB = nil
ns.CreateTurnInPlan()
check(logHas("W", "QuestieDB (QuestDB/NpcDB) is missing"), "Ohne QuestieDB sauber abgebrochen")

-- Löschen, Ausblenden, Papierkorb --------------------------------------------
QuestDB = OLDQDB
local function noteVisible(id)
    for _, sec in ipairs(ns.GetNoteSections()) do for _, n in ipairs(sec.items) do if n.id == id then return true end end end
    return false
end
check(noteVisible("c:fluffy"), "Post-Notiz sichtbar")
ns.DeleteNote("c:fluffy")
check(not noteVisible("c:fluffy"), "Post-Notiz ausgeblendet")
check(#ns.TrashList() >= 1, "Im Papierkorb")
ns.DeleteNote("c:anleitung")
check(RoadbookDB.hidden["c:anleitung"] ~= nil, "Globale Post-Notiz account-weit ausgeblendet")
local own = ns.CreateNote("Weg damit"); own.body = "Text"
ns.DeleteNote(own.id)
check(ns.FindNote(own.id) == nil, "Eigene Notiz gelöscht")
local items = ns.TrashList()
check(items[1].entry.title == "Weg damit", "Neuester Eintrag oben")
ns.RestoreTrash(items[1].index)
check(ns.FindNote(own.id) and ns.FindNote(own.id).body == "Text", "Eigene Notiz wiederhergestellt")
for _, it in ipairs(ns.TrashList()) do if it.entry.id == "c:fluffy" then ns.RestoreTrash(it.index) end end
check(noteVisible("c:fluffy"), "Post-Notiz wiederhergestellt")
-- Post-Plan ausblenden, geänderte Fassung taucht wieder auf
local sk = ns.GetPlan("steinkrallen-abgabe")
ns.DeletePlan(sk)
check(ns.GetPlan("steinkrallen-abgabe") == nil, "Post-Plan ausgeblendet")
ns.C.hidden["steinkrallen-abgabe"] = 12345
check(ns.GetPlan("steinkrallen-abgabe") ~= nil, "Geänderte Fassung wieder sichtbar")
-- Frist abgelaufen
local realTime = time
ns.DeleteNote(own.id)
time = function() return realTime() + 11 * 60 end
check(#ns.TrashList() == 0, "Nach 10 Minuten endgültig weg")
time = realTime
check(ns.FindNote(own.id) == nil, "Abgelaufene Notiz bleibt gelöscht")
-- UI mit Papierkorb
ns.ShowTrash(); ns.ShowFrame("notes"); ns.UpdateUI(); ns.ShowTab("plans"); ns.UpdateUI()
ns.HandleSlash("trash")
check(logHas("I", "Restored"), "Wiederherstellen protokolliert")

-- Paket 1: Bearbeiten, Hier merken, Tracker, Aufnehmen, Anleitung ---------------
RoadbookPost = OLDPOST; ns.LoadPost()
QuestDB = OLDQDB
-- eingebaute Anleitung
check(noteVisible("w:anleitung"), "Eingebaute Kurzanleitung sichtbar")
ns.DeleteNote("w:anleitung")
check(not noteVisible("w:anleitung") and RoadbookDB.hidden["w:anleitung"], "Anleitung ausblendbar (account-weit)")
for _, it in ipairs(ns.TrashList()) do if it.entry.id == "w:anleitung" then ns.RestoreTrash(it.index) end end
check(noteVisible("w:anleitung"), "Anleitung wiederhergestellt")

-- Post-Plan bearbeiten -> eigene Kopie
ns.C.hidden["unterwegs"] = nil
local uw = ns.GetPlan("unterwegs")
ns.ActivatePlan("unterwegs"); RunTimers()
ns.planEditId = "unterwegs"
ns.MoveStep(uw, uw.steps[2], -1); RunTimers()
check(ns.GetPlan("unterwegs") == nil, "Original von Post ausgeblendet")
local copy = ns.ActivePlan()
check(copy and copy.source == "eigen" and copy.title == "Unterwegs mitnehmen", "Aktiver Plan ist jetzt die Kopie")
check(copy.steps[1].title == "Je'neu Sancrea", "Reihenfolge getauscht: " .. tostring(copy.steps[1].title))
check(ns.planEditId == copy.id, "Bearbeiten-Modus folgt der Kopie")
ns.RenamePlan(copy, "Meine Runde")
check(ns.ActivePlan().title == "Meine Runde", "Umbenannt")
local before = #ns.ActivePlan().steps
ns.RemoveStep(ns.ActivePlan(), ns.ActivePlan().steps[1])
check(#ns.ActivePlan().steps == before - 1, "Schritt entfernt")
local tl = ns.TrashList()
check(tl[1].entry.kind == "step", "Schritt im Papierkorb")
ns.RestoreTrash(tl[1].index)
check(#ns.ActivePlan().steps == before and ns.ActivePlan().steps[1].title == "Je'neu Sancrea", "Schritt an alter Stelle zurück")

-- Hier merken
ns.AddHereStep(nil, "Lagerfeuer")
local last = ns.ActivePlan().steps[#ns.ActivePlan().steps]
check(last.type == "goto" and last.title == "Lagerfeuer" and last.x == 57.6 and last.y == 21.3, "Hier gemerkt im aktiven Plan")
ns.DeactivatePlan()
ns.HandleSlash("hier")
local mine
for _, p in ipairs(ns.GetPlans()) do if p.title == "Meine Punkte" then mine = p end end
check(mine == nil, "Ohne geladenen Plan: kein neuer Plan, solange ein eigener gewählt ist")
local selSteps = ns.GetPlan(ns.C.selectedPlan).steps
check(selSteps[#selSteps].title == "Wegekreuz", "Ohne geladenen Plan: Schritt mit Unterzone im gewählten eigenen Plan")
ns.C.selectedPlan = false
ns.HandleSlash("here")
for _, p in ipairs(ns.GetPlans()) do if p.title == "Meine Punkte" then mine = p end end
check(mine and mine.steps[1].title == "Wegekreuz", "Nichts gewählt: neuer Plan 'Meine Punkte' (englischer Befehl)")

-- Tracker
ns.ActivatePlan(copy.id); RunTimers()
ns.UpdateTracker()
check(ns.tracker and ns.tracker:IsShown(), "Tracker sichtbar")
check(ns.tracker.header:GetText() == "Meine Runde", "Tracker-Kopf zeigt Plan")
local miss = ns.MissingTurnIns(ns.ActivePlan())
check(#miss > 0, "Fehlende Abgaben erkannt: " .. #miss)
ns.DB.tracker.expanded = true; ns.UpdateTracker()
check(ns.tracker.warn:IsShown() and ns.tracker.addBtn:IsShown(), "Warnung + Hinzufügen ausgeklappt")
local nBefore = #ns.ActivePlan().steps
ns.AddMissingTurnIns()
check(#ns.ActivePlan().steps == nBefore + #miss, "Fehlende Abgaben angehängt")
check(#ns.MissingTurnIns(ns.ActivePlan()) == 0, "Danach nichts mehr fehlend")
ns.HandleSlash("tracker")
check(not ns.tracker:IsShown(), "Tracker ausgeblendet")
ns.HandleSlash("tracker")
check(ns.tracker:IsShown(), "Tracker wieder an")
ns.DeactivatePlan(); ns.UpdateTracker()
check(ns.tracker:IsShown() and ns.tracker.action:GetText() == "Runde", "Ohne Plan: Knopf Abgaberunde")
for _, q in ipairs(QS.log) do if q.id then QS.complete[q.id] = nil end end
ns.UpdateTracker()
check(not ns.tracker:IsShown(), "Ohne Plan und ohne Abgaben: Tracker aus")

-- Aufnehmen
local am
for _, m in ipairs(ns.post.macros) do if m.name == "Angriff" then am = m end end
ns.PickupMacroFor(am)
check(PICKED[#PICKED] == 121, "Makro aufgenommen (Index 121)")
ns.ShowFrame("macros"); ns.UpdateUI(); ns.ShowFrame("plans"); ns.planEditId = ns.C.selectedPlan; ns.UpdateUI()


-- Paket 0.5: Reisezeit, Zurücksetzen, TomTom-Reparatur ----------------------
local errBase = #ERRORS_FORWARDED
RoadbookPost = OLDPOST; ns.LoadPost()
ns.DeactivatePlan(); RunTimers()

-- Testwelt: Kontinent 9000 (10 000 Yards), „Thunder Bluff“ 9001, „Steinkrallen“ 9002,
-- anderer Kontinent 9101
MAPOFF[9000] = { 0, 0, 10000, 7 }
MAPOFF[9001] = { 6000, 6000, 1000, 7 }
MAPOFF[9002] = { 3000, 3000, 3000, 7 }
MAPOFF[9101] = { 0, 0, 5000, 8 }
MAPINFO[9000] = { name = "Testkalimdor", mapType = 2 }
MAPINFO[9001] = { name = "Thunder Bluff", mapType = 3, parentMapID = 9000 }
MAPINFO[9002] = { name = "Steinkrallengebirge", mapType = 3, parentMapID = 9000 }
MAPINFO[9101] = { name = "Anderswo", mapType = 3, parentMapID = 9100 }
MAPINFO[9100] = { name = "Ostkontinent", mapType = 2 }
TAXI[9000] = {
    { nodeID = 1, name = "Thunder Bluff, Mulgore", position = { x = 0.65, y = 0.65 }, faction = 1 },
    { nodeID = 2, name = "Sonnenfels, Steinkrallengebirge", position = { x = 0.45, y = 0.45 }, faction = 1 },
    { nodeID = 3, name = "Windschere, Steinkrallengebirge", position = { x = 0.525, y = 0.465 }, faction = 0 },
    { nodeID = 4, name = "Astranaar, Eschental", position = { x = 0.5, y = 0.3 }, faction = 2 },
}
-- Einträge bis 0.7 standen unter dem Namen: werden erkannt und auf die Nummer umgezogen
ns.C.taxi["Thunder Bluff, Mulgore"] = true; ns.C.taxi["Sonnenfels, Steinkrallengebirge"] = true; ns.C.taxi["Astranaar, Eschental"] = true
ns.taxiVersion = ns.taxiVersion + 1
local known = ns.KnownTaxiNodes(9002)
local kn = {}
for _, n in ipairs(known) do kn[#kn + 1] = n.short end
table.sort(kn)
check(joined(kn) == "Sonnenfels ; Thunder Bluff", "Nur bekannte Horde-/neutrale Flugpunkte: " .. joined(kn))

PLAYER = { map = 9001, x = 0.5, y = 0.5 }
local raw = {
    { type = "goto", map = 9002, x = 75, y = 55, title = "Ziz Fizziks" },
    { type = "goto", map = 9101, x = 10, y = 10, title = "Übersee" },
    { type = "goto", map = 9002, x = 50, y = 56, title = "Mor'rogal" },
    { type = "goto", title = "Ohne Ort" },
    { type = "goto", map = 9002, x = 50, y = 52, title = "Tammra" },
}
local ordered = ns.OrderSteps(raw)
local names = {}
for _, st in ipairs(ordered) do names[#names + 1] = st.title end
check(joined(names) == "Tammra ; Mor'rogal ; Ziz Fizziks ; Übersee ; Ohne Ort",
      "Mit Flug: erst Sonnenfels, dann Ziz; anderer Kontinent und ohne Ort hinten: " .. joined(names))
local hint = ns.TravelHint({ map = 9002, x = 50, y = 52 })
check(hint and hint:find("Flug Thunder Bluff → Sonnenfels", 1, true), "Reisehinweis Flug: " .. tostring(hint))
check(ns.TravelHint({ map = 9001, x = 52, y = 52 }) == nil, "Kurzer Weg: kein Reisehinweis (zu Fuß)")
-- ohne bekannte Flugpunkte: nur zu Fuß -> Ziz (Luftlinie näher) zuerst
local savedTaxi = ns.C.taxi
ns.C.taxi = { ["Irgendwo, Nirgendwo"] = true }; ns.taxiVersion = ns.taxiVersion + 1
ordered = ns.OrderSteps(raw); names = {}
for _, st in ipairs(ordered) do names[#names + 1] = st.title end
check(names[1] == "Ziz Fizziks", "Ohne Flugpunkte zu Fuß: Ziz zuerst: " .. joined(names))
ns.C.taxi = savedTaxi; ns.taxiVersion = ns.taxiVersion + 1
-- Beim Flugmeister merken
GetTaxiMapID = function() return 9000 end
C_TaxiMap.GetAllTaxiNodes = function() return {
    { nodeID = 3, name = "Windschere, Steinkrallengebirge", state = 1 }, { nodeID = 9, name = "Gadgetzan, Tanaris", state = 2 } } end
fire("TAXIMAP_OPENED", 1)
check(ns.C.taxi[3] and not ns.C.taxi[9], "Flugmeister: erreichbare unter der Nummer gemerkt, unbekannte nicht")
ordered = ns.OrderSteps(raw)
check(ordered[1].title == "Ziz Fizziks", "Mit Flugpunkt Windschere: Ziz zuerst (Flug direkt dorthin)")
C_TaxiMap.GetAllTaxiNodes = nil
ns.C.taxi[3] = nil; ns.taxiVersion = ns.taxiVersion + 1
-- Client zeigt Flugpunkte nur auf Gebietskarten: Gebiete werden abgefragt
local contNodes = TAXI[9000]
TAXI[9000] = nil
TAXI[9001] = { { nodeID = 1, name = "Thunder Bluff, Mulgore", position = { x = 0.5, y = 0.5 }, faction = 1 } }
TAXI[9002] = { { nodeID = 2, name = "Sonnenfels, Steinkrallengebirge", position = { x = 0.5, y = 0.5 }, faction = 1 } }
C_Map.GetMapChildrenInfo = function(m) if m == 9000 then return { { mapID = 9001 }, { mapID = 9002 } } end return {} end
ns.taxiVersion = ns.taxiVersion + 1
ordered = ns.OrderSteps(raw)
check(ordered[1].title == "Tammra" and #ns.KnownTaxiNodes(9002) == 2, "Flugpunkte über Gebietskarten gefunden")
TAXI[9000], TAXI[9001], TAXI[9002], C_Map.GetMapChildrenInfo = contNodes, nil, nil, nil
ns.taxiVersion = ns.taxiVersion + 1

-- Eigener Plan sortieren + Wegbeschreibung
ns.C.plans["p500"] = { id = "p500", title = "Steinkrallen", mode = "route", created = 5, steps = raw, origin = ns.CopySteps(raw) }
local sp = ns.GetPlan("e:p500")
ns.SortPlan(sp)
sp = ns.GetPlan("e:p500")
check(sp.steps[1].title == "Tammra" and sp.steps[3].title == "Ziz Fizziks", "Sortieren nach Reisezeit")
check(joined(LOG):find("Reihenfolge nach Reisezeit sortiert", 1, true), "Sortieren meldet Zeitersparnis")
local rt = ns.RouteText(sp)
check(rt:find("Flug Thunder Bluff → Sonnenfels", 1, true) and rt:find("Geschätzt gesamt", 1, true), "Wegbeschreibung mit Flug")
ns.HandleSlash("route")
-- Zurücksetzen stellt die ursprüngliche Reihenfolge wieder her, alter Stand im Papierkorb
ns.ResetPlan(sp)
sp = ns.GetPlan("e:p500")
check(sp.steps[1].title == "Ziz Fizziks", "Zurücksetzen: ursprüngliche Schritte")
local tl = ns.TrashList()
check(tl[1].entry.kind == "planState", "Alter Stand im Papierkorb")
ns.RestoreTrash(tl[1].index)
check(ns.GetPlan("e:p500").steps[1].title == "Tammra", "Stand vor dem Zurücksetzen wiederherstellbar")

-- Post-Plan: Überspringen, Abhaken, Zurücksetzen
PLAYER = { map = 1413, x = 0.576, y = 0.213 }
for _, q in ipairs({ 894, 6541, 97003, 872 }) do QS.flagged[q] = nil; QS.onQuest[q] = true; QS.complete[q] = true; ns.C.turnedIn[q] = nil end
local br = ns.GetPlan("brachland-abgabe")
ns.ActivatePlan(br.id); RunTimers()
LOG = {}
for i = 1, 3 do ns.ToggleSkip(br, br.steps[i]) end
ns.ToggleDone(br.steps[4])
RunTimers()
check(ns.CurrentStep(br) == nil, "Alles übersprungen/abgehakt -> Plan abgeschlossen")
ns.UpdateTracker()
check(ns.tracker.action:GetText() == "Zurück", "Tracker bietet „Zurück“ an")
ns.tracker.action:Click()
RunTimers()
check(ns.CountSkipped(br) == 0 and not ns.C.done[br.steps[4].key], "Zurückgesetzt: nichts mehr übersprungen/abgehakt")
check(ns.CurrentStep(br) == br.steps[1], "Plan fängt vorne an")
check(joined(TT_List()):find("Steuerkonsole", 1, true), "Wegpunkt für Schritt 1 wieder da: " .. joined(TT_List()))
check(joined(LOG):find("zurückgesetzt: 3 übersprungene und 1 abgehakte", 1, true), "Meldung nennt, was zurückkam")

-- TomTom verliert einen Punkt ohne Meldung -> wird beim nächsten Abgleich neu gesetzt
local uidA = ns.wp.byKey[br.steps[1].key]
TomTom.waypoints[uidA[1]][TomTom:GetKey(uidA)] = nil
fire("QUEST_LOG_UPDATE"); RunTimers()
check(ns.wp.byKey[br.steps[1].key] and ns.wp.byKey[br.steps[1].key] ~= uidA, "Verlorener Punkt neu gesetzt")
check(logHas("I", "vanished"), "Verlust protokolliert")
-- Verwaiste Roadbook-Punkte (alte Sitzung) werden aufgeräumt
TomTom:AddWaypoint(1413, 0.3, 0.3, { title = "Alter Roadbook-Punkt", from = "Roadbook" })
fire("QUEST_LOG_UPDATE"); RunTimers()
check(not joined(TT_List()):find("Alter Roadbook-Punkt", 1, true), "Verwaister Roadbook-Punkt entfernt")
check(joined(TT_List()):find("Mein Punkt|TomTom/way", 1, true), "Fremde TomTom-Punkte bleiben")
-- Von Hand entfernt -> Tracker warnt -> Linksklick auf den Tracker setzt neu
TomTom:RemoveWaypoint(ns.wp.byKey[br.steps[1].key])
fire("QUEST_LOG_UPDATE"); RunTimers()
check(not joined(TT_List()):find("Steuerkonsole", 1, true), "Von Hand entfernt bleibt weg")
ns.UpdateTracker()
check(ns.tracker.line3:IsShown() and ns.tracker.line3:GetText():find("Kein Wegpunkt", 1, true), "Tracker: Hinweis „Kein Wegpunkt“")
ns.tracker.scripts.OnMouseUp(ns.tracker, "LeftButton")
RunTimers()
check(joined(TT_List()):find("Steuerkonsole", 1, true), "Linksklick auf Tracker: Punkt wieder da")
check(TomTom.arrow and TomTom.arrow.title:find("Steuerkonsole", 1, true), "Pfeil wieder auf dem Schritt")
-- Nach dem Ziehen kein Neu-Setzen
GetTime = function() return 100 end
TomTom:RemoveWaypoint(ns.wp.byKey[br.steps[1].key]); RunTimers()
ns.tracker.scripts.OnDragStop(ns.tracker)
ns.tracker.scripts.OnMouseUp(ns.tracker, "LeftButton"); RunTimers()
check(not joined(TT_List()):find("Steuerkonsole", 1, true), "Loslassen nach dem Ziehen setzt nichts neu")
GetTime = function() return 101 end
ns.tracker.scripts.OnMouseUp(ns.tracker, "LeftButton"); RunTimers()
check(joined(TT_List()):find("Steuerkonsole", 1, true), "Späterer Klick setzt wieder neu")
-- Pfeil zeigt auf fremden Punkt -> Hinweis; /rb wegpunkte richtet ihn aus
TomTom:SetCrazyArrow(TomTom.waypoints[1413][TomTom:GetKey({ 1413, 0.5, 0.5, title = "Mein Punkt" })])
ns.UpdateTracker()
check(ns.tracker.line3:GetText():find("Pfeil zeigt auf etwas anderes", 1, true), "Tracker: Pfeil zeigt woanders hin")
ns.HandleSlash("wegpunkte"); RunTimers()
check(TomTom.arrow and TomTom.arrow.title:find("Steuerkonsole", 1, true), "/rb wegpunkte: Pfeil wieder auf dem Plan")
check(joined(LOG):find("Wegpunkte neu gesetzt", 1, true), "Meldung Wegpunkte neu gesetzt")
-- TomTom lädt neu (wie beim Profilwechsel): alles weg, Meldungen kommen -> Roadbook setzt neu
local old = TomTom.waypoints
TomTom.waypoints = {}
for _, e in pairs(old) do for _, u in pairs(e) do TomTom.cbs.WaypointRemoved("WaypointRemoved", u) end end
TomTom.cbs.WaypointsReloaded("WaypointsReloaded")
RunTimers()
check(joined(TT_List()):find("Steuerkonsole", 1, true), "Nach TomTom-Neuladen wieder gesetzt")

-- Abgaberunde neu erstellen: alte Übersprungen-Marken sind weg
QS.log = {}
for _, q in ipairs({ { 894, "Samophlang" }, { 6541, "Meldung bei Kadrak" } }) do
    table.insert(QS.log, { id = q[1], title = q[2] }); QS.onQuest[q[1]] = true; QS.complete[q[1]] = true; QS.flagged[q[1]] = nil
end
ns.CreateTurnInPlan(); RunTimers()
local ap = ns.ActivePlan()
for _, st in ipairs(ap.steps) do ns.ToggleSkip(ap, st) end
check(ns.CurrentStep(ap) == nil, "Runde komplett übersprungen")
ns.CreateTurnInPlan(); RunTimers()
check(ns.CountSkipped(ns.ActivePlan()) == 0 and ns.CurrentStep(ns.ActivePlan()) ~= nil, "Neue Runde ohne alte Übersprungen-Marken")
-- Runde löschen räumt ebenfalls auf
ap = ns.ActivePlan()
ns.ToggleSkip(ap, ap.steps[1])
ns.DeletePlan(ap)
check(ns.C.skipped["e:auto-abgabe"] == nil, "Löschen räumt Übersprungen-Marken auf")
ns.HandleSlash("reset")

-- Oberfläche mit neuen Knöpfen
ns.ActivatePlan("brachland-abgabe"); RunTimers()
ns.ShowFrame("plans"); ns.C.selectedPlan = "brachland-abgabe"; ns.UpdateUI()
for _, f in ipairs(ALLFRAMES) do
    if f.__kind == "Button" and f.scripts.OnClick and f.shown and f.enabled and f.template == "UIPanelButtonTemplate"
       and (f.text == "Zurücksetzen" or f.text == "Wegpunkte neu" or f.text == "Wegbeschreibung") then
        local ok, err = pcall(f.scripts.OnClick, f, "LeftButton")
        if not ok then check(false, "Klick-Fehler: " .. tostring(err)) else clicked = clicked + 1 end
    end
end
ns.planEditId = "brachland-abgabe"; ns.UpdateUI()
for _, f in ipairs(ALLFRAMES) do
    if f.__kind == "Button" and f.text == "Sortieren" and f.shown and f.scripts.OnClick then
        local ok, err = pcall(f.scripts.OnClick, f, "LeftButton")
        if not ok then check(false, "Klick-Fehler Sortieren: " .. tostring(err)) else clicked = clicked + 1 end
    end
end
check(ns.GetPlan("brachland-abgabe") == nil, "Sortieren macht den Post-Plan zur eigenen Kopie")
for _, f in ipairs(ALLFRAMES) do
    if f.scripts.OnEnter and f.shown then
        local ok, err = pcall(f.scripts.OnEnter, f)
        if not ok then check(false, "Tooltip-Fehler: " .. tostring(err)) end
    end
end
check(#ERRORS_FORWARDED == errBase, "Keine neuen Lua-Fehler im Paket 0.5: " .. joined(ERRORS_FORWARDED))


-- Paket 0.6: Pfeil zum Flugmeister -----------------------------------------
local errBase6 = #ERRORS_FORWARDED
ns.DeactivatePlan(); RunTimers()
ns.ClearRouteCache(); ns.taxiVersion = ns.taxiVersion + 1
PLAYER = { map = 9001, x = 0.4, y = 0.4 }
ns.C.plans["p600"] = { id = "p600", title = "Sonnenfels-Runde", mode = "route", created = 6, steps = {
    { type = "goto", map = 9002, x = 50, y = 52, title = "Tammra" },
    { type = "goto", map = 9002, x = 75, y = 55, title = "Ziz Fizziks" },
    { type = "goto", map = 9001, x = 42, y = 42, title = "Nebenan" },
} }
ns.ActivatePlan("e:p600"); RunTimers()
check(ns.travel and ns.travel.hop.kind == "flug" and ns.travel.hop.from.short == "Thunder Bluff"
      and ns.travel.hop.to.short == "Sonnenfels", "Flug Thunder Bluff → Sonnenfels gewählt")
local list = joined(TT_List())
check(list:find("Flugmeister Thunder Bluff – Flug nach Sonnenfels|Roadbook", 1, true), "Reise-Punkt beim Flugmeister: " .. list)
check(list:find("Tammra|Roadbook", 1, true), "Ziel-Punkt bleibt zusätzlich gesetzt")
check(TomTom.arrow and TomTom.arrow.title == "Flugmeister Thunder Bluff – Flug nach Sonnenfels", "Pfeil zeigt zuerst zum Flugmeister")
check(TomTom.arrow[1] == 9001 and math.abs(TomTom.arrow[2] - 0.5) < 0.001, "Flugmeister auf der Stadtkarte (9001 50 50)")
ns.UpdateTracker()
check(ns.tracker.line3:IsShown() and ns.tracker.line3:GetText():find("Erst zum Flugmeister Thunder Bluff, Flug nach Sonnenfels", 1, true),
      "Tracker: " .. tostring(ns.tracker.line3:GetText()))
-- Kein Hin und Her: ein paar Schritte weiter bleibt der Weg gleich
PLAYER = { map = 9001, x = 0.43, y = 0.43 }
LOG = {}
ns.CheckTravel(); RunTimers()
check(TomTom.arrow.title:find("Flugmeister", 1, true), "Weg bleibt stabil")
check(TomTom.arrowTitle == "Flugmeister Thunder Bluff – Flug nach Sonnenfels", "Pfeiltext nennt auch das Flugziel: " .. tostring(TomTom.arrowTitle))
-- Reise-Abschnitt steht im Plan und lässt sich überspringen (Punkt liegt nicht immer genau am Anleger)
check(ns.TravelRow() and not ns.TravelRow().skipped and ns.TravelRow().title:find("Flug nach Sonnenfels", 1, true), "Reise-Abschnitt als Zeile im Plan")
local legStep = ns.wp.targetKey
ns.SkipCurrentStep(); RunTimers()
check(ns.travel == nil and TomTom.arrow.title == "Tammra" and ns.TravelRow() and ns.TravelRow().skipped,
      "„Weiter“ überspringt zuerst den Reise-Abschnitt: " .. tostring(TomTom.arrow and TomTom.arrow.title))
check(ns.StepState(ns.CurrentStep(ns.ActivePlan()), ns.ActivePlan().id) ~= "skipped", "Der Schritt selbst bleibt offen")
ns.ToggleTravelSkip(legStep); RunTimers()
check(ns.travel and TomTom.arrow.title:find("Flugmeister", 1, true) and not ns.TravelRow().skipped, "Reise-Abschnitt wieder aufgenommen")
-- Ankunft beim Flugmeister + Flugkarte
PLAYER = { map = 9001, x = 0.5, y = 0.5 }
TomTom.arrow.callbacks.distance[15]("distance", TomTom.arrow, 15, 10, 20)
check(joined(LOG):find("Flugmeister Thunder Bluff: flieg nach", 1, true), "Ankunft am Flugmeister gemeldet")
check(not ns.C.done[ns.GetPlan("e:p600").steps[1].key], "Flugmeister hakt keinen Schritt ab")
LOG = {}
fire("TAXIMAP_OPENED", 1)
check(joined(LOG):find("Flieg nach |cffffffffSonnenfels, Steinkrallengebirge|r – für „Tammra“", 1, true), "Flugkarte: Ziel genannt: " .. joined(LOG))
-- Im Flug ändert sich nichts, nach der Landung zeigt der Pfeil zum Ziel
ON_TAXI = true
PLAYER = { map = 9002, x = 0.6, y = 0.6 }
ns.CheckTravel(); RunTimers()
check(TomTom.arrow.title:find("Flugmeister", 1, true), "Im Flug bleibt alles, wie es ist")
ON_TAXI = false
PLAYER = { map = 9002, x = 0.5, y = 0.5 }
fire("PLAYER_CONTROL_GAINED"); RunTimers()
check(ns.travel == nil, "Nach der Landung: zu Fuß weiter")
check(not joined(TT_List()):find("Flugmeister", 1, true), "Reise-Punkt entfernt")
check(TomTom.arrow and TomTom.arrow.title == "Tammra", "Pfeil zeigt jetzt auf Tammra")
-- Kurzer Weg: kein Flug
turnInDone = nil
ns.ToggleDone(ns.GetPlan("e:p600").steps[1]); ns.ToggleDone(ns.GetPlan("e:p600").steps[2]); RunTimers()
PLAYER = { map = 9001, x = 0.4, y = 0.4 }
fire("ZONE_CHANGED_NEW_AREA"); RunTimers()
check(ns.travel == nil and TomTom.arrow.title == "Nebenan", "Kurzer Weg: kein Flugmeister")
-- Von Hand entfernter Reise-Punkt: direkt zum Ziel; „Wegpunkte neu“ holt ihn zurück
ns.ResetPlan(ns.GetPlan("e:p600")); RunTimers()
check(ns.wp.travelUid ~= nil, "Nach Zurücksetzen wieder Flug")
TomTom:RemoveWaypoint(ns.wp.travelUid); RunTimers()
check(ns.travel == nil and TomTom.arrow and TomTom.arrow.title == "Tammra", "Reise-Punkt weg -> Pfeil direkt zum Ziel")
ns.ResetWaypoints(); RunTimers()
check(TomTom.arrow and TomTom.arrow.title:find("Flugmeister", 1, true), "„Wegpunkte neu“ holt den Flug zurück")
check(joined(LOG):find("Erst zum Flugmeister Thunder Bluff", 1, true), "Meldung nennt den Flug")
-- TomTom verliert den Reise-Punkt -> neu gesetzt
local tu = ns.wp.travelUid
TomTom.waypoints[tu[1]][TomTom:GetKey(tu)] = nil
fire("QUEST_LOG_UPDATE"); RunTimers()
check(ns.wp.travelUid and ns.wp.travelUid ~= tu and TomTom.arrow.title:find("Flugmeister", 1, true), "Verlorener Reise-Punkt neu gesetzt")
-- Anderer Kontinent: erst zum Zeppelin, mit bekanntem Flugpunkt erst fliegen
MAPOFF[1411] = { 8000, 1000, 1000, 7 }
MAPOFF[1420] = { 1000, 1000, 1000, 8 }
MAPINFO[1411] = { name = "Durotar", mapType = 3, parentMapID = 9000 }
MAPINFO[1420] = { name = "Tirisfal", mapType = 3, parentMapID = 9100 }
ns.ClearRouteCache(); ns.taxiVersion = ns.taxiVersion + 1
ns.C.plans["p601"] = { id = "p601", title = "Übersee", mode = "route", created = 7, steps = {
    { type = "goto", map = 9101, x = 30, y = 30, title = "Drüben" } } }
ns.ActivatePlan("e:p601"); RunTimers()
check(ns.travel and ns.travel.hop.kind == "schiff" and TomTom.arrow.title == "Anleger – Zeppelin Orgrimmar – Undercity",
      "Zeppelin: Pfeil zum Anleger: " .. tostring(TomTom.arrow and TomTom.arrow.title))
check(TomTom.arrow[1] == 1411, "Anleger auf der Durotar-Karte")
table.insert(TAXI[9000], { nodeID = 5, name = "Orgrimmar, Durotar", position = { x = 0.85, y = 0.115 }, faction = 1 })
ns.C.taxi[5] = true
ns.ClearRouteCache(); ns.taxiVersion = ns.taxiVersion + 1
ns.ResetWaypoints(); RunTimers()
check(ns.travel and ns.travel.hop.kind == "flug" and ns.travel.hop.after == "Zeppelin Orgrimmar – Undercity",
      "Erst Flug nach Orgrimmar, dann Zeppelin: " .. tostring(ns.travel and ns.travel.text))
check(ns.travel.text:find("Flug nach Orgrimmar, dann Zeppelin Orgrimmar – Undercity", 1, true), "Text nennt beides")
-- „Alle Punkte“: Reiseweg zum am schnellsten erreichbaren Schritt
ns.DeactivatePlan(); RunTimers()
ns.C.plans["p602"] = { id = "p602", title = "Alles", mode = "alle", created = 8, steps = {
    { type = "goto", map = 9002, x = 75, y = 55, title = "Ziz Fizziks" },
    { type = "goto", map = 9002, x = 50, y = 52, title = "Tammra" } } }
PLAYER = { map = 9001, x = 0.4, y = 0.4 }
ns.ActivatePlan("e:p602"); RunTimers()
check(ns.wp.targetKey == ns.GetPlan("e:p602").steps[2].key and ns.travel and ns.travel.hop.kind == "flug",
      "Alle Punkte: Ziel Tammra per Flug")
ns.UpdateTracker()
check(ns.tracker.line3:GetText():find("– für Tammra", 1, true), "Tracker nennt das Ziel im Alle-Modus: " .. tostring(ns.tracker.line3:GetText()))
ns.DeactivatePlan(); RunTimers()
check(not joined(TT_List()):find("Roadbook", 1, true), "Entladen räumt auch den Reise-Punkt weg: " .. joined(TT_List()))
check(#ERRORS_FORWARDED == errBase6, "Keine neuen Lua-Fehler im Paket 0.6: " .. joined(ERRORS_FORWARDED))


-- 0.8: Fehlerbehebungen, Import/Export, unbekannte Flugmeister ----------------------
local errBase8 = #ERRORS_FORWARDED
ns.DeactivatePlan(); RunTimers()
PLAYER = { map = 1413, x = 0.5, y = 0.5 }
ns.C.plans["p800"] = { id = "p800", title = "Alle-Test", mode = "alle", created = 8, steps = {
    { type = "goto", map = 1413, x = 52, y = 50, title = "Nah" },
    { type = "goto", map = 1413, x = 90, y = 90, title = "Fern" } } }
ns.ActivatePlan("e:p800"); RunTimers()
check(TomTom.arrow and TomTom.arrow.title == "Nah", "Alle: Pfeil zum nächsten Punkt: " .. tostring(TomTom.arrow and TomTom.arrow.title))
local p8 = ns.GetPlan("e:p800")
ns.FocusStep(p8, p8.steps[2]); RunTimers()
fire("QUEST_LOG_UPDATE"); RunTimers()
check(TomTom.arrow and TomTom.arrow.title == "Fern", "Alle: Klick auf einen Schritt hält den Pfeil auch nach dem nächsten Abgleich")
ns.HandleSlash("off"); RunTimers()
check(ns.C.activePlan == false, "Englischer Befehl /rb off entlädt")

-- Wiederholbare Quests: die eigene Abgabe-Marke gilt nur vorübergehend
ns.C.turnedIn[7001] = time()
local rq = ns.NormalizeStep({ type = "turnin", quest = 7001, title = "Wiederholbar" })
check(ns.StepState(rq) == "done", "Frisch abgegeben: erledigt")
QS.onQuest[7001] = true
check(ns.StepState(rq) ~= "done" and ns.C.turnedIn[7001] == nil, "Wieder angenommen: wieder offen")
ns.C.turnedIn[7002] = time() - 7200
check(ns.StepState(ns.NormalizeStep({ type = "turnin", quest = 7002 })) ~= "done", "Alte Abgabe-Marke verfällt")
QS.onQuest[7001] = nil

-- Schon einmal erreichter Ort: ein neuer Schritt dort fängt offen an
ns.C.done["p:1413:50.0:50.0"] = time()
ns.C.selectedPlan = false
ns.AddHereStep(nil, "Nochmal hier")
check(ns.C.done["p:1413:50.0:50.0"] == nil, "Neuer Schritt am alten Ort ist offen")

-- Export / Import
local text = ns.ExportPlan(p8)
check(text:find("^RB1 Alle%-Test\nmode=all\n") and text:find("step;type=goto;map=1413;x=52;y=50;title=Nah", 1, true), "Export: " .. text)
check(not text:find("|", 1, true), "Export ohne „|“ (WoW liest |t und |n in Textfeldern als Steuerzeichen)")
local tricky = ns.ImportText(ns.ExportPlan({ title = "A;B|C", steps = { ns.NormalizeStep({ type = "goto", map = 1413, x = 1, y = 2, title = "x;y|z", note = "n1\nn2" }) } }))
check(tricky and tricky.title == "A;B|C" and tricky.steps[1].title == "x;y|z" and tricky.steps[1].note == "n1\nn2", "Sonderzeichen überstehen Export und Import")
local pasted = ns.ImportText("RB1 Eingefügt\nstep||type=goto||map=1413||x=5||y=6||title=Doppelstrich")
check(pasted and pasted.steps[1].title == "Doppelstrich" and pasted.steps[1].x == 5, "Alte Fassung mit „|“ wird weiter gelesen, auch als „||“ aus dem Textfeld")
local back = ns.ImportText(text)
check(back and back.source == "eigen" and #back.steps == 2 and ns.PlanMode(back) == "alle" and back.steps[2].title == "Fern", "Export und Import ergeben denselben Plan")
local manKey = ns.NormalizeStep({ type = "manual", title = "Von Hand" }).key
ns.C.done[manKey] = time()
local fresh = ns.ImportText("RB1 Frisch\nstep;type=manual;title=Von Hand")
check(fresh and not ns.C.done[manKey] and ns.StepState(fresh.steps[1], fresh.id) ~= "done", "Importierter Plan fängt von vorn an (altes Häkchen weg)")
local imp = ns.ImportText("RB1 Geteilt | mit Strich\nmode=route\nnote=Zeile 1\\nZeile 2\n"
    .. "step|type=turnin|quest=894|map=1413|x=52.4|y=11.6|title=Konsole|text=A\\pB\nKauderwelsch")
check(imp and imp.title == "Geteilt | mit Strich" and #imp.steps == 1 and imp.steps[1].text == "A|B"
      and imp.steps[1].quest == 894 and imp.note == "Zeile 1\nZeile 2" and imp.mode == "route", "Import liest Titel, Notiz, Sonderzeichen")
check(joined(LOG):find("1 Zeile(n) nicht verstanden", 1, true), "Import meldet unverständliche Zeilen")
local way = ns.ImportText("/way #1413 40.5 60.1 Brunnen\n/way 10 20")
check(way and #way.steps == 2 and way.steps[1].title == "Brunnen" and way.steps[1].x == 40.5 and way.steps[2].map == 1413
      and way.steps[2].title == "Wegpunkt" and way.mode == "alle", "/way-Zeilen werden zu einem Plan")
local nPlans = #ns.GetPlans()
check(ns.ImportText("return os.exit()") == nil and ns.ImportText("") == nil and #ns.GetPlans() == nPlans, "Kein Plan aus Unsinn, nichts wird ausgeführt")
check(ns.ImportText(("x"):rep(20001)) == nil, "Zu langer Text wird abgelehnt")

-- Unbekannter Flugmeister in der Nähe
ns.C.taxi[3] = nil; ns.taxiVersion = ns.taxiVersion + 1
PLAYER = { map = 9000, x = 0.525, y = 0.465 }
ns.C.taxiSeen = nil
LOG = {}
ns.CheckNewTaxi()
check(not joined(LOG):find("Unbekannter Flugmeister", 1, true), "Ohne geöffnete Flugkarte kein Hinweis: " .. joined(LOG))
ns.C.taxiSeen = { [9000] = true }
ns.CheckNewTaxi()
check(joined(LOG):find("Unbekannter Flugmeister in der Nähe: |cffffffffWindschere", 1, true), "Hinweis auf unbekannten Flugmeister: " .. joined(LOG))
LOG = {}
ns.CheckNewTaxi()
check(#LOG == 0, "Hinweis nur einmal")
ns.HandleSlash("fm")
check(joined(TT_List()):find("Flugmeister Windschere|Roadbook flight master", 1, true), "/rb fm setzt einen Wegpunkt: " .. joined(TT_List()))
fire("QUEST_LOG_UPDATE"); RunTimers()
check(joined(TT_List()):find("Flugmeister Windschere", 1, true), "Der Abgleich lässt den Flugmeister-Punkt stehen")
-- Unbekannter Flugmeister als Abflugpunkt: hinlaufen, kennenlernen, losfliegen
-- (Windschere, Nummer 3, ist unbekannt; auf dem Kontinent wurde schon eine Flugkarte geöffnet)
ns.DeactivatePlan(); RunTimers()
PLAYER = { map = 9000, x = 0.53, y = 0.47 }
local uText, _, uHow = ns.LegText(ns.PlayerPos(), ns.WorldPos(9001, 50, 50))
check(uHow == "flug" and uText == "Flug Windschere → Thunder Bluff (neuer Flugmeister)", "Abflug beim unbekannten Flugmeister: " .. tostring(uText))
ns.C.plans["p820"] = { id = "p820", title = "Neu entdecken", mode = "route", created = 10, steps = {
    { type = "goto", map = 9001, x = 50, y = 50, title = "Stadt" } } }
ns.ActivatePlan("e:p820"); RunTimers()
check(ns.travel and ns.travel.hop.new and ns.travel.text:find("unbekannten Flugmeister Windschere", 1, true)
      and TomTom.arrowTitle == "Flugmeister Windschere – Flug nach Thunder Bluff", "Pfeil zum unbekannten Flugmeister: " .. tostring(ns.travel and ns.travel.text))
ns.C.taxiSeen = nil; ns.taxiVersion = ns.taxiVersion + 1
check(select(3, ns.LegText(ns.PlayerPos(), ns.WorldPos(9001, 50, 50))) ~= nil
      and not tostring((ns.LegText(ns.PlayerPos(), ns.WorldPos(9001, 50, 50)))):find("Windschere", 1, true),
      "Ohne geöffnete Flugkarte wird kein unbekannter Flugmeister eingeplant")
ns.C.taxiSeen = { [9000] = true }; ns.taxiVersion = ns.taxiVersion + 1
ns.DeactivatePlan(); RunTimers()

-- Unbekannter Flugmeister fast am Weg: mitnehmen; weit ab vom Weg: nicht
PLAYER = { map = 9000, x = 0.50, y = 0.45 }
ns.C.plans["p830"] = { id = "p830", title = "Am Weg", mode = "route", created = 11, steps = {
    { type = "goto", map = 9002, x = 83.33, y = 60, title = "Hinterm Flugmeister" },
    { type = "goto", map = 9002, x = 10, y = 10, title = "Ganz woanders" } } }
ns.ActivatePlan("e:p830"); RunTimers()
check(ns.travel and ns.travel.hop.kind == "neu" and TomTom.arrowTitle == "Flugmeister Windschere – unbekannt – mitnehmen",
      "Flugmeister am Weg wird mitgenommen: " .. tostring(TomTom.arrowTitle))
check(ns.TravelRow() and ns.TravelRow().title:find("mitnehmen", 1, true), "Mitnehmen steht als Zeile im Plan")
ns.C.taxi[3] = true; ns.taxiVersion = ns.taxiVersion + 1           -- Flugkarte geöffnet: jetzt bekannt
fire("ZONE_CHANGED_NEW_AREA"); RunTimers()
check(ns.travel == nil and TomTom.arrow.title == "Hinterm Flugmeister", "Nach dem Kennenlernen weiter zum Ziel: " .. tostring(TomTom.arrow.title))
ns.C.taxi[3] = nil; ns.taxiVersion = ns.taxiVersion + 1
ns.ToggleDone(ns.GetPlan("e:p830").steps[1]); RunTimers()
PLAYER = { map = 9000, x = 0.34, y = 0.34 }
fire("ZONE_CHANGED_NEW_AREA"); RunTimers()
check(not (ns.travel and ns.travel.hop.kind == "neu"), "Flugmeister weit ab vom Weg wird nicht eingeplant")
ns.DeactivatePlan(); RunTimers()

-- Einstellung: wie viel Umweg ein unbekannter Flugmeister wert ist
PLAYER = { map = 9000, x = 0.50, y = 0.45 }
ns.C.plans["p840"] = { id = "p840", title = "Umweg", mode = "route", created = 12, steps = {
    { type = "goto", map = 9002, x = 83.6, y = 60.4, title = "Auch hinterm Flugmeister" } } }
ns.ActivatePlan("e:p840"); RunTimers()
check(ns.travel and ns.travel.hop.kind == "neu", "Standard: Flugmeister am Weg wird mitgenommen")
ns.HandleSlash("umweg 0"); RunTimers()
check(ns.travel == nil and ns.PickupMax() == 0 and joined(LOG):find("Umweg für einen unbekannten Flugmeister: aus", 1, true), "/rb umweg 0 schaltet das Mitnehmen ab")
ns.HandleSlash("detour 9999"); RunTimers()
check(ns.PickupMax() == 600 and ns.travel and ns.travel.hop.kind == "neu", "Obergrenze 10 Minuten, Mitnehmen wieder an")
ns.DB.pickupMax = nil
check(ns.PickupMax() == 120, "Ohne Einstellung gelten 2 Minuten")
ns.DeactivatePlan(); RunTimers()

-- /rb fotos: jedes Fenster einmal mit Beispieldaten, je ein Screenshot mit Zuschnitt-Daten;
-- eigene Pläne, Notizen und Makros sind nicht zu sehen und bleiben unverändert
do
    local shots, seenPlans, seenMacros, seenNotes, seenTravel, seenNames, seenSkill = 0, nil, nil, nil, nil, nil, nil
    Screenshot = function()
        shots = shots + 1
        if shots == 1 then
            local t = {}
            for _, p in ipairs(ns.GetPlans()) do t[#t + 1] = p.title end
            seenPlans = joined(t)
            seenTravel = ns.TravelRow() and ns.TravelRow().title
            local order = ns.MacroGroups()
            seenMacros = joined(order)
            t = {}
            for _, sec in ipairs(ns.GetNoteSections()) do for _, n in ipairs(sec.items) do t[#t + 1] = n.title end end
            seenNotes = joined(t)
            seenNames = CVARS.UnitNameOwn .. CVARS.UnitNameNPC
            seenSkill = joined({ ns.PlayerSkill(356) })
        end
    end
    SKILLS = { { name = "Angeln", rank = 7, max = 75, line = 356 } }
    local plansBefore, activeBefore, selBefore, travelBefore = #ns.GetPlans(), ns.C.activePlan, ns.C.selectedPlan, ns.travel
    local wpBefore = joined(TT_List())
    LOG = {}
    ns.HandleSlash("fotos")
    for _ = 1, 6 do RunTimers() end
    local list = RoadbookDB.shots and RoadbookDB.shots.list or {}
    check(shots == 8 and #list == 8, "Fototour: acht Screenshots mit Zuschnitt, sind " .. shots .. "/" .. #list)
    local names = {}
    for _, r in ipairs(list) do names[#names + 1] = r.name end
    check(joined(names) == "plans ; tracker ; route ; notes ; macros ; search ; options ; import", "Reihenfolge der Bilder: " .. joined(names))
    check(seenPlans == "Abgaberunde (automatisch) ; Abgaben im Steinkrallengebirge ; Meine Punkte", "Nur Beispielpläne im Bild: " .. tostring(seenPlans))
    check(seenTravel == "Anleger – Zeppelin Orgrimmar – Undercity", "Zeppelin als Reise-Zeile: " .. tostring(seenTravel))
    check(seenMacros == "Roadbook ; Reise", "Nur Beispiel-Makros: " .. tostring(seenMacros))
    check(seenNotes and seenNotes:find("Einkaufsliste", 1, true) and not seenNotes:find("Fluffy", 1, true), "Nur Beispiel-Notizen: " .. tostring(seenNotes))
    check(ns.staging == nil and #ns.GetPlans() == plansBefore and ns.C.activePlan == activeBefore and ns.C.selectedPlan == selBefore
          and ns.travel == travelBefore and joined(TT_List()) == wpBefore, "Nach der Fototour ist alles wie vorher")
    check(joined(LOG):find("8 Screenshots liegen im Ordner", 1, true), "Abschlussmeldung")
    check(seenNames == "00" and CVARS.UnitNameOwn == "1" and CVARS.UnitNameNPC == "1", "Namen über Figuren sind nur während der Tour aus: " .. tostring(seenNames))
    check(seenSkill == "150 ; 150" and ns.PlayerSkill(356) == 7, "Im Bild stehen Beispiel-Berufe, nicht die eigenen: " .. tostring(seenSkill))
    SKILLS = {}
    Screenshot = nil
end

-- Zeppelin auf demselben Kontinent: schneller als der lange Fußweg
MAPOFF[1420] = { 0, 0, 1000, 8 }; MAPOFF[1434] = { 0, 9000, 1000, 8 }
ns.ClearRouteCache(); ns.taxiVersion = ns.taxiVersion + 1
local zFrom, zTo = ns.WorldPos(1420, 60, 58), ns.WorldPos(1434, 40, 40)
local zText, zTime, zHow = ns.LegText(zFrom, zTo)
check(zHow == "schiff" and zText == "Zeppelin Undercity – Grom'gol" and zTime < 700,
      "Gleicher Kontinent: Zeppelin statt 9 km zu Fuß: " .. tostring(zText) .. " " .. tostring(zTime))
check(select(3, ns.LegText(zFrom, ns.WorldPos(1420, 30, 30))) == "lauf", "Kurzer Weg auf demselben Kontinent bleibt zu Fuß")
PLAYER = { map = 1420, x = 0.5, y = 0.5 }
ns.C.plans["p810"] = { id = "p810", title = "Süden", mode = "route", created = 9, steps = {
    { type = "goto", map = 1434, x = 40, y = 40, title = "Weit im Süden" } } }
ns.ActivatePlan("e:p810"); RunTimers()
check(ns.travel and ns.travel.hop.kind == "schiff" and TomTom.arrow[1] == 1420
      and TomTom.arrowTitle == "Anleger – Zeppelin Undercity – Grom'gol", "Pfeil zuerst zum Zeppelin: " .. tostring(TomTom.arrowTitle))
-- an Bord: du wirst bewegt, läufst aber nicht selbst -> Anleger-Punkt verschwindet von allein
GetUnitSpeed = function() return 0 end
LOG = {}
ns.CheckRiding()
PLAYER.x = PLAYER.x + 0.02; ns.CheckRiding()
check(not ns.wp.riding, "Eine Messung reicht nicht (Rückstoß, Aufzug)")
PLAYER.x = PLAYER.x + 0.02; ns.CheckRiding(); RunTimers()
check(ns.wp.riding and ns.travel == nil and TomTom.arrow.title == "Weit im Süden" and joined(LOG):find("An Bord", 1, true),
      "An Bord erkannt: Pfeil zum Ziel: " .. tostring(TomTom.arrow and TomTom.arrow.title))
check(not joined(TT_List()):find("Anleger", 1, true), "Anleger-Punkt ist weg")
-- angekommen: kein Zeppelin zurück, zu Fuß weiter
PLAYER = { map = 1434, x = 0.32, y = 0.30 }
fire("ZONE_CHANGED_NEW_AREA"); RunTimers()
check(ns.travel == nil and TomTom.arrow.title == "Weit im Süden", "Nach der Fahrt zu Fuß zum Ziel: " .. tostring(TomTom.arrow and TomTom.arrow.title))
GetUnitSpeed = function() return 7 end
ns.CheckRiding(); RunTimers()
check(not ns.wp.riding and ns.travel == nil, "Wieder selbst unterwegs: Fahrt beendet, kein Zeppelin zurück")
GetUnitSpeed = nil
ns.DeactivatePlan(); RunTimers()
-- Zeppeline muss man nicht kennenlernen: auch ohne einen einzigen bekannten Flugpunkt
local noTaxi = ns.C.taxi
ns.C.taxi = {}; ns.C.taxiSeen = nil; ns.taxiVersion = ns.taxiVersion + 1
check(select(3, ns.LegText(zFrom, zTo)) == "schiff", "Zeppelin zählt ohne bekannte Flugpunkte")
ns.C.taxi = noTaxi; ns.taxiVersion = ns.taxiVersion + 1
-- ohne je geöffnete Flugkarte gilt kein Flugpunkt als bekannt, auch wenn das Spiel ihn „entdeckt“ nennt
local keepTaxi = ns.C.taxi
ns.C.taxi = {}; ns.taxiVersion = ns.taxiVersion + 1
TAXI[9000][1].isUndiscovered = false
check(#ns.KnownTaxiNodes(9002) == 0, "Leere Liste: nichts bekannt")
ns.C.taxi = keepTaxi; ns.taxiVersion = ns.taxiVersion + 1
check(#ERRORS_FORWARDED == errBase8, "Keine neuen Lua-Fehler in 0.8: " .. joined(ERRORS_FORWARDED))

-- NPC-Suche (Spieler im Brachland bei 57.6, 21.3)
PLAYER.map, PLAYER.x, PLAYER.y = 1413, 0.576, 0.213
local function cat(key) for _, c in ipairs(ns.NpcCategories()) do if c.key == key then return c end end end
local vend = ns.FindNpcs({ cat = cat("vendor") })
check(vend and #vend == 3 and vend[1].name == "Naher Händler" and vend[2].name == "Ferner Händler",
      "Händler: nächster zuerst, Allianz-Händler und Händler ohne Ort fehlen")
check(vend and vend[2].x == 30 and vend[2].y == 70, "Bei mehreren Fundorten zählt der nächste")
check(vend and vend[1].zone and vend[1].cost and vend[1].cost < vend[2].cost, "Treffer tragen Gebiet und Reisezeit")
local tr = ns.FindNpcs({ cat = cat("class") })
check(tr and #tr == 1 and tr[1].name == "Sorek" and tr[1].sub == "Kriegerlehrer", "Klassenlehrer über den englischen Grundtitel, nicht der nähere Magierlehrer")
local tl = ns.FindNpcs({ cat = cat("tailoring") })
check(tl and #tl == 2 and tl[1].name == "Schneiderin" and tl[1].cap == 150 and tl[2].cap == 225 and not tl[1].low,
      "Berufslehrer über den Titel, mit Lehrstufe (Journeyman 150, Expert 225)")
SKILLS = { { name = "Schneiderei", rank = 150, max = 150, line = 197 }, { name = "Angeln", rank = 150, max = 150, line = 356 } }
local r1, m1 = ns.PlayerSkill(197)
check(r1 == 150 and m1 == 150 and ns.PlayerSkill(171) == nil, "Eigene Berufe werden erkannt")
tl = ns.FindNpcs({ cat = cat("tailoring") })
check(tl and tl[1].name == "Schneidermeisterin" and tl[2].low, "Mit 150/150: der Lehrer, der weiterhilft, zuerst; der andere grau am Ende")
local fi = ns.FindNpcs({ cat = cat("fishing") })
check(fi and #fi == 2 and fi[1].name == "Ferner Händler" and fi[1].book == ns.L["sells %s"]:format("Angelbuch") and fi[2].low,
      "Angeln 150: zuerst der Händler mit dem Buch, der Lehrer bringt nichts Neues")
SKILLS = { { name = "Angeln", rank = 225, max = 225, line = 356 } }
fi = ns.FindNpcs({ cat = cat("fishing") })
check(fi and fi[1].name == "Sorek" and fi[1].book == ns.L["quest: %s"]:format("Angelquest"), "Angeln 225: zuerst der Questgeber")
SKILLS = {}
fi = ns.FindNpcs({ cat = cat("fishing") })
check(fi and #fi == 1 and fi[1].cap == 150 and not fi[1].low, "Ohne Angeln: nur der Lehrer, lehrt bis 150")
check(cat("pet") == nil and cat("repair") ~= nil, "Tierlehrer nur für Jäger")
local byName = ns.FindNpcs({ text = "kadr" })
check(byName and byName[1].name == "Kadrak", "Namenssuche mit Namensteil")
local none, why = ns.FindNpcs({ text = "x" })
check(none == nil and why == ns.L["Type at least two letters."], "Zu kurzer Suchtext wird abgelehnt")
check(ns.FindNpcs({ text = "gibtsnicht" }) == nil, "Kein Treffer: nil")
MAPINFO[1442] = MAPINFO[1442] or { name = "Mulgore" }
local inZone = ns.FindNpcs({ cat = cat("vendor"), place = " mulg " })
check(inZone and #inZone == 1 and inZone[1].name == "Mulgore-Händler", "Mit Gebiet: nur die Händler dort, auch wenn weit weg")
check(ns.FindNpcs({ cat = cat("vendor"), place = "nirgendwo" }) == nil, "Unbekanntes Gebiet: kein Treffer")
local byTitle = ns.FindNpcs({ text = "reagenz" })
check(byTitle and #byTitle == 2 and byTitle[2].name == "Mulgore-Händler", "Textsuche trifft auch den Titel")
local foe = ns.FindNpcs({ text = "allianz-h" })
check(foe and #foe == 1 and foe[1].unfit == ns.L["other faction"], "Textsuche findet die andere Fraktion und markiert sie")
local mage = ns.FindNpcs({ text = "magierlehr" })
check(mage and mage[1].unfit == ns.L["other class"] and not tr[1].unfit, "Lehrer einer anderen Klasse ist markiert, der eigene nicht")
ns.SearchOpt().otherFaction = true
check(#ns.FindNpcs({ cat = cat("vendor") }) == 4, "Option: Kategorien zeigen auch die andere Fraktion")
ns.SearchOpt().otherFaction = nil
ns.SearchOpt().allClasses = true
check(#ns.FindNpcs({ cat = cat("class") }) == 2, "Option: Klassenlehrer zeigt alle Klassen")
ns.SearchOpt().allClasses = nil
ns.HandleSlash("suche händler in mulgore")
check(joined(TT_List()):find("Mulgore-Händler|Roadbook search", 1, true), "/rb suche <Kategorie> in <Gebiet>")
-- Einstellungen: Trefferzahl, Papierkorb-Dauer, Grenzen
ns.SetOpt("searchHits", 4)
check(#ns.FindNpcs({ text = "nd" }) <= 4 and ns.Opt("searchHits") == 4, "Trefferzahl der Suche ist einstellbar")
ns.SetOpt("searchHits", 99)
check(ns.Opt("searchHits") == 20, "Einstellungen bleiben in ihren Grenzen")
ns.SetOpt("searchHits", 8)
check(ns.TrashSeconds() == 600, "Papierkorb: Standard 10 Minuten")
ns.SetOpt("trashMinutes", 30)
check(ns.TrashSeconds() == 1800, "Papierkorb-Dauer ist einstellbar")
ns.SetOpt("trashMinutes", 10)
check(ns.Opt("flySaving") == 30, "Flug-Ersparnis: Standard 30 s")
ns.GoToNpc(vend[1])
check(joined(TT_List()):find("Naher Händler|Roadbook search", 1, true), "Weg zeigen setzt einen TomTom-Punkt: " .. joined(TT_List()))
ns.GoToNpc(vend[2])
check(not joined(TT_List()):find("Naher Händler|Roadbook search", 1, true), "Der vorige Such-Punkt verschwindet")
ns.HandleSlash("suche händler")
check(joined(TT_List()):find("Naher Händler|Roadbook search", 1, true), "/rb suche <Kategorie> führt zum nächsten")
ns.HandleSlash("find sorek")
check(joined(TT_List()):find("Sorek|Roadbook search", 1, true), "/rb find <Name> führt zum NPC")
ns.DeactivatePlan(); RunTimers()
local own = ns.GetPlan("e:" .. (function() local id = ns.NextId("p"); ns.C.plans[id] = { id = id, title = "Suchziel", steps = {} }; return id end)())
ns.C.selectedPlan = own.id
ns.AddNpcStep(tr[1])
local got = ns.GetPlan(own.id)
check(#got.steps == 1 and got.steps[1].type == "goto" and got.steps[1].title == "Sorek" and got.steps[1].map == 1413 and got.steps[1].x == 50,
      "Zum Plan hinzufügen hängt den NPC als Schritt an")
check(#ERRORS_FORWARDED == errBase8, "Keine Lua-Fehler in der NPC-Suche: " .. joined(ERRORS_FORWARDED))

-- Versionshinweis
local realVersion, clock = ns.VERSION, 1000
local realGetTime = GetTime
GetTime = function() return clock end
ns.VERSION = "dev"
IN_GUILD = true
ns.BroadcastVersion()
check(#ADDON_SENT == 0, "Eine Kopie ohne saubere Versionsnummer sendet nichts")
ns.VERSION = "v1.2.0"
ns.BroadcastVersion(); ns.BroadcastVersion()
check(#ADDON_SENT == 1 and ADDON_SENT[1] == "RoadbookVer|v1.2.0|GUILD", "Version geht einmal an die Gilde (gedrosselt): " .. joined(ADDON_SENT))
ns.OnVersionMessage("RoadbookVer", "1.2.0", "GUILD")
ns.OnVersionMessage("RoadbookVer", "9.9.9-beta1", "GUILD")
ns.OnVersionMessage("Anderes", "9.9.9", "GUILD")
check(not ns.versionNotified and not ns.DB.newerVersion, "Gleiche Version, Beta und fremde Addons lösen nichts aus")
clock = clock + 60
ns.OnVersionMessage("RoadbookVer", "1.1.0", "GUILD"); RunTimers()
check(#ADDON_SENT == 2, "Auf eine ältere Version wird geantwortet")
ns.DB.noVersionCheck = true
ns.OnVersionMessage("RoadbookVer", "1.3.0", "GUILD")
check(not ns.versionNotified, "Abgeschaltet: kein Hinweis")
ns.DB.noVersionCheck = nil
ns.OnVersionMessage("RoadbookVer", "1.3.0", "GUILD")
check(ns.versionNotified == "1.3.0" and ns.DB.newerVersion == "1.3.0", "Neuere Version: Hinweis und gemerkt")
ns.versionNotified = nil
ns.VersionLogin()
check(ns.versionNotified == "1.3.0", "Beim nächsten Login erinnert Roadbook daran")
ns.versionNotified = nil
ns.DB.newerVersionAt = time() - 4 * 24 * 60 * 60
ns.VersionLogin()
check(not ns.versionNotified and ns.DB.newerVersion == nil, "Nach drei Tagen ohne neue Meldung ist Ruhe")
ns.VERSION, GetTime, IN_GUILD = realVersion, realGetTime, false
check(#ERRORS_FORWARDED == errBase8, "Keine Lua-Fehler im Versionshinweis: " .. joined(ERRORS_FORWARDED))

-- Orte: Briefkästen und andere Objekte aus QuestieDB
PLAYER = { map = 1413, x = 0.576, y = 0.213 }
local mb = ns.FindNpcs({ cat = cat("mailbox") })
check(mb and #mb == 1 and mb[1].name == "Briefkasten" and mb[1].obj and mb[1].x == 57.5 and not mb[1].unfit,
      "Briefkasten gefunden; der am Allianz-Gasthaus fehlt: " .. tostring(mb and #mb))
ns.SearchOpt().otherFaction = true
mb = ns.FindNpcs({ cat = cat("mailbox") })
check(mb and #mb == 2 and mb[2].unfit, "Mit der Option: auch der Briefkasten der anderen Fraktion, markiert")
ns.SearchOpt().otherFaction = nil
-- Vorwärmen: danach fragt ein Klick QuestieDB nicht mehr nach Fundorten
do
    ns.BuildNpcIndex(); RunTimers(); ns.WarmSpawns()
    for _ = 1, 50 do RunTimers() end
    local realGet, asked = ObjectDB.Get, 0
    ObjectDB.Get = function(id, key) if key == "spawns" then asked = asked + 1 end; return realGet(id, key) end
    local again = ns.FindNpcs({ cat = cat("mailbox") })
    ObjectDB.Get = realGet
    check(again and #again == 1 and asked == 0, "Vorgewärmt: Klick liest keine Fundorte mehr aus QuestieDB (" .. asked .. ")")
end
local fire = ns.FindNpcs({ cat = cat("fire") })
check(fire and #fire == 1 and fire[1].name == "Zwergenlagerfeuer", "Kochfeuer über das letzte Wort des englischen Namens")
check(not ns.FindNpcs({ cat = cat("anvil") }), "Kein Amboss in den Daten: nichts gefunden")
local vein = ns.FindNpcs({ text = "kupfer" })
check(vein and vein[1].name == "Kupferader" and vein[1].x == 56, "Textsuche findet Objekte am nächsten Fundort")
local onlyNpc = true
for _, r in ipairs(ns.FindNpcs({ cat = cat("vendor") }) or {}) do if r.obj then onlyNpc = false end end
check(onlyNpc, "NPC-Kategorien enthalten keine Objekte")
-- Hintergrundarbeit in Scheiben: mit Uhr viele Stücke je Bild, im Kampf Pause
do
    local now, steps, finished = 0, 0, false
    debugprofilestop = function() return now end
    ns.RunSliced(function() steps = steps + 1; now = now + 1; return steps >= 10 end, function() finished = true end)
    check(steps == 4 and not finished, "Zeitbudget: nach gut 3 ms ist für dieses Bild Schluss (" .. steps .. " Stücke)")
    COMBAT = true
    RunTimers()
    check(steps == 4, "Im Kampf pausiert die Hintergrundarbeit")
    COMBAT = false
    RunTimers()
    check(steps == 10 and finished, "Danach läuft sie zu Ende: " .. steps)
    debugprofilestop = nil
end
-- Daten aus OpenMap: Linien in Weltkoordinaten und das Flugnetz
do
    MAPOFF[1411], MAPOFF[1420] = { 8000, 1000, 1000, 7 }, { 1000, 1000, 1000, 8 }
    ns.SetLinks({ { 7, 8510, 1135, 8, 1610, 1590, "Horde", ns.L["Zeppelin %s – %s"], "Hier", "Dort", w = true } })
    ns.ClearRouteCache()
    local a, b = ns.WorldPos(1411, 60, 20, true), ns.WorldPos(1420, 50, 50, true)
    local _, _, how, via = ns.LegText(a, b)
    local t, how2, link = ns.LegCost(a, b)
    check(how2 == "schiff" and link and link.name == "Zeppelin Hier – Dort" and link.am and link.am.map == 1411
          and math.abs(link.am.x - 51) < 0.2, "Linie in Weltkoordinaten: Anleger auf der Gebietskarte: " .. tostring(link and link.am and link.am.x))
    ns.SetLinks(LINKS_FIXTURE); ns.ClearRouteCache()
    -- Flugnetz: 1 -> 2 -> 3, je 3000 Yards
    local n1, n2, n3 = { id = 1, c = 1, x = 0, y = 0 }, { id = 2, c = 1, x = 1000, y = 0 }, { id = 3, c = 1, x = 2000, y = 0 }
    local keep = ns.C.taxi
    ns.C.taxi = { [1] = true, [2] = true, [3] = true }
    ns.SetFlightPaths({ 1, 2, 3000, 2, 3, 3000 })
    ns.taxiVersion = ns.taxiVersion + 1
    check(ns.FlyTime(n1, n3) == 200, "Flugzeit über die echte Strecke (6000 Yards): " .. tostring(ns.FlyTime(n1, n3)))
    ns.C.taxi = { [1] = true, [3] = true }
    ns.taxiVersion = ns.taxiVersion + 1
    check(ns.FlyTime(n1, n3) == nil, "Zwischenhalt unbekannt: keine Verbindung, kein Flug")
    -- was die Flugkarte beim Flugmeister gezeigt hat, geht dem Netz vor
    local realAll, realId = C_TaxiMap.GetAllTaxiNodes, GetTaxiMapID
    GetTaxiMapID = function() return 9000 end
    C_TaxiMap.GetAllTaxiNodes = function() return { { nodeID = 1, state = 0 }, { nodeID = 3, state = 1 } } end
    ns.RecordTaxi()
    check(ns.C.taxiReach[1][3] and math.abs(ns.FlyTime(n1, n3) - 2000 / 28) < 0.01, "Flugkarte zeigt die Verbindung: Flug erlaubt")
    ns.C.taxi[2] = true
    C_TaxiMap.GetAllTaxiNodes = function() return { { nodeID = 1, state = 0 }, { nodeID = 2, state = 1 }, { nodeID = 3, state = 2 } } end
    ns.RecordTaxi()
    check(ns.FlyTime(n1, n3) == nil and ns.FlyTime(n1, n2) == 100, "Flugkarte zeigt „nicht erreichbar“: kein Flug, auch wenn das Netz ihn kennt")
    C_TaxiMap.GetAllTaxiNodes = function() return { { nodeID = 1, state = 0 }, { nodeID = 2, state = 1 }, { nodeID = 3, state = 2 }, { nodeID = 4, state = 1 } } end
    ns.RecordTaxi()
    check(next(ns.C.taxiBlock[1]) ~= nil and ns.C.taxi[4], "Neuer Flugpunkt gelernt: frische Liste für diesen Flugmeister")
    C_TaxiMap.GetAllTaxiNodes, GetTaxiMapID = realAll, realId
    ns.C.taxiReach, ns.C.taxiBlock = nil, nil
    ns.C.taxi = { [1] = true, [3] = true }
    ns.taxiVersion = ns.taxiVersion + 1
    check(math.abs(ns.FlyTime(n1, { id = 99, c = 1, x = 2800, y = 0 }) - 100) < 0.01, "Flugpunkt nicht im Netz: Luftlinie")
    ns.C.taxi = keep
    ns.SetFlightPaths({})
    ns.taxiVersion = ns.taxiVersion + 1
end
-- Berufe: nächste Stufe und was sie verlangt
do
    local hint = ns.RankHint(cat("tailoring"), 150, 150)
    check(hint == "Nächste Stufe (bis 225): ab Fertigkeit 125 und Stufe 20, kostet 50 Silber. Lehrer dafür stehen oben.", "Hinweis zur nächsten Stufe: " .. tostring(hint))
    hint = ns.RankHint(cat("tailoring"), 110, 150)
    check(hint and hint:find("Noch nicht möglich: deine Fertigkeit ist 110", 1, true), "Zu wenig Fertigkeit wird genannt: " .. tostring(hint))
    local realLevel = UnitLevel
    UnitLevel = function() return 18 end
    hint = ns.RankHint(cat("tailoring"), 150, 150)
    check(hint and hint:find("du bist Stufe 18", 1, true), "Zu niedrige Stufe wird genannt")
    hint = ns.RankHint(cat("mining"), 150, 150)
    check(hint and not hint:find("Stufe 20", 1, true) and not hint:find("Noch nicht", 1, true), "Sammelberufe brauchen keine Charakterstufe: " .. tostring(hint))
    UnitLevel = realLevel
    check(ns.RankHint(cat("tailoring"), 240, 225):find("bis 300", 1, true) and ns.RankHint(cat("tailoring"), 280, 300) == nil
          and ns.RankHint(cat("tailoring"), nil, nil) == nil, "Fachmann als nächste Stufe; bei 300 und ohne Beruf kein Hinweis")
    check(ns.RankHint(cat("fishing"), 150, 150):find("aus einem Buch", 1, true) and ns.RankHint(cat("cooking"), 225, 225):find("durch eine Quest", 1, true),
          "Kochen, Angeln, Erste Hilfe: Buch und Quest")
    -- Verzauberkunst: der „Expert Enchanter“ lehrt nur bis 150, der „Artisan Enchanter“ bis 225
    SKILLS = { { name = "Verzauberkunst", rank = 150, max = 150, line = 333 } }
    local en = ns.FindNpcs({ cat = cat("enchanting") })
    check(en and #en == 2 and en[1].name == "Verzauberin" and en[1].cap == 225 and en[2].cap == 150 and en[2].low,
          "Verzauberkunst um eine Stufe versetzt: " .. tostring(en and en[1].name) .. " " .. tostring(en and en[1].cap))
    SKILLS = {}
end
-- EP der Abgaben
ns.C.plans["p950"] = { id = "p950", title = "EP", mode = "route", created = 10, steps = {
    { type = "turnin", quest = 6401, map = 1413, x = 50, y = 50, title = "Abgabe" },
    { type = "goto", map = 1413, x = 51, y = 51, title = "Ort" } } }
QS.onQuest[6401], QS.complete[6401], QUEST_XP[6401] = true, true, 1250
local xpSum, xpShare = ns.PlanXP(ns.GetPlan("e:p950"))
check(ns.QuestXP(6401) == 1250 and ns.QuestXP(6541) == nil and xpSum == 1250 and xpShare == 25, "EP je Abgabe und Summe mit Anteil an der Stufe")
ns.ActivatePlan("e:p950"); RunTimers(); ns.UpdateTracker()
check(ns.tracker.xpLine:IsShown() and ns.tracker.xpLine:GetText() == "+1250 EP · noch 1250 EP im Plan (25%)",
      "Tracker zeigt die EP: " .. tostring(ns.tracker.xpLine:GetText()))
ns.ToggleSkip(ns.GetPlan("e:p950"), ns.GetPlan("e:p950").steps[1]); RunTimers(); ns.UpdateTracker()
check(not ns.tracker.xpLine:IsShown(), "Übersprungene Abgabe zählt nicht mit")
ns.ToggleSkip(ns.GetPlan("e:p950"), ns.GetPlan("e:p950").steps[1]); RunTimers()
ns.DeactivatePlan(); RunTimers()
ns.DB.noQuestXP = true
check(ns.QuestXP(6401) == nil and ns.PlanXP(ns.GetPlan("e:p950")) == nil, "EP-Anzeige abgeschaltet")
ns.DB.noQuestXP = nil
QS.onQuest[6401], QS.complete[6401], QUEST_XP[6401] = nil, nil, nil
ns.C.plans["p950"] = nil
-- Gelände: ein U aus Fundorten, die Luftlinie führt durch die Lücke in der Mitte
do
    local oldNpc, oldObj, oldOff = NpcDB, ObjectDB, MAPOFF[1413]
    MAPOFF[1413] = { 0, 0, 4000 }
    ns.ClearRouteCache()
    local pts = {}
    for v = 10, 90 do
        pts[#pts + 1] = { 10, v }; pts[#pts + 1] = { 90, v }; pts[#pts + 1] = { v, 10 }
    end
    NpcDB = { GetAllIds = function() return { 1 } end, Get = function() return { [17] = pts } end }
    ObjectDB = { GetAllIds = function() return { 1 } end, Get = function() return { [17] = { { 50, 95 }, { 500, 3 } } } end }
    local A, B = ns.WorldPos(1413, 10, 90, true), ns.WorldPos(1413, 90, 90, true)
    check(ns.GridLen(A, B) == nil, "Ohne Geländekarte: Luftlinie")
    ns.ResetGrid(); ns.BuildGrid(); RunTimers()
    local len = ns.GridLen(A, B)
    check(len and len > 2 * 3200 and len <= 2.5 * 3200 + 1, "Weg um das Hindernis herum statt Luftlinie (gedeckelt): " .. tostring(len))
    local near = ns.GridLen(ns.WorldPos(1413, 10, 90, true), ns.WorldPos(1413, 10, 50, true))
    check(near and near >= 1600 and near < 1700, "Freie Strecke: etwa die Luftlinie: " .. tostring(near))
    check(ns.GridLen(A, ns.WorldPos(1413, 50, 95, true)) == nil, "Keine Verbindung im Raster: Luftlinie wie bisher")
    check(ns.GridLen(A, ns.WorldPos(1413, 50, 50, true)) == nil, "Ziel außerhalb des Rasters: Luftlinie")
    local before = ns.LegCost(A, B)
    ns.DB.noTerrain = true
    check(ns.GridLen(A, B) == nil and ns.LegCost(A, B) < before, "Gelände abgeschaltet: wieder Luftlinie")
    ns.DB.noTerrain = nil
    NpcDB, ObjectDB, MAPOFF[1413] = oldNpc, oldObj, oldOff
    ns.ResetGrid(); ns.ClearRouteCache()
end
-- Gebietsübergänge: zwei Gebiete nebeneinander, ein Übergang weit oben
do
    local oldSeed, oldOff, oldInfo = ns.CROSSINGS, MAPOFF[1413], MAPINFO[1413]
    local errBase9g = #ERRORS_FORWARDED
    MAPOFF[1413], MAPOFF[9500] = { 0, 0, 4000 }, { 4000, 0, 4000 }
    MAPINFO[1413], MAPINFO[9500] = { name = "Brachland", mapType = 3 }, { name = "Nebenan", mapType = 3 }
    ns.CROSSINGS = { { 1413, 100, 10, 9500 }, { 9500, 0, 10, 1413 }, { 4711, 5, 5, 1413 } }
    ns.ClearRouteCache(); ns.ResetGates(); ns.DB.gates = nil
    check(ns.CrossingsText() == nil, "Ohne gesehene Übergänge gibt es nichts zu exportieren")
    local A, B = ns.WorldPos(1413, 90, 90, true), ns.WorldPos(9500, 10, 90, true)
    local len = ns.WalkLen(A, B)
    check(len and math.abs(len - 6450) < 10, "Gebietswechsel nur über den Übergang (800 Yards Luftlinie): " .. tostring(len))
    check(ns.WalkLen(A, ns.WorldPos(1413, 10, 90, true)) == nil, "Im selben Gebiet zählen Übergänge nicht")
    ns.DB.noTerrain = true
    check(ns.WalkLen(A, B) == nil, "Abgeschaltet: Luftlinie")
    ns.DB.noTerrain = nil
    -- Pfeil und Tracker führen erst zum Übergang
    ns.DeactivatePlan(); RunTimers()
    PLAYER = { map = 1413, x = 0.9, y = 0.9 }
    ns.C.plans["p960"] = { id = "p960", title = "Nebenan", mode = "route", created = 11, steps = {
        { type = "goto", map = 9500, x = 10, y = 90, title = "Hinterm Berg" } } }
    ns.ActivatePlan("e:p960"); RunTimers()
    check(ns.travel and ns.travel.hop.kind == "tor" and ns.travel.text == "Erst zum Übergang nach Nebenan"
          and TomTom.arrowTitle == "Übergang – Nebenan" and TomTom.arrow[1] == 1413,
          "Pfeil zeigt erst zum Übergang: " .. tostring(ns.travel and ns.travel.text) .. " / " .. tostring(TomTom.arrowTitle))
    ns.DB.noGateHop = true
    ns.travel = nil; ns.ResetWaypoints(true); RunTimers()
    check(ns.travel == nil and TomTom.arrow.title == "Hinterm Berg", "Abgeschaltet: Pfeil direkt zum Ziel")
    ns.DB.noGateHop = nil
    PLAYER = { map = 1413, x = 0.995, y = 0.105 }
    ns.travel = nil; ns.ResetWaypoints(true); RunTimers()
    check(ns.travel == nil and TomTom.arrow.title == "Hinterm Berg", "Am Übergang angekommen: Pfeil zum Ziel")
    PLAYER = { map = 9500, x = 0.01, y = 0.11 }
    ns.travel = nil; ns.ResetWaypoints(true); RunTimers()
    check(ns.travel == nil, "Im Zielgebiet: kein Übergang mehr")
    ns.wp.gatePassed = nil
    ns.DeactivatePlan(); RunTimers()
    ns.C.plans["p960"] = nil
    -- „Weg zeigen“ aus der Suche nutzt denselben Reiseweg
    PLAYER = { map = 1413, x = 0.9, y = 0.9 }
    local target = { id = 1, name = "Ferner NPC", map = 9500, x = 10, y = 90, zone = "Nebenan" }
    ns.GoToNpc(target)
    check(TomTom.arrow and TomTom.arrow.title == "Übergang – Nebenan" and TomTom.arrow.from == "Roadbook search",
          "Weg zeigen: Pfeil erst zum Übergang: " .. tostring(TomTom.arrow and TomTom.arrow.title))
    PLAYER = { map = 9500, x = 0.02, y = 0.5 }
    ns.CheckSearchGoal()
    check(TomTom.arrow and TomTom.arrow.title == "Ferner NPC", "Im Zielgebiet zeigt der Pfeil zum NPC: " .. tostring(TomTom.arrow and TomTom.arrow.title))
    PLAYER = { map = 9500, x = 0.1, y = 0.9 }
    ns.CheckSearchGoal(); ns.CheckSearchGoal()
    check(#ERRORS_FORWARDED == errBase9g, "Am Ziel endet die Führung ohne Fehler")
    ns.wp.gatePassed = nil
    -- Abgleich: Beobachtung nah am Startwert ersetzt ihn, weit weg kommt neu dazu
    ns.LearnCrossing(1413, 9500, { c = 1, x = 4000, y = 500 })
    local lastLog = ns.DB.log[#ns.DB.log].m
    check(#ns.DB.gates["1413>9500"] == 1 and lastLog:find("confirmed: 100 yd", 1, true), "Übergang bestätigt, Abstand im Protokoll: " .. lastLog)
    ns.LearnCrossing(1413, 9500, { c = 1, x = 4000, y = 560 })
    check(#ns.DB.gates["1413>9500"] == 1, "Dieselbe Stelle wird nicht doppelt gemerkt")
    local corrected = ns.WalkLen(A, B)
    check(corrected and corrected < len and corrected > 6000, "Gemessene Stelle ersetzt den Startwert: " .. tostring(corrected))
    ns.LearnCrossing(1413, 9500, { c = 1, x = 4000, y = 3000 })
    local short = ns.WalkLen(A, B)
    check(short and math.abs(short - 1442) < 10, "Neuer Übergang gelernt, Weg wird kürzer: " .. tostring(short))
    -- Erkennen beim Laufen
    ns.DB.gates = nil; ns.ResetGates()
    PLAYER = { map = 1413, x = 0.99, y = 0.5 }
    ns.CheckCrossing()
    GetUnitSpeed = function() return 0 end
    PLAYER = { map = 9500, x = 0.01, y = 0.5 }
    ns.CheckCrossing()
    check(not (ns.DB.gates and ns.DB.gates["1413>9500"]), "Getragen (Schiff, Tempo 0): kein Übergang gelernt")
    GetUnitSpeed = function() return 7 end
    PLAYER = { map = 1413, x = 0.99, y = 0.5 }
    ns.CheckCrossing()
    ns.DB.gates = nil
    PLAYER = { map = 9500, x = 0.01, y = 0.5 }
    ns.CheckCrossing()
    GetUnitSpeed = nil
    check(ns.DB.gates and ns.DB.gates["1413>9500"] and #ns.DB.gates["1413>9500"] == 1, "Gebietswechsel zu Fuß wird erkannt")
    local export = ns.CrossingsText()
    check(export and export:find("1 zone crossing(s) seen on foot", 1, true) and export:find(", 9500 }, -- ", 1, true)
          and export:find("yd from the list", 1, true), "Export der gesehenen Übergänge: " .. tostring(export))
    SlashCmdList["ROADBOOK"]("crossings")
    check(ns.copyFrame and ns.copyFrame:IsShown(), "/rb crossings öffnet das Kopierfenster")
    PLAYER = { map = 1413, x = 0.2, y = 0.5 }
    ns.CheckCrossing()
    check(ns.DB.gates["9500>1413"] == nil, "Ein Sprung (Teleport) ist kein Übergang")
    ON_TAXI = true
    PLAYER = { map = 1413, x = 0.99, y = 0.5 }; ns.CheckCrossing()
    PLAYER = { map = 9500, x = 0.01, y = 0.6 }; ns.CheckCrossing()
    ON_TAXI = false
    check(#ns.DB.gates["1413>9500"] == 1 and ns.DB.gates["9500>1413"] == nil, "Im Flug wird nichts gelernt")
    PLAYER = { map = 1413, x = 0.576, y = 0.213 }; ns.CheckCrossing()
    ns.CROSSINGS, MAPOFF[1413], MAPOFF[9500], MAPINFO[1413], MAPINFO[9500] = oldSeed, oldOff, nil, oldInfo, nil
    ns.DB.gates = nil
    ns.ResetGates(); ns.ClearRouteCache()
end
-- Teleports, Ruhestein, Portale der Gruppe, Beschwörung
local errBase9 = #ERRORS_FORWARDED
local function kind() return ns.travel and ns.travel.hop.kind or "-" end
local function reroute() ns.travel = nil; ns.ResetWaypoints(true); RunTimers() end
ns.DeactivatePlan(); RunTimers()
MAPOFF[1454] = { 30000, 30000, 100, 1 }   -- Orgrimmar, weit weg auf demselben Kontinent
ns.ClearRouteCache()
PLAYER = { map = 1413, x = 0.576, y = 0.213 }
ns.C.plans["p900"] = { id = "p900", title = "Fern", mode = "route", created = 9, steps = {
    { type = "goto", map = 1454, x = 60, y = 60, title = "In Orgrimmar" } } }
ns.ActivatePlan("e:p900"); RunTimers()
check(kind() ~= "sprung", "Ohne Teleport kein Sprung")
PLAYER_CLASS, SPELLS_KNOWN = "MAGE", { [3567] = true, [11417] = true }
reroute()
check(kind() ~= "sprung", "Teleport ohne Rune wird nicht empfohlen")
ITEMS[17031] = 2
reroute()
check(kind() == "sprung" and ns.travel.text:find("Teleportieren: Orgrimmar", 1, true) and TomTom.arrow.title == "In Orgrimmar",
      "Magier mit Rune: Teleport empfohlen, Pfeil bleibt auf dem Ziel: " .. tostring(ns.travel and ns.travel.text))
ns.SkipCurrentStep(); RunTimers()
check(ns.travel == nil and #ERRORS_FORWARDED == errBase9, "Sprung-Empfehlung lässt sich überspringen")
ns.ToggleTravelSkip(ns.GetPlan("e:p900").steps[1].key); RunTimers()
ns.DB.noTeleport = true
reroute()
check(kind() ~= "sprung", "Eigene Teleports abgeschaltet")
ns.DB.noTeleport = nil
PLAYER = { map = 1454, x = 0.4, y = 0.84 }
reroute()
check(ns.travel == nil, "Nach dem Teleport: kein zweiter")
-- Ruhestein: Ort beim Setzen merken
SPELLS_KNOWN, BIND = {}, "Orgrimmar"
ns.RecordHearth()
check(ns.C.hearth and ns.C.hearth.name == "Orgrimmar", "Ruhestein-Ort gemerkt")
PLAYER = { map = 1413, x = 0.576, y = 0.213 }
reroute()
check(kind() ~= "sprung", "Ohne Ruhestein in der Tasche kein Sprung")
ITEMS[6948] = 1
reroute()
check(kind() == "sprung" and ns.travel.sig == "sprung:hearth" and ns.travel.text:find("Ruhestein (Orgrimmar)", 1, true),
      "Ruhestein empfohlen: " .. tostring(ns.travel and ns.travel.text))
HEARTH_CD = 3600
reroute()
check(kind() ~= "sprung", "Ruhestein mit Abklingzeit wird nicht empfohlen")
HEARTH_CD, BIND = 0, "Woanders"
reroute()
check(kind() ~= "sprung", "Neu gebunden, Ort unbekannt: kein Sprung")
BIND = "Orgrimmar"
ns.DB.noHearth = true
reroute()
check(kind() ~= "sprung", "Ruhestein abgeschaltet")
-- Portale teilen
ADDON_SENT = {}
SPELLS_KNOWN = { [11417] = true, [11418] = true }
ns.SharePortals(true)
check(#ADDON_SENT == 0, "Ohne Gruppe wird nichts geteilt")
IN_GROUP = true
ns.SharePortals(); ns.SharePortals()
check(#ADDON_SENT == 1 and ADDON_SENT[1] == "RoadbookTp|11417,11418|PARTY", "Magier teilt seine Portale einmal: " .. joined(ADDON_SENT))
ns.SetPortalShare(false)
check(#ADDON_SENT == 2 and ADDON_SENT[2] == "RoadbookTp|-|PARTY", "Abschalten nimmt die Portale zurück")
ns.SharePortals(true)
check(#ADDON_SENT == 2, "Abgeschaltet: nichts mehr teilen")
ns.DB.noPortalShare = nil
-- Empfehlung: Magier in der Gruppe
PLAYER_CLASS, SPELLS_KNOWN = "WARRIOR", {}
UNITS.party1 = { name = "Magus", class = "MAGE", level = 45, map = 1413, x = 0.58, y = 0.22 }
reroute()
check(kind() == "-" or kind() == "flug" or kind() == "neu", "Magier ohne geteilte Portale: keine Empfehlung")
ns.OnPortalMessage("RoadbookTp", "11417,4711", "PARTY", "Magus-Testrealm")
ns.OnPortalMessage("RoadbookTp", "11418", "GUILD", "Magus-Testrealm")
check(ns.portals.Magus and ns.portals.Magus[11417] and not ns.portals.Magus[4711] and not ns.portals.Magus[11418],
      "Nur echte Portale aus der Gruppe werden angenommen")
reroute()
check(kind() == "portal" and ns.travel.hop.who == "Magus" and ns.travel.text:find("Frag Magus nach einem Portal", 1, true),
      "Portal-Empfehlung: " .. tostring(ns.travel and ns.travel.text))
ns.DB.noPortalHint = true
reroute()
check(kind() ~= "portal", "Portal-Empfehlung abgeschaltet")
ns.DB.noPortalHint = nil
ns.OnPortalMessage("RoadbookTp", "-", "PARTY", "Magus-Testrealm")
reroute()
check(ns.portals.Magus == nil and kind() ~= "portal", "Zurückgenommene Portale werden vergessen")
-- Empfehlung: Hexenmeister am Ziel
UNITS.party2 = { name = "Hexer", class = "WARLOCK", level = 30, map = 1454, x = 0.6, y = 0.62 }
reroute()
check(kind() == "ruf" and ns.travel.text:find("Frag Hexer nach einer Beschwörung", 1, true),
      "Beschwörung empfohlen: " .. tostring(ns.travel and ns.travel.text))
ns.DB.noSummonHint = true
reroute()
check(kind() ~= "ruf", "Beschwörungs-Empfehlung abgeschaltet")
ns.DB.noSummonHint = nil
UNITS.party2.level = 10
reroute()
check(kind() ~= "ruf", "Hexenmeister unter Stufe 20 kann nicht beschwören")
UNITS, IN_GROUP, ITEMS[17031], ITEMS[6948], ns.DB.noHearth = {}, false, nil, nil, nil
ns.C.hearth = nil
ns.DeactivatePlan(); RunTimers()
check(#ERRORS_FORWARDED == errBase9, "Keine Lua-Fehler bei Teleports und Portalen: " .. joined(ERRORS_FORWARDED))

print(("Tests: %d ok, %d Fehler, %d Knöpfe geklickt"):format(passes, fails, clicked))
