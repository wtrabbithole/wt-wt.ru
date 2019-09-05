local squadApplications = require("scripts/squads/squadApplications.nut")
local platformModule = require("scripts/clientState/platform.nut")
local battleRating = ::require("scripts/battleRating.nut")

enum squadEvent
{
  DATA_UPDATED = "SquadDataUpdated"
  SET_READY = "SquadSetReady"
  STATUS_CHANGED = "SquadStatusChanged"
  PLAYER_INVITED = "SquadPlayerInvited"
  INVITES_CHANGED = "SquadInvitesChanged"
  APPLICATIONS_CHANGED = "SquadApplicationsChanged"
  SIZE_CHANGED = "SquadSizeChanged"
  NEW_APPLICATIONS = "SquadHasNewApplications"
  PROPERTIES_CHANGED = "SquadPropertiesChanged"
}

enum squadStatusUpdateState {
  NONE
  MENU
  BATTLE
}

enum squadState
{
  NOT_IN_SQUAD
  JOINING
  IN_SQUAD
  LEAVING
}

const DEFAULT_SQUADS_VERSION = 1
const SQUADS_VERSION = 2
const SQUAD_REQEST_TIMEOUT = 45000

local DEFAULT_SQUAD_PROPERTIES = {
  maxMembers = 4
  isApplicationsEnabled = true
}

local SQUAD_SIZE_FEATURES_CHECK = {
  squad = ["Squad"]
  platoon = ["Clans", "WorldWar"]
  battleGroup = ["WorldWar"]
}

local DEFAULT_SQUAD_PRESENCE = ::g_presence_type.IDLE.getParams()

g_squad_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["squadData", "meReady", "isMyCrewsReady", "lastUpdateStatus", "state",
   "COMMON_SQUAD_SIZE", "MAX_SQUAD_SIZE", "squadSizesList", "delayedInvites"]

  COMMON_SQUAD_SIZE = 4
  MAX_SQUAD_SIZE = 4 //max available squad size to choose
  maxInvitesCount = 9
  squadSizesList = []

  cyberCafeSquadMembersNum = -1
  state = squadState.NOT_IN_SQUAD
  lastStateChangeTime = - SQUAD_REQEST_TIMEOUT
  squadData = {
    id = ""
    members = {}
    invitedPlayers = {}
    applications = {}
    platformInfo = []
    chatInfo = {
      name = ""
      password = ""
    }
    wwOperationInfo = {
      id = -1
      country = ""
      battle = null
    }
    properties = clone DEFAULT_SQUAD_PROPERTIES
    presence = clone DEFAULT_SQUAD_PRESENCE
    psnSessionId = ""
    leaderBattleRating = 0
    leaderGameModeId = ""
  }

  meReady = false
  isMyCrewsReady = false
  lastUpdateStatus = squadStatusUpdateState.NONE
  roomCreateInProgress = false
  hasNewApplication = false
  delayedInvites = []
}

function g_squad_manager::setState(newState)
{
  if (state == newState)
    return false
  state = newState
  lastStateChangeTime = ::dagor.getCurTime()
  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  return true
}

function g_squad_manager::isStateInTransition()
{
  return (state == squadState.JOINING || state == squadState.LEAVING)
    && lastStateChangeTime + SQUAD_REQEST_TIMEOUT > ::dagor.getCurTime()
}

function g_squad_manager::canStartStateChanging()
{
  return !isStateInTransition()
}

function g_squad_manager::canJoinSquad()
{
  return !isInSquad() && canStartStateChanging()
}

