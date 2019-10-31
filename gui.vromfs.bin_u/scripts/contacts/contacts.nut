local platformModule = require("scripts/clientState/platform.nut")
local xboxContactsManager = require("scripts/contacts/xboxContactsManager.nut")

::contacts_handler <- null
::ps4_console_friends <- {}
::contacts_sizes <- null
::EPLX_SEARCH <- "search"
::EPLX_CLAN <- "clan"
::EPLX_PS4_FRIENDS <- "ps4_friends"

::contacts_groups_default <- [::EPLX_SEARCH, ::EPL_FRIENDLIST, ::EPL_RECENT_SQUAD, /*::EPL_PLAYERSMET,*/ ::EPL_BLOCKLIST]
::contacts_groups <- []
::contacts_players <- {}
/*
  "12345" = {  //uid
    name = "WINLAY"
    uid = "12345"
    presence = { ... }
  }
*/
::contacts <- null
/*
{
  friend = [
    {  //uid
      name = "WINLAY"
      uid = "12345"
      presence = { ... }
    }
  ]
  met = []
  block = []
  search = []
}
*/

::g_contacts <- {}

foreach (fn in [
    "contactPresence.nut"
    "contact.nut"
    "playerStateTypes.nut"
    "contactsHandler.nut"
    "searchForSquadHandler.nut"
  ])
::g_script_reloader.loadOnce("scripts/contacts/" + fn)

g_contacts.onEventUserInfoManagerDataUpdated <- function onEventUserInfoManagerDataUpdated(params)
{
  local usersInfo = ::getTblValue("usersInfo", params, null)
  if (usersInfo == null)
    return

  ::update_contacts_by_list(usersInfo)
}

g_contacts.onEventUpdateExternalsIDs <- function onEventUpdateExternalsIDs(params)
{
  if (!(params?.request?.uid) || !(params?.externalIds))
    return

  local config = params.externalIds
  config.uid <- params.request.uid
  if (params?.request?.afterSuccessUpdateFunc)
    config.afterSuccessUpdateFunc <- params.request.afterSuccessUpdateFunc

  ::updateContact(config)
}

g_contacts.removeContactGroup <- function removeContactGroup(group)
{
  ::contacts.rawdelete(group)
  ::u.removeFrom(::contacts_groups, group)
}

g_contacts.removeContact <- function removeContact(uid, group)
{
  local uidIdx = ::contacts[group].findindex( @(p) p.uid == uid)
  if (uidIdx != null)
    ::contacts[group].remove(uidIdx)

  if (::g_contacts.isFriendsGroupName(group))
    ::clearContactPresence(uid)
}

g_contacts.getPlayerFullName <- function getPlayerFullName(name, clanTag = "", addInfo = "")
{
  return ::g_string.implode([::has_feature("Clans")? clanTag : "", name, addInfo], " ")
}

g_contacts.isFriendsGroupName <- function isFriendsGroupName(group)
{
  return group == ::EPLX_PS4_FRIENDS || group == ::EPL_FRIENDLIST
}

::missed_contacts_data <- {}

::g_script_reloader.registerPersistentData("ContactsGlobals", ::getroottable(),
  ["ps4_console_friends", "contacts_groups", "contacts_players", "contacts"])

::sortContacts <- function sortContacts(a, b)
{
  return b.presence.sortOrder <=> a.presence.sortOrder
    || ::english_russian_to_lower_case(a.name) <=> ::english_russian_to_lower_case(b.name)
}

::getContactsGroupUidList <- function getContactsGroupUidList(groupName)
{
  local res = []
  if (!(groupName in ::contacts))
    return res
  foreach(p in ::contacts[groupName])
    res.append(p.uid)
  return res
}

::isPlayerInContacts <- function isPlayerInContacts(uid, groupName)
{
  if (!(groupName in ::contacts) || ::u.isEmpty(uid))
    return false
  foreach(p in ::contacts[groupName])
    if (p.uid == uid)
      return true
  return false
}

