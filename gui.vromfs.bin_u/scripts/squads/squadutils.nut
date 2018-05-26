local systemMsg = ::require("scripts/utils/systemMsg.nut")
local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")
local platformModule = require("modules/platform.nut")

const MEMBER_STATUS_LOC_TAG_PREFIX = "#msl"

enum memberStatus {
  READY
  SELECTED_AIRS_BROKEN
  NO_REQUIRED_UNITS
  SELECTED_AIRS_NOT_AVAILABLE
  ALL_AVAILABLE_AIRS_BROKEN
  AIRS_NOT_AVAILABLE
}

local memberStatusLocId = {
  [memberStatus.READY]                          = "status/squad_ready",
  [memberStatus.AIRS_NOT_AVAILABLE]             = "squadMember/airs_not_available",
  [memberStatus.ALL_AVAILABLE_AIRS_BROKEN]      = "squadMember/all_available_airs_broken",
  [memberStatus.SELECTED_AIRS_NOT_AVAILABLE]    = "squadMember/selected_airs_not_available",
  [memberStatus.SELECTED_AIRS_BROKEN]           = "squadMember/selected_airs_broken",
  [memberStatus.NO_REQUIRED_UNITS]              = "squadMember/no_required_units",
}

local locTags = { [MEMBER_STATUS_LOC_TAG_PREFIX] = "unknown" }
foreach(status, locId in memberStatusLocId)
  locTags[MEMBER_STATUS_LOC_TAG_PREFIX + status] <- locId
systemMsg.registerLocTags(locTags)

::g_squad_utils <- {
  getMemberStatusLocId = @(status) memberStatusLocId?[status] ?? "unknown"
  getMemberStatusLocTag = @(status) MEMBER_STATUS_LOC_TAG_PREFIX + (status in memberStatusLocId ? status : "")
}

function g_squad_utils::canJoinFlightMsgBox(options = null,
                                            okFunc = null, cancelFunc = null)
{
  if (!::isInMenu())
  {
    ::g_popups.add("", ::loc("squad/cant_join_in_flight"))
    return false
  }

  if (!::g_squad_manager.isInSquad())
    return true

  local msgId = ::getTblValue("msgId", options, "squad/cant_start_new_flight")
  if (::getTblValue("allowWhenAlone", options, true) && !::g_squad_manager.isNotAloneOnline())
    return true

  if (!::getTblValue("isLeaderCanJoin", options, false) || !::g_squad_manager.isSquadLeader())
  {
    showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
    return false
  }

  local maxSize = ::getTblValue("maxSquadSize", options, 0)
  if (maxSize > 0 && ::g_squad_manager.getOnlineMembersCount() > maxSize)
  {
    ::showInfoMsgBox(::loc("gamemode/squad_is_too_big",
      {
        squadSize = ::colorize("userlogColoredText", ::g_squad_manager.getOnlineMembersCount())
        maxTeamSize = ::colorize("userlogColoredText", maxSize)
      }))
    return false
  }

  if (::g_squad_manager.readyCheck(true))
  {
    if (::getTblValue("showOfflineSquadMembersPopup", options, false))
      checkAndShowHasOfflinePlayersPopup()
    return true
  }

  if (::g_squad_manager.readyCheck(false))
  {
    showRevokeNonAcceptInvitesMsgBox(okFunc, cancelFunc)
    return false
  }

  msgId = "squad/not_all_ready"
  showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
  return false
}

