local mapPreferences = ::require_native("mapPreferences")

local function hasPreferences(curEvent)
{
  return (curEvent?.missionsBanMode ?? "none") != "none"
}

local function sortByLevel(list)
{
  list.sort(@(a,b) a.image <=> b.image)
  foreach(idx, map in list)
    map.mapId = idx
  return list
}

local function getCurBattleTypeName(curEvent)
{
  return (hasPreferences(curEvent))
    ? curEvent.statistic_group + "_" + curEvent.difficulty : ""
}

local function getProfileBanData(curEvent)
{
  local curBattleTypeName = getCurBattleTypeName(curEvent)
  return {
    disliked = mapPreferences.get(curBattleTypeName, mapPreferences.DISLIKE),
    banned = mapPreferences.get(curBattleTypeName, mapPreferences.BAN)
  }
}

local function getMissionLoc(missionId, config, isBanByLevel, locNameKey = "locName")
{
  local missionLocName = ::loc("missions/" + missionId)
  local locNameValue = config?[locNameKey]
  if (locNameValue && locNameValue.len())
    missionLocName = isBanByLevel ? ::loc(::split(locNameValue, "; ")?[1] ?? "") :
                                    ::get_locId_name(config, locNameKey)

  if (isBanByLevel)
    missionLocName += ::loc("ui/parentheses/space", { text = ::loc("maps/preferences/all_missions") })

  return missionLocName
}

local function getMapStateByBanParams(isBanned, isDisliked)
{
  return isBanned ? "banned" : isDisliked ? "disliked" : ""
}

local function getInactiveMaps(curEvent, mapsList)
{
  local res = {}
  local banData = getProfileBanData(curEvent)
  foreach(name, list in banData)
  {
    res[name] <- []
      foreach(mission in list)
        if(!::u.search(mapsList, @(map) map.mission == mission))
          res[name].append(mission)
  }

  return res
}

local function getMapsList(curEvent)
{
  if(!hasPreferences(curEvent))
    return []

  local isBanByLevel = curEvent.missionsBanMode == "level"
  local banData = getProfileBanData(curEvent)
  local dislikeList = banData.disliked
  local banList = banData.banned
  local list = []
  local hasTankOrShip =  (::events.getEventUnitTypesMask(curEvent)
    & (::g_unit_type.TANK.bit | ::g_unit_type.SHIP.bit)) != 0
  local missionToLevelTable = {}
  if (isBanByLevel)
    foreach(mission in curEvent?.missions_info ?? {})
      if (mission?.name && mission?.level)
        missionToLevelTable[mission.name] <- mission.level

  local missionList = {}
  foreach(gm in ::g_matching_game_modes.getGameModesByEconomicName(::events.getEventEconomicName(curEvent)))
    missionList.__update(gm?.mission_decl.missions_list ?? {})

  local assertMisNames = []
  foreach(name, val in missionList)
  {
    local missionInfo = ::get_meta_mission_info_by_name(name)
    if(!missionInfo?.level || missionInfo.level == "")
    {
      assertMisNames.append(name)
      continue
    }
    local level = missionToLevelTable?[name] ?? ::map_to_location(missionInfo.level)
    local image = ::get_level_texture(missionInfo.level, hasTankOrShip).slice(0,-1) + "_thumb*"
    local mission = isBanByLevel ? level : name
    if(isBanByLevel)
      if (::u.search(list, @(inst) inst.level == level) != null)
        continue

    local isBanned = banList.find(mission) != null
    local isDisliked = dislikeList.find(mission) != null
    list.append({
      mapId = list.len()
      title = getMissionLoc(name, missionInfo, isBanByLevel)
      level = level
      image = image
      mission = mission
      disliked = isDisliked
      banned = isBanned
      state = getMapStateByBanParams(isBanned, isDisliked)
    })
  }

  if(assertMisNames.len() > 0)
  {
    local invalidMissions = assertMisNames.reduce(@(a, b) a + ", " + b) // warning disable: -declared-never-used
    ::script_net_assert_once("MapPreferencesParams:", "Missions have no level")
  }

  if(!isBanByLevel)
    list = sortByLevel(list)

  return list
}

local function getParams(curEvent)
{
  local params = {bannedMissions = [], dislikedMissions = []}
  if(hasPreferences(curEvent))
    foreach(inst in getMapsList(curEvent))
    {
      if(inst.banned)
       params.bannedMissions.append(inst.mission)
      if(inst.disliked)
        params.dislikedMissions.append(inst.mission)
    }

  return params
}

local function getCounters(curEvent)
{
  if(!hasPreferences(curEvent))
    return {}

  local banData = getProfileBanData(curEvent)
  local hasPremium  = ::havePremium()
  return {
    banned = {
      maxCounter = hasPremium
        ? curEvent.maxBannedMissions
        : 0,
      maxCounterWithPremium = curEvent.maxBannedMissions
      curCounter = banData.banned.len()
    },
    disliked = {
      maxCounter = hasPremium
        ? curEvent.maxPremDislikedMissions
        : curEvent.maxDislikedMissions,
      maxCounterWithPremium = curEvent.maxPremDislikedMissions
      curCounter = banData.disliked.len()
    }
  }
}

local function resetProfilePreferences(curEvent, pref)
{
  local curBattleTypeName = getCurBattleTypeName(curEvent)
  local params = getProfileBanData(curEvent)
  foreach(item in params[pref])
    mapPreferences.remove(curBattleTypeName, pref == "banned"
      ? mapPreferences.BAN : mapPreferences.DISLIKE, item)
}

local function getPrefTitle(curEvent)
{
  return ! hasPreferences(curEvent) ? ""
    : curEvent.missionsBanMode == "level" ? ::loc("mainmenu/mapPreferences")
    : ::loc("mainmenu/missionPreferences")
}

return {
  getParams = getParams
  getMapsList = getMapsList
  getCounters = getCounters
  getCurBattleTypeName = getCurBattleTypeName
  hasPreferences = hasPreferences
  resetProfilePreferences = resetProfilePreferences
  getPrefTitle = getPrefTitle
  getMapStateByBanParams = getMapStateByBanParams
  getInactiveMaps = getInactiveMaps
}