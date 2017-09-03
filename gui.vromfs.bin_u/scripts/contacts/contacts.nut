enum contactEvent
{
  CONTACTS_UPDATED = "ContactsUpdated"
  CONTACTS_GROUP_UPDATE = "ContactsGroupUpdate"
}

::contacts_handler <- null
::contacts_prev_scenes <- [] //{ scene, show }
::ps4_console_friends <- {}
::contacts_sizes <- null
::last_contacts_scene_show <- false
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

function g_contacts::onEventUserInfoManagerDataUpdated(params)
{
  local usersInfo = ::getTblValue("usersInfo", params, null)
  if (usersInfo == null)
    return

  ::update_contacts_by_list(usersInfo)
}

::missed_contacts_data <- {}

::g_script_reloader.registerPersistentData("ContactsGlobals", ::getroottable(),
  ["ps4_console_friends", "contacts_groups", "contacts_players", "contacts"])

function sortContacts(a, b)
{
  return b.presence.sortOrder <=> a.presence.sortOrder
    || ::english_russian_to_lower_case(a.name) <=> ::english_russian_to_lower_case(b.name)
}

class ::ContactsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  searchText = ""

  listNotPlayerChildsByGroup = null

  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  function constructor(gui_scene, params = {})
  {
    base.constructor(gui_scene, params)
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    listNotPlayerChildsByGroup = {}
  }

  function initScreen(obj, resetList = true)
  {
    if (::checkObj(scene) && scene.isEqual(obj))
      return

    foreach(group in ::contacts_groups)
      ::contacts[group].sort(::sortContacts)

    sceneShow(false)
    scene = obj
    sceneChanged = true
    if (resetList)
      ::friend_prev_scenes <- []
    sceneShow(true)
    closeSearchGroup()
  }

  function isValid()
  {
    return true
  }

  function getControlsAllowMask()
  {
    if (!::last_contacts_scene_show || !checkScene() || !scene.isEnabled())
      return CtrlsInGui.CTRL_ALLOW_FULL
    return wndControlsAllowMask
  }

  function updateControlsAllowMask()
  {
    if (!::last_contacts_scene_show)
      return

    local focusObj = getCurFocusObj(true)
    local mask = CtrlsInGui.CTRL_ALLOW_FULL
    if (::check_obj(focusObj))
      if (::show_console_buttons)
        mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT
      else if (focusObj.id == "search_edit_box")
        mask =CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD

    switchControlsAllowMask(mask)
  }

  _lastMaskUpdateDelayedCall = 0
  function updateControlsAllowMaskDelayed()
  {
    if (_lastMaskUpdateDelayedCall
        && _lastMaskUpdateDelayedCall < ::dagor.getCurTime() + LOST_DELAYED_ACTION_MSEC)
      return

    _lastMaskUpdateDelayedCall = ::dagor.getCurTime()
    guiScene.performDelayed(this, function()
    {
      _lastMaskUpdateDelayedCall = 0
      updateControlsAllowMask()
    })
  }

  function switchScene(obj, newOwner = null, onlyShow = false)
  {
    if (!::checkObj(obj) || (::checkObj(scene) && scene.isEqual(obj)))
    {
      if (!onlyShow || !::last_contacts_scene_show)
        sceneShow()
    } else
    {
      ::contacts_prev_scenes.append({ scene = scene, show = ::last_contacts_scene_show, owner = owner })
      owner = newOwner
      initScreen(obj, false)
    }
  }

  function goBack()
  {
    sceneShow(false)
  }

  function checkScene()
  {
    if (::checkObj(scene))
      return true

    for(local i=::contacts_prev_scenes.len()-1; i>=0; i--)
      if (::checkObj(::contacts_prev_scenes[i].scene))
      {
        scene = ::contacts_prev_scenes[i].scene
        owner = ::contacts_prev_scenes[i].owner
        guiScene = scene.getScene()
        sceneChanged = true
        sceneShow(::contacts_prev_scenes[i].show || ::last_contacts_scene_show)
        return true
      } else
        ::contacts_prev_scenes.remove(i)
    scene = null
    return false
  }

  function sceneShow(show=null)
  {
    if (!checkScene())
      return

    local wasVisible = scene.isVisible()
    if (show==null)
      show = !wasVisible
    if (!show)
    {
      getSizes()
      if (wasVisible)
      {
        local focusObj = getCurFocusObj(true)
        if (focusObj)
          broadcastEvent("OutsideObjWrap", { obj = focusObj, dir = -1 })
      }
    }
    scene.show(show)
    scene.enable(show)
    ::last_contacts_scene_show = show
    if (show)
    {
      if (!reloadSceneData())
      {
        setSavedSizes()
        fillContactsList()
        closeSearchGroup()
      }
      scene.findObject("contacts_groups").select()
    }

    updateControlsAllowMaskDelayed()
  }

  function getSizes()
  {
    if (::last_contacts_scene_show && checkScene())
    {
      ::contacts_sizes = {}
      local obj = scene.findObject("contacts_wnd")
      ::contacts_sizes.pos <- obj.getPosRC()
      ::contacts_sizes.size <- obj.getSize()

      saveLocalByScreenSize("contacts_sizes", save_to_json(::contacts_sizes))
    }
  }

  function setSavedSizes()
  {
    if (!::contacts_sizes)
    {
      local data = loadLocalByScreenSize("contacts_sizes")
      if (data)
      {
        ::contacts_sizes = ::parse_json(data)
        if (!("pos" in ::contacts_sizes) || !("size" in ::contacts_sizes))
          ::contacts_sizes = null
        else
          ::contacts_sizes.pos[0] = ::contacts_sizes.pos[0].tointeger()
          ::contacts_sizes.pos[1] = ::contacts_sizes.pos[1].tointeger()
          ::contacts_sizes.size[0] = ::contacts_sizes.size[0].tointeger()
          ::contacts_sizes.size[1] = ::contacts_sizes.size[1].tointeger()
      }
    }

    if (::last_contacts_scene_show && ::contacts_sizes && checkScene())
    {
      local obj = scene.findObject("contacts_wnd")
      if (!obj) return

      local rootSize = guiScene.getRoot().getSize()
      for(local i=0; i<=1; i++) //pos chat in screen
        if (::contacts_sizes.pos[i] < ::top_menu_borders[i][0]*rootSize[i])
          ::contacts_sizes.pos[i] = (::top_menu_borders[i][0]*rootSize[i]).tointeger()
        else
          if (::contacts_sizes.pos[i]+::contacts_sizes.size[i] > ::top_menu_borders[i][1]*rootSize[i])
            ::contacts_sizes.pos[i] = (::top_menu_borders[i][1]*rootSize[i] - ::contacts_sizes.size[i]).tointeger()

      obj.pos = ::contacts_sizes.pos[0] + ", " + ::contacts_sizes.pos[1]
      obj.size = ::contacts_sizes.size[0] + ", " + ::contacts_sizes.size[1]
    }
  }

  function reloadSceneData()
  {
    if (!checkScene())
      return false

    if (!scene.findObject("contacts_wnd"))
    {
      sceneChanged = true
      guiScene = scene.getScene()
      guiScene.replaceContent(scene, "gui/contacts.blk", this)
      setSavedSizes()
      scene.findObject("contacts_update").setUserData(this)
      fillContactsList()
      return true
    }
    return false
  }

  function onUpdate(obj, dt)
  {
    if (::last_contacts_scene_show)
    {
      updateSizesTimer -= dt
      if (updateSizesTimer <= 0)
      {
        updateSizesTimer = updateSizesDelay
        getSizes()
      }
    }
  }

  function needRebuildPlayersList(gName, listObj)
  {
    if (gName == ::EPLX_SEARCH)
      return true //this group often refilled by other objects
    local count = ::contacts[gName].len() + ::getTblValue(gName, listNotPlayerChildsByGroup, -100000)
    return listObj.childrenCount() != count
  }

  function buildPlayersList(gName, showOffline=true)
  {
    local playerListView = {
      playerListItem = []
      playerButton = []
      searchAdvice = gName != searchGroup
      searchAdviceID = "group_" + gName + "_search_advice"
    }

    foreach(idx, contactData in ::contacts[gName])
    {
      playerListView.playerListItem.push({
        blockID = "player_" + gName + "_" + idx
        contactUID = contactData.uid
        pilotIcon = contactData.pilotIcon
      })
    }

    if (gName == ::EPL_FRIENDLIST && ::isInMenu())
    {
      if (::has_feature("Invites"))
        playerListView.playerButton.push(createPlayerButtonView("btnInviteFriend", "#ui/gameuiskin#btn_invite_friend", "onInviteFriend"))
      if (::has_feature("Facebook"))
        playerListView.playerButton.push(createPlayerButtonView("btnFacebookFriendsAdd", "#ui/gameuiskin#btn_facebook_friends_add", "onFacebookFriendsAdd"))
      if (::steam_is_running())
        playerListView.playerButton.push(createPlayerButtonView("btnSteamFriendsAdd", "#ui/gameuiskin#btn_steam_friends_add", "onSteamFriendsAdd"))
    }

    listNotPlayerChildsByGroup[gName] <- playerListView.playerButton.len()
    if (playerListView.searchAdvice)
      listNotPlayerChildsByGroup[gName]++

    return ::handyman.renderCached(("gui/contacts/playerList"), playerListView)
  }

  function createPlayerButtonView(gId, gIcon, callback)
  {
    if (!gId || gId == "")
      return {}

    local shortName = ::loc("mainmenu/" + gId + "Short", "")
    return {
      name = shortName == "" ? "#mainmenu/" + gId : shortName
      tooltip = "#mainmenu/" + gId
      icon = gIcon
      callback = callback
    }
  }

  function updatePlayersList(gName)
  {
    local sel = -1
    local selUid = (curPlayer && curGroup==gName)? curPlayer.uid : ""

    local gObj = scene.findObject("contacts_groups")
    foreach(fIdx, f in ::contacts[gName])
    {
      local obj = gObj.findObject("player_" + gName + "_" + fIdx)
      if (!::check_obj(obj))
        continue

      local fullName = (f.clanTag != ""? (f.clanTag + " ") : "") + f.name
      local contactNameObj = obj.findObject("contactName")
      contactNameObj.setValue(fullName)
      local contactPresenceObj = obj.findObject("contactPresence")
      if (::checkObj(contactPresenceObj))
      {
        contactPresenceObj.setValue(f.getPresenceText())
        contactPresenceObj["color-factor"] = f.presence.getTransparencyDegree()
      }
      obj.findObject("tooltip").uid = f.uid
      if (selUid == f.uid)
        sel = fIdx

      local imgObj = obj.findObject("statusImg")
      imgObj["background-image"] = f.presence.getIcon()
      imgObj["background-color"] = f.presence.getIconColor()

      local pilotImgObj = obj.findObject("pilotIconImg")
      pilotImgObj["background-image"] = "#ui/opaque#" + f.pilotIcon + "_ico"
    }
    return sel
  }

  function fillPlayersList(gName)
  {
    local listObj = scene.findObject("contacts_groups").findObject("group_" + gName)
    if (!listObj)
      return

    if (needRebuildPlayersList(gName, listObj))
    {
      local data = buildPlayersList(gName)
      guiScene.replaceContentFromText(listObj, data, data.len(), this)
    }
    updateContactButtonsForGroup(gName)
    applyContactFilter()
    return updatePlayersList(gName)
  }

  function updateContactButtonsForGroup(gName)
  {
    foreach (idx, contact in ::contacts[gName])
    {
      local contactObject = scene.findObject(format("player_%s_%s", gName.tostring(), idx.tostring()))
      local contactButtonsHolder = contactObject.findObject("contact_buttons_holder")
      updateContactButtonsVisibility(contact, contactButtonsHolder)
    }
  }

  function updateContactButtonsVisibility(contact_data, contact_buttons_holder)
  {
    if (!checkScene())
      return

    contact_buttons_holder.contact_buttons_contact_uid = contact_data.uid

    local isFriend = ::isPlayerInContacts(contact_data.uid, ::EPL_FRIENDLIST)
    local isBlock = ::isPlayerInContacts(contact_data.uid, ::EPL_BLOCKLIST)
    local isMe = contact_data.uid == ::my_user_id_str

    showBtn("btn_friendAdd", !isMe && !isFriend && !isBlock, contact_buttons_holder)
    showBtn("btn_friendRemove", isFriend, contact_buttons_holder)
    showBtn("btn_blacklistAdd", !isMe && !isFriend && !isBlock, contact_buttons_holder)
    showBtn("btn_blacklistRemove", isBlock, contact_buttons_holder)
    showBtn("btn_message", owner && !isBlock && ::ps4_is_chat_enabled(), contact_buttons_holder)

    showBtn("btn_squadInvite", !isMe && !isBlock && ::g_squad_manager.canInviteMember(contact_data.uid), contact_buttons_holder)
    showBtn("btn_usercard", true, contact_buttons_holder)
    showBtn("btn_facebookFriends", ::has_feature("Facebook") && !::is_platform_ps4, contact_buttons_holder)
    showBtn("btn_steamFriends", ::steam_is_running(), contact_buttons_holder)
    showBtn("btn_squadInvite_bottom", false, contact_buttons_holder)
  }

  searchGroupActiveTextInclude = @"
    id:t='search_group_active_text';
    Button_close {
      id:t='close_search_group';
      on_click:t='onCloseSearchGroupClicked';
      smallIcon:t='yes'
    }"

  groupFormat = @"group {
    activeText {
      text:t='%s';
      %s
    }
    groupList {
      id:t='%s';
      %s
      on_select:t='onPlayerSelect';
      on_dbl_click:t='%s';
      on_cancel_edit:t='onPlayerCancel';
      on_wrap_up:t='onPlayerWrapUp';
      on_set_focus:t='onContactsFocus'
      contacts_group_list:t='yes';
    }
  }"

  function getIndexOfGroup(group_name)
  {
    local contactsGroups = scene.findObject("contacts_groups")
    for (local idx = contactsGroups.childrenCount() - 1; idx >= 0; --idx)
    {
      local childObject = contactsGroups.getChild(idx)
      local groupListObject = childObject.getChild(childObject.childrenCount() - 1)
      if (groupListObject.id == "group_" + group_name)
      {
        return idx
      }
    }
    return -1
  }

  function getGroupByName(group_name)
  {
    local contactsGroups = scene.findObject("contacts_groups")
    if (::checkObj(contactsGroups))
    {
      local groupListObject = contactsGroups.findObject("group_" + group_name)
      return groupListObject.getParent()
    }
    return null
  }

  function setSearchGroupVisibility(value)
  {
    local groupObject = getGroupByName(searchGroup)
    groupObject.show(value)
    groupObject.enable(value)
  }

  function onSearchEditBoxActivate()
  {
    local searchText = ::clearBorderSymbols(getSearchObj().getValue() || "")
    if (searchText == "" || searchText == "*")
      return

    doSearch()
  }

  function doSearch()
  {
    local contactsGroups = scene.findObject("contacts_groups")
    if (::checkObj(contactsGroups))
    {
      local searchGroupIndex = getIndexOfGroup(searchGroup)
      if (searchGroupIndex != -1)
      {
        setSearchGroupVisibility(true)
        contactsGroups.setValue(searchGroupIndex)
        onSearch(null)
      }
    }
  }

  function onSearchEditBoxCancelEdit(obj)
  {
    if (curGroup == searchGroup)
    {
      closeSearchGroup()
      return
    }

    if (obj.getValue() == "")
      goBack()
    else
      obj.setValue("")
  }

  function onSearchEditBoxChangeValue(target)
  {
    local searchEditBox = scene.findObject("search_edit_box")
    if (::checkObj(searchEditBox))
    {
      setSearchText(searchEditBox.text, false)
      applyContactFilter()
    }
  }

  _lastFocusdelayedCall = 0
  function onContactsFocus()
  {
    if (_lastFocusdelayedCall
        && _lastFocusdelayedCall < ::dagor.getCurTime() + LOST_DELAYED_ACTION_MSEC)
      return

    _lastFocusdelayedCall = ::dagor.getCurTime()
    guiScene.performDelayed(this, function()
    {
      _lastFocusdelayedCall = 0
      if (!checkScene())
        return

      updateControlsAllowMask()
      updateConsoleButtons()

      local showAdvice = false
      if (!::show_console_buttons)
      {
        local focusObj = getCurFocusObj(true)
        showAdvice = focusObj && focusObj.id == "search_edit_box"
      }
      setSearchAdviceVisibility(showAdvice)
    })
  }

  function setSearchText(search_text, set_in_edit_box = true)
  {
    searchText = ::english_russian_to_lower_case(search_text)
    if (set_in_edit_box)
    {
      local searchEditBox = scene.findObject("search_edit_box")
      if (::checkObj(searchEditBox))
      {
        searchEditBox.setValue(search_text)
      }
    }
  }

  function applyContactFilter()
  {
    if (curGroup == "" || curGroup == searchGroup)
      return

    foreach (idx, contact_data in ::contacts[curGroup])
    {
      local contactObjectName = "player_" + curGroup + "_" + idx
      local contactObject = scene.findObject(contactObjectName)
      if (!::checkObj(contactObject))
        continue

      local contactName = ::english_russian_to_lower_case(contact_data.name)
      local searchResult = (contactName.find(searchText) == 0)
      contactObject.show(searchResult)
      contactObject.enable(searchResult)
    }
  }

  function fillContactsList(groups_array = null)
  {
    if (!checkScene())
      return

    if (!groups_array)
      groups_array = ::contacts_groups

    local data = ""
    local gObj = scene.findObject("contacts_groups")
    if (!gObj) return
    guiScene.setUpdatesEnabled(false, false)

    local data = ""
    foreach(gIdx, gName in groups_array)
    {
      ::contacts[gName].sort(::sortContacts)
      local activateEvent = "onPlayerMsg"
      if (::show_console_buttons || !::ps4_is_chat_enabled())
        activateEvent = "onPlayerMenu"
      local gData = buildPlayersList(gName)
      data += format(groupFormat, "#contacts/" + gName,
        gName == searchGroup ? searchGroupActiveTextInclude : "",
        "group_" + gName, gData, activateEvent)
    }
    guiScene.replaceContentFromText(gObj, data, data.len(), this)
    foreach (gName in groups_array)
      updateContactButtonsForGroup(gName)

    applyContactFilter()

    local selected = [-1, -1]
    foreach(gIdx, gName in groups_array)
    {
      if (curGroup==gName)
        selected[0] = gIdx
      local sel = updatePlayersList(gName)
      if (sel > 0)
        selected[1] = sel
    }

    if (selected[0]<0)
      selected[0] = 0

    if (::contacts[groups_array[selected[0]]].len() > 0)
      gObj.findObject("group_" + groups_array[selected[0]]).setValue(
              (selected[1]>=0)? selected[1] : 0)

    guiScene.setUpdatesEnabled(true, true)

    gObj.setValue(selected[0])
    onGroupSelect(gObj)
  }

  function updateContactsGroup(groupName)
  {
    local sel = 0
    if (groupName && groupName in ::contacts)
    {
      ::contacts[groupName].sort(::sortContacts)
      if (!checkScene())
        return
      sel = fillPlayersList(groupName)
    }
    else
      foreach(group in ::contacts_groups)
        if (group in ::contacts)
        {
          ::contacts[group].sort(::sortContacts)
          if (!checkScene())
            continue
          local selected = fillPlayersList(group)
          if (group == curGroup)
            sel = selected
        }

    if (!checkScene())
      return

    if (curGroup && (!groupName || curGroup == groupName))
    {
      local gObj = scene.findObject("contacts_groups")
      local listObj = gObj.findObject("group_" + curGroup)
      if (listObj)
      {
        if (::contacts[curGroup].len() > 0)
          listObj.setValue(sel>0? sel : 0)
        onPlayerSelect(listObj)
      }
    }
  }

  function onEventContactsGroupUpdate(params)
  {
    local groupName = null
    if ("groupName" in params)
      groupName = params.groupName

    if (::last_contacts_scene_show && checkScene())
      updateContactsGroup(groupName)
  }

  function onGroupSelect(obj)
  {
    if (!obj) return
    selectItemInGroup(obj, ::contacts_groups, false)
    applyContactFilter()
  }

  function onGroupActivate(obj)
  {
    selectItemInGroup(obj, ::contacts_groups, true)
    applyContactFilter()
  }

  function onGroupCancel(obj)
  {
    goBack()
  }

  function onPlayerCancel(obj)
  {
    if (!checkScene())
      return

    scene.findObject("contacts_groups").select()
  }

  function getCurFocusObj(getOnlyFocused = false)
  {
    if (!checkScene() || scene.getModalCounter() != 0 || !scene.isVisible())
      return null
    local obj = findObjInFocusArray(true)
    if (!obj && !getOnlyFocused)
      obj = getFocusItemObj(currentFocusItem) || findObjInFocusArray(false)
    return obj
  }

  function onSearchButtonClick(target)
  {
    doSearch()
  }

  function getListFocusObj(getOnlyFocused = false)
  {
    local listObj = scene.findObject("contacts_groups")
    if (listObj.isFocused())
      return listObj

    local groupObj = scene.findObject("group_" + curGroup)
    if (::checkObj(groupObj) && groupObj.isFocused())
      return groupObj

    local searchBox = scene.findObject("search_edit")
    if (::checkObj(searchBox) && searchBox.isFocused())
      return searchBox
    return getOnlyFocused? null : listObj
  }

  function onBtnSelect(obj)
  {
    if (!checkScene())
      return

    local listObj = scene.findObject("contacts_groups")
    if (listObj.isFocused())
      onGroupActivate(listObj)
    else
    {
      local searchObject = getSearchObj()
      if (searchObject.isFocused())
      {
        doSearch()
      }
      else
      {
        local groupObj = scene.findObject("group_" + curGroup)
        if (::checkObj(groupObj))
          onPlayerMenu(groupObj)
      }
    }
  }

  function selectItemInGroup(obj, groups, switchFocus = false)
  {
    local value = obj.getValue()
    if (!(value in groups))
      return

    curGroup = groups[value]

    local listObj = obj.findObject("group_" + curGroup)
    if (!::checkObj(listObj))
      return

    if (listObj.getValue()<0 && ::contacts[curGroup].len() > 0)
      listObj.setValue(0)

    onPlayerSelect(listObj)
    showSceneBtn("button_invite_friend", curGroup == ::EPL_FRIENDLIST)

    if (!switchFocus)
      return

   listObj.select()
  }

  function onInsWrapDown(obj)
  {
    if (!checkScene())
      return

    local listObj = scene.findObject("contacts_groups").findObject("group_" + curGroup)
    if (::checkObj(listObj) && listObj.childrenCount())
      listObj.select()
  }

  function onPlayerWrapUp(obj)
  {
    if (!checkScene())
      return

    local groupObj = scene.findObject("contacts_groups").findObject("group_" + curGroup)
    local editObj = ::checkObj(groupObj)? groupObj.findObject("search_edit") : null
    if (::checkObj(editObj))
      editObj.select()
  }

  function onPlayerSelect(obj)
  {
    if (!obj) return

    local value = obj.getValue()
    if ((curGroup in ::contacts) && (value in ::contacts[curGroup]))
      curPlayer = ::contacts[curGroup][value]
    else
      curPlayer = null
    updatePlayerButtons()
  }

  function onPlayerMenu(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    showCurPlayerRClickMenu(obj.getChild(value).getPosRC())
    local child = obj.getChild(value)
    if (!child)
      return
    local func = child.on_click
    if (typeof(func) == "string" && func in this)
      this[func]()
  }

  function onPlayerRClick(obj)
  {
    if (!obj || !checkScene()) return

    local id = obj.id
    local prefix = "player_" + curGroup + "_"
    if (id.len() <= prefix.len() || id.slice(0, prefix.len()) != prefix)
      return

    local idx = id.slice(prefix.len()).tointeger()
    if ((curGroup in ::contacts) && (idx in ::contacts[curGroup]))
    {
      local listObj = scene.findObject("group_" + curGroup)
      if (!listObj)
        return

      listObj.setValue(idx)
      showCurPlayerRClickMenu()
    }
  }

  function onCloseSearchGroupClicked(obj)
  {
    closeSearchGroup()
  }

  function closeSearchGroup()
  {
    if (!checkScene())
      return

    local contactsGroups = scene.findObject("contacts_groups")
    if (::checkObj(contactsGroups))
    {
      setSearchGroupVisibility(false)
      local searchGroupIndex = getIndexOfGroup(searchGroup)
      if (contactsGroups.getValue() == searchGroupIndex)
      {
        setSearchText("")
        local friendsGroupIndex = getIndexOfGroup(::EPL_FRIENDLIST)
        contactsGroups.setValue(friendsGroupIndex)
      }
    }
    applyContactFilter()
  }

  function setSearchAdviceVisibility(value)
  {
    foreach (idx, groupName in ::contacts_groups)
    {
      local searchAdviceID = "group_" + groupName + "_search_advice"
      local searchAdviceObject = scene.findObject(searchAdviceID)
      if (::checkObj(searchAdviceObject))
      {
        searchAdviceObject.show(value)
        searchAdviceObject.enable(value)
      }
    }
  }

  function showCurPlayerRClickMenu(position = null)
  {
    if (!curPlayer)
      return

    local isMe = curPlayer.uid == ::my_user_id_str
    local meLeader = ::g_squad_manager.isSquadLeader()
    local inMySquad = ::g_squad_manager.isInMySquad(curPlayer.name, false)
    local isFriend = ::isPlayerInFriendsGroup(curPlayer.uid)
    local isBlock = ::isPlayerInContacts(curPlayer.uid, ::EPL_BLOCKLIST)
    local inviteMenu = ::g_chat.generateInviteMenu(curPlayer.name)
    local clanTag = curPlayer.clanTag

    local menu = [
      {
        text = ::loc("multiplayer/invite_to_session")
        show = ::SessionLobby.canInvitePlayer(curPlayer.uid)
        action = function () {
          if (::is_psn_player_use_same_titleId(curPlayer.name))
            ::g_psn_session_invitations.sendSkirmishInvitation(curPlayer.name)
          else
            ::SessionLobby.invitePlayer(curPlayer.uid)
        }
      }
      {
        text = ::loc("contacts/message")
        show = !isMe && ::ps4_is_chat_enabled()
        action = function() { onPlayerMsg(null) }
      }
      {
        text = ::loc("mainmenu/btnUserCard")
        action = function() { onUsercard(null) }
      }
      {
        text = ::loc("clan/btn_clan_info")
        show = (clanTag!="" && ::has_feature("Clans"))
        action = (@(clanTag) function() {showClanPage("", "", clanTag)})(clanTag)
      }
      {
        text = ::loc("squad/invite_player")
        show = !isMe && !isBlock && ::g_squad_manager.canInviteMember(curPlayer.uid)
        action = function() { onSquadInvite(null) }
      }
      {
        text = ::loc("squad/remove_player")
        show = !isMe && meLeader && inMySquad
        action = function() { onSquadRemove(null) }
      }
      {
        text = ::loc("squad/tranfer_leadership")
        show = ::g_squad_manager.canTransferLeadership(curPlayer.uid)
        action = (@(curPlayer) function() {
          ::g_squad_manager.transferLeadership(curPlayer.uid)
        })(curPlayer)
      }
      {
        text = ::loc("contacts/friendlist/add")
        show = !isMe && ::has_feature("Friends") && !isFriend && !isBlock
        action = function() { onFriendAdd(null) }
      }
      {
        text = ::loc("contacts/friendlist/remove")
        show = isFriend && !::isPlayerPS4Friend(curPlayer.name)
        action = function() { onFriendRemove(null) }
      }
      {
        text = ::loc("contacts/blacklist/add")
        show = !isMe && !isFriend && !isBlock
        action = function() { onBlacklistAdd(null) }
      }
      {
        text = ::loc("contacts/blacklist/remove")
        show = isBlock
        action = function() { onBlacklistRemove(null) }
      }
      {
        text = ::loc("chat/invite_to_room")
        show = inviteMenu && inviteMenu.len() > 0 && ::ps4_is_chat_enabled()
        action = @() ::open_invite_menu(inviteMenu, position)
      }
    ]

    local inGameEx = ::getTblValue("inGameEx", curPlayer)
    if (inGameEx && curPlayer.online && ::isInMenu())
    {
      local eventId = ::getTblValue("eventId", curPlayer.gameConfig)
      local event = ::events.getEvent(eventId)
      if (event && ::events.isEnableFriendsJoin(event))
      {
        menu.append({
          text = ::loc("contacts/join_team")
          show = true
          action = (@(inGameEx, eventId) function() {
            if (::isInMenu())
              ::queues.joinFriendsQueue(inGameEx, eventId)
          })(inGameEx, eventId)
        })
      }
    }
    ::gui_right_click_menu(menu, this, position)
  }

  function isContactsWindowActive()
  {
    return checkScene() && ::last_contacts_scene_show;
  }

  function updatePlayerButtons()
  {
    if (!checkScene())
      return

    local isFriend = curPlayer? ::isPlayerInContacts(curPlayer.uid, ::EPL_FRIENDLIST) : false
    local isBlock = curPlayer? ::isPlayerInContacts(curPlayer.uid, ::EPL_BLOCKLIST) : false
    local isMe = curPlayer? curPlayer.uid == ::my_user_id_str : false

    showSceneBtn("btn_friendAdd", curPlayer && !isMe && !isFriend && !isBlock)
    showSceneBtn("btn_friendRemove", curPlayer && isFriend)
    showSceneBtn("btn_blacklistAdd", curPlayer && !isMe && !isFriend && !isBlock)
    showSceneBtn("btn_blacklistRemove", curPlayer && isBlock)
    showSceneBtn("btn_message", owner && curPlayer && !isBlock && ::ps4_is_chat_enabled())

    showSceneBtn("btn_squadInvite", !isMe && !isBlock && curPlayer && ::g_squad_manager.canInviteMember(curPlayer.uid))
    showSceneBtn("btn_usercard", curPlayer!=null)
    showSceneBtn("btn_facebookFriends", ::has_feature("Facebook") && !::is_platform_ps4)
    showSceneBtn("btn_steamFriends", !::is_platform_ps4 && ::steam_is_running())
    showSceneBtn("btn_squadInvite_bottom", false)
  }

  function updateConsoleButtons()
  {
    if (!checkScene())
      return

    if (!::show_console_buttons)
    {
      scene.findObject("contacts_buttons_console").show(false)
      return
    }

    local focusObj = getListFocusObj(true)
    local showSelectButton = focusObj != null || getSearchObj().isFocused()

    if (showSelectButton)
    {
      local btnText = getSearchObj().isFocused() ? ::loc("contacts/search") : ::loc("mainmenu/btnSelect")
      scene.findObject("btn_select").setValue(btnText)
    }

    showSceneBtn("btn_psnFriends", ::is_platform_ps4)
    showSceneBtn("btn_select", showSelectButton)
  }

  function onFacebookFriendsAdd()
  {
    onFacebookLoginAndAddFriends()
  }

  function editPlayerInList(obj, listName, add)
  {
    updateCurPlayer(obj)
    if (!curPlayer)
      return
    ::editContactMsgBox(curPlayer, listName, add, this)
  }

  function updateCurPlayer(button_object)
  {
    if (!::checkObj(button_object))
      return

    local contactButtonsObject = button_object.getParent()
    local contactUID = contactButtonsObject.contact_buttons_contact_uid
    if (!contactUID)
      return

    local contact = ::getContact(contactUID)
    curPlayer = contact

    foreach (idx, contact in contacts[curGroup])
    {
      if (contact.uid == contactUID)
      {
        local groupObject = scene.findObject("contacts_groups")
        local listObject = groupObject.findObject("group_" + curGroup)
        listObject.setValue(idx)
      }
    }
  }

  function onFriendAdd(obj)
  {
    editPlayerInList(obj, ::EPL_FRIENDLIST, true)
  }

  function onFriendRemove(obj)
  {
    editPlayerInList(obj, ::EPL_FRIENDLIST, false)
  }

  function onBlacklistAdd(obj)
  {
    editPlayerInList(obj, ::EPL_BLOCKLIST, true)
  }

  function onBlacklistRemove(obj)
  {
    editPlayerInList(obj, ::EPL_BLOCKLIST, false)
  }

  function onPlayerMsg(obj)
  {
    updateCurPlayer(obj)
    if (!curPlayer || !owner)
      return

    ::openChatPrivate(curPlayer.name, owner)
  }

  function onSquadInvite(obj)
  {
    updateCurPlayer(obj)

    if (curPlayer == null)
      return ::g_popups.add("", ::loc("msgbox/noChosenPlayer"))

    if (!::g_squad_manager.canInviteMember(curPlayer.uid))
      return

    if (::is_psn_player_use_same_titleId(curPlayer.name))
      ::g_psn_session_invitations.sendSquadInvitation(curPlayer.name)
    else
      ::g_squad_manager.inviteToSquad(curPlayer.uid)
  }

  function onSquadRemove(obj)
  {
    updateCurPlayer(obj)
    if (!curPlayer || !owner)
      return
    if (::has_feature("Squad"))
      ::g_squad_manager.dismissFromSquadByName(curPlayer.name)
    else
      msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok")
  }

  function onUsercard(obj)
  {
    updateCurPlayer(obj)
    if (curPlayer)
      ::gui_modal_userCard(curPlayer)
  }

  function onCancelSearchEdit(obj)
  {
    if (!obj) return

    local value = obj.getValue()
    if (!value || value=="")
    {
      if (::show_console_buttons)
        onPlayerCancel(obj)
      else
        goBack()
    } else
    {
      obj.setValue("")
      if (searchShowDefaultOnReset)
      {
        fillDefaultSearchList()
        updateSearchList()
      }
    }
    searchShowNotFound = false
  }

  function getSearchObj()
  {
    if (!checkScene()) return
    return scene.findObject("search_edit_box")
  }

  function onSearch(obj)
  {
    local sObj = getSearchObj()
    if (!sObj || searchInProgress) return
    local value = sObj.getValue()
    if (!value || value == "*")
      return
    if (::is_chat_message_empty(value))
    {
      if (searchShowDefaultOnReset)
      {
        fillDefaultSearchList()
        updateSearchList()
      }
      return
    }

    value = ::clearBorderSymbols(value)

    local searchGroupActiveTextObject = scene.findObject("search_group_active_text")
    searchGroupActiveTextObject.text = ::loc("contacts/" + searchGroup) + ": " + value

    taskId = find_nicks_by_prefix(value, maxSearchPlayers, true)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      afterSlotOp = onSearchCb
      searchInProgress = true
      ::contacts[searchGroup] <- []
      updateSearchList()
    }
  }

  function onSearchCb()
  {
    searchInProgress = false

    local searchRes = ::DataBlock()
    searchRes = ::get_nicks_find_result_blk()
    ::contacts[searchGroup] <- []

    local brokenData = false
    for(local i = 0; i < searchRes.paramCount(); i++)
    {
      local contact = ::getContact(searchRes.getParamName(i), searchRes.getParamValue(i))
      if (contact)
        ::contacts[searchGroup].append(contact)
      else
        brokenData = true
    }

    if (brokenData)
    {
      local errText = "broken result on find_nicks_by_prefix cb: \n" + ::toString(searchRes)
      ::script_net_assert_once("broken searchCb data", errText)
    }

    updateSearchList()
  }

  function updateSearchList()
  {
    if (!checkScene())
      return

    local gObj = scene.findObject("contacts_groups")
    local listObj = gObj.findObject("group_" + searchGroup)
    if (!listObj)
      return

    guiScene.setUpdatesEnabled(false, false)
    local sel = -1
    if (::contacts[searchGroup].len() > 0)
      sel = fillPlayersList(searchGroup)
    else
    {
      local data = ""
      if (searchInProgress)
        data = "animated_wait_icon { pos:t='0.5(pw-w),0.03sh'; position:t='absolute'; background-rotation:t='0'; wait_icon_cock {} }"
      else if (searchShowNotFound)
        data = "textAreaCentered { text:t='#contacts/searchNotFound'; enable:t='no' }"
      else
      {
        fillDefaultSearchList()
        sel = fillPlayersList(searchGroup)
        data = null
      }

      if (data)
      {
        guiScene.replaceContentFromText(listObj, data, data.len(), this)
        searchShowNotFound = true
      }
    }
    guiScene.setUpdatesEnabled(true, true)

    if (curGroup == searchGroup)
    {
      if (::contacts[searchGroup].len() > 0)
        listObj.setValue(sel>0? sel : 0)
      onPlayerSelect(listObj)
    }
  }

  function fillDefaultSearchList()
  {
    ::contacts[searchGroup] <- []
  }

  function onSteamFriendsAdd()
  {
    if(!isInArray(::EPL_STEAM, ::contacts_groups))
      ::addContactGroup(::EPL_STEAM)

    local friendListFreeSpace = ::EPL_MAX_PLAYERS_IN_LIST - ::contacts[::EPL_STEAM].len();

    if (friendListFreeSpace <= 0)
    {
      msgBox("cant_add_contact",
             format(::loc("msg/cant_add/too_many_contacts"), ::EPL_MAX_PLAYERS_IN_LIST),
             [["ok", function() { } ]], "ok");
      return;
    }

    msgBox("add_steam_friend", ::loc("msgbox/add_steam_friends"),
      [
        ["yes", function()
        {
          addSteamFriends();
        }],
        ["no",  function() {} ],
      ], "no");
  }

  function onInviteFriend()
  {
    ::show_viral_acquisition_wnd()
  }

  function onPsnFriends()
  {
    ::addPsnFriends()
  }

  function onEventContactsUpdated(params)
  {
    updateContactsGroup(null)
  }

  isPrimaryFocus = false
  focusArray = [
    "search_edit_box"
    function() { return getListFocusObj() }
    "contacts_buttons_console"
  ]
  currentFocusItem = 0

  scene = null
  sceneChanged = true
  owner = null

  updateSizesTimer = 0.0
  updateSizesDelay = 1.0

  curGroup = ""
  curPlayer = null

  searchGroup = ::EPLX_SEARCH
  maxSearchPlayers = 20
  searchInProgress = false
  searchShowNotFound = false
  searchShowDefaultOnReset = false
}

