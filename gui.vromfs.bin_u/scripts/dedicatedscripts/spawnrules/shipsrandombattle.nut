// ------------- shipsRandomBattle BEGIN -------------------

function shipsRandomBattle_onSessionStart()
{
  randomSpawnUnit_onSessionStart()
}

function shipsRandomBattle_onPlayerConnected(userId, team, country)
{
  numSpawnsByUnitType_onPlayerConnected(userId, team, country)
  randomSpawnUnit_onPlayerConnected(userId, team, country)
}

function shipsRandomBattle_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  local randomUnitCanSpawn = randomSpawnUnit_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
  local unitTypeCanSpawn = numSpawnsByUnitType_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
  return (randomUnitCanSpawn && unitTypeCanSpawn)
}

function shipsRandomBattle_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
  numSpawnsByUnitType_onPlayerSpawn(userId, team, country, unit, weapon, cost)
}

function shipsRandomBattle_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
{
  randomSpawnUnit_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
}

// ------------- shipsRandomBattle END -------------------
dagor.debug("shipsRandomBattle loaded successfully")