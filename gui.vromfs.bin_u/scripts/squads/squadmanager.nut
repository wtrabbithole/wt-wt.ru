enum squadEvent
{
  DATA_UPDATED = "SquadDataUpdated"
  SET_READY = "SquadSetReady"
  STATUS_CHANGED = "SquadStatusChanged"
  PLAYER_INVITED = "SquadPlayerInvited"
  INVITES_CHANGED = "SquadInvitesChanged"
}

enum squadStatusUpdateState {
  NONE
  MENU
  BATTLE
}

enum SquadState
{
  NOT_IN_SQUAD
  SQUAD_LEADER //leader cant be offline or not ready.
  SQUAD_MEMBER
  SQUAD_MEMBER_READY
  SQUAD_MEMBER_OFFLINE
}

const DEFAULT_SQUADS_VERSION = 1
const SQUADS_VERSION = 2

g_squad_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["squadData", "meReady", "lastUpdateStatus"]

  maxSquadSize = 4
  maxInvitesCount = 9

  cyberCafeSquadMembersNum = -1
  squadData = {
    id = ""
    members = {}
    invitedPlayers = {}
    chatInfo = {
      name = ""
      password = ""
    }
    wwOperationInfo = {
      id = -1
      country = ""
    }
  }

  meReady = false
  lastUpdateStatus = squadStatusUpdateState.NONE
  roomCreateInProgress = false
}