function gui_start_search_squadPlayer()
{
  if (!::g_squad_manager.canInviteMember())
  {
    ::showInfoMsgBox(::loc("squad/not_a_leader"), "squad_not_available")
    return
  }

  ::update_ps4_friends()
  ::handlersManager.loadHandler(::gui_handlers.SearchForSquadHandler)
}

class ::gui_handlers.SearchForSquadHandler extends ::ContactsHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/contacts.blk"

  curGroup = ::EPL_FRIENDLIST
  searchGroup = ::EPLX_SEARCH
  clanGroup = ::EPLX_CLAN
  searchShowDefaultOnReset = true
  isPrimaryFocus = true

  sg_groups = null

  function initScreen()
  {
    guiScene.setUpdatesEnabled(false, false)

    fillDefaultSearchList()

    local fObj = scene.findObject("contacts_wnd")
    fObj.pos = "0.5(sw-w), 0.4(sh-h)"
    fObj["class"] = ""
    if (::contacts_sizes)
      fObj.size = ::contacts_sizes.size[0] + ", " + ::contacts_sizes.size[1]
    scene.findObject("contacts_backShade").show(true)
    scene.findObject("title").setValue(::loc("mainmenu/btnInvite"))

    showSceneBtn("btn_squadInvite_bottom", !::show_console_buttons)

    sg_groups = [::EPLX_SEARCH, ::EPL_FRIENDLIST, ::EPL_RECENT_SQUAD]
    if(::clan_get_my_clan_id() != "-1" && !::isInArray(clanGroup, sg_groups))
    {
      sg_groups.push(clanGroup)
      if (!(clanGroup in ::contacts))
        ::contacts[clanGroup] <- []
    }
    if (::is_platform_ps4)
      sg_groups.insert(2, ::EPLX_PS4_FRIENDS)

    fillContactsList(sg_groups)
    guiScene.setUpdatesEnabled(true, true)
    initFocusArray()
    closeSearchGroup()
    updateConsoleButtons()
  }

  function isValid()
  {
    return ::gui_handlers.BaseGuiHandlerWT.isValid.bindenv(this)()
  }

  function goBack()
  {
    ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function checkScene()
  {
    return checkObj(scene)
  }

  function onPlayerSelect(obj)
  {
    if (!obj) return

    local value = obj.getValue()
    curPlayer = ::getTblValue(value, ::contacts[curGroup])
  }

  function onGroupSelect(obj)
  {
    selectItemInGroup(obj, sg_groups, false)
  }

  function onGroupActivate(obj)
  {
    selectItemInGroup(obj, sg_groups, true)
  }

  function onPlayerMsg(obj)
  {
    updateCurPlayer(obj)
    if (curPlayer)
      ::openChatPrivate(curPlayer.name, this)
  }

  function onEventContactsGroupUpdate(params)
  {
    local groupName = null
    if ("groupName" in params)
      groupName = params.groupName

    updateContactsGroup(groupName)
  }
}

