enum WW_OPERATION_STATUSES
{
  UNKNOWN = -1
  ES_ACTIVE = 1
  ES_PAUSED = 7
}

class WwOperation
{
  id = -1
  data = null
  status = WW_OPERATION_STATUSES.UNKNOWN

  isArmyGroupsDataGathered = false
  _myClanGroup = null
  _assignCountry = null

  constructor(_data)
  {
    data = _data
    id = ::getTblValue("_id", data, -1)
    status = ::getTblValue("st", data, WW_OPERATION_STATUSES.UNKNOWN)
  }

  function isValid()
  {
    return id >= 0
  }

  function isAvailableToJoin()
  {
    return status == WW_OPERATION_STATUSES.ES_ACTIVE ||
           status == WW_OPERATION_STATUSES.ES_PAUSED
  }

  function isEqual(operation)
  {
    return operation && operation.id == id
  }

  function getMapId()
  {
    return ::getTblValue("map", data, "unknown_map")
  }

  function getMap()
  {
    return ::g_ww_global_status.getMapByName(getMapId())
  }

  function getNameText(full = true)
  {
    return getNameTextByIdAndMapName(id, full ? getMapText() : null)
  }

  static function getNameTextByIdAndMapName(operationId, mapName = null)
  {
    local res = ::loc("ui/number_sign") + operationId
    if (mapName)
      res = mapName + " " + res
    return res
  }

  function getMapText()
  {
    local map = getMap()
    return map ? map.getNameText() : ""
  }

  function getDescription(showClanParticipateStatus = true)
  {
    local txtList = []
    if (showClanParticipateStatus && isMyClanParticipate())
      txtList.append(::colorize("userlogColoredText", ::loc("worldwar/yourClanInThisOperation")))
    local map = getMap()
    if (map)
      txtList.append(map.getDescription(false))
    return ::implode(txtList, "\n")
  }

  function getStartDateTxt()
  {
    local createTime = ::getTblValue("ct", data, 0)
    return ::build_date_str(::get_time_from_t(createTime))
  }

  function getGeoCoordsText()
  {
    local map = getMap()
    return map ? map.getGeoCoordsText() : ""
  }

  function getCantJoinReasonDataBySide(side)
  {
    local res = {
      canJoin = false
      country = ""
      reasonText = ""
    }

    local countryes = ::getTblValue(side, getCountriesByTeams(), [])
    local assignCountry = getMyAssignCountry()
    if (assignCountry)
    {
      res.country = assignCountry
      if (!::isInArray(assignCountry, countryes))
        res.reasonText = ::loc("worldWar/cantPlayByThisSide")
      else
        res.canJoin = true

      return res
    }

    local summaryCantJoinReasonText = ""
    foreach(idx, country in countryes)
    {
      local reasonData = getCantJoinReasonData(country)
      if (reasonData.canJoin)
      {
        res.canJoin = true
        res.country = country
        return res
      }

      if (!::u.isEmpty(summaryCantJoinReasonText))
        summaryCantJoinReasonText += "\n"

      summaryCantJoinReasonText += ::loc(country) + ::loc("ui/colon") + reasonData.reasonText
    }

    if (summaryCantJoinReasonText.len() > 0)
      res.reasonText = summaryCantJoinReasonText
    else
      res.canJoin = true

    return res
  }

  function getCantJoinReasonData(country)
  {
    local res = {
      canJoin = false
      reasonText = ""
    }

    local assignCountry = getMyAssignCountry()
    if (isMyClanParticipate())
    {
      if (!canJoinByMyClan())
        res.reasonText = ::loc("worldWar/cantJoinByAnotherSideClan")
    }
    else if (assignCountry && assignCountry != country)
      res.reasonText = ::loc("worldWar/cantPlayByThisSide")
    else if (!canJoinByCountry(country))
      res.reasonText = ::loc("worldWar/chooseAvailableCountry")

    if (!res.reasonText.len())
      res.canJoin = true

    return res
  }

  function join(country, onErrorCb = null, isSilence = false)
  {
    local cantJoinReason = getCantJoinReasonData(country)
    if (!cantJoinReason.canJoin)
    {
      if (!isSilence)
        ::showInfoMsgBox(cantJoinReason.reasonText)
      return false
    }

    ::g_world_war.stopWar()
    return _join(country, onErrorCb, isSilence)
  }