::isPlayerNickInContacts <- function isPlayerNickInContacts(nick, groupName)
{
  if (!(groupName in ::contacts))
    return false
  foreach(p in ::contacts[groupName])
    if (p.name == nick)
      return true
  return false
}

::can_add_player_to_contacts_list <- function can_add_player_to_contacts_list(groupName)
{
  if (::contacts[groupName].len() < ::EPL_MAX_PLAYERS_IN_LIST)
    return true

  ::scene_msg_box("cant_add_contact", ::get_gui_scene(),
                  ::format(::loc("msg/cant_add/too_many_contacts"), ::EPL_MAX_PLAYERS_IN_LIST),
                  [["ok", function() { } ]], "ok")
  return false
}

::edit_players_list_in_contacts <- function edit_players_list_in_contacts(requestTable, groupName)
{
  local realGroupName = groupName == ::EPLX_PS4_FRIENDS? ::EPL_FRIENDLIST : groupName
  local blk = ::DataBlock()
  blk[realGroupName] <- ::DataBlock()

  local addList = []
  local removeList = []

  foreach (isAdding, playersList in requestTable)
    foreach (player in playersList)
    {
      if (isAdding)
        addList.append(player)
      else
        removeList.append(player)

      blk[realGroupName][player.uid] <- isAdding
      ::dagor.debug((isAdding? "Adding" : "Removing") + " player '" + player.name + "' (" + player.uid + ") to " + groupName + ", realGroupName " + realGroupName)
    }

  local result = ::request_edit_player_lists(blk, false)
  if (result)
  {
    foreach (isAdding, playersList in requestTable)
    {
      if (isAdding)
      {
        foreach (player in playersList)
        {
          if (groupName == ::EPL_FRIENDLIST && platformModule.isPS4PlayerName(player.name) && ::isPlayerPS4Friend(player.name))
            groupName = ::EPLX_PS4_FRIENDS
          ::contacts[groupName].append(player)
        }
      }
      else
      {
        foreach (player in playersList)
        {
          foreach(idx, p in ::contacts[groupName])
            if (p.uid == player.uid)
            {
              ::contacts[groupName].remove(idx)
              break
            }

          if (groupName == ::EPL_FRIENDLIST || groupName == ::EPLX_PS4_FRIENDS)
            ::clearContactPresence(player.uid)
        }
      }
    }
    ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, {groupName = groupName})
  }
  return result
}

::editPlayerInContacts <- function editPlayerInContacts(player, groupName, add) //playerConfig: { uid, name }
{
  if (add == ::isPlayerInContacts(player.uid, groupName))
    return -1 //no need to do something

  if (add && !::can_add_player_to_contacts_list(groupName))
    return -1

  local realGroupName = groupName == ::EPLX_PS4_FRIENDS? ::EPL_FRIENDLIST : groupName
  local blk = ::DataBlock()
  blk[realGroupName] <- ::DataBlock()
  blk[realGroupName][player.uid] <- add
  dagor.debug((add? "Adding" : "Removing") + " player '"+player.name+"' ("+player.uid+") to "+groupName + ", realGroupName " + realGroupName);

  local result = ::request_edit_player_lists(blk, false)
  if (result)
  {
    if (add)
    {
      if (groupName == ::EPL_FRIENDLIST && platformModule.isPS4PlayerName(player.name) && ::isPlayerPS4Friend(player.name))
        groupName = ::EPLX_PS4_FRIENDS
      ::contacts[groupName].append(player)
    }
    else
    {
      foreach(idx, p in ::contacts[groupName])
        if (p.uid == player.uid)
        {
          ::contacts[groupName].remove(idx)
          break
        }
      if (groupName == ::EPL_FRIENDLIST || groupName == ::EPLX_PS4_FRIENDS)
        ::clearContactPresence(player.uid)
      if (groupName == ::EPL_FACEBOOK && ::contacts[groupName].len() == 0)
        ::g_contacts.removeContactGroup(groupName)
    }
    ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, {groupName = groupName})
  }
  return result
}

