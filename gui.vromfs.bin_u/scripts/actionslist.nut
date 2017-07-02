/*
  API
    ActionsList.create(parent, params)
      parent - an object, in which will be created ActionsList.
        No need to make a special object for ActionsList.
        ActionList will be aligned on border of parent in specified side

      params = {
        orientation = ALIGN.TOP

        handler = null - handler, which implemets functions, specified in func
          field of actions.

        actions = [
          {
            // icon = ""
            text = ""
            action = function (){}
            // show = function (){return true}
            // selected = false
          }

          ...

        ]
      }

*/

class ::gui_handlers.ActionsList
{
  params    = null
  parentObj = null
  selfObj   = null
  guiScene  = null

  closeOnUnhover = false

  __al_obj_blk      = "gui/actionsList/actionsListBlock.blk"
  __al_obj_tag      = "popup_menu"

  __al_item_obj_tpl = "gui/actionsList/actionsListItem"

  function constructor(_parentObj, _params)
  {
    if (!::checkObj(_parentObj))
      return
    if (::checkObj(_parentObj.findObject("actions_list"))) //duplicate protection
      return
    guiScene = _parentObj.getScene()
    params = _params
    parentObj = _parentObj
    initScreen()
  }

  function initScreen()
  {
    if (parentObj.refuseOpenHoverMenu == "yes")
      return

    selfObj = guiScene.createElementByObject(parentObj,
                                             __al_obj_blk,
                                             __al_obj_tag,
                                             this)

    if (!("closeOnUnhover" in params))
      params.closeOnUnhover <- false

    selfObj.closeOnUnhover = params.closeOnUnhover
                            ? "yes"
                            : "no"
    fillList()
    setOrientation()
  }

  function fillList()
  {
    if (!("actions" in params) || params.actions.len() <= 0)
      return goBack()

    local nest = selfObj.findObject("list_nest")

    local isIconed = false
    foreach (idx, action in params.actions)
    {
      local show = ::getTblValue("show", action, true)
      if (!("show" in action))
        action.show <- show

      action.text <- ::stringReplace(::getTblValue("text", action, ""), " ", ::nbsp)

      isIconed = isIconed || (show && ::getTblValue("icon", action) != null)
    }
    selfObj.iconed = isIconed ? "yes" : "no"

    local data = ::handyman.renderCached(__al_item_obj_tpl, params)
    guiScene.replaceContentFromText(nest, data, data.len(), this)

    // Temp Fix, DaGui cannot recalculate childrens width according to parent after replaceContent
    local maxWidth = 0
    for(local i = 0; i < nest.childrenCount(); i++)
      maxWidth = ::max(maxWidth, nest.getChild(i).getSize()[0])
    nest.width = maxWidth

    if (!params.closeOnUnhover)
    {
      guiScene.performDelayed(this, (@(nest, params) function () {
        if (!::checkObj(nest))
          return

        local selIdx = ::u.searchIndex(params.actions, function (action) {
          return ::getTblValue("selected", action, false) && ::getTblValue("show", action)
        })

        nest.setValue(::max(selIdx, 0))
        nest.select()
      })(nest, params))
    }
  }

  function setOrientation()
  {
    guiScene.setUpdatesEnabled(true, true)
    selfObj.al_align = "orientation" in params
                     ? params.orientation
                     : ALIGN.TOP
    local selfSize = selfObj.getSize()
    local prntSize = parentObj.getSize()
    local prntPos  = parentObj.getPosRC()
    local rootSize = guiScene.getRoot().getSize()

    if (!("orientation" in params))
      params.orientation <- ALIGN.TOP


    if (params.orientation == ALIGN.TOP
        && prntPos[1] - selfSize[1] < 0)
      params.orientation = ALIGN.BOTTOM

    if (params.orientation == ALIGN.BOTTOM
        && prntPos[1] + prntSize[1] + selfSize[1] > rootSize[1])
      params.orientation = ALIGN.TOP

    selfObj.al_align = params.orientation
  }

  function goBack()
  {
    if (::checkObj(selfObj))
      selfObj.close = "yes"
  }

  function onAction(obj)
  {
    goBack()
    local actionName = obj.id
    if (actionName == "")
      return

    guiScene.performDelayed(this, (@(actionName) function () {
      if (!::checkObj(selfObj))
        return

      guiScene.destroyElement(selfObj)
      local func = null
      foreach(action in params.actions)
        if (action.actionName == actionName)
        {
          func = action.action
          break
        }

      if (func == null)
        return

      if (typeof func == "string")
        params.handler[func].call(params.handler)
      else
        func.call(params.handler)
    })(actionName))
  }

  function close()
  {
    goBack()
    ::broadcastEvent("ClosedUnitItemMenu")
  }

  function onFocus(obj)
  {
    guiScene.performDelayed(this, (@(obj) function () {
        if (!::checkObj(obj))
          return
        local total = obj.childrenCount()
        if (!total)
          return close()

        local value = ::clamp(obj.getValue(), 0, total - 1)
        local currentObj = obj.getChild(value)
        if (( !::checkObj(currentObj) || !currentObj.isFocused()) &&
          !obj.isFocused() && !params.closeOnUnhover)
          close()
      })(obj)
    )
  }

  function onBtnClose()
  {
    close()
  }

  static function removeActionsListFromObject(obj, fadeout = false)
  {
    local alObj = obj.findObject("actions_list")
    if (!::checkObj(alObj))
      return
    if (fadeout)
      alObj.close = "yes"
    else
      alObj.getScene().destroyElement(alObj)
  }

  static function hasActionsListOnObject(obj)
  {
    return ::checkObj(obj.findObject("actions_list"))
  }

  static function switchActionsListVisibility(obj)
  {
    if (!::checkObj(obj))
      return false

    if (obj.refuseOpenHoverMenu)
    {
      obj.refuseOpenHoverMenu = obj.refuseOpenHoverMenu == "no"? "yes" : "no"
      return true
    }

    return false
  }
}
