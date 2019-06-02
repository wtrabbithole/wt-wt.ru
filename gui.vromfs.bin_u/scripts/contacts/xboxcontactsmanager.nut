local platformModule = require("scripts/clientState/platform.nut")

local MAX_UNKNOWN_XBOX_IDS_PEER_REQUEST = 100

local persist = { isInitedXboxContacts = false }
local pendingXboxContactsToUpdate = {}

::g_script_reloader.registerPersistentData("XboxContactsManagerGlobals", persist, ["isInitedXboxContacts"])

local updateContactXBoxPresence = function(xboxId, isAllowed)
{
  local contact = ::findContactByXboxId(xboxId)
  if (!contact)
    return

  local forceOffline = !isAllowed
  if (contact.forceOffline == forceOffline && contact.isForceOfflineChecked)
    return

  ::updateContact({
    uid = contact.uid
    forceOffline = forceOffline
    isForceOfflineChecked = true
  })
}

local fetchContactsList = function()
{
  pendingXboxContactsToUpdate.clear()
  //No matter what will be done first,
  //anyway, we will wait all groups data.
  ::xbox_get_people_list_async()
  ::xbox_get_avoid_list_async()
}

local updateXboxOneFriends = function(needIgnoreInitedFlag = false)
{
  if (!::is_platform_xboxone || !::isInMenu())
  {
    if (needIgnoreInitedFlag && persist.isInitedXboxContacts)
      persist.isInitedXboxContacts = false
    return
  }

  if (!needIgnoreInitedFlag && persist.isInitedXboxContacts)
    return

  persist.isInitedXboxContacts = true
  fetchContactsList()
}

local tryUpdateContacts = function(contactsBlk)
{
  local haveAnyUpdate = false
  foreach (group, usersList in contactsBlk)
    haveAnyUpdate = haveAnyUpdate || usersList.paramCount() > 0

  if (!haveAnyUpdate)
  {
    ::dagor.debug("XBOX CONTACTS: Update: No changes. No need to server call")
    return
  }

  local result = ::request_edit_player_lists(contactsBlk, false)
  if (result)
  {
    foreach(group, playersBlock in contactsBlk)
    {
      foreach (uid, isAdding in playersBlock)
      {
        local contact = ::getContact(uid)
        if (!contact)
          continue

        if (isAdding)
          ::contacts[group].append(contact)
        else
          ::g_contacts.removeContact(contact.uid, group)
      }
      ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE { groupName = group })
    }
  }
}

local xboxUpdateContactsList = function(usersTable)
{
  //Create or update exist contacts
  local contactsTable = {}
  foreach (uid, playerData in usersTable)
    contactsTable[playerData.id] <- ::updateContact({
      uid = uid
      name = playerData.nick
      xboxId = playerData.id
    })

  local contactsBlk = ::DataBlock()
  contactsBlk[::EPL_FRIENDLIST] <- ::DataBlock()
  contactsBlk[::EPL_BLOCKLIST]  <- ::DataBlock()

  foreach (group, playersArray in pendingXboxContactsToUpdate)
  {
    local existedXBoxContacts = ::get_contacts_array_by_regexp(group, platformModule.xboxNameRegexp)
    foreach (xboxPlayerId in playersArray)
    {
      local contact = contactsTable?[xboxPlayerId]
      if (!contact)
        continue

      if (!contact.isInFriendGroup() && group == ::getFriendGroupName(contact.name))
      {
        contactsBlk[::EPL_FRIENDLIST][contact.uid] = true
        if (contact.isInBlockGroup())
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
      }
      if (!contact.isInBlockGroup() && group == ::EPL_BLOCKLIST)
      {
        contactsBlk[::EPL_BLOCKLIST][contact.uid] = true
        if (contact.isInFriendGroup())
          contactsBlk[::EPL_FRIENDLIST][contact.uid] = false
      }

      //Check both lists, as there can be mistakes
      if (contact.isInFriendGroup() && contact.isInBlockGroup())
      {
        if (group == ::getFriendGroupName(contact.name))
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
        else
          contactsBlk[::EPL_FRIENDLIST][contact.uid] = false
      }

      //Validate in-game contacts list
      //in case if in xbox contacts list some players
      //are gone. So we need to clear then in game.
      for (local i = existedXBoxContacts.len() - 1; i >= 0; i--)
      {
        if (contact == existedXBoxContacts[i])
        {
          existedXBoxContacts.remove(i)
          break
        }
      }
    }

    foreach (oldContact in existedXBoxContacts)
      contactsBlk[group][oldContact.uid] = false
  }

  tryUpdateContacts(contactsBlk)
  pendingXboxContactsToUpdate.clear()
}