function g_squad_manager::updateMyMemberData(data = null)
{
  if (!isInSquad())
    return

  if (data == null)
    data = ::g_user_utils.getMyStateData()

  data.isReady <- isMeReady()
  data.isCrewsReady <- isMyCrewsReady
  data.canPlayWorldWar <- ::g_world_war.canPlayWorldwar()
  data.isWorldWarAvailable <- ::is_worldwar_enabled()
  data.squadsVersion <- SQUADS_VERSION

  local wwOperations = []
  if (::is_worldwar_enabled())
    foreach (wwOperation in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getList())
    {
      if (!wwOperation.isValid())
        continue

      local country = wwOperation.getMyAssignCountry() || wwOperation.getMyClanCountry()
      if (country != null)
        wwOperations.append({
          id = wwOperation.id
          country = country
        })
    }
  data.wwOperations <- wwOperations
  data.wwStartingBattle <- null
  data.sessionRoomId <- ::SessionLobby.canInviteIntoSession() ? ::SessionLobby.roomId : ""

  local memberData = getMemberData(::my_user_id_str)
  if (!memberData)
  {
    memberData = SquadMember(::my_user_id_str)
    squadData.members[::my_user_id_str] <- memberData
  }

  memberData.update(data)
  memberData.online = true
  ::updateContact(memberData.getData())

  ::msquad.setMyMemberData(::my_user_id_str, data)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::isInSquad(forChat = false)
{
  if (forChat && !::SessionLobby.isMpSquadChatAllowed())
    return false

  return state == squadState.IN_SQUAD
}

function g_squad_manager::isMeReady()
{
  return meReady
}

function g_squad_manager::getLeaderUid()
{
  return squadData.id
}

function g_squad_manager::isSquadLeader()
{
  return isInSquad() && getLeaderUid() == ::my_user_id_str
}

function g_squad_manager::getSquadLeaderData()
{
  return getMemberData(getLeaderUid())
}

function g_squad_manager::getMembers()
{
  return squadData.members
}

function g_squad_manager::setPsnSessionId(id = null)
{
  squadData.psnSessionId <- id
  updateSquadData()
}

function g_squad_manager::getPsnSessionId()
{
  return squadData?.psnSessionId ?? ""
}

function g_squad_manager::getInvitedPlayers()
{
  return squadData.invitedPlayers
}

function g_squad_manager::getPlatformInfo()
{
  return squadData.platformInfo
}

function g_squad_manager::isPlayerInvited(uid, name = null)
{
  if (uid)
    return uid in getInvitedPlayers()

  return ::u.search(getInvitedPlayers(), @(player) player.name == name) != null
}

function g_squad_manager::getApplicationsToSquad()
{
  return squadData.applications
}

function g_squad_manager::hasApplicationInMySquad(uid, name = null)
{
  if (uid)
    return uid in getApplicationsToSquad()

  return ::u.search(getApplicationsToSquad(), @(player) player.name == name) != null
}

function g_squad_manager::getLeaderNick()
{
  if (!isInSquad())
    return ""

  local leaderData = getSquadLeaderData()
  if (leaderData == null)
    return ""

  return leaderData.name
}

function g_squad_manager::getSquadRoomName()
{
  return squadData.chatInfo.name
}

function g_squad_manager::getSquadRoomPassword()
{
  return squadData.chatInfo.password
}

function g_squad_manager::getWwOperationId()
{
  return ::getTblValue("id", squadData.wwOperationInfo, -1)
}

function g_squad_manager::getWwOperationCountry()
{
  return ::getTblValue("country", squadData.wwOperationInfo, "")
}

function g_squad_manager::getWwOperationBattle()
{
  return ::getTblValue("battle", squadData.wwOperationInfo)
}

function g_squad_manager::isNotAloneOnline()
{
  if (!isInSquad())
    return false

  if (squadData.members.len() == 1)
    return false

  foreach(uid, memberData in squadData.members)
    if (uid != ::my_user_id_str && memberData.online == true)
      return true

  return false
}

function g_squad_manager::isMySquadLeader(uid)
{
  return isInSquad() && uid != null && uid == getLeaderUid()
}

function g_squad_manager::isSquadMember()
{
  return isInSquad() && !isSquadLeader()
}

function g_squad_manager::isMemberReady(uid)
{
  local memberData = getMemberData(uid)
  return memberData ? memberData.isReady : false
}

function g_squad_manager::isInMySquad(name, checkAutosquad = true)
{
  if (isInSquad() && _getSquadMemberByName(name) != null)
    return true
  return checkAutosquad && ::SessionLobby.isMemberInMySquadByName(name)
}

function g_squad_manager::isMe(uid)
{
  return uid == ::my_user_id_str
}

function g_squad_manager::canInviteMember(uid = null)
{
  return !isMe(uid)
    && canManageSquad()
    && (canJoinSquad() || isSquadLeader())
    && !isInvitedMaxPlayers()
    && (!uid || !getMemberData(uid))
}

function g_squad_manager::canDismissMember(uid = null)
{
  return isSquadLeader()
         && canManageSquad()
         && !isMe(uid)
         && getPlayerStatusInMySquad(uid) >= squadMemberState.SQUAD_MEMBER
}

function g_squad_manager::canSwitchReadyness()
{
  return ::g_squad_manager.isSquadMember() && ::g_squad_manager.canManageSquad() && !checkIsInQueue()
}

function g_squad_manager::canLeaveSquad()
{
  return isInSquad() && canManageSquad()
}

function g_squad_manager::canManageSquad()
{
  return ::has_feature("Squad") && ::isInMenu()
}

function g_squad_manager::canInviteMemberByPlatform(name)
{
  local platformInfo = getPlatformInfo()
  if (platformModule.isPS4PlayerName(name) && ::isInArray("xboxOne", platformInfo))
    return false

  if (platformModule.isXBoxPlayerName(name) && ::isInArray("ps4", platformInfo))
    return false

  return true
}

function g_squad_manager::canInvitePlayerToSessionByName(name)
{
  if (::SessionLobby.getGameMode() != ::GM_SKIRMISH)
    return true

  local platformInfo = getPlatformInfo()
  return platformInfo.len() == 1 || !platformModule.isXBoxPlayerName(name)
}

function g_squad_manager::getMaxSquadSize()
{
  return squadData.properties.maxMembers
}

function g_squad_manager::setMaxSquadSize(newSize)
{
  squadData.properties.maxMembers = newSize
}

function g_squad_manager::getSquadSize(includeInvites = false)
{
  if (!isInSquad())
    return 0

  local res = squadData.members.len()
  if (includeInvites)
  {
    res += getInvitedPlayers().len()
    res += getApplicationsToSquad().len()
  }
  return res
}

function g_squad_manager::isSquadFull()
{
  return getSquadSize() >= getMaxSquadSize()
}

function g_squad_manager::canChangeSquadSize(shouldCheckLeader = true)
{
  return ::has_feature("SquadSizeChange")
         && (!shouldCheckLeader || ::g_squad_manager.isSquadLeader())
         && squadSizesList.len() > 1
}

function g_squad_manager::setSquadSize(newSize)
{
  if (newSize == getMaxSquadSize())
    return

  setMaxSquadSize(newSize)
  updateSquadData()
  ::broadcastEvent(squadEvent.SIZE_CHANGED)
}

function g_squad_manager::initSquadSizes()
{
  squadSizesList.clear()
  local sizesBlk = ::get_game_settings_blk()?.squad?.sizes
  if (!::u.isDataBlock(sizesBlk))
    return

  local maxSize = 0
  for (local i = 0; i < sizesBlk.paramCount(); i++)
  {
    local name = sizesBlk.getParamName(i)
    local needAddSize = ::has_feature_array_any(SQUAD_SIZE_FEATURES_CHECK?[name] ?? [])
    if (!needAddSize)
      continue

    local size = sizesBlk.getParamValue(i)
    squadSizesList.append({
      name = name
      value = size
    })
    maxSize = ::max(maxSize, size)
  }

  if (!squadSizesList.len())
    return

  COMMON_SQUAD_SIZE = squadSizesList[0].value
  MAX_SQUAD_SIZE = maxSize
  setMaxSquadSize(COMMON_SQUAD_SIZE)
}

function g_squad_manager::isInvitedMaxPlayers()
{
  return isSquadFull() || getInvitedPlayers().len() >= maxInvitesCount
}

function g_squad_manager::isApplicationsEnabled()
{
  return squadData.properties.isApplicationsEnabled
}

function g_squad_manager::enableApplications(shouldEnable)
{
  if (shouldEnable == isApplicationsEnabled())
    return

  squadData.properties.isApplicationsEnabled = shouldEnable

  updateSquadData()
}

function g_squad_manager::canChangeReceiveApplications(shouldCheckLeader = true)
{
  return ::has_feature("ClanSquads") && (!shouldCheckLeader || isSquadLeader())
}

function g_squad_manager::getPlayerStatusInMySquad(uid)
{
  if (!isInSquad())
    return squadMemberState.NOT_IN_SQUAD

  if (getLeaderUid() == uid)
    return squadMemberState.SQUAD_LEADER

  local memberData = getMemberData(uid)
  if (memberData == null)
    return squadMemberState.NOT_IN_SQUAD

  if (!memberData.online)
    return squadMemberState.SQUAD_MEMBER_OFFLINE
  if (memberData.isReady)
    return squadMemberState.SQUAD_MEMBER_READY
  return squadMemberState.SQUAD_MEMBER
}

function g_squad_manager::readyCheck(considerInvitedPlayers = false)
{
  if (!isInSquad())
    return false

  foreach(uid, memberData in squadData.members)
    if (memberData.online == true && memberData.isReady == false)
      return false

  if (considerInvitedPlayers && squadData.invitedPlayers.len() > 0)
    return false

  return  true
}

function g_squad_manager::crewsReadyCheck()
{
  if (!isInSquad())
    return false

  foreach(uid, memberData in squadData.members)
    if (memberData.online && !memberData.isCrewsReady)
      return false

  return  true
}

function g_squad_manager::getDiffCrossPlayConditionMembers()
{
  local res = []
  if (!isInSquad())
    return res

  local leaderCondition = squadData.members[getLeaderUid()].crossplay
  foreach (uid, memberData in squadData.members)
    if (leaderCondition != memberData.crossplay)
      res.append(memberData)

  return res
}

function g_squad_manager::getOfflineMembers()
{
  return getMembersByOnline(false)
}

function g_squad_manager::getOnlineMembers()
{
  return getMembersByOnline(true)
}

function g_squad_manager::getMembersByOnline(online = true)
{
  local res = []
  if (!isInSquad())
    return res

  foreach(uid, memberData in squadData.members)
    if (memberData.online == online)
      res.append(memberData)

  return res
}

function g_squad_manager::getOnlineMembersCount()
{
  if (!isInSquad())
    return 1
  local res = 0
  foreach(member in squadData.members)
    if (member.online)
      res++
  return res
}

function g_squad_manager::setReadyFlag(ready = null, needUpdateMemberData = true)
{
  local isLeader = isSquadLeader()
  if (isLeader && ready != true)
    return

  if (::checkIsInQueue() && !isLeader && isInSquad() && (ready == false || (ready == null && isMeReady() == true)))
  {
    ::g_popups.add(null, ::loc("squad/cant_switch_off_readyness_in_queue"))
    return
  }

  if (ready == null)
    meReady = !isMeReady()
  else if (isMeReady() != ready)
    meReady = ready
  else
    return

  if (!meReady)
    isMyCrewsReady = false

  if (needUpdateMemberData)
    updateMyMemberData(::g_user_utils.getMyStateData())

  ::broadcastEvent(squadEvent.SET_READY)
}

function g_squad_manager::setCrewsReadyFlag(ready = null, needUpdateMemberData = true)
{
  local isLeader = isSquadLeader()
  if (isLeader && ready != true)
    return

  if (ready == null)
    isMyCrewsReady = !isMyCrewsReady
  else if (isMyCrewsReady != ready)
    isMyCrewsReady = ready
  else
    return

  if (needUpdateMemberData)
    updateMyMemberData(::g_user_utils.getMyStateData())
}

function g_squad_manager::createSquad(callback)
{
  if (!::has_feature("Squad"))
    return

  if (!canJoinSquad() || !canManageSquad() || ::queues.isAnyQueuesActive())
    return

  setState(squadState.JOINING)
  ::msquad.create(function(response) { ::g_squad_manager.requestSquadData(callback) })
}

function g_squad_manager::joinSquadChatRoom()
{
  if (!isNotAloneOnline())
    return

  if (!::gchat_is_connected())
    return

  if (::g_chat.isSquadRoomJoined())
    return

  if (roomCreateInProgress)
    return

  local name = getSquadRoomName()
  local password = getSquadRoomPassword()
  local callback = null

  if (::u.isEmpty(name))
    return

  if (isSquadLeader() && ::u.isEmpty(password))
  {
    password = ::gen_rnd_password(15)
    squadData.chatInfo.password = password

    roomCreateInProgress = true
    callback = function() {
                 ::g_squad_manager.updateSquadData()
                 ::g_squad_manager.roomCreateInProgress = false
               }
  }

  if (::u.isEmpty(password))
    return

  ::g_chat.joinSquadRoom(callback)
}

function g_squad_manager::updateSquadData()
{
  local data = {}
  data.chatInfo <- { name = getSquadRoomName(), password = getSquadRoomPassword() }
  data.wwOperationInfo <- {
    id = getWwOperationId()
    country = getWwOperationCountry()
    battle = getWwOperationBattle() }
  data.properties <- clone squadData.properties
  data.presence <- clone squadData.presence
  data.psnSessionId <- squadData?.psnSessionId ?? ""
  data.leaderBattleRating <- squadData?.leaderBattleRating ?? 0
  data.leaderGameModeId <- squadData?.leaderGameModeId ?? ""

  ::g_squad_manager.setSquadData(data)
}

function g_squad_manager::disbandSquad()
{
  if (!isSquadLeader())
    return

  setState(squadState.LEAVING)
  ::msquad.disband()
}

//It function will be use in future: Chat with password
function g_squad_manager::setSquadData(newSquadData)
{
  if (!isSquadLeader())
    return

  ::msquad.setData(newSquadData)
}

function g_squad_manager::checkForSquad()
{
  if (!::g_login.isLoggedIn())
    return

  local callback = function(response) {
                     if (::getTblValue("error_id", response, null) != msquadErrorId.NOT_SQUAD_MEMBER)
                       if (!::checkMatchingError(response))
                         return

                     if ("squad" in response)
                     {
                       ::g_squad_manager.onSquadDataChanged(response)

                       if (::g_squad_manager.getSquadSize(true) == 1)
                         ::g_squad_manager.disbandSquad()
                       else
                         ::g_squad_manager.updateMyMemberData(::g_user_utils.getMyStateData())

                      ::broadcastEvent(squadEvent.STATUS_CHANGED)
                     }

                     local invites = ::getTblValue("invites", response, null)
                     if (invites != null)
                       foreach (squadId in invites)
                         ::g_invites.addInviteToSquad(squadId, squadId.tostring())

                     squadApplications.updateApplicationsList(response?.applications ?? [])
                   }

  ::msquad.requestInfo(callback, callback, {showError = false})
}

function g_squad_manager::requestSquadData(callback = null)
{
  local fullCallback = (@(callback) function(response) {
                         if ("squad" in response)
                         {
                           ::g_squad_manager.onSquadDataChanged(response)

                           if (::g_squad_manager.getSquadSize(true) == 1)
                             ::g_squad_manager.disbandSquad()
                         }
                         else if (::g_squad_manager.isInSquad())
                           ::g_squad_manager.reset()

                         if (callback != null)
                           callback()
                       })(callback)

  ::msquad.requestInfo(fullCallback)
}

function g_squad_manager::leaveSquad(cb = null)
{
  if (!isInSquad())
    return

  setState(squadState.LEAVING)
  ::msquad.leave(function(response)
  {
    ::g_squad_manager.reset()
    if (cb)
      cb()
  })

  ::xbox_on_local_player_leave_squad()
}

function g_squad_manager::inviteToSquad(uid, name = null, cb = null)
{
  if (isInSquad() && !isSquadLeader())
    return

  if (isSquadFull())
    return ::g_popups.add(null, ::loc("matching/SQUAD_FULL"))

  if (isInvitedMaxPlayers())
    return ::g_popups.add(null, ::loc("squad/maximum_intitations_sent"))

  if (!canInviteMemberByPlatform(name))
    return ::g_popups.add(null, ::loc("msg/squad/noPlayersForDiffConsoles"))

  local isInvitingPsnPlayer = name && ::isPlayerPS4Friend(name)
  if (isInvitingPsnPlayer && u.isEmpty(getPsnSessionId()))
    delayedInvites.append(::get_psn_account_id(name))

  local callback = function(response) {
    if (isInvitingPsnPlayer && u.isEmpty(::g_squad_manager.delayedInvites))
      ::g_psn_sessions.invite(::g_squad_manager.getPsnSessionId(), ::get_psn_account_id(name))

    ::g_xbox_squad_manager.sendSystemInvite(uid, name)

    ::g_squad_manager.requestSquadData(cb)
  }

  ::msquad.invitePlayer(uid, callback.bindenv(this))
}

function g_squad_manager::processDelayedInvitations()
{
  if (u.isEmpty(getPsnSessionId()) || u.isEmpty(delayedInvites))
    return

  ::g_psn_sessions.invite(getPsnSessionId(), delayedInvites)
  delayedInvites.clear()
}

function g_squad_manager::revokeAllInvites(callback)
{
  if (!isSquadLeader())
    return

  local fullCallback = null
  if (callback != null)
  {
    local counterTbl = { invitesLeft = ::g_squad_manager.getInvitedPlayers().len() }
    fullCallback = (@(callback, counterTbl) function() {
                     if (!--counterTbl.invitesLeft)
                       callback()
                   })(callback, counterTbl)
  }

  foreach (uid, memberData in getInvitedPlayers())
    revokeSquadInvite(uid, fullCallback)
}

function g_squad_manager::revokeSquadInvite(uid, callback = null)
{
  if (!isSquadLeader())
    return

  local fullCallback = @(response) ::g_squad_manager.requestSquadData(function() {
                         if (callback)
                           callback()
                       }.bindenv(this))

  ::msquad.revokeInvite(uid, fullCallback)
}

function g_squad_manager::membershipAplication(sid)
{
  local callback = ::Callback(@(response) squadApplications.addApplication(sid, sid), this)
  local cb = function()
  {
    ::request_matching("msquad.request_membership",
      callback
      null, {squadId = sid}, null)
  }
  local canJoin = ::g_squad_utils.canJoinFlightMsgBox(
    { allowWhenAlone = false, msgId = "squad/leave_squad_for_application" },
    cb)

  if (canJoin)
  {
    cb()
  }
}

function g_squad_manager::revokeMembershipAplication(sid)
{
  squadApplications.deleteApplication(sid)
  ::request_matching("msquad.revoke_membership_request", null, null,{squadId = sid}, null)
}

function g_squad_manager::acceptMembershipAplication(uid)
{
  if (isInSquad() && !isSquadLeader())
    return

  if (isSquadFull())
    return ::g_popups.add(null, ::loc("matching/SQUAD_FULL"))

  local callback = ::Callback(@(response) addMember(uid.tostring()), this)
  ::request_matching("msquad.accept_membership", callback, null,{userId = uid}, null)
}

function g_squad_manager::denyAllAplication()
{
  if (!isSquadLeader())
    return

  ::request_matching("msquad.deny_all_membership_requests", null, null, null, null)
}

function g_squad_manager::denyMembershipAplication(uid, callback = null)
{
  if (isInSquad() && !isSquadLeader())
    return

  ::request_matching("msquad.deny_membership", callback, null,{userId = uid}, null)
}

function g_squad_manager::dismissFromSquad(uid)
{
  if (!isSquadLeader())
    return

  if (squadData.members?[uid])
    ::msquad.dismissMember(uid)
}

function g_squad_manager::dismissFromSquadByName(name)
{
  if (!isSquadLeader())
    return

  local memberData = _getSquadMemberByName(name)
  if (memberData == null)
    return

  if (canDismissMember(memberData.uid))
    dismissFromSquad(memberData.uid)
}

function g_squad_manager::_getSquadMemberByName(name)
{
  if (!isInSquad())
    return null

  foreach(uid, memberData in squadData.members)
    if (memberData.name == name)
      return memberData

  return null
}

function g_squad_manager::canTransferLeadership(uid)
{
  if (!::has_feature("SquadTransferLeadership"))
    return false

  if (!canManageSquad())
    return false

  if (::u.isEmpty(uid))
    return false

  if (uid == ::my_user_id_str)
    return false

  if (!isSquadLeader())
    return false

  local memberData = getMemberData(uid)
  if (memberData == null || memberData.isInvite)
    return false

  return memberData.online
}

function g_squad_manager::transferLeadership(uid)
{
  if (!canTransferLeadership(uid))
    return

  ::msquad.transferLeadership(uid)
}

function g_squad_manager::onLeadershipTransfered()
{
  ::g_squad_manager.setReadyFlag(::g_squad_manager.isSquadLeader())
  ::g_squad_manager.setCrewsReadyFlag(::g_squad_manager.isSquadLeader())
  ::broadcastEvent(squadEvent.STATUS_CHANGED)
}

function g_squad_manager::acceptSquadInvite(sid)
{
  if (!canJoinSquad())
    return

  setState(squadState.JOINING)
  ::msquad.acceptInvite(sid,
    function(response)
    {
      requestSquadData()
    }.bindenv(this),
    function(response)
    {
      setState(squadState.NOT_IN_SQUAD)
      rejectSquadInvite(sid)
      ::xbox_on_local_player_leave_squad()
    }.bindenv(this)
  )
}

function g_squad_manager::rejectSquadInvite(sid)
{
  ::msquad.rejectInvite(sid)
}

function g_squad_manager::requestMemberData(uid)
{
  local memberData = ::getTblValue(uid, ::g_squad_manager.squadData.members, null)
  if (memberData)
  {
    memberData.isWaiting = true
    ::broadcastEvent(squadEvent.DATA_UPDATED)
  }

  local callback = @(response) ::g_squad_manager.requestMemberDataCallback(uid, response)
  ::msquad.requestMemberData(uid, callback)
}

function g_squad_manager::requestMemberDataCallback(uid, response)
{
  local receivedData = response?.data
  if (receivedData == null)
    return

  local memberData = ::g_squad_manager.getMemberData(uid)
  if (memberData == null)
    return

  local currentMemberData = memberData.getData()
  local receivedMemberData = receivedData?.data
  local isMemberDataChanged = memberData.update(receivedMemberData)
  local isMemberDataVehicleChanged = isMemberDataChanged
    && ::g_squad_manager.isMemberDataVehicleChanged(currentMemberData, memberData)
  local contact = ::getContact(memberData.uid, memberData.name)
  contact.online = response.online
  memberData.online = response.online
  if (!response.online)
    memberData.isReady = false

  ::update_contacts_by_list([memberData.getData()])

  if (::g_squad_manager.isSquadLeader())
  {
    if (!::g_squad_manager.readyCheck())
      ::queues.leaveAllQueues()

    if (::SessionLobby.canInviteIntoSession()
        && memberData.canJoinSessionRoom()
        && ::g_squad_manager.canInvitePlayerToSessionByName(memberData.name))
    {
      ::SessionLobby.invitePlayer(memberData.uid)
    }
  }

  ::g_squad_manager.joinSquadChatRoom()

  ::broadcastEvent(squadEvent.DATA_UPDATED)
  if (::g_squad_manager.isSquadLeader() && isMemberDataVehicleChanged)
    battleRating.updateBattleRating()

  local memberSquadsVersion = receivedMemberData?.squadsVersion ?? DEFAULT_SQUADS_VERSION
  ::g_squad_utils.checkSquadsVersion(memberSquadsVersion)
}

function g_squad_manager::setMemberOnlineStatus(uid, isOnline)
{
  local memberData = getMemberData(uid)
  if (memberData == null)
    return

  if (memberData.online == isOnline)
    return

  memberData.online = isOnline
  if (!isOnline)
  {
    memberData.isReady = false
    if (isSquadLeader() && ::queues.isAnyQueuesActive())
      ::queues.leaveAllQueues()
  }

  ::updateContact(memberData.getData())
  ::broadcastEvent(squadEvent.DATA_UPDATED)
  battleRating.updateBattleRating()
}

function g_squad_manager::getMemberData(uid)
{
  if (!isInSquad())
    return null

  return ::getTblValue(uid, squadData.members, null)
}

function g_squad_manager::getSquadMemberNameByUid(uid)
{
  if (isInSquad() && uid in squadData.members)
    return squadData.members[uid].name
  return ""
}

function g_squad_manager::getSameCyberCafeMembersNum()
{
  if (cyberCafeSquadMembersNum >= 0)
    return cyberCafeSquadMembersNum

  local num = 0
  if (isInSquad() && squadData.members && ::get_cyber_cafe_level() > 0)
  {
    local myCyberCafeId = ::get_cyber_cafe_id()
    foreach (uid, memberData in squadData.members)
      if (myCyberCafeId == memberData.cyberCafeId)
        num++
  }

  cyberCafeSquadMembersNum = num
  return num
}

function g_squad_manager::getSquadRank()
{
  if (!isInSquad())
    return -1

  local squadRank = 0
  foreach (uid, memberData in squadData.members)
    squadRank = ::max(memberData.rank, squadRank)

  return squadRank
}

function g_squad_manager::reset()
{
  if (state == squadState.IN_SQUAD)
    setState(squadState.LEAVING)

  ::queues.leaveAllQueues()
  ::g_chat.leaveSquadRoom()

  cyberCafeSquadMembersNum = -1

  squadData.id = ""
  local contactsUpdatedList = []
  foreach(id, memberData in squadData.members)
    contactsUpdatedList.append(memberData.getData())

  squadData.members.clear()
  squadData.invitedPlayers.clear()
  squadData.applications.clear()
  squadData.platformInfo.clear()
  squadData.chatInfo = { name = "", password = "" }
  squadData.wwOperationInfo = { id = -1, country = "", battle = null }
  squadData.properties = clone DEFAULT_SQUAD_PROPERTIES
  squadData.presence = clone DEFAULT_SQUAD_PRESENCE
  squadData.psnSessionId = ""
  squadData.leaderBattleRating = 0
  squadData.leaderGameModeId = ""
  setMaxSquadSize(COMMON_SQUAD_SIZE)

  lastUpdateStatus = squadStatusUpdateState.NONE
  if (meReady)
    setReadyFlag(false, false)

  ::update_contacts_by_list(contactsUpdatedList)
  battleRating.updateBattleRating()

  setState(squadState.NOT_IN_SQUAD)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
}

function g_squad_manager::updateInvitedData(invites)
{
  local newInvitedData = {}
  foreach(uidInt64 in invites)
  {
    if (!::is_numeric(uidInt64))
      continue

    local uid = uidInt64.tostring()
    if (uid in squadData.invitedPlayers)
      newInvitedData[uid] <- squadData.invitedPlayers[uid]
    else
      newInvitedData[uid] <- SquadMember(uid, true)

    ::g_users_info_manager.requestInfo([uid])
  }

  squadData.invitedPlayers = newInvitedData
}

function g_squad_manager::addInvitedPlayers(uid)
{
  if (uid in squadData.invitedPlayers)
    return

  squadData.invitedPlayers[uid] <- SquadMember(uid, true)

  ::g_users_info_manager.requestInfo([uid])

  ::broadcastEvent(squadEvent.PLAYER_INVITED, { uid = uid })
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::removeInvitedPlayers(uid)
{
  if (!(uid in squadData.invitedPlayers))
    return

  squadData.invitedPlayers.rawdelete(uid)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::updateApplications(applications)
{
  local newApplicationsData = {}
  foreach(uid in applications)
  {
    if (uid in squadData.applications)
      newApplicationsData[uid] <- squadData.applications[uid]
    else
    {
      newApplicationsData[uid] <- SquadMember(uid.tostring(), false, true)
      hasNewApplication = true
    }
    ::g_users_info_manager.requestInfo([uid.tostring()])
  }
  if (!newApplicationsData)
    hasNewApplication = false
  squadData.applications = newApplicationsData
}

function g_squad_manager::addApplication(uid)
{
  if (uid in squadData.applications)
    return

  squadData.applications[uid] <- SquadMember(uid.tostring(), false, true)
  ::g_users_info_manager.requestInfo([uid.tostring()])
  checkNewApplications()
  if (isSquadLeader())
    ::g_popups.add(null, ::colorize("chatTextInviteColor",
      ::format(::loc("squad/player_application"),
        platformModule.getPlayerName(squadData.applications[uid]?.name ?? ""))))

  ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED, { uid = uid })
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::removeApplication(applications)
{
  if (!::u.isArray(applications))
    applications = [applications]
  local isApplicationsChanged = false
  foreach (uid in applications)
  {
    if (!(uid in squadData.applications))
      continue
    squadData.applications.rawdelete(uid)
    isApplicationsChanged = true
  }

  if (!isApplicationsChanged)
    return

  if (getSquadSize(true) == 1)
    ::g_squad_manager.disbandSquad()
  checkNewApplications()
  ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED, {})
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::markAllApplicationsSeen()
{
  foreach (application in squadData.applications)
    application.isNewApplication = false
  checkNewApplications()
}

function g_squad_manager::checkNewApplications()
{
  local curHasNewApplication = hasNewApplication
  hasNewApplication = false
  foreach (application in squadData.applications)
    if (application.isNewApplication == true)
      {
        hasNewApplication = true
        break
      }
   if (curHasNewApplication != hasNewApplication)
     ::broadcastEvent(squadEvent.NEW_APPLICATIONS)
}

function g_squad_manager::addMember(uid)
{
  removeInvitedPlayers(uid)
  local memberData = SquadMember(uid)
  squadData.members[uid] <- memberData
  removeApplication(uid.tointeger())
  requestMemberData(uid)

  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::removeMember(uid)
{
  local memberData = getMemberData(uid)
  if (memberData == null)
    return

  squadData.members.rawdelete(memberData.uid)
  ::update_contacts_by_list([memberData.getData()])

  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::updatePlatformInfo()
{
  local playerPlatforms = []
  local checksArray = [getMembers(), getInvitedPlayers(), getApplicationsToSquad()]
  foreach (idx, membersArray in checksArray)
    foreach (uid, member in membersArray)
    {
      if (platformModule.isXBoxPlayerName(member.name))
        ::u.appendOnce("xboxOne", playerPlatforms)
      else if (platformModule.isPS4PlayerName(member.name))
        ::u.appendOnce("ps4", playerPlatforms)
      else
        ::u.appendOnce("pc", playerPlatforms)
    }

  squadData.platformInfo = playerPlatforms
}

function g_squad_manager::onSquadDataChanged(data = null)
{
  local alreadyInSquad = isInSquad()
  local resSquadData = ::getTblValue("squad", data)

  local newSquadId = ::getTblValue("id", resSquadData)
  if (::is_numeric(newSquadId)) //bad squad data
    squadData.id = newSquadId.tostring() //!!FIX ME: why this convertion to string?
  else if (!alreadyInSquad)
  {
    ::script_net_assert_once("no squad id", "Error: received squad data without squad id")
    ::msquad.leave() //leave broken squad
    setState(squadState.NOT_IN_SQUAD)
    return
  }

  local resMembers = ::getTblValue("members", resSquadData, [])
  local newMembersData = {}
  foreach(uidInt64 in resMembers)
  {
    if (!::is_numeric(uidInt64))
      continue

    local uid = uidInt64.tostring()
    if (uid in squadData.members)
      newMembersData[uid] <- squadData.members[uid]
    else
      newMembersData[uid] <- SquadMember(uid)

    if (uid != ::my_user_id_str)
      requestMemberData(uid)
  }
  squadData.members = newMembersData

  updateInvitedData(::getTblValue("invites", resSquadData, []))

  updateApplications(::getTblValue("applications", resSquadData, []))

  updatePlatformInfo()

  cyberCafeSquadMembersNum = getSameCyberCafeMembersNum()
  _parseCustomSquadData(::getTblValue("data", resSquadData, null))
  local chatInfo = ::getTblValue("chat", resSquadData, null)
  if (chatInfo != null)
  {
    local chatName = ::getTblValue("id", chatInfo, "")
    if (!::u.isEmpty(chatName))
      squadData.chatInfo.name = chatName
  }

  if (setState(squadState.IN_SQUAD)) {
    updateMyMemberData(::g_user_utils.getMyStateData())
    if (isSquadLeader()) {
      updatePresenceSquad()
      updateSquadData()
    }
    if (getPresence().isInBattle)
      ::g_popups.add(::loc("squad/name"), ::loc("squad/wait_until_battle_end"))
  }
  updateCurrentWWOperation()
  joinSquadChatRoom()

  if (isSquadLeader() && !readyCheck())
    ::queues.leaveAllQueues()

  if (!alreadyInSquad)
    checkUpdateStatus(squadStatusUpdateState.MENU)

  squadData.leaderGameModeId = resSquadData?.data?.leaderGameModeId ?? ""
  squadData.leaderBattleRating = resSquadData?.data?.leaderBattleRating ?? 0

  ::broadcastEvent(squadEvent.DATA_UPDATED)

  local lastReadyness = isMeReady()
  local currentReadyness = lastReadyness || isSquadLeader()
  if (lastReadyness != currentReadyness || !alreadyInSquad)
    setReadyFlag(currentReadyness)

  local lastCrewsReadyness = isMyCrewsReady
  local currentCrewsReadyness = lastCrewsReadyness || isSquadLeader()
  if (lastCrewsReadyness != currentCrewsReadyness || !alreadyInSquad)
    setCrewsReadyFlag(currentCrewsReadyness)

  ::g_world_war.checkOpenGlobalBattlesModal()
}

function g_squad_manager::_parseCustomSquadData(data)
{
  local chatInfo = ::getTblValue("chatInfo", data, null)
  if (chatInfo != null)
    squadData.chatInfo = chatInfo
  else
    squadData.chatInfo = {name = "", password = ""}

  local wwOperationInfo = ::getTblValue("wwOperationInfo", data, null)
  if (wwOperationInfo != null)
    squadData.wwOperationInfo = wwOperationInfo
  else
    squadData.wwOperationInfo = { id = -1, country = "", battle = null }

  local properties = ::getTblValue("properties", data)
  local property = null
  local isPropertyChange = false
  if (::u.isTable(properties))
    foreach(key, value in properties)
    {
      property = squadData?.properties?[key]
      if (::u.isEqual(property, value))
        continue

      squadData.properties[key] <- value
      isPropertyChange = true
    }
  if (isPropertyChange)
    ::broadcastEvent(squadEvent.PROPERTIES_CHANGED)
  squadData.presence = data?.presence ?? clone DEFAULT_SQUAD_PRESENCE
  squadData.psnSessionId = data?.psnSessionId ?? ""
}

function g_squad_manager::checkMembersPkg(pack) //return list of members dont have this pack
{
  local res = []
  if (!isInSquad())
    return res

  foreach(uid, memberData in squadData.members)
    if (memberData.missedPkg != null && ::isInArray(pack, memberData.missedPkg))
      res.append({ uid = uid, name = memberData.name })

  return res
}

function g_squad_manager::getSquadMembersDataForContact()
{
  local contactsData = {}

  if (!isInSquad())
    return contactsData

  local leaderUid = getLeaderUid()
  if (leaderUid != ::my_user_id_str)
    contactsData[leaderUid] <- getLeaderNick()

  foreach(uid, memberData in squadData.members)
    if (uid != leaderUid && uid != ::my_user_id_str)
        contactsData[uid] <- memberData.name

  return contactsData
}

function g_squad_manager::checkUpdateStatus(newStatus)
{
  if (lastUpdateStatus == newStatus || !isInSquad())
    return

  lastUpdateStatus = newStatus
  ::g_squad_utils.updateMyCountryData()
}

function g_squad_manager::getSquadRoomId()
{
  return ::getTblValue("sessionRoomId", getSquadLeaderData(), "")
}

function g_squad_manager::updatePresenceSquad(shouldUpdateSquadData = false)
{
  if (!isSquadLeader())
    return

  local presence = ::g_presence_type.getCurrent()
  local presenceParams = presence.getParams()
  if (!::u.isEqual(squadData.presence, presenceParams))
  {
    squadData.presence = presenceParams
    if (shouldUpdateSquadData)
      updateSquadData()
  }
}

function g_squad_manager::getPresence()
{
  return ::g_presence_type.getByPresenceParams(squadData?.presence ?? {})
}

function g_squad_manager::onEventUpdateEsFromHost(p)
{
  checkUpdateStatus(squadStatusUpdateState.BATTLE)
}

function g_squad_manager::onEventNewSceneLoaded(p)
{
  if (::isInMenu())
    checkUpdateStatus(squadStatusUpdateState.MENU)
}

function g_squad_manager::onEventBattleEnded(p)
{
  if (::isInMenu())
    checkUpdateStatus(squadStatusUpdateState.MENU)
}

function g_squad_manager::onEventSessionDestroyed(p)
{
  if (::isInMenu())
    checkUpdateStatus(squadStatusUpdateState.MENU)
}

function g_squad_manager::onEventChatConnected(params)
{
  joinSquadChatRoom()
}

function g_squad_manager::onEventApproveLastPs4SquadInvite(params)
{
  joinSquadChatRoom()
}

function g_squad_manager::onEventContactsUpdated(params)
{
  local isChanged = false
  local contact = null
  foreach (uid, memberData in getInvitedPlayers())
  {
    contact = ::getContact(uid)
    if (contact == null)
      continue

    memberData.update(contact)
    isChanged = true
  }

  if (isChanged)
    ::broadcastEvent(squadEvent.INVITES_CHANGED)

  isChanged = false
  foreach (uid, memberData in getApplicationsToSquad())
  {
    contact = ::getContact(uid.tostring())
    if (contact == null)
      continue

    if (memberData.update(contact))
      isChanged = true
  }
  if (isChanged)
    ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED {})
}

function g_squad_manager::onEventAvatarChanged(params)
{
  updateMyMemberData()
}

function g_squad_manager::onEventCrewTakeUnit(params)
{
  updateMyMemberData()
}

function g_squad_manager::onEventUnitRepaired(p)
{
  ::g_squad_utils.updateMyCountryData()
}

function g_squad_manager::onEventCrossPlayOptionChanged(p)
{
  updateMyMemberData()
}

function g_squad_manager::onEventMatchingDisconnect(params)
{
  reset()
}

function g_squad_manager::onEventMatchingConnect(params)
{
  reset()
  checkForSquad()
}

function g_squad_manager::onEventLoginComplete(params)
{
  initSquadSizes()
  reset()
  checkForSquad()
}

function g_squad_manager::onEventLoadingStateChange(params)
{
  if (::is_in_flight())
    setReadyFlag(false)

  updatePresenceSquad(true)
}

function g_squad_manager::onEventWWLoadOperation(params)
{
  updateCurrentWWOperation()
  updatePresenceSquad()
  updateSquadData()
}

function g_squad_manager::updateCurrentWWOperation()
{
  if (!isSquadLeader())
    return

  local wwOperationId = ::ww_get_operation_id()
  local country = ::get_profile_country_sq()
  if (wwOperationId > -1)
  {
    local wwOperation = ::g_ww_global_status.getOperationById(wwOperationId)
    if (wwOperation)
      country = wwOperation.getMyAssignCountry() || country
  }

  squadData.wwOperationInfo.id = wwOperationId
  squadData.wwOperationInfo.country = country
}

function g_squad_manager::startWWBattlePrepare(battleId = null)
{
  if (!isSquadLeader())
    return

  if (getWwOperationBattle() == battleId)
    return

  squadData.wwOperationInfo.battle <- battleId
  squadData.wwOperationInfo.id = ::ww_get_operation_id()
  squadData.wwOperationInfo.country = ::get_profile_country_sq()

  updatePresenceSquad()
  updateSquadData()
}

function g_squad_manager::getLockedCountryData()
{
  if (!isPrepareToWWBattle())
    return null

  return {
    country = getWwOperationCountry()
    reasonText = ::loc("worldWar/cantChangeCountryInBattlePrepare")
  }
}

function g_squad_manager::getNotInvitedToSessionUsersList()
{
  if (!isSquadLeader())
    return []

  local res = []
  foreach (uid, member in getMembers())
    if (member.online
        && !member.isMe()
        && !canInvitePlayerToSessionByName(member.name) )
      res.append(member)
  return res
}

function g_squad_manager::cancelWwBattlePrepare()
{
  startWWBattlePrepare() // cancel battle prepare if no args
}

function g_squad_manager::onEventWWStopWorldWar(params)
{
  if (getWwOperationId() == -1)
    return

  if (!isInSquad() || isSquadLeader()) {
    squadData.wwOperationInfo = { id = -1, country = "", battle = null }
  }
  updatePresenceSquad()
  updateSquadData()
}

function g_squad_manager::isPrepareToWWBattle()
{
  return getWwOperationBattle() &&
         getWwOperationId() >= 0 &&
         !::u.isEmpty(getWwOperationCountry())
}

function g_squad_manager::onEventLobbyStatusChange(params)
{
  if (!::SessionLobby.isInRoom())
    setReadyFlag(false)

  updateMyMemberData()
  updatePresenceSquad(true)
}

function g_squad_manager::onEventQueueChangeState(params)
{
  if (!::queues.hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
    setCrewsReadyFlag(false)

  updatePresenceSquad(true)
}

function g_squad_manager::isMemberDataVehicleChanged(currentData, receivedData)
{
  local currentCountry = currentData?.country ?? ""
  local receivedCountry = receivedData?.country ?? ""
  if (currentCountry != receivedCountry)
    return true

  if (currentData?.selSlots?[currentCountry] != receivedData?.selSlots?[receivedCountry])
    return true

  if (!::u.isEqual(battleRating.getCrafts(currentData), battleRating.getCrafts(receivedData)))
    return true

  return false
}

function g_squad_manager::onEventBattleRatingChanged(params)
{
  setLeaderData()
}

function g_squad_manager::onEventCurrentGameModeIdChanged(params)
{
  setLeaderData(false)
}

function g_squad_manager::onEventEventsDataUpdated(params)
{
  setLeaderData(false)
}

function g_squad_manager::setLeaderData(isActualBR = true)
{
  if (!isSquadLeader())
    return

  local currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
  if (!isActualBR && squadData.leaderGameModeId == currentGameModeId)
    return

  local data = clone squadData
  data.leaderBattleRating = isActualBR ? battleRating.getBR() : 0
  data.leaderGameModeId = isActualBR ? battleRating.getRecentGameModeId() : currentGameModeId
  setSquadData(data)
}

function g_squad_manager::getMembersNotAllowedInWorldWar()
{
  local res = []
  foreach (uid, member in getMembers())
    if (!member.isWorldWarAvailable)
      res.append(member)

  return res
}

::cross_call_api.squad_manger <- ::g_squad_manager

::g_script_reloader.registerPersistentDataFromRoot("g_squad_manager")

::subscribe_handler(::g_squad_manager, ::g_listener_priority.DEFAULT_HANDLER)
