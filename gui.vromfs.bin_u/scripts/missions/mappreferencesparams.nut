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
    dislikeList = mapPreferences.get(curBattleTypeName, mapPreferences.DISLIKE),
    banList = mapPreferences.get(curBattleTypeName, mapPreferences.BAN)
  }
}

local function getMissionLoc(missionId, config, isBanByLevel, locNameKey = "locName")
{
  local missionLocName = ::loc("missions/" + missionId)
  local locNameValue = config?[locNameKey]
  if (locNameValue && locNameValue.len())
    missionLocName = isBanByLevel ? ::loc(::split(locNameValue, "; ")?[1]) :
                                    ::get_locId_name(config, locNameKey)

  if (isBanByLevel) missionLocName += ::loc("ui/parentheses/space", { text = ::loc("maps/preferences/all_missions") })

  return missionLocName
}

local function getMapStateByBanParams(isBanned, isDisliked)
{
  return isBanned ? "banned" : isDisliked ? "disliked" : ""
}

local function getMapsList(curEvent)
{
  if(!hasPreferences(curEvent))
    return []

  local isBanByLevel = curEvent.missionsBanMode == "level"
  local suffix = isBanByLevel ? "_tankmap*" : "_map*"
  local banData = getProfileBanData(curEvent)
  local dislikeList = banData.dislikeList
  local banList = banData.banList
  local list = []
  local missionToLevelTable = {}
  if (isBanByLevel)
    foreach(mission in curEvent.missions_info ?? {})
      if (mission.name && mission.level)
        missionToLevelTable[mission.name] <- mission.level

  foreach(name, val in curEvent?.mission_decl.missions_list ?? {})
  {
    local missionInfo = ::get_meta_mission_info_by_name(name)
    local level = missionToLevelTable?[name] ?? ::map_to_location(missionInfo?.level ?? "")
    local image = ::map_to_location(missionInfo?.level ?? "") + suffix
    local mission = isBanByLevel ? level : name
    if(isBanByLevel)
      if (u.search(list, @(inst) inst.level == level) != null)
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
    banCount = {
      maxCounter = hasPremium
        ? curEvent.maxBannedMissions
        : 0,
      maxCounterWithPremium = curEvent.maxBannedMissions
      curCounter = banData.banList.len()
    },
    dislikeCount = {
      maxCounter = hasPremium
        ? curEvent.maxPremDislikedMissions
        : curEvent.maxDislikedMissions,
      maxCounterWithPremium = curEvent.maxPremDislikedMissions
      curCounter = banData.dislikeList.len()
    }
  }
}

local function resetProfilePreferences(curEvent, isBan)
{
  local curBattleTypeName = getCurBattleTypeName(curEvent)
  local params = getProfileBanData(curEvent)
  local list = isBan ? params.banList : params.dislikeList
  foreach(item in list)
    mapPreferences.remove(curBattleTypeName, isBan
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
}