::find_contact_by_name_and_do <- function find_contact_by_name_and_do(playerName, func) //return taskId if delayed.
{
  local contact = ::Contact.getByName(playerName)
  if (contact && contact?.uid != "")
  {
    func(contact)
    return null
  }

  local taskCallback = function(result = ::YU2_OK) {
    if (!func)
      return

    if (result == ::YU2_OK)
    {
      local searchRes = ::DataBlock()
      searchRes = ::get_nicks_find_result_blk()
      foreach(uid, nick in searchRes)
        if (nick == playerName)
        {
          func(::getContact(uid, playerName))
          return
        }
    }

    func(null)
    ::showInfoMsgBox(::loc("chat/error/item-not-found", { nick = playerName }), "incorrect_user")
  }

  local taskId = ::find_nicks_by_prefix(playerName, 1, false)
  ::g_tasker.addTask(taskId, null, taskCallback, taskCallback)
  return taskId
}

::send_friend_added_event <- function send_friend_added_event(friend_uid)
{
  matching_api_notify("mpresence.notify_friend_added",
      {
        friendId = friend_uid
      })
}


::editContactMsgBox <- function editContactMsgBox(player, groupName, add) //playerConfig: { uid, name }
{
  if (!player)
    return null

  if (!("uid" in player) || !player.uid || player.uid == "")
  {
    if (!("name" in player))
      return null

    return ::find_contact_by_name_and_do(
      player.name,
      @(contact) ::editContactMsgBox(contact, groupName, add)
    )
  }

  local contact = ::getContact(player.uid, player.name)
  if (contact.canOpenXBoxFriendsWindow(groupName))
  {
    contact.openXBoxFriendsEdit()
    return
  }

  if (add == ::isPlayerInContacts(player.uid, groupName))
    return

  if (groupName == ::EPL_FRIENDLIST)
  {
    if (add)
      ::send_friend_added_event(player.uid.tointeger())

    groupName = ::getFriendGroupName(player.name)
  }

  if (add)
  {
    local res = ::editPlayerInContacts(contact, groupName, true)
    local msg = ::loc("msg/added_to_" + groupName)
    if (res)
    {
      ::g_popups.add(null, format(msg, contact.getName()))
    }
  }
  else
  {
    local msg = ::loc("msg/ask_remove_from_" + groupName)
    ::scene_msg_box("remove_from_list", null, format(msg, contact.getName()), [
      ["ok", @() ::editPlayerInContacts(contact, groupName, false)],
      ["cancel", @() null ]
    ], "cancel")
  }
  return null
}

::addPlayersToContacts <- function addPlayersToContacts(players, groupName) //{ uid = name, uid2 = name2 }
{
  local addedPlayersNumber = 0;
  local editBlk = ::DataBlock()
  local realGroupName = groupName == ::EPLX_PS4_FRIENDS? ::EPL_FRIENDLIST : groupName

  editBlk[realGroupName] <- ::DataBlock()
  local groupChanged = false
  foreach(uid, nick in players)
  {
    editBlk[realGroupName][uid] <- true
    dagor.debug("Adding player '"+nick+"' ("+uid+") to "+groupName + ", realGroupName is " + realGroupName);

    local player = ::getContact(uid, nick)
    if ((groupName in ::contacts) && !::isPlayerInContacts(uid, groupName))
    {
      if (groupName == ::EPLX_PS4_FRIENDS && !platformModule.isPS4PlayerName(nick))
        groupName = ::EPL_FRIENDLIST

      ::contacts[groupName].append(player)
      if (groupName == ::EPLX_PS4_FRIENDS)
        ::ps4_console_friends[nick] <- player
      addedPlayersNumber++;
      groupChanged = true
      if (::contacts[groupName].len() > ::EPL_MAX_PLAYERS_IN_LIST)
        break;
    }
  }
  if (groupChanged)
    ::contacts[groupName].sort(::sortContacts)

  ::request_edit_player_lists(editBlk)

  if (groupChanged)
    ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, {groupName = groupName})

  return addedPlayersNumber;
}