function getContactsGroupUidList(groupName)
{
  local res = []
  if (!(groupName in ::contacts))
    return res
  foreach(p in ::contacts[groupName])
    res.append(p.uid)
  return res
}

function isPlayerInContacts(uid, groupName)
{
  if (!(groupName in ::contacts))
    return false
  foreach(p in ::contacts[groupName])
    if (p.uid == uid)
      return true
  return false
}

function isPlayerNickInContacts(nick, groupName)
{
  if (!(groupName in ::contacts))
    return false
  foreach(p in ::contacts[groupName])
    if (p.name == nick)
      return true
  return false
}

function editPlayerInContacts(player, groupName, add) //playerConfig: { uid, name }
{
  if (add == ::isPlayerInContacts(player.uid, groupName))
    return -1 //no need to do something

  if (add && ::contacts[groupName].len() >= ::EPL_MAX_PLAYERS_IN_LIST)
  {
    scene_msg_box("cant_add_contact", ::get_gui_scene(),
                  format(::loc("msg/cant_add/too_many_contacts"), ::EPL_MAX_PLAYERS_IN_LIST),
                  [["ok", function() { } ]], "ok")
    return -1
  }

  local realGroupName = groupName == ::EPLX_PS4_FRIENDS? ::EPL_FRIENDLIST : groupName
  local blk = ::DataBlock()
  blk[realGroupName] <- ::DataBlock()
  blk[realGroupName][player.uid] <- add
  dagor.debug((add? "Adding" : "Removing") + " player '"+player.name+"' ("+player.uid+") to "+groupName + ", realGroupName " + realGroupName);

  local result = request_edit_player_lists(blk, false)
  if (result)
  {
    if (add)
    {
      if (groupName == ::EPL_FRIENDLIST && player.name.slice(0, 1) == "*" && ::isPlayerPS4Friend(player.name))
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
    }
    ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, {groupName = groupName})
  }
  return result
}

