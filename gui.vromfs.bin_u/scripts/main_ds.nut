::dagor.includeOnce("std/math.nut")
::dagor.includeOnce("scripts/ranks_common.nut")
::dagor.includeOnce("scripts/custom_common.nut")

foreach (script in [
  "shared.nut",
  "economics/warpoints.nut",
  "economics/experience.nut",
  "economics/shipsAwards.nut",
  "economics/battleTrophy.nut",
  "economics/pveAwards.nut",
  "economics/battleRoyaleAwards.nut",
  "economics/tutorialAwards.nut",
  "spawnRules/battleRoyale.nut",
  "spawnRules/shipsRandomBattle.nut",
  "spawnRules/teamSpawnScore.nut",
  "spawnRules/casualtiesHelper.nut",
  "spawnRules/randomSpawnUnit.nut",
  "spawnRules/unitsDeck.nut",
  "spawnRules/enduringConfrontation.nut",
  "spawnRules/sharedPool.nut",
  "spawnRules/wwSharedPool.nut"
]) {
  ::dagor.includeOnce("scripts/dedicatedScripts/"+script)
}
dagor.debug("DEDICATED scripts loaded")