::request_edit_player_lists <- function request_edit_player_lists(editBlk, checkFeature = true)
{
  local taskId = ::edit_player_lists(editBlk)
  local taskCallback = (@(checkFeature) function (result = null) {
    if (!checkFeature || ::has_feature("Friends"))
      ::reload_contact_list()
  })(checkFeature)
  return ::g_tasker.addTask(taskId, null, taskCallback, taskCallback)
}

::loadContactsToObj <- function loadContactsToObj(obj, owner=null)
{
  if (!::checkObj(obj))
    return

  local guiScene = obj.getScene()
  if (!::contacts_handler)
    ::contacts_handler = ::ContactsHandler(guiScene)
  ::contacts_handler.owner = owner
  ::contacts_handler.initScreen(obj)
}

::switchContactsObj <- function switchContactsObj(scene, owner=null)
{
  local objName = "contacts_scene"
  local obj = null
  if (::checkObj(scene))
  {
    obj = scene.findObject(objName)
    if (!obj)
    {
      scene.getScene().appendWithBlk(scene, "tdiv { id:t='"+objName+"' }")
      obj = scene.findObject(objName)
    }
  } else
  {
    local guiScene = ::get_gui_scene()
    obj = guiScene[objName]
    if (!::checkObj(obj))
    {
      guiScene.appendWithBlk("", "tdiv { id:t='"+objName+"' }")
      obj = guiScene[objName]
    }
  }

  if (!::contacts_handler)
    ::loadContactsToObj(obj, owner)
  else
    ::contacts_handler.switchScene(obj, owner)
}

::getContact <- function getContact(uid, nick = null, clanTag = "", forceUpdate = false)
{
  if(!uid)
    return null

  if (!(uid in ::contacts_players))
  {
    if (::u.isString(nick))
    {
      local contact = Contact({ name = nick, uid = uid , clanTag = clanTag})
      ::contacts_players[uid] <- contact
      if(uid in ::missed_contacts_data)
        contact.update(::missed_contacts_data.rawdelete(uid))
    }
    else
      return null
  }

  local contact = ::contacts_players[uid]
  if (forceUpdate || contact.name == "")
  {
    if(::u.isString(nick))
      contact.name = nick
    if(::u.isString(clanTag))
      contact.setClanTag(clanTag)
  }

  return contact
}

::clearContactPresence <- function clearContactPresence(uid)
{
  local contact = ::getContact(uid)
  if (!contact)
    return

  contact.online = null
  contact.unknown = null
  contact.presence = ::g_contact_presence.UNKNOWN
  contact.gameStatus = null
  contact.gameConfig = null
}

::update_contacts_by_list <- function update_contacts_by_list(list, needEvent = true)
{
  if (::u.isArray(list))
    foreach(config in list)
      updateContact(config)
  else if (::u.isTable(list))
    foreach(key, config in list)
      updateContact(config)

  if (needEvent)
    ::broadcastEvent(contactEvent.CONTACTS_UPDATED)
}

