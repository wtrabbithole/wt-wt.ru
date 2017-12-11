local squadsListData = require("scripts/squads/clanSquadsList.nut")

class ::gui_handlers.MyClanSquadsListModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanSquadsModal.blk"
  squadsListObj = null
  minListItems = 5

  curList = null
  selectedSquad = null
  selectedIndex = 0

  static function open()
  {
    ::gui_start_modal_wnd(::gui_handlers.MyClanSquadsListModal)
  }

  function initScreen()
  {
    squadsListObj = scene.findObject("clan_squads_list")
    if (!::checkObj(squadsListObj))
      return goBack()
    curList = []
    selectedSquad = null
    local view = { squad = array(minListItems, null) }
    local blk = ::handyman.renderCached(("gui/clans/clanSquadsList"), view)
    guiScene.appendWithBlk(squadsListObj, blk, this)
    scene.findObject("squad_list_update").setUserData(this)
    refreshList()

    squadsListObj.setValue(0)
    initFocusArray()
    restoreFocus()
  }

  function refreshList()
  {
    local newList = clone squadsListData.getList()

    local total = ::max(newList.len(), curList.len())
    local isSelected = false
    for(local i = 0; i < total; i++)
    {
      updateSquadInfo(i, curList?[i], newList?[i])
      if (!isSelected && ::u.isEqual(selectedSquad, newList?[i]) && (selectedIndex != -1))
        {
          squadsListObj.setValue(i)
          isSelected = true
        }
    }
    if (!isSelected && curList.len()>0)
    {
      selectedIndex = clamp(selectedIndex, 0, curList.len() - 1)
      selectedSquad = curList[selectedIndex]
      squadsListObj.setValue(selectedIndex)
    }
    curList = newList

    updateSquadsListInfo(curList.len())
  }

  function updateSquadInfo(idx, curSquad, newSquad)
  {
    if (curSquad == newSquad
      || (::u.isEqual(curSquad, newSquad)))
      return

    local obj = getSquadObj(idx)
    local show = newSquad ? true: false
    obj.show(show)
    obj.enable(show)
    if (!show)
      return null
    obj.findObject("leader_name").setValue(getLeaderName(newSquad))
    obj.findObject("num_members").setValue(getNumMembers(newSquad))
    obj.findObject("presence").setValue(getPresence(newSquad))
  }

  function getSquadObj(idx)
  {
    if (squadsListObj.childrenCount() > idx) {
        return squadsListObj.getChild(idx)
    }
    return squadsListObj.getChild(idx-1).getClone()
  }

  function getLeaderName(squad)
  {
    return ::getContact(squad?.leader.tostring())?.name ?? ""
  }

  function getNumMembers(squad)
  {
    return ::loc("squad/size", { numMembers = getNumberMembers(squad)
                          maxMembers = getMaxMembers(squad)})
  }

  function getPresence(squad)
  {
    local presenceParams = squad?.data?.presence ?? {}
    return ::g_presence_type.getByPresenceParams(presenceParams).getLocText(presenceParams)
  }

  function onUpdate(obj, dt)
  {
    doWhenActiveOnce("refreshList")
  }

  function updateSquadsListInfo(visibleSquadsAmount)
  {
    local needWaitIcon = !visibleSquadsAmount && squadsListData.isInUpdate
    scene.findObject("items_list_wait_icon").show(needWaitIcon)

    local infoText = ""
    if (!visibleSquadsAmount && !needWaitIcon)
      infoText = ::loc("clan/no_squads_in_clan")

    scene.findObject("items_list_msg").setValue(infoText)
  }

  function getNumberMembers(squad)
  {
    return (squad?.members ?? []).len()
  }

  function getMaxMembers(squad)
  {
    return squad?.data?.properties?.maxMembers ?? ""
  }

  function onItemSelect(obj)
  {
    local countListItem = curList.len()
    if (countListItem <= 0)
      {
        selectedSquad = null
        selectedIndex = -1
        return
      }

    local index = obj.getValue()
    if (index < 0 || index >= countListItem)
    {
      return
    }

    selectedIndex = index
    selectedSquad = curList[index]
  }

  function getMainFocusObj()
  {
    return squadsListObj
  }
}
