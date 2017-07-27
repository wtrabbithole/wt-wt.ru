function debug_wnd(blkName = null, tplParams = {}, callbacksContext = null)
{
  ::gui_start_modal_wnd(::gui_handlers.debugWndHandler, { blkName = blkName, tplParams = tplParams, callbacksContext = callbacksContext })
}

class ::gui_handlers.debugWndHandler extends ::BaseGuiHandler
{
  sceneBlkName = "gui/debugFrame.blk"
  wndType = handlerType.MODAL

  isExist = false
  blkName = null
  tplName = null
  tplParams = {}
  lastModified = null
  checkTimer = 0.0

  callbacksContext = null

  function initScreen()
  {
    isExist = blkName ? ::is_existing_file(blkName, false) : false
    tplName = ::g_string.endsWith(blkName, ".tpl") ? ::g_string.slice(blkName, 0, -4) : null
    tplParams = tplParams || {}

    scene.findObject("debug_wnd_update").setUserData(this)
    updateWindow()
  }

  function reinitScreen(params)
  {
    local _blkName = ::getTblValue("blkName", params, blkName)
    local _tplParams = ::getTblValue("tplParams", params, tplParams)
    if (_blkName == blkName && ::u.isEqual(_tplParams, tplParams))
      return

    blkName = _blkName
    isExist = blkName ? ::is_existing_file(blkName, false) : false
    tplName = ::g_string.endsWith(blkName, ".tpl") ? ::g_string.slice(blkName, 0, -4) : null
    tplParams = _tplParams || {}

    lastModified = null
    updateWindow()
  }

  function updateWindow()
  {
    if (!::checkObj(scene))
      return

    local obj = scene.findObject("debug_wnd_content_box")
    if (!isExist)
    {
      local txt = (blkName == null ? "No file specified." :
        ("File not found: \"" + ::colorize("userlogColoredText", blkName) + "\""))
        + "~nUsage examples:"
        + "~ndebug_wnd(\"gui/debriefing/debriefing.blk\")"
        + "~ndebug_wnd(\"gui/menuButton.tpl\", {buttonText=\"Test\"})"
      local data = "textAreaCentered { pos:t='pw/2-w/2, ph/2-h/2' position:t='absolute' text='" + txt + "' }"
      return guiScene.replaceContentFromText(obj, data, data.len(), callbacksContext)
    }

    if (tplName)
    {
      local data = ::handyman.render(::load_scene_template(tplName), tplParams)
      guiScene.replaceContentFromText(obj, data, data.len(), callbacksContext)
    }
    else
      guiScene.replaceContent(obj, blkName, callbacksContext)
  }

  function checkModify()
  {
    if (!isExist)
      return
    local modified = ::get_file_modify_time(blkName)
    if (!modified)
      return

    modified = ::get_full_time_table(modified)
    if (!lastModified)
    {
      lastModified = modified
      return
    }

    if (::cmp_date(lastModified, modified) != 0)
    {
      lastModified = modified
      updateWindow()
    }
  }

  function onUpdate(obj, dt)
  {
    checkTimer -= dt
    if (checkTimer < 0)
    {
      checkTimer += 0.5
      checkModify()
    }
  }
}