-- Alle Fenster durch den Layout-Prüfer (mit dem Layout-Rechner aus layoutsim.lua):
-- findet abgeschnittene, überstehende und überlappende Texte in jeder Sprache.
-- Aufruf: python tests/run.py . tests/screens.lua      (LOCALE=enUS für Englisch)
local ns = RB_NS
local fire = function(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end

for _, q in ipairs({ 894, 6541, 97003, 872, 6401 }) do QS.onQuest[q] = true; QS.complete[q] = true end
QS.log = { { id = 894, title = "Samophlange" }, { id = 6541, title = "Meldung bei Kadrak" }, { id = 872, title = "Die Brandschatzer" } }
fire("ADDON_LOADED", "Roadbook")
fire("PLAYER_LOGIN")
RunTimers()

local found, seen, screens = {}, {}, 0
local function scan(where, roots)
    screens = screens + 1
    for _, m in ipairs(ns.LayoutCheck(roots)) do
        if not seen[m] then
            seen[m] = true
            found[#found + 1] = where .. ": " .. m
        end
    end
end

-- Reiter Pläne: jeder Plan, geladen, im Bearbeiten-Modus, leer
ns.ShowFrame("plans")
scan("Pläne")
for _, plan in ipairs(ns.GetPlans()) do
    ns.C.selectedPlan = plan.id
    ns.UpdateUI()
    scan("Plan " .. plan.id)
end
local first = ns.GetPlans()[1]
ns.ActivatePlan(first.id); RunTimers()
scan("Plan geladen")
ns.planEditId = first.id
ns.UpdateUI()
scan("Plan bearbeiten")
ns.planEditId = nil
ns.CreateTurnInPlan(); RunTimers()
ns.SkipCurrentStep(); RunTimers()
scan("Abgaberunde mit Übersprungenem")

-- Tracker: eingeklappt, ausgeklappt mit fehlenden Abgaben, ohne Plan
ns.ActivatePlan(first.id); RunTimers()
scan("Tracker", { ns.tracker })
ns.DB.tracker.expanded = true
ns.UpdateUI()
scan("Tracker ausgeklappt", { ns.tracker })
ns.DeactivatePlan(); RunTimers()
scan("Tracker ohne Plan", { ns.tracker })

-- Reiter Notizen: jede Notiz (Anleitung, Post, eigene, für alle Charaktere)
local own = ns.CreateNote("Eigene Notiz mit einem ziemlich langen Titel zum Testen")
ns.SetNoteAccount(ns.CreateNote("Für alle"), true)
ns.ShowFrame("notes")
for _, sec in ipairs(ns.GetNoteSections()) do
    for _, n in ipairs(sec.items) do
        ns.SelectNote(n.id)
        scan("Notiz " .. n.id)
    end
end

-- Reiter Optionen: Standard, Umweg aus, Umweg am oberen Ende
ns.ShowFrame("options")
scan("Optionen")
ns.SetPickupMax(0); ns.UpdateUI()
scan("Optionen, Umweg aus")
ns.SetPickupMax(600); ns.UpdateUI()
scan("Optionen, Umweg 10 Min.")
ns.SetPickupMax(120)

-- Reiter Makros: jedes Makro (neu, geändert, aktuell), im Kampf
ns.ShowFrame("macros")
scan("Makros")
for _, row in ipairs(ALLFRAMES) do
    if row.macro and row.scripts.OnClick then
        row.scripts.OnClick(row)
        scan("Makro " .. row.macro.name)
    end
end
COMBAT = true
ns.UpdateUI()
scan("Makros im Kampf")
COMBAT = false

-- Einzelfenster
ns.ShowCopy("Titel des Kopierfensters", "Text")
scan("Kopieren", { ns.copyFrame })
ns.DeleteNote(own.id)
ns.ShowTrash()
scan("Papierkorb", { ns.trashFrame })
ns.ShowImport()
scan("Import", { ns.importFrame })

for _, f in ipairs(found) do print("FEHLER: " .. f) end
print(("Layout (%s): %d ok, %d Fehler"):format(GetLocale(), screens - math.min(screens, #found), #found))
