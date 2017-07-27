local MRoomsHandlers = class {
  hostId = null
  roomId = null
  room   = null
  roomMembers = []
  connectAllowed = null
  roomOps = {}
  hostReady = null
  selfReady = null

  constructor()
  {
    hostId = null
    roomId = null
    room   = null
    roomMembers = []
    connectAllowed = null
    roomOps = {}
    hostReady = null
    selfReady = null

    foreach (notificationName, callback in
              {
                ["*.on_room_invite"] = onRoomInvite.bindenv(this),
                ["mrooms.on_host_notify"] = onHostNotify.bindenv(this),
                ["mrooms.on_room_member_joined"] = onRoomMemberJoined.bindenv(this),
                ["mrooms.on_room_member_leaved"] = onRoomMemberLeft.bindenv(this),
                ["mrooms.on_room_attributes_changed"] = onRoomAttrChanged.bindenv(this),
                ["mrooms.on_room_member_attributes_changed"] = onRoomMemberAttrChanged.bindenv(this),
                ["mrooms.on_room_destroyed"] = onRoomDestroyed.bindenv(this),
                ["mrooms.on_room_member_kicked"] = onRoomMemberKicked.bindenv(this)
              }
            )
      ::matching_rpc_subscribe(notificationName, callback)
  }

  function getRoomId()
  {
    return roomId
  }

  function hasSession()
  {
    return hostId != null
  }

  function isPlayerRoomOperator(user_id)
  {
    return (user_id in roomOps)
  }

  function __cleanupRoomState()
  {
    if (room == null)
      return

    hostId = null
    roomId = null
    room   = null
    roomMembers = []
    roomOps = {}
    connectAllowed = null
    hostReady = null
    selfReady = null
    ::reset_room_key()

    notify_room_destroyed({})
  }

  function __onHostConnectReady()
  {
    hostReady = true
    if (selfReady)
      connectToHost()
  }

  function __onSelfReady()
  {
    selfReady = true
    if (hostReady)
      connectToHost()
  }

  function __addRoomMember(member)
  {
    if (getTblValue("operator", member.public))
      roomOps[member.userId] <- true

    if (getTblValue("host", member.public))
    {
      dagor.debug(format("found host %s (%s)", member.name, member.userId.tostring()))
      hostId = member.userId
    }

    local curMember = __getRoomMember(member.userId)
    if (curMember == null)
      roomMembers.append(member)
    __updateMemberAttributes(member, curMember)
  }

  function __getRoomMember(user_id)
  {
    foreach (idx, member in roomMembers)
      if (member.userId == user_id)
        return member
    return null
  }

  function __getMyRoomMember()
  {
    foreach (idx, member in roomMembers)
      if (is_my_userid(member.userId))
        return member
    return null
  }

  function __removeRoomMember(user_id)
  {
    foreach (idx, member in roomMembers)
    {
      if (member.userId == user_id)
      {
        roomMembers.remove(idx)
        break
      }
    }

    if (user_id == hostId)
    {
      hostId = null
      connectAllowed = null
      hostReady = null
    }

    if (user_id in roomOps)
      delete roomOps[user_id]

    if (is_my_userid(user_id))
      __cleanupRoomState()
  }

  function __updateMemberAttributes(member, cur_member = null)
  {
    if (cur_member == null)
      cur_member = __getRoomMember(member.userId)
    if (cur_member == null)
    {
      dagor.debug(format("failed to update member attributes. member not found in room %s",
                          member.userId.tostring()))
      return
    }
    __mergeAttribs(member, cur_member)

    if (member.userId == hostId)
    {
      if (getTblValueByPath("public.connect_ready", member, false))
        __onHostConnectReady()
    }
    else if (is_my_userid(member.userId))
    {
      local readyStatus = getTblValueByPath("public.ready", member, null)
      if (readyStatus == true)
        __onSelfReady()
      else if (readyStatus == false)
        selfReady = false
    }
  }

  function __mergeAttribs(attr_from, attr_to)
  {
    local updateAttribs = function(upd_data, attribs)
    {
      foreach (key, value in upd_data)
      {
        if (value == null && (key in attribs))
          delete attribs[key]
        else
          attribs[key] <- value
      }
    }

    local pub = getTblValue("public", attr_from)
    local priv = getTblValue("private", attr_from)

    if (typeof priv == "table")
    {
      if ("private" in attr_to)
        updateAttribs(priv, attr_to.private)
      else
        attr_to.private <- priv
    }
    if (typeof pub == "table")
    {
      if ("public" in attr_to)
        updateAttribs(pub, attr_to.public)
      else
        attr_to.public <- pub
    }
  }


  // notifications
  function onRoomInvite(notify, send_resp)
  {
    roomId = notify.roomId
    local inviteData = notify.invite_data
    if (!(typeof inviteData == "table"))
      inviteData = {}
    inviteData.roomId <- roomId

    if (notify_room_invite(inviteData))
      send_resp({accept = true})
    else
      send_resp({accept = false})
  }

  function onRoomMemberJoined(member)
  {
    if (!room)
      return

    dagor.debug(format("%s (%s) joined to room", member.name, member.userId.tostring()))
    __addRoomMember(member)

    notify_room_member_joined(member)
  }

  function onRoomMemberLeft(member)
  {
    if (!room)
      return

    dagor.debug(format("%s (%s) left from room", member.name, member.userId.tostring()))
    __removeRoomMember(member.userId)
    notify_room_member_leaved(member)
  }

  function onRoomMemberKicked(member)
  {
    if (!room)
      return

    dagor.debug(format("%s (%s) kicked from room", member.name, member.userId.tostring()))
    __removeRoomMember(member.userId)
    notify_room_member_kicked(member)
  }

  function onRoomAttrChanged(notify)
  {
    if (!room)
      return

    __mergeAttribs(notify, room)
    notify_room_attribs_changed(notify)
  }

  function onRoomMemberAttrChanged(notify)
  {
    if (!room)
      return

    __updateMemberAttributes(notify)
    notify_room_member_attribs_changed(notify)
  }

  function onRoomDestroyed(notify)
  {
    __cleanupRoomState()
  }

  function onHostNotify(notify)
  {
    debugTableData(notify)
    if (notify.hostId != hostId)
    {
      dagor.debug("warning: got host notify from host that is not in current room")
      return
    }

    if (notify.roomId != getRoomId())
    {
      dagor.debug("warning: got host notify for wrong room")
      return
    }

    if (notify.message == "connect-allowed")
    {
      connectAllowed = true
      connectToHost()
    }
  }

  function onRoomJoinCb(resp)
  {
    if (room != null)
      return

    room = resp
    roomId = room.roomId
    foreach (member in room.members)
      __addRoomMember(member)

    if (getTblValue("connect_on_join", room.public))
    {
      dagor.debug("room with auto-connect feature")
      selfReady = true
      __onSelfReady()
    }
  }

  function onRoomLeaveCb()
  {
    __cleanupRoomState()
  }

  function connectToHost()
  {
    dagor.debug("connectToHost")
    if (!hasSession())
      return

    local host = __getRoomMember(hostId)
    if (!host)
    {
      dagor.debug("connectToHost failed: host is not in the room")
      return
    }

    local me = __getMyRoomMember()
    if (!me)
    {
      dagor.debug("connectToHost failed: player is not in the room")
      return
    }

    local hostPub = host.public
    local roomPub = room.public

    ::connect_to_host(hostPub.ip, hostPub.port,
                      roomPub.room_key, me.private.auth_key,
                      getTblValue("sessionId", roomPub, roomId))
  }
}

