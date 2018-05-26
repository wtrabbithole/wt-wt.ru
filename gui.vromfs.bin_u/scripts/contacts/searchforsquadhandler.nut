function gui_start_search_squadPlayer()
{
  if (!::g_squad_manager.canInviteMember())
  {
    ::showInfoMsgBox(::loc("squad/not_a_leader"), "squad_not_available")
    return
  }

  ::update_ps4_friends()
  ::g_contacts.updateXboxOneFriends()
  ::handlersManager.loadHandler(::gui_handlers.SearchForSquadHandler)
}

class ::gui_handlers.SearchForSquadHandler extends ::ContactsHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/contacts/contacts.blk"

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