function find_contact_by_name_and_do(playerName, ownerHandler, func) //return taskId if delayed.
{
  local uid = getPlayerUid(playerName)
  if (uid!=null)
  {
    func.call(ownerHandler, ::getContact(uid, playerName))
    return null
  }

  local taskCallback = (@(playerName, ownerHandler, func) function(result = ::YU2_OK) {
    if (!ownerHandler || !func)
      return

    if (result == ::YU2_OK)
    {
      local searchRes = ::DataBlock()
      searchRes = ::get_nicks_find_result_blk()
      foreach(uid, nick in searchRes)
        if (nick == playerName)
        {
          func.call(ownerHandler, ::getContact(uid, playerName))
          return
        }
    }

    func.call(ownerHandler, null)
    ::showInfoMsgBox(::loc("chat/error/item-not-found", { nick = playerName }), "incorrect_user")
  })(playerName, ownerHandler, func)

  local taskId = ::find_nicks_by_prefix(playerName, 1, false)
  ::g_tasker.addTask(taskId, null, taskCallback, taskCallback)
  return taskId
}

function send_friend_added_event(friend_uid)
{
  matching_api_notify("mpresence.notify_friend_added",
      {
        friendId = friend_uid
      })
}


function editContactMsgBox(player, groupName, add, ownerHandler, onModify = null) //playerConfig: { uid, name }
{
  if (!player)
    return null

  if (!("uid" in player) || !player.uid || player.uid == "")
  {
    if (!("name" in player))
      return null

    return ::find_contact_by_name_and_do(player.name, ownerHandler,
      (@(groupName, add, ownerHandler, onModify) function(contact) {
        if (contact)
          ::editContactMsgBox(contact, groupName, add, ownerHandler, onModify)
      })(groupName, add, ownerHandler, onModify)
    )
  }

  local contact = ::getContact(player.uid, player.name)
  local add = !::isPlayerInContacts(player.uid, groupName)

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
      if (onModify)
        onModify.call(ownerHandler)
      ::g_popups.add(null, format(msg, contact.name))
    }
  }
  else
  {
    local msg = ::loc("msg/ask_remove_from_" + groupName)
    ::scene_msg_box("remove_from_list", null, format(msg, contact.name), [
      ["ok", (@(contact, groupName, ownerHandler, onModify) function() {
        ::editPlayerInContacts(contact, groupName, false)
        if (onModify && ownerHandler)
          onModify.call(ownerHandler)
      })(contact, groupName, ownerHandler, onModify) ],
      ["cancel", function() {} ]
    ], "cancel")
  }
  return null
}