::updateContact <- function updateContact(config)
{
  local configIsContact = ::u.isInstance(config) && config instanceof ::Contact
  if (::u.isInstance(config) && !configIsContact) //Contact no need update by instances because foreach use function as so constructor
  {
    ::script_net_assert_once("strange config for contact update", "strange config for contact update")
    return null
  }

  local uid = config.uid
  local contact = ::getContact(uid, config?.name)
  if (!contact)
    return null

  //when config is instance of contact we no need update it to self
  if (!configIsContact)
  {
    if (config?.needReset ?? false)
      contact.resetMatchingParams()

    contact.update(config)
  }

  //update presence
  local presence = ::g_contact_presence.UNKNOWN
  if (contact.online)
    presence = ::g_contact_presence.ONLINE
  else if (!contact.unknown)
    presence = ::g_contact_presence.OFFLINE

  local squadStatus = ::g_squad_manager.getPlayerStatusInMySquad(uid)
  if (squadStatus == squadMemberState.NOT_IN_SQUAD)
  {
    if (contact.forceOffline)
      presence = ::g_contact_presence.OFFLINE
    else if (contact.online && contact.gameStatus)
    {
      if (contact.gameStatus == "in_queue")
        presence = ::g_contact_presence.IN_QUEUE
      else
        presence = ::g_contact_presence.IN_GAME
    }
  }
  else if (squadStatus == squadMemberState.SQUAD_LEADER)
    presence = ::g_contact_presence.SQUAD_LEADER
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_READY)
    presence = ::g_contact_presence.SQUAD_READY
  else if (squadStatus == squadMemberState.SQUAD_MEMBER_OFFLINE)
    presence = ::g_contact_presence.SQUAD_OFFLINE
  else
    presence = ::g_contact_presence.SQUAD_NOT_READY

  contact.presence = presence

  if (squadStatus != squadMemberState.NOT_IN_SQUAD || ::is_in_my_clan(null, uid))
    ::chatUpdatePresence(contact)

  return contact
}

::getFriendsOnlineNum <- function getFriendsOnlineNum()
{
  local online = 0
  if (::contacts)
  {
    foreach (groupName in [::EPL_FRIENDLIST, ::EPLX_PS4_FRIENDS])
    {
      if (!(groupName in ::contacts))
        continue

      foreach(f in ::contacts[groupName])
        if (f.online && !f.forceOffline)
          online++
    }
  }
  return online
}

::isContactsWindowActive <- function isContactsWindowActive()
{
  if (!::contacts_handler)
    return false;

  return ::contacts_handler.isContactsWindowActive();
}

::findContactByXboxId <- function findContactByXboxId(xboxId)
{
  foreach(uid, player in ::contacts_players)
    if (player.xboxId == xboxId)
      return player
  return null
}

::fillContactTooltip <- function fillContactTooltip(obj, contact, handler)
{
  local view = {
    name = contact.getName()
    presenceText = contact.getPresenceText()
    presenceIcon = contact.presence.getIcon()
    presenceIconColor = contact.presence.getIconColor()
    icon = contact.pilotIcon
    wins = contact.getWinsText()
    rank = contact.getRankText()
  }

  local squadStatus = ::g_squad_manager.getPlayerStatusInMySquad(contact.uid)
  if (squadStatus != squadMemberState.NOT_IN_SQUAD && squadStatus != squadMemberState.SQUAD_MEMBER_OFFLINE)
  {
    local memberData = ::g_squad_manager.getMemberData(contact.uid)
    if (memberData)
    {
      view.unitList <- []

      if (("country" in memberData) && ::checkCountry(memberData.country, "memberData of contact = " + contact.uid)
          && ("crewAirs" in memberData) && (memberData.country in memberData.crewAirs))
      {
        view.unitList.append({ header = ::loc("mainmenu/arcadeInstantAction") })
        foreach(unitName in memberData.crewAirs[memberData.country])
        {
          local unit = ::getAircraftByName(unitName)
          view.unitList.append({
            countryIcon = ::get_country_icon(memberData.country)
            rank = ::is_default_aircraft(unitName) ? ::loc("shop/reserve/short") : unit.rank
            unit = unitName
          })
        }
      }

      if ("selAirs" in memberData)
      {
        view.unitList.append({ header = ::loc("mainmenu/instantAction") })
        foreach(country in ::shopCountriesList)
        {
          local countryIcon = ::get_country_icon(country)
          debugTableData(memberData.selAirs)
          if (country in memberData.selAirs)
          {
            local unitName = memberData.selAirs[country]
            local unit = ::getAircraftByName(unitName)
            view.unitList.append({
              countryIcon = countryIcon
              rank = ::is_default_aircraft(unitName) ? ::loc("shop/reserve/short") : unit.rank
              unit = unitName
            })
          }
          else
          {
            view.unitList.append({
              countryIcon = countryIcon
              noUnit = true
            })
          }
        }
      }
    }
  }

  local blk = ::handyman.renderCached("gui/contacts/contactTooltip", view)
  obj.getScene().replaceContentFromText(obj, blk, blk.len(), handler)
}

