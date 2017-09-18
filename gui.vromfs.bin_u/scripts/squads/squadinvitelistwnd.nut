class ::gui_handlers.squadInviteListWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType             = handlerType.MODAL
  sceneBlkName        = "gui/squads/squadInvites.blk"
  shouldBlurSceneBg   = false

  inviteListTplName   = "gui/squads/squadInvites"

  INVITE_LIST_OBJ_ID  = "invites_list"
  NEST_OBJ_ID         = "squad_invites"

  align = "top"
  alignObj = null

  optionsObj = null

  static function open(alignObj)
  {
    if (!canOpen())
      return null

    if (!::checkObj(alignObj))
      return null

    local params = {
      alignObj = alignObj
    }

    return ::handlersManager.loadHandler(::gui_handlers.squadInviteListWnd, params)
  }

  static function canOpen()
  {
    return ::has_feature("Squad") && ::has_feature("SquadWidget")
      && ::g_squad_manager.isInSquad()
      && (::g_squad_manager.canChangeSquadSize(false) || ::g_squad_manager.getInvitedPlayers().len() > 0)
  }

  function initScreen()
  {
    optionsObj = scene.findObject("options_block")

    updateSquadSizeOption()
    updateInviteesList()
  }

  function updateInviteesList()
  {
    local invitedPlayers = ::g_squad_manager.getInvitedPlayers()
    local listObj = scene.findObject(INVITE_LIST_OBJ_ID)
    local viewData = getMembersViewData()
    local viewBlk = ::handyman.renderCached(inviteListTplName, viewData)

    guiScene.replaceContentFromText(listObj, viewBlk, viewBlk.len(), this)

    foreach(memberData in invitedPlayers)
    {
      local inviteObj = listObj.findObject("squad_invite_" + memberData.uid)
      if (::checkObj(inviteObj))
        inviteObj.setUserData(memberData)
    }

    scene.findObject("invited_players_header").show(invitedPlayers.len() > 0)
    updateSelectedItem()
    updateSize()
    updatePosition()
  }

  function getMembersViewData()
  {
    local items = []
    foreach(memberData in ::g_squad_manager.getInvitedPlayers())
      items.push(
        {
          id = memberData.uid
          pilotIcon = "#ui/images/avatars/" + memberData.pilotIcon
        }
      )

    return { items = items }
  }

  function updateSquadSizeOption()
  {
    local isAvailable = ::g_squad_manager.canChangeSquadSize(false)
    optionsObj.show(isAvailable)
    optionsObj.enable(isAvailable)
    if (!isAvailable)
      return

    local sizes = ::u.map(::g_squad_manager.squadSizesList,
      @(s) s.value + ::loc("ui/comma") + ::loc("squadSize/" + s.name))
    local curValue = ::g_squad_manager.getMaxSquadSize()
    local curIdx = ::u.searchIndex(::g_squad_manager.squadSizesList, @(s) s.value == curValue, 0)

    local optionObj = scene.findObject("squad_size_option")
    local markup = ::create_option_combobox("", sizes, curIdx, null, false)
    guiScene.replaceContentFromText(optionObj, markup, markup.len(), this)
    optionObj.setValue(curIdx)
    optionObj.enable(::g_squad_manager.canChangeSquadSize())
  }

  function updateSize()
  {
    local listObj = scene.findObject(INVITE_LIST_OBJ_ID)
    if (!::checkObj(listObj))
      return

    local total = ::g_squad_manager.getInvitedPlayers().len()
    local rows = total && (total <= 5 ? 1 : 2)
    local columns = rows && ::ceil(total.tofloat() / rows.tofloat())

    local sizeFormat = "%d@mIco"
    listObj.width = ::format(sizeFormat, columns)
    listObj.height = ::format(sizeFormat, rows)
  }

  function updatePosition()
  {
    local nestObj = scene.findObject(NEST_OBJ_ID)
    if (::checkObj(nestObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, nestObj)
  }

  function updateSelectedItem()
  {
    local navigatorObj = scene.findObject(INVITE_LIST_OBJ_ID)
    local childrenCount = navigatorObj.childrenCount()
    if (childrenCount <= 0)
      return

    local value = navigatorObj.getValue()
    value = (value >= childrenCount || value < 0) ? 0 : value
    navigatorObj.setValue(value)
    navigatorObj.select()
  }

  function checkActiveForDelayedAction()
  {
    return isSceneActive()
  }

  function onInviteMemberMenu(obj)
  {
    local listObj = scene.findObject(INVITE_LIST_OBJ_ID)
    if (!::checkObj(listObj))
      return

    local childrenCount = listObj.childrenCount()
    if (!childrenCount)
      return

    local value = ::clamp(listObj.getValue(), 0, childrenCount - 1)
    local selectedObj = listObj.getChild(value)

    ::g_squad_utils.showMemberMenu(selectedObj)
  }

  function onMemberClicked(obj)
  {
    ::g_squad_utils.showMemberMenu(obj)
  }

  function onSquadSizeChange(obj)
  {
    local idx = obj.getValue()
    if (idx in ::g_squad_manager.squadSizesList)
      ::g_squad_manager.setSquadSize(::g_squad_manager.squadSizesList[idx].value)
  }

  /**event handlers**/
  function onEventSquadInvitesChanged(params)
  {
    doWhenActiveOnce("updateInviteesList")
  }
}
