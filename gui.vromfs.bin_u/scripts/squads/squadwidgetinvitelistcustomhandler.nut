class ::gui_handlers.SquadWidgetInviteListCustomHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType             = handlerType.MODAL
  sceneBlkName        = "gui/squads/squadInvites.blk"
  inviteListTplName   = "gui/squads/squadInvites"

  INVITE_LIST_OBJ_ID  = "invites_list"
  NEST_OBJ_ID         = "squad_invites"

  align = "top"
  alignObj = null

  function initScreen()
  {
    updateView()
  }

  function updateView()
  {
    local invitedPlayers = ::g_squad_manager.getInvitedPlayers()
    if (invitedPlayers.len() == 0)
      return goBack()

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

  function updateSize()
  {
    local listObj = scene.findObject(INVITE_LIST_OBJ_ID)
    if (!::checkObj(listObj))
      return

    local invites = ::g_squad_manager.getInvitedPlayers()
    local rows = (::sqrt(invites.len()) + 0.5).tointeger() || 1
    local columns = ::ceil(invites.len().tofloat() / rows.tofloat())

    local sizeFormat = "%d@mIco + 2@framePadding"
    listObj.width = ::format(sizeFormat, columns)
    listObj.height = ::format(sizeFormat, rows)
  }

  function updatePosition()
  {
    local nestObj = scene.findObject(NEST_OBJ_ID)
    if (::checkObj(nestObj))
      nestObj.pos = ::getPositionToDraw(alignObj, align)
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

  /**event handlers**/
  function onEventSquadInvitesChanged(params)
  {
    doWhenActiveOnce("updateView")
  }
}