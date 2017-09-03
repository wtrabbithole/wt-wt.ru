/*
  config = [
    {
      text = string
      action = function
      show = boolean || function
      onUpdateButton = function(params)  //return table { text = "new button text", enable = true, stopUpdate = false }
                                         //updates button once per sec.
    }
    ...
  ]
*/
function gui_right_click_menu(config, owner, position = null)
{
  if (typeof config == "array")
    config = { actions = config }
  ::handlersManager.loadHandler(::gui_handlers.RightClickMenu, { config = config, owner = owner, position = position })
}

class ::gui_handlers.RightClickMenu extends ::BaseGuiHandler
{
  wndType      = handlerType.MODAL
  sceneTplName = "gui/rightClickMenu"
  shouldBlurSceneBg = false

  owner        = null
  config       = null
  position     = null
  choosenValue = -1

  timeOpen     = 0
  isListEmpty  = true

  idPrefix     = "btn_"

  function getSceneTplView()
  {
    local view = {
      actions = []
    }

    isListEmpty = true
    if (!("actions" in config))
      return view

    foreach(idx, item in config.actions)
    {
      if ("show" in item && !((typeof(item.show) == "function") ? item.show.call(owner) : item.show))
        continue

      local actionData = null //lineDiv
      if ("text" in item)
      {
        local enabled = true
        if ("enabled" in item)
          enabled = typeof(item.enabled) == "function"
                    ? item.enabled.call(owner)
                    : item.enabled

        actionData = {
          id = idPrefix + idx.tostring()
          text = item.text
          textUncolored = ::g_dagui_utils.removeTextareaTags(item.text)
          tooltip = ::getTblValue("tooltip", item, "")
          enabled = enabled
          needTimer = ::u.isFunction(::getTblValue("onUpdateButton", item))
        }
      }

      view.actions.append(actionData)
      isListEmpty = false
    }

    return view
  }

  function initScreen()
  {
    if (isListEmpty)
      return goBack()

    timeOpen = ::dagor.getCurTime()
    local listObj = scene.findObject("rclick_menu_div")

    guiScene.setUpdatesEnabled(false, false)
    initTimers(listObj, config.actions)
    guiScene.setUpdatesEnabled(true, true)
    listObj.select()

    local rootSize = guiScene.getRoot().getSize()
    local cursorPos = position ? position : ::get_dagui_mouse_cursor_pos_RC()
    local menuSize = listObj.getSize()
    local menuPos =  [cursorPos[0], cursorPos[1]]
    for(local i = 0; i < 2; i++)
      if (menuPos[i] + menuSize[i] > rootSize[i])
        if (menuPos[i] > menuSize[i])
          menuPos[i] -= menuSize[i]
        else
          menuPos[i] = ((rootSize[i] - menuSize[i]) / 2).tointeger()

    listObj.pos = menuPos[0] + ", " + menuPos[1]
  }

  function initTimers(listObj, actions)
  {
    foreach(idx, item in actions)
    {
      local onUpdateButton = ::getTblValue("onUpdateButton", item)
      if (!::u.isFunction(onUpdateButton))
        continue

      local obj = listObj.findObject(idPrefix + idx.tostring())
      if (!::checkObj(obj))
        continue

      ::secondsUpdater(obj,
                       (@(onUpdateButton) function(obj, params) {
                         local data = onUpdateButton(params)
                         updateBtnByTable(obj, data)
                         return ::getTblValue("stopUpdate", data, false)
                       })(onUpdateButton).bindenv(this))
    }
  }

  function updateBtnByTable(btnObj, data)
  {
    local text = ::getTblValue("text", data)
    if (!::u.isEmpty(text))
    {
      btnObj.setValue(::g_dagui_utils.removeTextareaTags(text))
      btnObj.findObject("text").setValue(text)
    }

    local enable = ::getTblValue("enable", data)
    if (::u.isBool(enable))
      btnObj.enable(enable)
  }

  function onMenuButton(obj)
  {
    if (!obj || obj.id.len() < 5)
      return

    choosenValue = obj.id.slice(4).tointeger()
    goBack()
  }

  function goBack()
  {
    if (scene && (::dagor.getCurTime() - timeOpen) < 100 && !isListEmpty)
      return

    base.goBack()
  }

  function afterModalDestroy()
  {
    if (!(choosenValue in config.actions))
      return

    local applyFunc = ::getTblValue("action", config.actions[choosenValue])
    ::call_for_handler(owner, applyFunc)
  }
}
