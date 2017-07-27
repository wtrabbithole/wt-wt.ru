::no_dump_facebook_friends <- {}
::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS <- 200
::PS4_UPDATE_TIMER_LIMIT <- 300000
::last_update_ps4_friends <- -::PS4_UPDATE_TIMER_LIMIT

::g_script_reloader.registerPersistentData("SocialGlobals", ::getroottable(), ["no_dump_facebook_friends"])

function addSocialFriends(blk, group)
{
  local addedFriendsNumber = 0
  local resultMessage = ""
  local players = {}

  foreach(userId, info in blk)
    players[userId] <- info.nick

  if (players.len())
  {
    if(!isInArray(group, ::contacts_groups))
      ::addContactGroup(group)
    addedFriendsNumber = ::addPlayersToContacts(players, group)
  }
  if (addedFriendsNumber == 0)
    resultMessage = ::loc("msgbox/no_friends_added");
  else if (addedFriendsNumber == 1)
    resultMessage = ::loc("msgbox/added_friends_one");
  else
    resultMessage = format(::loc("msgbox/added_friends_number"), addedFriendsNumber)

  ::on_facebook_destroy_waitbox()
  ::showInfoMsgBox(resultMessage, "friends_added")
}

//--------------- <PlayStation> ----------------------
function addPsnFriends()
{
  if (::ps4_show_friend_list_ex(true, true, false) == 1)
  {
    local taskId = ::ps4_find_friend()
    if (taskId < 0)
      return

    local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
    ::add_bg_task_cb(taskId, (@(progressBox) function () {
      ::destroyMsgBox(progressBox)
      local blk = ::DataBlock()
      blk = ::ps4_find_friends_result()
      if (blk.paramCount() || blk.blockCount())
        ::addSocialFriends(blk, ::EPLX_PS4_FRIENDS)
      else
      {
        local blockName = "PS4_Specific/invitationsRecievers"
        local selectedPlayer = ::ps4_selected_friend()
        if (typeof(selectedPlayer) != "string" || selectedPlayer == "")
          return

        local msgText = ::loc("msgbox/no_psn_friends_added")
        local buttonsArray = [["ok", function() {}]]
        local defaultButton = "ok"
        local inviteConfig = {}

        local path = blockName + "/" + selectedPlayer
        local isSecondTry = ::load_local_account_settings(path, false)
        if (!isSecondTry)
        {
          inviteConfig = {
                           target = selectedPlayer,
                           inviteType = "gameStart",
                           expireMinutes = 1440
                         }
          msgText += "\n" + ::loc("msgbox/send_game_invitation", {friendName = selectedPlayer})
          buttonsArray = [
                           ["yes", (@(path, inviteConfig) function() {
                                if (::sendInvitationPsn(inviteConfig) == 0)
                                  ::save_local_account_settings(path, true)
                              })(path, inviteConfig)],
                           ["no", function() {}]
                         ]
          defaultButton = "yes"
        }

        ::scene_msg_box("friends_added", null, msgText, buttonsArray, defaultButton)
      }
    })(progressBox))
  }
}

function update_ps4_friends()
{
  if (::is_platform_ps4 && ::dagor.getCurTime() - ::last_update_ps4_friends > ::PS4_UPDATE_TIMER_LIMIT)
  {
    ::last_update_ps4_friends = ::dagor.getCurTime()
    ::getPS4FriendsFromIndex(0)
    ::g_psn_mapper.updateAccountIdsList()
  }
}

function getPS4FriendsFromIndex(index)
{
  local blk = ::DataBlock()
  blk.apiGroup = "userProfile"
  blk.method = ::HTTP_METHOD_GET
  local query = ::format("/v1/users/%s/friendList?friendStatus=friend&offset=%d&limit=%d",
    ::ps4_get_online_id(), index, ::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS)
  blk.path = query
  blk.respSize = 8*1024

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    dagor.debug("Error: "+ret.error);
    dagor.debug("Error text: "+ret.errorStr);
  }
  else if ("response" in ret)
  {
    dagor.debug("json Response: "+ret.response);
    local parsedRetTable = ::parse_json(ret.response)

    local startIndex = ::getTblValue("start", parsedRetTable, 0)
    local size = ::getTblValue("size", parsedRetTable, 0)
    local endIndex = size >= ::getTblValue("totalResults", parsedRetTable, 0)? 0 : size

    ::addContactGroup(::EPLX_PS4_FRIENDS)
    ::processPS4FriendsFromArray(::getTblValue("friendList", parsedRetTable, []), endIndex)
  }
}