g_mrooms_handlers <- MRoomsHandlers()

function is_my_userid(user_id)
{
  if (typeof user_id == "string")
    return user_id == ::my_user_id_str
  return user_id == ::my_user_id_int64
}

// mrooms API

function is_host_in_room()
{
  return g_mrooms_handlers.hasSession()
}

function create_room(params, cb)
{
  matching_api_func("mrooms.create_room",
                    function(resp)
                    {
                      if (::checkMatchingError(resp, false))
                        g_mrooms_handlers.onRoomJoinCb(resp)
                      cb(resp)
                    },
                    params)
}

function destroy_room(params, cb)
{
  matching_api_func("mrooms.destroy_room", cb, params)
}

function join_room(params, cb)
{
  matching_api_func("mrooms.join_room",
                    function(resp)
                    {
                      if (::checkMatchingError(resp, false))
                        g_mrooms_handlers.onRoomJoinCb(resp)
                      cb(resp)
                    },
                    params)
}

function leave_room(params, cb)
{
  matching_api_func("mrooms.leave_room",
                    function(resp)
                    {
                      g_mrooms_handlers.onRoomLeaveCb()
                      cb(resp)
                    },
                    params)
}

function set_member_attributes(params, cb)
{
  matching_api_func("mrooms.set_member_attributes", cb, params)
}

function set_room_attributes(params, cb)
{
  matching_api_func("mrooms.set_attributes", cb, params)
}

function kick_member(params, cb)
{
  matching_api_func("mrooms.kick_from_room", cb, params)
}

function room_ban_player(params, cb)
{
  matching_api_func("mrooms.ban_player", cb, params)
}

function room_unban_player(params, cb)
{
  matching_api_func("mrooms.unban_player", cb, params)
}

function room_start_session(params, cb)
{
  matching_api_func("mrooms.start_session", cb, params)
}

function room_set_password(params, cb)
{
  matching_api_func("mrooms.set_password", cb, params)
}

function room_set_ready_state(params, cb)
{
  matching_api_func("mrooms.set_ready_state", cb, params)
}

function invite_player_to_room(params, cb)
{
  matching_api_func("mrooms.invite_player", cb, params)
}

function fetch_rooms_list(params, cb)
{
  matching_api_func("mrooms.fetch_rooms_digest",
                    function (resp)
                    {
                      if (::checkMatchingError(resp, false))
                      {
                        foreach (room in getTblValue("digest", resp, []))
                        {
                          local hasPassword = getTblValueByPath("public.hasPassword", room, null)
                          if (hasPassword != null)
                            room.hasPassword <- hasPassword
                        }
                      }
                      cb(resp)
                    },
                    params)
}

function serialize_dyncampaign(params, cb)
{
  local priv = {
    dyncamp = {
      data = get_dyncampaign_b64blk()
    }
  }

  matching_api_func("mrooms.set_attributes", cb, {private = priv})
}

function get_current_room()
{
  local roomId = ::g_mrooms_handlers.getRoomId()
  return roomId ? roomId : INVALID_ROOM_ID
}

function leave_session()
{
  if (::g_mrooms_handlers.getRoomId())
    leave_room({}, function(resp) {})
}

function is_player_room_operator(user_id)
{
  return ::g_mrooms_handlers.isPlayerRoomOperator(user_id)
}

