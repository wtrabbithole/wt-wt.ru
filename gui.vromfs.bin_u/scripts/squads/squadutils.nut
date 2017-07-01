enum memberStatus {
  READY
  SELECTED_AIRS_BROKEN
  NO_REQUIRED_UNITS
  SELECTED_AIRS_NOT_AVAILABLE
  ALL_AVAILABLE_AIRS_BROKEN
  AIRS_NOT_AVAILABLE
}

::g_squad_utils <- {}

function g_squad_utils::getMemberStatusLocId(status)
{
  switch (status)
  {
    case memberStatus.READY:
      return "status/squad_ready"
    case memberStatus.AIRS_NOT_AVAILABLE:
      return "squadMember/airs_not_available"
    case memberStatus.ALL_AVAILABLE_AIRS_BROKEN:
      return "squadMember/all_available_airs_broken"
    case memberStatus.SELECTED_AIRS_NOT_AVAILABLE:
      return "squadMember/selected_airs_not_available"
    case memberStatus.SELECTED_AIRS_BROKEN:
      return "squadMember/selected_airs_broken"
    case memberStatus.NO_REQUIRED_UNITS:
      return "squadMember/no_required_units"
  }
  return "unknown"
}

function g_squad_utils::canJoinFlightMsgBox(options = null,
                                            okFunc = null, cancelFunc = null)
{
  if (!::isInMenu())
    return false

  if (!::g_squad_manager.isInSquad())
    return true

  local msgId = ::getTblValue("msgId", options, "squad/cant_start_new_flight")
  if (::getTblValue("allowWhenAlone", options, true) && !::g_squad_manager.isNotAloneOnline())
    return true

  if (::getTblValue("isLeaderCanJoin", options, false) && ::g_squad_manager.isSquadLeader())
    if (::g_squad_manager.readyCheck(true))
    {
      if (::getTblValue("showOfflineSquadMembersPopup", options, false))
        checkAndShowHasOfflinePlayersPopup()
      return true
    }
    else if (::g_squad_manager.readyCheck(false))
    {
      showRevokeNonAcceptInvitesMsgBox(okFunc, cancelFunc)
      return false
    }
    else
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
      [ isSquadLeader ? "disbandSquad" : "leaveSquad",
        function()
        {
          ::g_squad_manager.leaveSquad()
          if (okFunc)
            okFunc()
        }
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

function g_squad_utils::checkSquadUnreadyAndDo(handler, func, cancelFunc = null)
{
  if (!::g_squad_manager.isSquadMember() || !::g_squad_manager.isMeReady())
    return func.call(handler)

  ::scene_msg_box("msg_need_unready", null, ::loc("msg/switch_off_ready_flag"),
    [
      ["ok", (@(handler, func) function() {
          ::g_squad_manager.setReadyFlag(false)
          if (handler)
            func.call(handler)
        })(handler, func)
      ],
      ["no", (@(handler, cancelFunc) function() { if (handler && cancelFunc) cancelFunc.call(handler) })(handler, cancelFunc)]
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
  local res = { canFlyout = true, members = [] }

  if (!::g_squad_manager.isInSquad() || !teamData)
    return res

  local squadMembers = ::g_squad_manager.getMembers()
  foreach(uid, memberData in squadMembers)
  {
    if (!memberData.online || ::g_squad_manager.getPlayerStatusInMySquad(uid) == SquadState.SQUAD_LEADER)
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
          }

    local haveAvailCountries = false
    local isAnyRequiredAndAvailableFound = false

    local checkOnlyMemberCountry = !canChangeMemberCountry
                                   || ::isInArray(memberData.country, teamData.countries)
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

  if (memberAvailableUnits.len() == 0)
  {
    memberCantJoinData.canFlyout = false
    memberCantJoinData.joinStatus = hasBrokenUnits ? memberStatus.ALL_AVAILABLE_AIRS_BROKEN
                                                   : memberStatus.AIRS_NOT_AVAILABLE
  }

  return memberCantJoinData
}

function g_squad_utils::showAloneInSquadNotification()
{
  local buttons = [
      { id = "invite_player",
        text = ::loc("squad/invite_player"),
        func = ::open_search_squad_player
      }
    ]

  ::g_popups.add(null, ::format("<color=@warningTextColor>%s</color>", ::loc("squad/notification/alone")), null, buttons, null)
}

function g_squad_utils::checkAndShowHasOfflinePlayersPopup()
{
  if (!::g_squad_manager.isSquadLeader())
    return

  local offlineMembers = ::g_squad_manager.getOfflineMembers()
  if (offlineMembers.len() == 0)
    return

  local text = ::loc("squad/has_offline_members") + ::loc("ui/colon")
  text += ::implode(::u.map(offlineMembers,
                            function(memberData)
                            {
                              return ::colorize("warningTextColor", memberData.name)
                            }
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

  local mText = ::implode(
    ::u.map(notAvailableMemberNames, function(name) { return ::colorize("userlogColoredText", name) })
    ", "
  )
  local msg = ::loc("msg/members_no_access_to_mode", {  members = mText  })
  ::showInfoMsgBox(msg, "members_req_new_content")
  return res
}

function g_squad_utils::showMemberMenu(obj, handlerForChat = null)
{
  if (!::checkObj(obj))
    return

  local member = obj.getUserData()
  if (member == null)
      return

  local menu = getMemberPopupMenu(member, handlerForChat)
  local position = obj.getPosRC()
  ::gui_right_click_menu(menu, this, position)
}

function g_squad_utils::getMemberPopupMenu(member, handlerForChat)
{
  local meLeader = ::g_squad_manager.isSquadLeader()
  local isMe = member.uid == ::my_user_id_str

  local menu = [
    {
      text = ::loc("contacts/message")
      show = !isMe && ::ps4_is_chat_enabled() && !::u.isEmpty(member.name)
      action = (@(member) function() {
        ::openChatPrivate(member.name)
      })(member)
    }
    {
      text = ::loc("squadAction/openChat")
      show = ::g_chat.getMySquadRoomId() && ::ps4_is_chat_enabled()
      action = (@(handlerForChat) function() {
        ::g_chat.openChatRoom(::g_chat.getMySquadRoomId(), handlerForChat)
      })(handlerForChat)
    }
    {
      text = ::loc("mainmenu/btnUserCard")
      action = (@(member) function() {
        ::gui_modal_userCard({ uid = member.uid })
      })(member)
    }
    {
      text = ::loc("mainmenu/btnClanCard")
      show = !::u.isEmpty(member.clanTag) && ::has_feature("Clans")
      action = (@(member) function() {
        ::showClanPage("", "", member.clanTag)
      })(member)
    }
    {
      text = ::loc("squad/remove_player")
      show = !isMe && meLeader && member != null && !member.isInvite && ::g_squad_manager.canManageSquad()
      action = (@(member) function() {
        ::g_squad_manager.dismissFromSquad(member.uid)
      })(member)
    }
    {
      text = ::loc("squad/tranfer_leadership")
      show = ::g_squad_manager.canTransferLeadership(member.uid)
      action = (@(member) function() {
        ::g_squad_manager.transferLeadership(member.uid)
      })(member)
    }
    {
      text = ::loc("squad/revoke_invite")
      show = meLeader && member != null && member.isInvite
      action = (@(member) function() {
        ::g_squad_manager.revokeSquadInvite(member.uid)
      })(member)
    }
  ]

  return menu
}

function g_squad_utils::showSquadInvitesWidget(alignObj)
{
  if (!::has_feature("Squad") || !::has_feature("SquadWidget"))
    return null

  if (!::checkObj(alignObj))
    return null

  local params = {
    alignObj = alignObj
  }

  return ::handlersManager.loadHandler(::gui_handlers.SquadWidgetInviteListCustomHandler, params)
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
