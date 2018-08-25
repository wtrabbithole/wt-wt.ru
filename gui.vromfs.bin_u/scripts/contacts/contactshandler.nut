local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")
local platformModule = require("scripts/clientState/platform.nut")

::contacts_prev_scenes <- [] //{ scene, show }
::last_contacts_scene_show <- false

class ::ContactsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  searchText = ""

  listNotPlayerChildsByGroup = null

  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  isPrimaryFocus = false
  focusArray = [
    "search_edit_box"
    function() { return getListFocusObj() }
    "btn_psnFriends"
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
    ::handlersManager.doDelayed(::Callback(function()
    {
      _lastMaskUpdateDelayedCall = 0
      updateControlsAllowMask()
    }, this))
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
      guiScene.replaceContent(scene, "gui/contacts/contacts.blk", this)
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

  needShowContactHoverButtons = @() !::is_ps4_or_xbox

  function buildPlayersList(gName, showOffline=true)
  {
    local playerListView = {
      playerListItem = []
      playerButton = []
      searchAdvice = gName != searchGroup
      searchAdviceID = "group_" + gName + "_search_advice"
      needHoverButtons = needShowContactHoverButtons()
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
        playerListView.playerButton.push(createPlayerButtonView("btnSteamFriendsAdd", "#ui/gameuiskin#btn_steam_friends_add.svg", "onSteamFriendsAdd"))
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

      local fullName = ::g_contacts.getPlayerFullName(f.getName(), f.clanTag)
      local contactNameObj = obj.findObject("contactName")
      contactNameObj.setValue(fullName)
      local contactPresenceObj = obj.findObject("contactPresence")
      if (::checkObj(contactPresenceObj))
      {
        contactPresenceObj.setValue(f.getPresenceText())
        contactPresenceObj["color-factor"] = f.presence.iconTransparency
      }
      obj.findObject("tooltip").uid = f.uid
      if (selUid == f.uid)
        sel = fIdx

      local imgObj = obj.findObject("statusImg")
      imgObj["background-image"] = f.presence.getIcon()
      imgObj["background-color"] = f.presence.getIconColor()

      obj.findObject("pilotIconImg").setValue(f.pilotIcon)
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
      local contactObject = scene.findObject(::format("player_%s_%s", gName.tostring(), idx.tostring()))
      contactObject.contact_buttons_contact_uid = contact.uid

      local contactButtonsHolder = contactObject.findObject("contact_buttons_holder")
      if (!::check_obj(contactButtonsHolder))
        continue

      updateContactButtonsVisibility(contact, contactButtonsHolder)
    }
  }

  function updateContactButtonsVisibility(contact, contact_buttons_holder)
  {
    if (!checkScene())
      return

    local isFriend = contact? contact.isInFriendGroup() : false
    local isBlock = contact? contact.isInBlockGroup() : false
    local isMe = contact? contact.isMe() : false
    local isXBoxOnePlayer = platformModule.isXBoxPlayerName(contact?.name ?? "")
    local canInvitePlayer = ::is_platform_xboxone == isXBoxOnePlayer
    local canInteractWithPlayer = contact? contact.canInteract() : true
    local canInviteXboxPlayerFriend = !::is_platform_xboxone || isFriend
    local canInviteXboxPlayerOnline = !::is_platform_xboxone || contact && contact.presence == ::g_contact_presence.ONLINE

    showBtn("btn_friendAdd", !isMe && !isFriend && !isBlock && canInvitePlayer, contact_buttons_holder)
    showBtn("btn_friendRemove", isFriend, contact_buttons_holder)
    showBtn("btn_blacklistAdd", !isMe && !isFriend && !isBlock && (!canInvitePlayer || !::is_platform_xboxone), contact_buttons_holder)
    showBtn("btn_blacklistRemove", isBlock && (!canInvitePlayer || !::is_platform_xboxone), contact_buttons_holder)
    showBtn("btn_message", owner
                           && !isBlock
                           && platformModule.isChatEnabled()
                           && canInteractWithPlayer, contact_buttons_holder)

    local showSquadInvite = ::has_feature("SquadInviteIngame")
      && !isMe
      && !isBlock
      && canInvitePlayer
      && ::g_squad_manager.canInviteMember(contact?.uid ?? "")
      && !::g_squad_manager.isPlayerInvited(contact?.uid ?? "", contact?.name ?? "")
      && canInteractWithPlayer
      && platformModule.canSquad()
      && canInviteXboxPlayerFriend
      && canInviteXboxPlayerOnline

    local btnObj = showBtn("btn_squadInvite", showSquadInvite, contact_buttons_holder)
    if (btnObj && showSquadInvite && contact?.uidInt64)
      updateButtonInviteText(btnObj, contact.uidInt64)

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
    groupHeader {
      canBeClosed:t='yes';
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

  function onSearchEditBoxActivate(obj)
  {
    doSearch(obj)
  }

  function doSearch(editboxObj = null)
  {
    if (!editboxObj)
      editboxObj = scene.findObject("search_edit_box")
    if (!::check_obj(editboxObj))
      return

    local searchText = ::clearBorderSymbols(editboxObj.getValue())
    searchText = platformModule.getPlayerNameNoSpecSymbol(searchText)
    if (searchText == "")
      return

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

  function onSearchEditBoxChangeValue(obj)
  {
    setSearchText(platformModule.getPlayerName(obj.getValue()), false)
    applyContactFilter()
  }

  _lastFocusdelayedCall = 0
  function onContactsFocus()
  {
    if (_lastFocusdelayedCall
        && _lastFocusdelayedCall < ::dagor.getCurTime() + LOST_DELAYED_ACTION_MSEC)
      return

    _lastFocusdelayedCall = ::dagor.getCurTime()
    ::handlersManager.doDelayed(::Callback(function()
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
    }, this))
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
      contactName = platformModule.getPlayerName(contactName)
      local searchResult = searchText == "" || contactName.find(searchText) != null
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

    local gObj = scene.findObject("contacts_groups")
    if (!gObj) return
    guiScene.setUpdatesEnabled(false, false)

    local data = ""
    foreach(gIdx, gName in groups_array)
    {
      ::contacts[gName].sort(::sortContacts)
      local activateEvent = "onPlayerMsg"
      if (::show_console_buttons || !platformModule.isChatEnabled())
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

  function onEventModalWndDestroy(params)
  {
    checkScene()
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

  function onSearchButtonClick(obj)
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

    if (::contacts[curGroup].len() == 0)
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

    if (needShowContactHoverButtons())
      updateContactButtonsVisibility(curPlayer, scene)
  }

  function onPlayerMenu(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    showCurPlayerRClickMenu(obj.getChild(value).getPosRC())
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
    playerContextMenu.showMenu(curPlayer, this, {position = position} )
  }

  function isContactsWindowActive()
  {
    return checkScene() && ::last_contacts_scene_show;
  }

  function updateButtonInviteText(btnObj, uid)
  {
    btnObj.tooltip = ::g_squad_manager.hasApplicationInMySquad(uid)
        ? ::loc("squad/accept_membership")
        : ::loc("squad/invite_player")
  }

  function updateConsoleButtons()
  {
    if (!checkScene())
      return

    showSceneBtn("contacts_buttons_console", ::show_console_buttons)
    if (!::show_console_buttons)
      return

    local focusObj = getListFocusObj(true)
    local showSelectButton = focusObj != null || getSearchObj().isFocused()

    if (showSelectButton)
    {
      local btnTextLocId = "contacts/choosePlayer"
      if (focusObj?.id == "contacts_groups")
        btnTextLocId = "contacts/chooseGroup"
      else if (getSearchObj().isFocused())
        btnTextLocId = "contacts/search"
      scene.findObject("btn_contactsSelect").setValue(::loc(btnTextLocId))
    }

    showSceneBtn("btn_psnFriends", ::is_platform_ps4)
    showSceneBtn("btn_contactsSelect", showSelectButton)
  }

  function onFacebookFriendsAdd()
  {
    onFacebookLoginAndAddFriends()
  }

  function editPlayerInList(obj, listName, add)
  {
    updateCurPlayer(obj)
    ::editContactMsgBox(curPlayer, listName, add)
  }

  function updateCurPlayer(button_object)
  {
    if (!::checkObj(button_object))
      return

    local contactButtonsObject = button_object.getParent().getParent()
    local contactUID = contactButtonsObject.contact_buttons_contact_uid
    if (!contactUID)
      return

    local contact = ::getContact(contactUID)
    curPlayer = contact

    local idx = contacts[curGroup].find(contact)
    if (idx >= 0)
    {
      local groupObject = scene.findObject("contacts_groups")
      local listObject = groupObject.findObject("group_" + curGroup)
      listObject.setValue(idx)
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

    local uid = curPlayer.uid
    local name = curPlayer.name
    if (::g_squad_manager.canInviteMember(uid))
      if (::g_squad_manager.hasApplicationInMySquad(uid.tointeger(), name))
        ::g_squad_manager.acceptMembershipAplication(uid.tointeger())
      else
        ::g_squad_manager.inviteToSquad(uid, name)
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

    local taskId = ::find_nicks_by_prefix(value, maxSearchPlayers, true)
    if (taskId >= 0)
    {
      searchInProgress = true
      ::contacts[searchGroup] <- []
      updateSearchList()
    }
    ::g_tasker.addTask(taskId, null, ::Callback(onSearchCb, this))
  }

  function onSearchCb()
  {
    searchInProgress = false

    local searchRes = ::DataBlock()
    searchRes = ::get_nicks_find_result_blk()
    ::contacts[searchGroup] <- []

    local brokenData = false
    for (local i = 0; i < searchRes.paramCount(); i++)
    {
      local contact = ::getContact(searchRes.getParamName(i), searchRes.getParamValue(i))
      if (contact)
      {
        if (!contact.isMe() && !contact.isInFriendGroup())
          ::contacts[searchGroup].append(contact)
      }
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
        data = "animated_wait_icon { pos:t='0.5(pw-w),0.03sh'; position:t='absolute'; background-rotation:t='0' }"
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

  function onEventSquadStatusChanged(p)
  {
    updateContactsGroup(null)
  }
}