function processPS4FriendsFromArray(ps4FriendsArray, lastIndex)
{
  if (ps4FriendsArray.len() == 0)
    return

  for(local i = ::contacts[::EPL_FRIENDLIST].len()-1; i >= 0; i--)
  {
    foreach(num, ps4playerBlock in ps4FriendsArray)
    {
      local playerName = "*" + ps4playerBlock.onlineId
      ::ps4_console_friends[playerName] <- ps4playerBlock

      local friendBlock = ::contacts[::EPL_FRIENDLIST][i]
      if ((playerName) == friendBlock.name)
      {
        ::contacts[::EPLX_PS4_FRIENDS].append(friendBlock)
        ::contacts[::EPL_FRIENDLIST].remove(i)
        dagor.debug(::format("Change contacts group from '%s' to '%s', for '%s', uid %s",
          ::EPL_FRIENDLIST, ::EPLX_PS4_FRIENDS, friendBlock.name, friendBlock.uid))
        break
      }
    }
  }

  ::contacts[::EPLX_PS4_FRIENDS].sort(::sortContacts)

  if (lastIndex != 0)
    ::getPS4FriendsFromIndex(lastIndex+1)
}

function isPlayerPS4Friend(playerName)
{
  return ::is_platform_ps4 && playerName in ::ps4_console_friends
}
//--------------- </PlayStation> ----------------------

//------------------ <Steam> --------------------------
function addSteamFriendsOnStart()
{
  local cdb = ::get_local_custom_settings_blk();
  if (cdb.steamFriendsAdded != null && cdb.steamFriendsAdded)
    return;

  local friendListFreeSpace = ::EPL_MAX_PLAYERS_IN_LIST - ::contacts[::EPL_FRIENDLIST].len();
  if (friendListFreeSpace <= 0)
    return;

  if (::skip_steam_confirmations)
    addSteamFriends()
  else
    ::scene_msg_box("add_steam_friend", null, ::loc("msgbox/add_steam_friends"),
      [
        ["yes", function() { addSteamFriends() }],
        ["no",  function() {}],
      ], "no")

  cdb.steamFriendsAdded = true;
  save_profile(false);
}

function addSteamFriends()
{
  local taskId = ::steam_find_friends(::EPL_MAX_PLAYERS_IN_LIST)
  if (taskId < 0)
    return

  local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
  ::add_bg_task_cb(taskId, (@(progressBox) function () {
    ::destroyMsgBox(progressBox)
    local blk = ::DataBlock();
    blk = ::steam_find_friends_result();
    ::addSocialFriends(blk, ::EPL_STEAM)
  })(progressBox))
}
//------------------ </Steam> --------------------------

//-----------------<Facebook> --------------------------
function on_facebook_friends_loaded(blk)
{
  foreach(id, block in blk)
    ::no_dump_facebook_friends[id] <- block.name

  //TEST ONLY!
  //foreach (id, data in blk)
  //  dagor.debug("FACEBOOK FRIEND: id="+id+" name="+data.name)

  if(::no_dump_facebook_friends.len()==0)
  {
    ::on_facebook_destroy_waitbox()
    ::showInfoMsgBox(::loc("msgbox/no_friends_added"), "facebook_failed")
  }

  local inBlk = ::DataBlock()
  foreach(id, block in ::no_dump_facebook_friends)
    inBlk.id <- id.tostring()

  if(inBlk=="")
    return

  local taskId = ::facebook_find_friends(inBlk, ::EPL_MAX_PLAYERS_IN_LIST)
  if(taskId < 0)
  {
    ::on_facebook_destroy_waitbox()
    ::showInfoMsgBox(::loc("msgbox/no_friends_added"), "facebook_failed")
  }
  else
    ::add_bg_task_cb(taskId, function(){
        local resultBlk = ::facebook_find_friends_result()
        ::addSocialFriends(resultBlk, ::EPL_FACEBOOK)
        ::addContactGroup(::EPL_FACEBOOK)
      })
}
//-------------------- </Facebook> ----------------------------