local requestUnknownXboxIds = function(playersList, knownUsers, cb) {} //forward declaration
requestUnknownXboxIds = function(playersList, knownUsers, cb)
{
  if (!playersList.len())
  {
    //Need to update contacts list, because empty list - means no users,
    //and returns -1, for not to send empty array to char.
    //So, contacts list must be cleared in this case from xbox users.
    //Send knownUsers if we already have all required data,
    //playersList is not empty and no need to
    //request char-server for known data.
    cb(knownUsers)
    return
  }

  local cutIndex = ::min(playersList.len(), MAX_UNKNOWN_XBOX_IDS_PEER_REQUEST)
  local requestList = playersList.slice(0, cutIndex)
  local leftList = playersList.slice(cutIndex)

  local taskId = ::xbox_find_friends(requestList)
  ::g_tasker.addTask(taskId, null, function() {
      local blk = ::DataBlock()
      blk = ::xbox_find_friends_result()

      local table = ::buildTableFromBlk(blk)
      table.__update(knownUsers)

      requestUnknownXboxIds(leftList, table, cb)
    }.bindenv(this)
  )
}

local proceedXboxPlayersList = function()
{
  if (!(::EPL_FRIENDLIST in pendingXboxContactsToUpdate)
      || !(::EPL_BLOCKLIST in pendingXboxContactsToUpdate))
    return

  local playersList = []
  foreach (group, usersArray in pendingXboxContactsToUpdate)
    playersList.extend(usersArray)

  local knownUsers = {}
  for (local i = playersList.len() - 1; i >= 0; i--)
  {
    local contact = ::findContactByXboxId(playersList[i])
    if (contact)
    {
      knownUsers[contact.uid] <- {
        nick = contact.name
        id = playersList.remove(i)
      }
    }
  }

  requestUnknownXboxIds(playersList, knownUsers, xboxUpdateContactsList)
}

local onReceivedXboxListCallback = function(playersList, group)
{
  pendingXboxContactsToUpdate[group] <- playersList
  proceedXboxPlayersList()
}

local xboxOverlayContactClosedCallback = function(playerStatus)
{
  if (playerStatus == XBOX_PERSON_STATUS_CANCELED)
    return

  fetchContactsList()
}

::add_event_listener("SignOut", function(p) {
  pendingXboxContactsToUpdate.clear()
  persist.isInitedXboxContacts = false
}, this)

::add_event_listener("XboxSystemUIReturn", function(p) {
  if (!::g_login.isLoggedIn())
    return

  updateXboxOneFriends(true)
}, this)

::add_event_listener("ContactsUpdated", function(p) {
  if (!::is_platform_xboxone)
    return

  local xboxContactsToCheck = ::u.filter(::contacts_players, @(contact) contact.needCheckForceOffline())
  foreach (contact in xboxContactsToCheck)
  {
    if (contact.xboxId != "")
      ::can_view_target_presence(contact.xboxId)
    else
      contact.getXboxId(@() ::can_view_target_presence(contact.xboxId))
  }

  updateXboxOneFriends()
}, this)

return {
  fetchContactsList = fetchContactsList
  onReceivedXboxListCallback = onReceivedXboxListCallback

  xboxOverlayContactClosedCallback = xboxOverlayContactClosedCallback

  updateContactXBoxPresence = updateContactXBoxPresence
  updateXboxOneFriends = updateXboxOneFriends
}