function g_squad_manager::updateMyMemberData(data = null)
{
  if (!isInSquad())
    return

  if (data == null)
    data = ::g_user_utils.getMyStateData()

  data.isReady <- isMeReady()
  data.squadsVersion <- SQUADS_VERSION

  local wwOperations = {}
  if (::is_worldwar_enabled())
    foreach (wwOperation in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getList())
    {
      if (!wwOperation.isValid())
        continue

      local country = wwOperation.getMyAssignCountry() || wwOperation.getMyClanCountry()
      if (country != null)
        wwOperations[wwOperation.id] <- country
    }
  data.wwOperations <- wwOperations
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

  return !::u.isEmpty(squadData.id)
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

function g_squad_manager::getInvitedPlayers()
{
  return squadData.invitedPlayers
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
  return squadData.wwOperationInfo.id
}

function g_squad_manager::getWwOperationCountry()
{
  return squadData.wwOperationInfo.country
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
  if (!isInSquad())
    return checkAutosquad && ::SessionLobby.isMemberInMySquadByName(name)

  return _getSquadMemberByName(name) != null
}

function g_squad_manager::canInviteMember()
{
  return canManageSquad() && (!isInSquad() || isSquadLeader()) && !isInvitedMaxPlayers()
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

function g_squad_manager::getSquadSize(includeInvites = false)
{
  if (!isInSquad())
    return 0

  local res = squadData.members.len()
  if (includeInvites)
    res += getInvitedPlayers().len()

  return res
}

function g_squad_manager::isSquadFull()
{
  return getSquadSize() >= maxSquadSize
}

function g_squad_manager::isInvitedMaxPlayers()
{
  return isSquadFull() || getInvitedPlayers().len() >= maxInvitesCount
}

function g_squad_manager::getPlayerStatusInMySquad(uid)
{
  if (!isInSquad())
    return SquadState.NOT_IN_SQUAD

  if (getLeaderUid() == uid)
    return SquadState.SQUAD_LEADER

  local memberData = getMemberData(uid)
  if (memberData == null)
    return SquadState.NOT_IN_SQUAD

  if (!memberData.online)
    return SquadState.SQUAD_MEMBER_OFFLINE
  if (memberData.isReady)
    return SquadState.SQUAD_MEMBER_READY
  return SquadState.SQUAD_MEMBER
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

function g_squad_manager::getOfflineMembers()
{
  local res = []
  if (!isInSquad())
    return res

  foreach(uid, memberData in squadData.members)
    if (memberData.online == false)
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

  if (needUpdateMemberData)
    updateMyMemberData(::g_user_utils.getMyStateData())

  ::broadcastEvent(squadEvent.SET_READY)
}

function g_squad_manager::createSquad(callback)
{
  if (!::has_feature("Squad"))
    return

  if (isInSquad())
    return

  if (!canManageSquad() || ::queues.isAnyQueuesActive())
    return

  local fullCallback = (@(callback) function() {
                         ::g_squad_manager.updateMyMemberData(::g_user_utils.getMyStateData())

                         if (callback != null)
                           callback()

                         ::broadcastEvent(squadEvent.STATUS_CHANGED)
                       })(callback)

  ::msquad.create((@(fullCallback) function(response) {
                    ::g_squad_manager.requestSquadData(fullCallback)
                  })(fullCallback)
                 )
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
    password = squadData.chatInfo.password = ::gen_rnd_password(15)

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

function g_squad_manager::joinWwOperation()
{
  if (!isInSquad() || !::is_worldwar_enabled())
    return

  local wwOperationId = getWwOperationId()
  if (wwOperationId < 0 || wwOperationId == ::g_world_war.lastPlayedOperationId)
    return

  local wwOperation = ::g_ww_global_status.getOperationById(wwOperationId)
  if (wwOperation == null)
    return

  local wwOperationCountry = getWwOperationCountry()
  if (::u.isEmpty(wwOperationCountry))
    return

  local myOperationCountry = wwOperation.getMyAssignCountry() || wwOperation.getMyClanCountry()
  if (myOperationCountry != wwOperationCountry)
    return

  ::g_world_war.joinOperationById(wwOperationId, wwOperationCountry, true)
}

function g_squad_manager::updateSquadData()
{
  local data = {}
  data.chatInfo <- { name = getSquadRoomName(), password = getSquadRoomPassword() }
  data.wwOperationInfo <- { id = getWwOperationId(), country = getWwOperationCountry() }

  ::g_squad_manager.setSquadData(data)
}

function g_squad_manager::disbandSquad()
{
  if (!isSquadLeader())
    return

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
                       ::g_squad_manager.updateMyMemberData(::g_user_utils.getMyStateData())

                       if (::g_squad_manager.getSquadSize(true) == 1)
                         ::g_squad_utils.showAloneInSquadNotification()

                      ::broadcastEvent(squadEvent.STATUS_CHANGED)
                     }

                     local invites = ::getTblValue("invites", response, null)
                     if (invites != null)
                       foreach (squadId in invites)
                         ::g_invites.addInviteToSquad(squadId, squadId.tostring())
                   }

  ::msquad.requestInfo(callback, callback, {showError = false})
}

function g_squad_manager::requestSquadData(callback = null)
{
  local fullCallback = (@(callback) function(response) {
                         if ("squad" in response)
                           ::g_squad_manager.onSquadDataChanged(response)
                         else if (::g_squad_manager.isInSquad())
                           ::g_squad_manager.reset()

                         if (callback != null)
                           callback()
                       })(callback)

  ::msquad.requestInfo(fullCallback)
}

function g_squad_manager::leaveSquad()
{
  if (!isInSquad())
    return

  local callback = function(response) {
                     ::g_squad_manager.reset()
                   }

  ::msquad.leave(callback)
}

function g_squad_manager::inviteToSquad(uid)
{
  if (!isInSquad())
    return createSquad((@(uid) function() {::g_squad_manager.inviteToSquad(uid)})(uid))

  if (!isSquadLeader())
    return

  if (isSquadFull())
    return ::g_popups.add(null, ::loc("matching/SQUAD_FULL"))

  if (isInvitedMaxPlayers())
    return ::g_popups.add(null, ::loc("squad/maximum_intitations_sent"))

  ::msquad.invitePlayer(uid)
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

  local fullCallback = null
  if (callback != null)
    fullCallback = (@(callback) function(response) {
                     if (callback != null)
                       callback()
                   })(callback)

  ::msquad.revokeInvite(uid, fullCallback)
}

function g_squad_manager::dismissFromSquad(uid)
{
  if (!isSquadLeader())
    return

  ::msquad.dismissMember(uid)
}

function g_squad_manager::dismissFromSquadByName(name)
{
  if (!isSquadLeader())
    return

  local memeberData = _getSquadMemberByName(name)
  if (memeberData == null)
    return

  ::msquad.dismissMember(memeberData.uid)
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
  ::broadcastEvent(squadEvent.STATUS_CHANGED)
}

function g_squad_manager::acceptSquadInvite(sid)
{
  if (isInSquad())
    return

  local callback = function(response) {
                     local getDataCallback = function() {
                                               ::g_squad_manager.updateMyMemberData(::g_user_utils.getMyStateData())
                                               ::broadcastEvent(squadEvent.STATUS_CHANGED)
                                             }
                     ::g_squad_manager.requestSquadData(getDataCallback)
                   }

  ::msquad.acceptInvite(sid, callback)
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

  local callback = (@(uid) function(response) {
                      local receivedData = ::getTblValue("data", response, null)
                      if (receivedData == null)
                        return

                      local memberData = ::g_squad_manager.getMemberData(uid)
                      if (memberData == null)
                        return

                      local receivedMemberData = ::getTblValue("data", receivedData)
                      memberData.update(receivedMemberData)
                      local contact = ::getContact(memberData.uid, memberData.name)
                      contact.online = memberData.online = response.online
                      if (!response.online)
                        memberData.isReady = false

                      ::update_contacts_by_list([memberData.getData()])

                      if (::g_squad_manager.isSquadLeader())
                      {
                        if (!::g_squad_manager.readyCheck())
                          ::queues.leaveAllQueues()

                        if (::SessionLobby.canInviteIntoSession() && memberData.canJoinSessionRoom())
                          ::SessionLobby.invitePlayer(memberData.uid)
                      }

                      ::g_squad_manager.joinSquadChatRoom()

                      ::broadcastEvent(squadEvent.DATA_UPDATED)

                      local memberSquadsVersion = ::getTblValue("squadsVersion", receivedMemberData, DEFAULT_SQUADS_VERSION)
                      ::g_squad_utils.checkSquadsVersion(memberSquadsVersion)
                    })(uid)

  ::msquad.requestMemberData(uid, callback)
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
  ::queues.leaveAllQueues()
  ::g_chat.leaveSquadRoom()

  cyberCafeSquadMembersNum = -1

  squadData.id = ""
  local contactsUpdatedList = []
  foreach(id, memberData in squadData.members)
    contactsUpdatedList.append(memberData.getData())

  squadData.members.clear()
  squadData.invitedPlayers.clear()
  squadData.chatInfo = { name = "", password = "" }
  squadData.wwOperationInfo = { id = -1, country = "" }

  lastUpdateStatus = squadStatusUpdateState.NONE
  if (meReady)
    setReadyFlag(false, false)

  ::update_contacts_by_list(contactsUpdatedList)

  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
}

function g_squad_manager::addRequestedPlayer(uid)
{
  if (uid in squadData.invitedPlayers)
    return

  squadData.invitedPlayers[uid] <- SquadMember(uid, true)

  local contact = ::getContact(uid)
  if (contact != null)
    squadData.invitedPlayers[uid].update(contact)

  ::g_users_info_manager.requestInfo([uid])

  ::broadcastEvent(squadEvent.PLAYER_INVITED, { uid = uid })
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::removeRequestedPlayer(uid)
{
  if (!(uid in squadData.invitedPlayers))
    return

  squadData.invitedPlayers.rawdelete(uid)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

function g_squad_manager::addMember(uid)
{
  removeRequestedPlayer(uid)
  local memberData = SquadMember(uid)
  squadData.members[uid] <- memberData
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

  local invites = ::getTblValue("invites", resSquadData, [])
  squadData.invitedPlayers.clear()
  foreach (invitedUid in invites)
    addRequestedPlayer(invitedUid.tostring())

  cyberCafeSquadMembersNum = getSameCyberCafeMembersNum()
  _parseCustomSquadData(::getTblValue("data", resSquadData, null))
  local chatInfo = ::getTblValue("chat", resSquadData, null)
  if (chatInfo != null)
  {
    local chatName = ::getTblValue("id", chatInfo, "")
    if (!::u.isEmpty(chatName))
      squadData.chatInfo.name = chatName
  }
  joinSquadChatRoom()
  joinWwOperation()

  if (isSquadLeader() && !readyCheck())
    ::queues.leaveAllQueues()

  if (!alreadyInSquad)
    checkUpdateStatus(squadStatusUpdateState.MENU)

  ::broadcastEvent(squadEvent.DATA_UPDATED)

  local lastReadyness = isMeReady()
  local currentReadyness = lastReadyness || isSquadLeader()
  if (lastReadyness != currentReadyness || !alreadyInSquad)
    setReadyFlag(currentReadyness)
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
    squadData.wwOperationInfo = { id = -1, country = "" }
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
  if (!isInSquad())
    return

  local contactsData = {}
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

  if (lastUpdateStatus == squadStatusUpdateState.BATTLE)
    ::crews_list = get_crew_info()

  lastUpdateStatus = newStatus
  ::g_squad_utils.updateMyCountryData()
}

function g_squad_manager::getSquadRoomId()
{
  return ::getTblValue("sessionRoomId", getSquadLeaderData(), "")
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
}

function g_squad_manager::onEventAvatarChanged(params)
{
  updateMyMemberData()
}

function g_squad_manager::onEventCrewTakeUnit(params)
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
  reset()
  checkForSquad()
}

function g_squad_manager::onEventLoadingStateChange(params)
{
  if (::is_in_flight())
    setReadyFlag(false)
}

function g_squad_manager::onEventWWLoadOperation(params)
{
  if (!isSquadLeader())
    return

  local wwOperationId = ::g_world_war.lastPlayedOperationId
  local country = ::g_world_war.lastPlayedOperationCountry

  if (wwOperationId < 0 || getWwOperationId() == wwOperationId || ::u.isEmpty(country))
    return

  squadData.wwOperationInfo.id = wwOperationId
  squadData.wwOperationInfo.country = country

  updateSquadData()
}

function g_squad_manager::onEventWWStopWorldWar(params)
{
  if (getWwOperationId() == -1)
    return

  squadData.wwOperationInfo = { id = -1, country = "" }
  updateSquadData()
}

function g_squad_manager::onEventLobbyStatusChange(params)
{
  if (!::SessionLobby.isInRoom())
    setReadyFlag(false)

  updateMyMemberData()
}

::g_script_reloader.registerPersistentDataFromRoot("g_squad_manager")

::subscribe_handler(::g_squad_manager, ::g_listener_priority.DEFAULT_HANDLER)