function addPlayersToContacts(players, groupName) //{ uid = name, uid2 = name2 }
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
      if (groupName == ::EPL_FRIENDLIST || groupName == ::EPLX_PS4_FRIENDS)
      {
        if (::isPlayerInFriendsGroup(uid))
          continue
        else if (groupName == ::EPLX_PS4_FRIENDS && nick.slice(0, 1) != "*")
          groupName = ::EPL_FRIENDLIST
      }

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

function request_edit_player_lists(editBlk, checkFeature = true)
{
  local taskId = ::edit_player_lists(editBlk)
  local taskCallback = (@(checkFeature) function (result = null) {
    if (!checkFeature || ::has_feature("Friends"))
      ::reload_contact_list()
  })(checkFeature)
  return ::g_tasker.addTask(taskId, null, taskCallback, taskCallback)
}

function loadContactsToObj(obj, owner=null)
{
  if (!::checkObj(obj))
    return

  local guiScene = obj.getScene()
  if (!::contacts_handler)
    ::contacts_handler <- ::ContactsHandler(guiScene)
  ::contacts_handler.owner = owner
  ::contacts_handler.initScreen(obj)
}

function switchContactsObj(scene, owner=null)
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

function checkContactsBack()
{
  if (::contacts_handler)
    ::contacts_handler.checkScene()
}

