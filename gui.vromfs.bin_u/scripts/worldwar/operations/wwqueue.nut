class WwQueue
{
  map = null
  data = null

  myClanCountries = null
  myClanQueueTime = -1
  cachedClanId = -1 //need to update clan data if clan changed

  constructor(_map, _data = null)
  {
    map = _map
    data = _data
  }

  function getArmyGroupsByCountry(country, defValue = null)
  {
    return ::getTblValue(country, data, defValue)
  }

  function isMyClanJoined(country = null)
  {
    local countries = getMyClanCountries()
    return country ? ::isInArray(country, countries) : countries.len() != 0
  }

  function getMyClanCountries()
  {
    gatherMyClanDataOnce()
    return myClanCountries || []
  }

  function getMyClanQueueJoinTime()
  {
    gatherMyClanDataOnce()
    return ::max(0, myClanQueueTime)
  }

  function resetCache()
  {
    myClanCountries = null
    myClanQueueTime = -1
    cachedClanId = -1
  }

  function gatherMyClanDataOnce()
  {
    local myClanId = ::clan_get_my_clan_id().tointeger()
    if (myClanId == cachedClanId)
      return

    cachedClanId = myClanId
    if (!data)
      return

    myClanCountries = []
    foreach(country in ::shopCountriesList)
    {
      local groups = getArmyGroupsByCountry(country)
      local myGroup = groups && ::u.search(groups, (@(myClanId) function(ag) { return ::getTblValue("clanId", ag) == myClanId })(myClanId) )
      if (myGroup)
      {
        myClanCountries.append(country)
        myClanQueueTime = ::max(myClanQueueTime, ::getTblValue("at", myGroup, -1))
      }
    }

    if (!myClanCountries.len())
    {
      myClanCountries = null
      myClanQueueTime = -1
    }
  }

  function getArmyGroupsAmountByCountries()
  {
    local res = {}
    foreach(country in ::shopCountriesList)
    {
      local groups = getArmyGroupsByCountry(country)
      res[country] <- groups ? groups.len() : 0
    }
    return res
  }

  function getArmyGroupsAmountTotal()
  {
    local res = 0
    foreach(country in ::shopCountriesList)
    {
      local groups = getArmyGroupsByCountry(country)
      if (groups)
        res += groups.len()
    }
    return res
  }

  function getNameText()
  {
    return map.getNameText()
  }

  function getGeoCoordsText()
  {
    return ::loc("worldwar/сlansInQueueTotal") + " " + getArmyGroupsAmountTotal()
  }

  function getCountriesByTeams()
  {
    return map.getCountriesByTeams()
  }

  function getCantJoinQueueReasonData(country = null)
  {
    local res = getCantJoinAnyQueuesReasonData()
    if (! res.canJoin)
      return res

    res.canJoin = false

    if (country && !map.canJoinByCountry(country))
      res.reasonText = ::loc("worldWar/chooseAvailableCountry")
    else
      res.canJoin = true

    return res
  }

  static function getCantJoinAnyQueuesReasonData()
  {
    local res = {
      canJoin = false
      reasonText = ""
    }

    if (::g_ww_global_status.getMyClanOperation())
      res.reasonText = ::loc("worldwar/squadronAlreadyInOperation")
    else if (::g_ww_global_status.isMyClanInQueue())
      res.reasonText = ::loc("worldwar/mapStatus/yourClanInQueue")
    else if (!::g_clans.hasRightsToQueueWWar())
      res.reasonText = ::loc("worldWar/onlyLeaderCanQueue")
    else if (::g_clans.getMyClanMembersCount() < ::g_clans.getMyClanType().minMemberCountToWWar)
    {
      local myClanType = ::g_clans.getMyClanType()
      res.reasonText = ::loc("clan/wwar/lacksMembers", {
        clanType = myClanType.getTypeNameLoc()
        count = myClanType.minMemberCountToWWar
      })
    }
    else
      res.canJoin = true

    return res
  }

  function joinQueue(country, isSilence = true)
  {
    local cantJoinReason = getCantJoinQueueReasonData(country)
    if (!cantJoinReason.canJoin)
    {
      if (!isSilence)
        ::showInfoMsgBox(cantJoinReason.reasonText)
      return false
    }

    return _joinQueue(country)
  }

  function _joinQueue(country)
  {
    local requestBlk = ::DataBlock()
    requestBlk.mapName = map.name
    requestBlk.country = country
    ::g_ww_global_status.actionRequest("cln_clan_register_ww_army_group", requestBlk, { showProgressBox = true })
  }

  function getCantLeaveQueueReasonData()
  {
    local res = {
      canLeave = false
      reasonText = ""
    }

    if (!::g_clans.hasRightsToQueueWWar())
      res.reasonText = ::loc("worldWar/onlyLeaderCanQueue")
    else if (!isMyClanJoined())
      res.reasonText = ::loc("matching/SERVER_ERROR_NOT_IN_QUEUE")
    else
      res.canLeave = true

    return res
  }

  function leaveQueue(isSilence = true)
  {
    local cantLeaveReason = getCantLeaveQueueReasonData()
    if (!cantLeaveReason.canLeave)
    {
      if (!isSilence)
        ::showInfoMsgBox(cantLeaveReason.reasonText)
      return false
    }

    return _leaveQueue()
  }

  function _leaveQueue()
  {
    local requestBlk = ::DataBlock()
    requestBlk.mapName = map.name
    ::g_ww_global_status.actionRequest("cln_ww_unregister_army_group", requestBlk, { showProgressBox = true })
  }
}