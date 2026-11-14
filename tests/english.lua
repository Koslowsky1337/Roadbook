-- Englischer Client: Grundtexte, Befehle und Übersetzungs-Rückfall
-- Aufruf: LOCALE=enUS python tests/run.py . tests/english.lua
local ns = RB_NS
local fails, passes = 0, 0
local function check(cond, msg)
    if cond then passes = passes + 1 else fails = fails + 1; print("FEHLER: " .. msg) end
end
local fire = function(event, ...) ns.eventFrame.scripts.OnEvent(ns.eventFrame, event, ...) end
local function chat() return table.concat(LOG, " ; ") end
for _, q in ipairs({ 894, 6541, 872 }) do QS.onQuest[q] = true; QS.complete[q] = true end
QS.log = { { id = 894, title = "Samophlange" }, { id = 6541, title = "Report to Kadrak" }, { id = 872, title = "The Disruption Ends" } }
fire("ADDON_LOADED", "Roadbook")
fire("PLAYER_LOGIN")
RunTimers()
check(ns.LOCALE == "enUS" and ns.L["Plans"] == "Plans", "englische Texte sind die Schlüssel")
check(chat():find("Welcome! |cffffffff/rb|r opens Roadbook", 1, true), "Begrüßung beim ersten Start: " .. chat())
check(chat():find("New post", 1, true), "Post-Meldung englisch")
LOG = {}
ns.HandleSlash("help")
check(chat():find("/rb turnin|r – build and load a turn-in round", 1, true) and not chat():find("Abgabe", 1, true), "Hilfe englisch")
LOG = {}
ns.HandleSlash("turnin"); RunTimers()
check(chat():find("Turn-in round created: 3 quests", 1, true), "Abgaberunde englisch: " .. chat())
local plan = ns.ActivePlan()
check(plan and plan.title == "Turn-in round (automatic)", "Titel der Abgaberunde englisch")
check(ns.STEP_LABEL.turnin == "Turn in" and ns.BUILTIN_NOTES[1].title == "Quick guide", "Schrittarten und Anleitung englisch")
check(not ns.BUILTIN_NOTES[1].body:find("[äöüß]"), "Anleitung ohne deutsche Reste")
LOG = {}
ns.HandleSlash("skip")
check(chat():find("Skipped: ", 1, true), "/rb skip")
ns.HandleSlash("weiter"); ns.HandleSlash("aus")
check(ns.C.activePlan == false, "deutsche Befehlswörter gehen auch im englischen Client")
check(ns.RouteText(nil) == "No plan loaded or selected.", "Wegbeschreibung ohne Plan")
print(("English: %d ok, %d Fehler"):format(passes, fails))
