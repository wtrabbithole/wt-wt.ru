function gui_start_encyclopedia()
{
  ::gui_start_modal_wnd(::gui_handlers.Encyclopedia)
}

class ::gui_handlers.Encyclopedia extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chapterModal.blk"
  menuConfig = null
  curChapter = null

  function initScreen()
  {
    if (!scene || !::encyclopedia_data)
      return goBack()

    ::req_unlock_by_client("view_encyclopedia", false)

    local blockObj = scene.findObject("chapter_include_block")
    if (::checkObj(blockObj))
      blockObj.show(true)

    local view = { tabs = [] }
    foreach(idx, chapter in ::encyclopedia_data)
      view.tabs.append({
        id = chapter.id
        tabName = "#encyclopedia/" + chapter.id
        navImagesText = ::get_navigation_images_text(idx, ::encyclopedia_data.len())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local chaptersObj = scene.findObject("chapter_top_list")
    guiScene.replaceContentFromText(chaptersObj, data, data.len(), this)
    chaptersObj.on_select = "onChapterSelect"
    chaptersObj.show(true)
    chaptersObj.setValue(0)
    onChapterSelect(chaptersObj)

    foreach(btn in ["faq", "forum", "support", "wiki"])
      showSceneBtn("button_" + btn, !::is_vendor_tencent())
  }

  function onChapterSelect(obj)
  {
    if (!::check_obj(obj))
      return

    local value = obj.getValue()
    if (!(value in ::encyclopedia_data))
      return

    local objArticles = scene.findObject("items_list")
    if (!::check_obj(objArticles))
      return

    curChapter = ::encyclopedia_data[value]

    local view = { items = [] }
    foreach(idx, article in curChapter.articles)
      view.items.append({
        id = article.id
        isSelected = idx == 0
        itemText = (curChapter.id == "aircrafts")? "#" + article.id + "_0" : "#encyclopedia/" + article.id
      })

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)

    guiScene.replaceContentFromText(objArticles, data, data.len(), this)
    objArticles.select()
    objArticles.setValue(0)
    onItemSelect(objArticles)
  }

  function onItemSelect(obj)
  {
    local list = scene.findObject("items_list")
    local index = list.getValue()
    if (!(index in curChapter.articles))
      return

    local article = curChapter.articles[index]
    local txtDescr = ::loc("encyclopedia/" + article.id + "/desc")
    local objDesc = scene.findObject("item_desc")
    objDesc.findObject("item_desc_text").setValue(txtDescr)
    objDesc.findObject("item_name").setValue(::loc("encyclopedia/" + article.id))

    local objImgDiv = scene.findObject("div_before_text")
    local data = ""
    if ("images" in article)
    {
      local w = article.imgSize[0]
      local h = article.imgSize[1]
      local sizeText = (w >= h)? ["0.333p.p.p.w - 8@imgFramePad", h + "/" + w + "w"] : [w + "/" + h + "h", "0.333p.p.p.w - 8@imgFramePad"]
      foreach(imageName in article.images)
      {
        local image = "ui/slides/encyclopedia/" + imageName + ".jpg"
        if (::check_image_exist(image, "Error: not found encyclopedia image %s"))
          data += format("imgFrame { img { width:t='%s'; height:t='%s'; max-width:t='%d'; max-height:t='%d'; " +
                         " background-image:t='%s'; click_to_resize:t='yes' }} ",
                         sizeText[0], sizeText[1], w, h,
                         image)
      }
    }
    guiScene.replaceContentFromText(objImgDiv, data, data.len(), this)
  }

  function onStart() {}
}

function view_fullscreen_image(obj)
{
  ::handlersManager.loadHandler(::gui_handlers.ShowImage, { showObj = obj })
}

class ::gui_handlers.ShowImage extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/showImage.blk"

  showObj = null
  baseSize = null
  maxSize = null
  basePos = null
  lastPos = null
  imgObj = null
  frameObj = null
  shadeObj = null

  resizeTime = 0.2
  timer = 0.0
  moveBack = false

  function initScreen()
  {
    if (!::checkObj(showObj))
      return goBack()

    local image = showObj["background-image"]
    maxSize = [showObj["max-width"].tointeger(), showObj["max-height"].tointeger()]

    if (!image || image=="" || !maxSize[0] || !maxSize[1])
      return goBack()

    scene.findObject("image_update").setUserData(this)

    baseSize = showObj.getSize()
    basePos = showObj.getPosRC()
    local rootSize = guiScene.getRoot().getSize()
    basePos = [basePos[0] + baseSize[0]/2, basePos[1] + baseSize[1]/2]
    lastPos = [rootSize[0]/2, rootSize[1]/2]

    local sizeKoef = 1.0
    if (maxSize[0] > 0.9*rootSize[0])
      sizeKoef = 0.9*rootSize[0] / maxSize[0]
    if (maxSize[1] > 0.9*rootSize[1])
    {
      local koef2 = 0.9*rootSize[1] / maxSize[1]
      if (koef2 < sizeKoef)
        sizeKoef = koef2
    }
    if (sizeKoef < 1.0)
    {
      maxSize[0] = (maxSize[0] * sizeKoef).tointeger()
      maxSize[1] = (maxSize[1] * sizeKoef).tointeger()
    }

    imgObj = scene.findObject("image")
    imgObj["max-width"] = maxSize[0].tostring()
    imgObj["max-height"] = maxSize[1].tostring()
    imgObj["background-image"] = image

    frameObj = scene.findObject("imgFrame")
    shadeObj = scene.findObject("root-box")
    onUpdate(null, 0.0)
  }

  function countProp(baseVal, max, t)
  {
    local div = max - baseVal
    div *= 1.0 - (t - 1)*(t - 1)
    return (baseVal + div).tointeger().tostring()
  }

  function onUpdate(obj, dt)
  {
    if (frameObj && frameObj.isValid()
        && ((!moveBack && timer < resizeTime) || (moveBack && timer > 0)))
    {
      timer += moveBack? -dt : dt
      local t = timer / resizeTime
      if (t >= 1.0)
      {
        t = 1.0
        timer = resizeTime
        scene.findObject("btn_back").show(true)
      }
      if (moveBack && t <= 0.0)
      {
        t = 0.0
        timer = 0.0
        goBack() //performDelayed inside
      }

      imgObj.width = countProp(baseSize[0], maxSize[0], t)
      imgObj.height = countProp(baseSize[1], maxSize[1], t)
      frameObj.left = countProp(basePos[0], lastPos[0], t) + "-50%w"
      frameObj.top = countProp(basePos[1], lastPos[1], t) + "-50%h"
      shadeObj["transparent"] = (100 * t).tointeger().tostring()
    }
  }

  function onBack()
  {
    if (!moveBack)
    {
      moveBack = true
      scene.findObject("btn_back").show(false)
    }
  }
}

function gui_modal_rank_versus_info(unit)
{
  ::gui_start_modal_wnd(::gui_handlers.RankVersusInfo, { unit = unit })
}
