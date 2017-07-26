/*
  config = {
    options = [{ image = img1 }, { image = img2, height = 50 }]
    tooltipObjFunc = function(obj, value)  - function to generate custom tooltip for item.
                                             must return bool if filled correct
    value = 0
  }
*/
function gui_choose_image(config, applyFunc, owner)
{
  ::handlersManager.loadHandler(::gui_handlers.ChooseImage, {
                                  config = config
                                  owner = owner
                                  applyFunc = applyFunc
                                })
}

class ::gui_handlers.ChooseImage extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chooseImage/chooseImage.blk"

  config = null
  options = null
  owner = null
  applyFunc = null
  choosenValue = null

  currentPage  = -1
  itemsPerPage = 24
  valueInited = false

  value = -1
  contentObj = null

  function initScreen()
  {
    if (!config || !("options" in config))
      return goBack()

    options = []
    local configValue = ("value" in config)? config.value : -1
    foreach(idx, option in config.options)
    {
      local isVisible = ::getTblValue("show", option, true)
      if (!isVisible)
        continue

      if (value < 0 || idx == configValue)
        value = options.len()
      options.append(option)
    }
    currentPage = ::max(0, (value / itemsPerPage).tointeger())

    contentObj = scene.findObject("images_list")
    contentObj.select()
    fillPage()

    showSceneBtn("btn_select", ::show_console_buttons)
  }

  function fillPage()
  {
    local view = {
      avatars = []
    }

    local haveCustomTooltip = getTooltipObjFunc() != null
    local start = currentPage * itemsPerPage
    local end = ::min((currentPage + 1) * itemsPerPage, options.len()) - 1
    for (local i = start; i <= end; i++)
    {
      local item = options[i]
      local avatar = {
        id          = i
        avatarImage = item.image
        enabled     = item.enabled
        haveCustomTooltip = haveCustomTooltip
        tooltipId   = haveCustomTooltip ? null : ::getTblValue("tooltipId", item)
      }
      view.avatars.append(avatar)
    }

    local blk = ::handyman.renderCached("gui/avatars", view)
    guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
    ::generatePaginator(scene.findObject("paginator_place"), this, currentPage, (options.len() - 1) / itemsPerPage)

    local sel = ::min(contentObj.getValue(), end - start)
    if (!valueInited && value >= start && value <= end)
      sel = value - start
    contentObj.setValue(sel)
    valueInited = true

    updateButtons()
  }

  function goToPage(obj)
  {
    currentPage = obj.to_page.tointeger()
    fillPage()
  }

  function chooseImage(idx)
  {
    choosenValue = idx
    goBack()
  }

  function onImageChoose(obj)
  {
    if (obj)
      chooseImage(obj.id.tointeger())
  }

  function onSelect()
  {
    chooseImage(getSelIconIdx())
  }

  function getSelIconIdx()
  {
    if (!::checkObj(contentObj))
      return -1
    return contentObj.getValue() + currentPage * itemsPerPage
  }

  function updateButtons()
  {
    local option = ::getTblValue(getSelIconIdx(), options)
    showSceneBtn("btn_select", ::getTblValue("enabled", option, false))
  }

  function afterModalDestroy()
  {
    if (!applyFunc || choosenValue==null)
      return

    if (owner)
      applyFunc.call(owner, options[choosenValue])
    else
      applyFunc(options[choosenValue])
  }

  function getTooltipObjFunc()
  {
    return ::getTblValue("tooltipObjFunc", config)
  }

  function onImageTooltipOpen(obj)
  {
    local id = getTooltipObjId(obj)
    local func = getTooltipObjFunc()
    if (!id || !func)
      return

    local res = func(obj, id.tointeger())
    if (!res)
      obj["class"] = "empty"
  }
}