function g_squad_utils::showRevokeNonAcceptInvitesMsgBox(okFunc = null, cancelFunc = null)
{
  showCantJoinSquadMsgBox(
    "revoke_non_accept_invitees",
    ::loc("squad/revoke_non_accept_invites"),
    [["revoke_invites", function() { ::g_squad_manager.revokeAllInvites(okFunc) } ],
     ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

function g_squad_utils::showLeaveSquadMsgBox(msgId, okFunc = null, cancelFunc = null)
{
  local isSquadLeader = ::g_squad_manager.isSquadLeader()
  showCantJoinSquadMsgBox(
    "cant_join",
    ::loc(msgId),
    [
      [ "leaveSquad",
        function() { ::g_squad_manager.leaveSquad(okFunc) }
      ],
      ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

function showCantJoinSquadMsgBox(id, msg, buttons, defBtn, options)
{
  ::scene_msg_box(id, null, msg, buttons, defBtn, options)
}

function g_squad_utils::checkSquadUnreadyAndDo(handler, func, cancelFunc = null,
                                               shouldCheckCrewsReady = false)
{
  if (!::g_squad_manager.isSquadMember() ||
      !::g_squad_manager.isMeReady() ||
      (!::g_squad_manager.isMyCrewsReady && shouldCheckCrewsReady))
    return func.call(handler)

  local messageText = (::g_squad_manager.isMyCrewsReady && shouldCheckCrewsReady)
    ? ::loc("msg/switch_off_crews_ready_flag")
    : ::loc("msg/switch_off_ready_flag")

  local onOkFunc = function() {
    if (::g_squad_manager.isMyCrewsReady && shouldCheckCrewsReady)
      ::g_squad_manager.setCrewsReadyFlag(false)
    else
      ::g_squad_manager.setReadyFlag(false)
    if (handler)
      func.call(handler)
  }
  local onCancelFunc = function() {
    if (handler && cancelFunc)
      cancelFunc.call(handler)
  }

  ::scene_msg_box("msg_need_unready", null, messageText,
    [
      ["ok", onOkFunc],
      ["no", onCancelFunc]
    ],
    "ok", { cancel_fn = function() {}})
}

function g_squad_utils::updateMyCountryData()
{
  local memberData = ::g_user_utils.getMyStateData()
  ::g_squad_manager.updateMyMemberData(memberData)

  //Update Skirmish Lobby info
  ::SessionLobby.setCountryData({
    country = memberData.country
    crewAirs = memberData.crewAirs
    selAirs = memberData.selAirs  //!!FIX ME need to remove this and use slots in client too.
    slots = memberData.selSlots
  })
}

function g_squad_utils::getMembersFlyoutData(teamData, respawn, ediff = -1, canChangeMemberCountry = true)
{
  local res = {
    canFlyout = true,
    members = []
    countriesChanged = 0
  }

  if (!::g_squad_manager.isInSquad() || !teamData)
    return res

  local squadMembers = ::g_squad_manager.getMembers()
  foreach(uid, memberData in squadMembers)
  {
    if (!memberData.online || ::g_squad_manager.getPlayerStatusInMySquad(uid) == squadMemberState.SQUAD_LEADER)
      continue

    if (memberData.country == "")
      continue

    local mData = {
            uid = memberData.uid
            name = memberData.name
            status = memberStatus.READY
            countries = []
            selAirs = memberData.selAirs
            selSlots = memberData.selSlots
            isSelfCountry = false
          }

    local haveAvailCountries = false
    local isAnyRequiredAndAvailableFound = false

    local checkOnlyMemberCountry = !canChangeMemberCountry
                                   || ::isInArray(memberData.country, teamData.countries)
    if (checkOnlyMemberCountry)
      mData.isSelfCountry = true
    else
      res.countriesChanged++

    local needCheckRequired = ::events.getRequiredCrafts(teamData).len() > 0
    foreach(country in teamData.countries)
    {
      if (checkOnlyMemberCountry && country != memberData.country)
        continue

      local haveAvailable = false
      local haveNotBroken = false
      local haveRequired  = !needCheckRequired

      if (!respawn)
      {
        if (!(country in memberData.selAirs))
          continue

        local unitName = memberData.selAirs[country]
        haveAvailable = ::events.isUnitAllowedByTeamData(teamData, unitName, ediff)
        haveNotBroken = haveAvailable && !::isInArray(unitName, memberData.brokenAirs)
        haveRequired  = haveRequired || ::events.isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
      } else
      {
        if (!(country in memberData.crewAirs))
          continue

        foreach(unitName in memberData.crewAirs[country])
        {
          haveAvailable = haveAvailable || ::events.isUnitAllowedByTeamData(teamData, unitName, ediff)
          haveNotBroken = haveNotBroken || (haveAvailable && !::isInArray(unitName, memberData.brokenAirs))
          haveRequired  = haveRequired  || ::events.isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
        }
      }

      haveAvailCountries = haveAvailCountries || haveAvailable
      isAnyRequiredAndAvailableFound = isAnyRequiredAndAvailableFound || (haveAvailable && haveRequired)
      if (haveAvailable && haveNotBroken && haveRequired)
        mData.countries.append(country)
    }

    if (!haveAvailCountries)
      mData.status = respawn ? memberStatus.AIRS_NOT_AVAILABLE : memberStatus.SELECTED_AIRS_NOT_AVAILABLE
    else if (!isAnyRequiredAndAvailableFound)
      mData.status = memberStatus.NO_REQUIRED_UNITS
    else if (!mData.countries.len())
      mData.status = respawn ? memberStatus.ALL_AVAILABLE_AIRS_BROKEN : memberStatus.SELECTED_AIRS_BROKEN

    res.canFlyout = res.canFlyout && mData.status == memberStatus.READY
    res.members.append(mData)
  }

  return res
}

function g_squad_utils::getMembersAvailableUnitsCheckingData(remainUnits, country)
{
  local res = []
  foreach (uid, memberData in ::g_squad_manager.getMembers())
    res.append(getMemberAvailableUnitsCheckingData(memberData, remainUnits, country))

  return res
}

function g_squad_utils::getMemberAvailableUnitsCheckingData(memberData, remainUnits, country)
{
  local memberCantJoinData = {
                               canFlyout = true
                               joinStatus = memberStatus.READY
                               unbrokenAvailableUnits = []
                               memberData = memberData
                             }

  if (!(country in memberData.crewAirs))
  {
    memberCantJoinData.canFlyout = false
    memberCantJoinData.joinStatus = memberStatus.AIRS_NOT_AVAILABLE
    return memberCantJoinData
  }

  local memberAvailableUnits = memberCantJoinData.unbrokenAvailableUnits
  local hasBrokenUnits = false
  foreach (idx, name in memberData.crewAirs[country])
    if (name in remainUnits)
      if (::isInArray(name, memberData.brokenAirs))
        hasBrokenUnits = true
      else
        memberAvailableUnits.append(name)

  if (remainUnits && memberAvailableUnits.len() == 0)
  {
    memberCantJoinData.canFlyout = false
    memberCantJoinData.joinStatus = hasBrokenUnits ? memberStatus.ALL_AVAILABLE_AIRS_BROKEN
                                                   : memberStatus.AIRS_NOT_AVAILABLE
  }

  return memberCantJoinData
}

function g_squad_utils::checkAndShowHasOfflinePlayersPopup()
{
  if (!::g_squad_manager.isSquadLeader())
    return

  local offlineMembers = ::g_squad_manager.getOfflineMembers()
  if (offlineMembers.len() == 0)
    return

  local text = ::loc("squad/has_offline_members") + ::loc("ui/colon")
  text += ::g_string.implode(::u.map(offlineMembers,
                            @(memberData) ::colorize("warningTextColor", platformModule.getPlayerName(memberData.name))
                           ),
                    ::loc("event_comma")
                   )

  ::g_popups.add("", text)
}

function g_squad_utils::checkSquadsVersion(memberSquadsVersion)
{
  if (memberSquadsVersion <= SQUADS_VERSION)
    return

  local message = ::loc("squad/need_reload")
  ::scene_msg_box("need_update_squad_version", null, message,
                  [["relogin", function() {
                     ::save_short_token()
                     ::gui_start_logout()
                   } ],
                   ["cancel", function() {}]
                  ],
                  "cancel", { cancel_fn = function() {}}
                 )
}

/**
    availableUnitsArrays = [
                             [unitName...]
                           ]

    controlUnits = {
                     unitName = count
                     ...
                   }

    availableUnitsArrayIndex - recursion param
**/
function g_squad_utils::checkAvailableUnits(availableUnitsArrays, controlUnits, availableUnitsArrayIndex = 0)
{
  if (availableUnitsArrays.len() >= availableUnitsArrayIndex)
    return true

  local units = availableUnitsArrays[availableUnitsArrayIndex]
  foreach(idx, name in units)
  {
    if (controlUnits[name] <= 0)
      continue

    controlUnits[name]--
    if (checkAvailableUnits(availableUnitsArrays, controlUnits, availableUnitsArrayIndex++))
      return true

    controlUnits[name]++
  }

  return false
}

function g_squad_utils::canJoinByMySquad(operationId = null, controlCountry = "")
{
  if (operationId == null)
    operationId = ::g_squad_manager.getWwOperationId()

  local squadMembers = ::g_squad_manager.getMembers()
  foreach(uid, member in squadMembers)
  {
    if (!member.online)
      continue

    local memberCountry = member.getWwOperationCountryById(operationId)
    if (!::u.isEmpty(memberCountry))
      if (controlCountry == "")
        controlCountry = memberCountry
      else if (controlCountry != memberCountry)
        return false
  }

  return true
}

function g_squad_utils::isEventAllowedForAllMembers(eventEconomicName, isSilent = false)
{
  if (!::g_squad_manager.isInSquad())
    return true

  local notAvailableMemberNames= []
  foreach(member in ::g_squad_manager.getMembers())
    if (!member.isEventAllowed(eventEconomicName))
      notAvailableMemberNames.append(member.name)

  local res = !notAvailableMemberNames.len()
  if (res || isSilent)
    return res

  local mText = ::g_string.implode(
    ::u.map(notAvailableMemberNames, @(name) ::colorize("userlogColoredText", platformModule.getPlayerName(name)))
    ", "
  )
  local msg = ::loc("msg/members_no_access_to_mode", {  members = mText  })
  ::showInfoMsgBox(msg, "members_req_new_content")
  return res
}

function g_squad_utils::showMemberMenu(obj)
{
  if (!::checkObj(obj))
    return

  local member = obj.getUserData()
  if (member == null)
      return

  local position = obj.getPosRC()
  playerContextMenu.showMenu(
    null,
    this,
    {
      playerName = member.name
      uid = member.uid
      clanTag = member.clanTag
      squadMemberData = member
      position = position
  })
}

/*use by client .cpp code*/
function is_in_my_squad(name, checkAutosquad = true)
{
  return ::g_squad_manager.isInMySquad(name, checkAutosquad)
}

function is_in_squad(forChat = false)
{
  return ::g_squad_manager.isInSquad(forChat)
}