function get_contact_focus_obj()
{
  if (::contacts_handler)
    return ::contacts_handler.getCurFocusObj()
  return null
}

class Contact
{
  name = ""
  uid = ""
  clanTag = ""
  presence = null
  voiceStatus = null

  online = null
  unknown = null
  gameStatus = null
  gameConfig = null
  inGameEx = null

  pilotIcon = "cardicon_bot"
  wins = -1
  rank = -1

  update = false

  constructor(contactData)
  {
    presence = ::g_contact_presence.UNKNOWN
    unknown = true

    local newName = ::getTblValue(name, contactData, "")
    if (newName.len()
        && ::u.isEmpty(::getTblValue("clanTag", contactData))
        && newName in clanUserTable)
      contactData.clanTag <- clanUserTable[newName]

    update(contactData)
  }

  function update(contactData)
  {
    foreach (name, val in contactData)
      if (name in this)
        this[name] = val
    refreshClanTagsTable()
  }

  function getWinsText() {
    if (wins >= 0)
      return wins
    return ::loc("leaderboards/notAvailable")
  }

  function getRankText() {
    if (rank >= 0)
      return rank
    return ::loc("leaderboards/notAvailable")
  }

  function setClanTag(_clanTag)
  {
    clanTag = _clanTag
    refreshClanTagsTable()
  }