::collectMissedContactData <- function collectMissedContactData (uid, key, val)
{
  if(!(uid in ::missed_contacts_data))
    ::missed_contacts_data[uid] <- {}
  ::missed_contacts_data[uid][key] <- val
}

::addContactGroup <- function addContactGroup(group)
{
  if(!(::isInArray(group, ::contacts_groups)))
  {
    ::contacts_groups.insert(2, group)
    ::contacts[group] <- []
    if(::contacts_handler && "fillContactsList" in ::contacts_handler)
      ::contacts_handler.fillContactsList.call(::contacts_handler)
  }
}

::getFriendGroupName <- function getFriendGroupName(playerName)
{
  if (::isPlayerPS4Friend(playerName))
    return ::EPLX_PS4_FRIENDS
  return ::EPL_FRIENDLIST
}

::isPlayerInFriendsGroup <- function isPlayerInFriendsGroup(uid, searchByUid = true, playerNick = "")
{
  if (::u.isEmpty(uid))
    searchByUid = false

  local isFriend = false
  if (searchByUid)
    isFriend = ::isPlayerInContacts(uid, ::EPL_FRIENDLIST) || ::isPlayerInContacts(uid, ::EPLX_PS4_FRIENDS)
  else if (playerNick != "")
    isFriend = ::isPlayerNickInContacts(playerNick, ::EPL_FRIENDLIST) || ::isPlayerNickInContacts(playerNick, ::EPLX_PS4_FRIENDS)

  return isFriend
}

::clear_contacts <- function clear_contacts()
{
  ::contacts_groups = []
  foreach(num, group in ::contacts_groups_default)
    ::contacts_groups.append(group)
  ::contacts = {}
  foreach(list in ::contacts_groups)
    ::contacts[list] <- []

  if (::contacts_handler)
    ::contacts_handler.curGroup = ::EPL_FRIENDLIST
}

::get_contacts_array_by_filter_func <- function get_contacts_array_by_filter_func(groupName, filterFunc)
{
  if (!(groupName in ::contacts))
    return null

  return ::u.filter(::contacts[groupName], @(contact) filterFunc(contact.name))
}

::add_squad_to_contacts <- function add_squad_to_contacts()
{
  if (!::g_squad_manager.isInSquad())
    return

  local contactsData = ::g_squad_manager.getSquadMembersDataForContact()
  if (contactsData.len() > 0)
    ::addPlayersToContacts(contactsData, ::EPL_RECENT_SQUAD)
}

if (!::contacts)
  clear_contacts()

::subscribe_handler(::g_contacts, ::g_listener_priority.DEFAULT_HANDLER)

::xbox_on_returned_from_system_ui <- @() ::broadcastEvent("XboxSystemUIReturn")

::can_view_target_presence_callback <- xboxContactsManager.updateContactXBoxPresence
::xbox_on_add_remove_friend_closed <- xboxContactsManager.xboxOverlayContactClosedCallback
::xbox_get_people_list_callback <- @(list) xboxContactsManager.onReceivedXboxListCallback(list, ::EPL_FRIENDLIST)
::xbox_get_avoid_list_callback <- @(list) xboxContactsManager.onReceivedXboxListCallback(list, ::EPL_BLOCKLIST)