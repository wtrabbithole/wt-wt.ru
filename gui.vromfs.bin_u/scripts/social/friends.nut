local psnApi = require("scripts/social/psnWebApi.nut")

local platformModule = require("scripts/clientState/platform.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

::no_dump_facebook_friends <- {}
::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS <- 200
::PS4_UPDATE_TIMER_LIMIT <- 300000
::last_update_ps4_friends <- -::PS4_UPDATE_TIMER_LIMIT

::g_script_reloader.registerPersistentData("SocialGlobals", ::getroottable(), ["no_dump_facebook_friends"])

local ps4TitleId = ::is_platform_ps4? ::ps4_get_title_id() : ""
local isFirstPs4FriendsUpdate = true

function addSocialFriends(blk, group, silent = false)
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

  ::on_facebook_destroy_waitbox()
  if (silent)
    return

  if (addedFriendsNumber == 0)
    resultMessage = ::loc("msgbox/no_friends_added");
  else if (addedFriendsNumber == 1)
    resultMessage = ::loc("msgbox/added_friends_one");
  else
    resultMessage = format(::loc("msgbox/added_friends_number"), addedFriendsNumber)

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
      {
        ::addSocialFriends(blk, ::EPLX_PS4_FRIENDS)
        foreach(userId, info in blk)
        {
          local friend = {}
          friend["accountId"] <- info.id
          friend["onlineId"] <- info.nick.slice(1)
          ::ps4_console_friends[info.nick] <- friend
        }
      }
      else
      {
        local selectedPlayerName = ""
        local selectedPlayerAccountId = 0
        local selected = ::ps4_selected_friend()
        if (::u.isString(selected))
        {
          selectedPlayerName = selected
        }
        else if (::u.isDataBlock(selected))
        {
          selectedPlayerName = selected.onlineId
          selectedPlayerAccountId = selected.accountId
        }
        else
          return

        local msgText = ::loc("msgbox/no_psn_friends_added")
        local buttonsArray = [["ok", function() {}]]
        local defaultButton = "ok"
        local inviteConfig = {}

        local path = "PS4_Specific/invitationsRecievers/" + selectedPlayerName
        local isSecondTry = ::load_local_account_settings(path, false)
        if (!isSecondTry)
        {
            inviteConfig = {
                             targetOnlineId = selectedPlayerName,
                             targetAccountId = selectedPlayerAccountId,
                             inviteType = "gameStart",
                             expireMinutes = 1440
                           }
          msgText += "\n" + ::loc("msgbox/send_game_invitation", {friendName = selectedPlayerName})
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
  // We MUST do this on first opening, even if it is in battle/respawn
  if (!::isInMenu() && !isFirstPs4FriendsUpdate)
    return

  isFirstPs4FriendsUpdate = false
  if (::is_platform_ps4 && ::dagor.getCurTime() - ::last_update_ps4_friends > ::PS4_UPDATE_TIMER_LIMIT)
  {
    ::last_update_ps4_friends = ::dagor.getCurTime()
    ::getPS4FriendsFromIndex(0)
  }
}

function getPS4FriendsFromIndex(index)
{
  local cb = function(response, error) {
    debugTableData(response)
    if (error)
      return
    if (index == 0) // Initial chunk of friends from WebAPI
      ::resetPS4ContactsGroup()

    local size = (response?.size || 0) + (response?.start || 0)
    local endIndex = size >= (response?.totalResults || 0) ? 0 : size

    ::addContactGroup(::EPLX_PS4_FRIENDS)
    ::processPS4FriendsFromArray((response?.friendList || []), endIndex)
    ::broadcastEvent(contactEvent.CONTACTS_UPDATED)
  }
  psnApi.send(psnApi.profile.listFriends(index, ::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS), cb)
}

function processPS4FriendsFromArray(ps4FriendsArray, lastIndex)
{
  foreach (idx, playerBlock in ps4FriendsArray)
  {
    local name = "*" + playerBlock.user.onlineId
    ::ps4_console_friends[name] <- playerBlock.user
    ::ps4_console_friends[name].presence <- playerBlock.presence
  }

  if (ps4FriendsArray.len() == 0 || lastIndex == 0)
    ::movePS4ContactsToSpecificGroup()
  else
    ::getPS4FriendsFromIndex(lastIndex)
}

function resetPS4ContactsGroup()
{
  ::u.extend(::contacts[::EPL_FRIENDLIST], ::contacts[::EPLX_PS4_FRIENDS])
  ::contacts[::EPL_FRIENDLIST].sort(::sortContacts)
  ::g_contacts.removeContactGroup(::EPLX_PS4_FRIENDS)
  ::ps4_console_friends.clear()
}

function movePS4ContactsToSpecificGroup()
{
  for (local i = ::contacts[::EPL_FRIENDLIST].len()-1; i >= 0; i--)
  {
    local friendBlock = ::contacts[::EPL_FRIENDLIST][i]
    if (friendBlock.name in ::ps4_console_friends)
    {
      ::contacts[::EPLX_PS4_FRIENDS].append(friendBlock)
      ::contacts[::EPL_FRIENDLIST].remove(i)
      ::dagor.debug(::format("Change contacts group from '%s' to '%s', for '%s', uid %s",
        ::EPL_FRIENDLIST, ::EPLX_PS4_FRIENDS, friendBlock.name, friendBlock.uid))
    }
  }

  ::contacts[::EPLX_PS4_FRIENDS].sort(::sortContacts)
}

function isPlayerPS4Friend(playerName)
{
  return ::is_platform_ps4 && playerName in ::ps4_console_friends
}

function get_psn_account_id(playerName)
{
  if (!::is_platform_ps4)
    return null

  return ::ps4_console_friends?[playerName]?.accountId
}

local function initPs4Friends()
{
  isFirstPs4FriendsUpdate = true
}


subscriptions.addListenersWithoutEnv({
  LoginComplete    = @(p) initPs4Friends()
})

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

//----------------- <XBox One> --------------------------

function xbox_on_add_remove_friend_closed(playerStatus)
{
  if (playerStatus == XBOX_PERSON_STATUS_CANCELED)
    return

  ::g_contacts.xboxFetchContactsList()
}

function xbox_get_people_list_callback(playersList = [])
{
  ::g_contacts.proceedXboxPlayersListFromCallback(playersList, ::EPL_FRIENDLIST)
  ::xbox_get_avoid_list_async()
}

function xbox_get_avoid_list_callback(playersList = [])
{
  ::g_contacts.proceedXboxPlayersListFromCallback(playersList, ::EPL_BLOCKLIST)
}

//---------------- </XBox One> --------------------------
