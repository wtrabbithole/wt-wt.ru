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

    local canShowLinkButtons = !::is_vendor_tencent() && ::has_feature("AllowExternalLink")
    foreach(btn in ["faq", "support", "wiki"])
      showSceneBtn("button_" + btn, canShowLinkButtons)
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
      local maxWidth = guiScene.calcString("1@rw", null).tointeger()
      local maxHeight = (maxWidth * (h.tofloat()/w)).tointeger()
      local sizeText = (w >= h)? ["0.333p.p.p.w - 8@imgFramePad", h + "/" + w + "w"] : [w + "/" + h + "h", "0.333p.p.p.w - 8@imgFramePad"]
      foreach(imageName in article.images)
      {
        local image = "ui/slides/encyclopedia/" + imageName + ".jpg"
        data += format("imgFrame { img { width:t='%s'; height:t='%s'; max-width:t='%d'; max-height:t='%d'; " +
                       " background-image:t='%s'; click_to_resize:t='yes' }} ",
                       sizeText[0], sizeText[1], maxWidth, maxHeight,
                       image)
      }
    }
    guiScene.replaceContentFromText(objImgDiv, data, data.len(), this)
  }

  function onStart() {}
  function onListItemsFocusChange(obj) {}
}
