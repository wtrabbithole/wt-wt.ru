class ::gui_handlers.FramedOptionsWnd extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/framedOptionsWnd.blk"
  sceneNavBlkName = null
  multipleInstances = true

  align = ALIGN.TOP
  alignObj = null
  menuWidth = "0.6@sf"

  function initScreen()
  {
    local tableObj = scene.findObject("optionslist")
    tableObj.width = menuWidth
    if (options)
    {
      tableObj.height = options.len() + "@baseTrHeight"
      if (options.len() <= 1)
        tableObj.invisibleSelection = "yes"
    }

    base.initScreen()

    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"))
    initOpenAnimParams()
  }

  function goBack()
  {
    applyOptions(true)
  }

  function applyReturn()
  {
    if (!applyFunc)
      restoreMainOptions()
    base.applyReturn()
  }

  function initOpenAnimParams()
  {
    local animObj = scene.findObject("anim_block")
    if (!animObj)
      return
    local size = animObj.getSize()
    if (!size[0] || !size[1])
      return

    local isVertical = align == ALIGN.TOP || align == ALIGN.BOTTOM
    local scaleId = isVertical ? "height" : "width"
    local scaleAxis = isVertical ? 1 : 0

    animObj[scaleId] = "1"
    animObj[scaleId + "-base"] = "1"
    animObj[scaleId + "-end"] = size[scaleAxis].tostring()
  }
}