  function refreshClanTagsTable()
  {
    //clanTagsTable used in lists where not know userId, so not exist contact.
    //but require to correct work with contacts too
    if (name.len())
      clanUserTable[name] <- clanTag
  }

  function getPresenceText()
  {
    local res = presence.getText()
    if (presence == ::g_contact_presence.IN_QUEUE
        || presence == ::g_contact_presence.IN_GAME)
    {
      local event = ::events.getEvent(::getTblValue("eventId", gameConfig))
      local locParams = {
        gameMode = event ? ::events.getEventNameText(event) : ""
        country = ::loc(::getTblValue("country", gameConfig, ""))
      }
      res = ::replaceParamsInLocalizedText(res, locParams)
    }

    return res
  }
}

function getContact(uid, nick = null, clanTag = "", forceUpdate = false)
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

  if(forceUpdate)
  {
    if(::u.isString(nick))
      ::contacts_players[uid].name = nick
    if(::u.isString(clanTag))
      ::contacts_players[uid].setClanTag(clanTag)
  }

  return ::contacts_players[uid]
}

function clearContactPresence(uid)
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

function update_contacts_by_list(list, needEvent = true)
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

function updateContact(config)
{
  local replace = "replace" in config ? config.replace : false
  local configIsContact = ::u.isInstance(config) && config instanceof ::Contact
  if (::u.isInstance(config) && !configIsContact) //Contact no need update by instances because foreach use function as so constructor
    return

  local uid = config.uid
  if (!configIsContact) //when config is instance of contact we no need update it to self
    if (uid in ::contacts_players && !replace)
      ::contacts_players[uid].update(config)
    else
      ::contacts_players[uid] <- Contact(config)

  local contact = ::contacts_players[uid]
  local presence = ::g_contact_presence.UNKNOWN

  //update presence
  if (contact.online)
    presence = ::g_contact_presence.ONLINE
  else if (!contact.unknown)
    presence = ::g_contact_presence.OFFLINE

  local squadStatus = ::g_squad_manager.getPlayerStatusInMySquad(uid)
  if (squadStatus == squadMemberState.NOT_IN_SQUAD)
  {
    if (contact.online && contact.gameStatus)
      presence = contact.gameStatus == "in_queue"
        ? ::g_contact_presence.IN_QUEUE : ::g_contact_presence.IN_GAME
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

  if (squadStatus != squadMemberState.NOT_IN_SQUAD || is_in_my_clan(null, uid))
    chatUpdatePresence(contact)

  return contact
}

function getFriendsOnlineNum()
{
  local online = 0
  if (::contacts)
  {
    foreach(f in ::contacts[::EPL_FRIENDLIST])
    {
      local contactOnline = !::isInArray(
        f.presence,
        [
          ::g_contact_presence.OFFLINE,
          ::g_contact_presence.UNKNOWN
        ]
      )
      if (contactOnline)
        online++
    }
    if (::EPLX_PS4_FRIENDS in ::contacts)
      foreach(f in ::contacts[::EPLX_PS4_FRIENDS])
      {
        local contactOnline = !::isInArray(
          f.presence,
          [
            ::g_contact_presence.OFFLINE,
            ::g_contact_presence.UNKNOWN
          ]
        )
        if (contactOnline)
          online++
      }
  }
  return online
}

function isContactsWindowActive()
{
  if (!::contacts_handler)
    return false;

  return ::contacts_handler.isContactsWindowActive();
}

function getPlayerUid(nick)
{
  foreach(uid, player in ::contacts_players)
    if (player.name == nick)
      return uid
  return null
}

function findContactByNick(nick)
{
  foreach(uid, player in ::contacts_players)
    if (player.name == nick)
      return player
  return null
}

function fillContactTooltip(obj, contact, handler)
{
  local view = {
    name = contact.name
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

  local blk = ::handyman.renderCached("gui/contactTooltip", view)
  obj.getScene().replaceContentFromText(obj, blk, blk.len(), handler)
}

function collectMissedContactData (uid, key, val)
{
  if(!(uid in ::missed_contacts_data))
    ::missed_contacts_data[uid] <- {}
  ::missed_contacts_data[uid][key] <- val
}

function addContactGroup(group)
{
  if(!(::isInArray(group, ::contacts_groups)))
  {
    ::contacts_groups.insert(2, group)
    ::contacts[group] <- []
    if(::contacts_handler && "fillContactsList" in ::contacts_handler)
      ::contacts_handler.fillContactsList.call(::contacts_handler)
  }
}

function getFriendGroupName(playerName)
{
  if (::isPlayerPS4Friend(playerName))
    return ::EPLX_PS4_FRIENDS
  return ::EPL_FRIENDLIST
}

function isPlayerInFriendsGroup(uid, searchByUid = true, playerNick = "")
{
  if (uid == null)
    searchByUid = false

  local isFriend = false
  if (searchByUid)
    isFriend = ::isPlayerInContacts(uid, ::EPL_FRIENDLIST) || ::isPlayerInContacts(uid, ::EPLX_PS4_FRIENDS)
  else if (playerNick != "")
    isFriend = ::isPlayerNickInContacts(playerNick, ::EPL_FRIENDLIST) || ::isPlayerNickInContacts(playerNick, ::EPLX_PS4_FRIENDS)

  return isFriend
}

function clear_contacts()
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

function add_squad_to_contacts()
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