  function _join(country, onErrorCb, isSilence)
  {
    local taskId = ::ww_start_war(id)
    local cb = (@(country, id, isSilence) function() { ::g_world_war.onJoinOperationSuccess(id, country, isSilence) })(country, id, isSilence)
    local errorCb = (@(onErrorCb) function(res) {
                      ::g_world_war.stopWar()
                      if (onErrorCb)
                        onErrorCb(res)
                    })(onErrorCb)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, cb, errorCb)
    return taskId >= 0
  }

  function resetCache()
  {
    isArmyGroupsDataGathered = false
    _myClanGroup = null
    _assignCountry = null
  }

  function gatherArmyGroupsDataOnce()
  {
    if (isArmyGroupsDataGathered)
      return
    isArmyGroupsDataGathered = true

    local myClanId = ::clan_get_my_clan_id().tointeger()
    foreach(ag in getArmyGroups())
    {
      if (::getTblValue("clanId", ag) == myClanId)
        _myClanGroup = ag
      if (isAssignedToGroup(ag))
        _assignCountry = getArmyGroupCountry(ag)
    }
  }

  function getArmyGroupsBySide(side)
  {
    local countriesByTeams = getCountriesByTeams()
    local sideCountries = ::getTblValue(side, countriesByTeams)

    return ::u.filter(
      getArmyGroups(),
      (@(sideCountries) function(ag) {
        return ::isInArray(::getTblValue("cntr", ag, ""), sideCountries)
      })(sideCountries)
    )
  }

  function getMyClanGroup()
  {
    gatherArmyGroupsDataOnce()
    return _myClanGroup
  }

  function getMyAssignCountry()
  {
    gatherArmyGroupsDataOnce()
    return _assignCountry
  }

  function getMyClanCountry()
  {
    local myClanGroup = getMyClanGroup()
    return myClanGroup && getArmyGroupCountry(myClanGroup)
  }

  function isMyClanSide(side)
  {
    if (!isMyClanParticipate())
      return false

    local country = getMyClanCountry()
    local countries = ::getTblValue(side, getCountriesByTeams(), [])
    return ::isInArray(country, countries)
  }

  function isMyClanParticipate()
  {
    return isAvailableToJoin() && getMyClanGroup() != null
  }

  function canJoinByMyClan()
  {
    //can join after change clan only if played by the same country in this operation
    local assignCountry = getMyAssignCountry()
    return isMyClanParticipate() && (assignCountry == null || assignCountry == getMyClanCountry())
  }

  function getArmyGroups()
  {
    return ::getTblValue("armyGroups", data, [])
  }

  function getArmyGroupCountry(armyGroup)
  {
    return ::getTblValue("cntr", armyGroup)
  }

  function isAssignedToGroup(armyGroup)
  {
    return ::getTblValue("rel", armyGroup, ::EAOUR_NONE) != ::EAOUR_NONE
  }

  /*
  return {
    [side] = ["country_germany"]
  }
  */
  function getCountriesByTeams()
  {
    local res = {}
    local map = getMap()
    if (!map)
      return res

    local countryToSide = map.getCountryToSideTbl()
    foreach(ag in getArmyGroups())
    {
      local country = getArmyGroupCountry(ag)
      local side = ::getTblValue(country, countryToSide, ::SIDE_NONE)
      if (side == ::SIDE_NONE)
        continue

      if (!(side in res))
        res[side] <- []
      ::append_once(country, res[side])
    }
    return res
  }

  function canJoinByCountry(country)
  {
    foreach(ag in getArmyGroups())
      if (getArmyGroupCountry(ag) == country)
        return true
    return false
  }

  function isLastPlayed()
  {
    return id == ::g_world_war.lastPlayedOperationId
  }

  function getPriority()
  {
    local res = 0
    local availableByMyClan = canJoinByMyClan()
    if (availableByMyClan)
      res = res | WW_MAP_PRIORITY.CAN_JOIN_BY_MY_CLAN
    if (getMyAssignCountry() && (availableByMyClan || !getMyClanGroup()))
      res = res | WW_MAP_PRIORITY.CAN_JOIN_BY_ARMY_RELATIONS
    if (isLastPlayed())
      res = res | WW_MAP_PRIORITY.LAST_PLAYED
    return res
  }
}