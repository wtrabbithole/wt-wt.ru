local time = require("scripts/time.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")
local { getMapByName, getMapFromShortStatusByName } = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

enum WW_OPERATION_STATUSES
{
  UNKNOWN = -1
  ES_ACTIVE = 1
  ES_PAUSED = 7
}

enum WW_OPERATION_PRIORITY //bit enum
{
  NONE                       = 0
  CAN_JOIN_BY_ARMY_RELATIONS = 0x0001
  CAN_JOIN_BY_MY_CLAN        = 0x0002

  MAX                        = 0xFFFF
}

class WwOperation
{
  id = -1
  data = null
  status = WW_OPERATION_STATUSES.UNKNOWN

  isArmyGroupsDataGathered = false
  _myClanGroup = null
  _assignCountry = null

  isFromShortStatus = false
  isFinished = false //this parametr updated from local operation when return main menu of WWar

  constructor(_data, _isFromShortStatus = false)
  {
    data = _data
    isFromShortStatus = _isFromShortStatus
    id = ::getTblValue("_id", data, -1)
    status = ::getTblValue("st", data, WW_OPERATION_STATUSES.UNKNOWN)
  }

  function isValid()
  {
    return id >= 0
  }

  function isAvailableToJoin()
  {
    return !isFinished &&
      ( status == WW_OPERATION_STATUSES.ES_ACTIVE
        || status == WW_OPERATION_STATUSES.ES_PAUSED )
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
    if (isFromShortStatus)
      return getMapFromShortStatusByName(getMapId())
    else
      return getMapByName(getMapId())
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
    return ::g_string.implode(txtList, "\n")
  }

  function getStartDateTxt()
  {
    return time.buildDateStr(data?.ct ?? 0)
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

    if (::g_squad_manager.isSquadMember())
    {
      local queue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
      if (queue && queue.getQueueWwOperationId() != id)
        return res.__update({
          reasonText = ::loc("worldWar/cantJoinBecauseOfQueue", {operationInfo = getNameText()})
        })
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
    if (isMyClanParticipate() && !canJoinByMyClan())
      res.reasonText = ::loc("worldWar/cantJoinByAnotherSideClan")
    else if (assignCountry && assignCountry != country)
      res.reasonText = ::loc("worldWar/cantPlayByThisSide")
    else if (!canJoinByCountry(country))
      res.reasonText = ::loc("worldWar/chooseAvailableCountry")

    if (!res.reasonText.len())
      res.canJoin = true

    return res
  }

  function join(country, onErrorCb = null, isSilence = false, onSuccess = null)
  {
    local cantJoinReason = getCantJoinReasonData(country)
    if (!cantJoinReason.canJoin)
    {
      if (!isSilence)
        ::showInfoMsgBox(cantJoinReason.reasonText)
      return false
    }

    ::g_world_war.stopWar()
    return _join(country, onErrorCb, isSilence, onSuccess)
  }

  function _join(country, onErrorCb, isSilence, onSuccess)
  {
    local taskId = ::ww_start_war(id)
    local cb = ::Callback(function() {
        ::g_world_war.onJoinOperationSuccess(id, country, isSilence, onSuccess)
      }, this)
    local errorCb = function(res) {
        ::g_world_war.stopWar()
        if (onErrorCb)
          onErrorCb(res)
      }
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
      if (ag?.clanId != myClanId)
        continue

      _myClanGroup = ag
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
      ::u.appendOnce(country, res[side])
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
      res = res | WW_OPERATION_PRIORITY.CAN_JOIN_BY_MY_CLAN
    if (getMyAssignCountry() && (availableByMyClan || !getMyClanGroup()))
      res = res | WW_OPERATION_PRIORITY.CAN_JOIN_BY_ARMY_RELATIONS

    return res
  }

  setFinishedStatus = @(isFinish) isFinished = isFinish
}
