function gui_start_open_chest_list(items)
{
  if (items.len() == 0)
    return

  local inventoryItems = ::ItemsManager.getInventoryList()
  while (items.len() > 0 ) {
    local itemId = items.remove(0).itemid

    foreach (item in inventoryItems) {
      if (item.id == itemId) {
        local afterFunc = items.len() > 0 ? function() { ::gui_start_open_chest_list(items) } : null
        ::gui_start_modal_wnd(::gui_handlers.openChestWnd, {showItem = item, afterFunc = afterFunc})
        return
      }
    }
  }
}

class ::gui_handlers.openChestWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/trophyReward.blk"

  showItem = null
  afterFunc = null

  slotbarActions = [ "take", "weapons", "info" ]

  function initScreen()
  {
    scene.findObject("reward_title").setValue(::loc("mainmenu/trophyReward/title"))
    updateWnd()
  }

  function updateWnd()
  {
    updateImage()
    updateRewardText()
    updateButtons()
  }

  function updateImage()
  {
    local imageObj = scene.findObject("reward_image")
    if (!::checkObj(imageObj))
      return

    local layersData = showItem.getBigIcon()
    guiScene.replaceContentFromText(imageObj, layersData, layersData.len(), this)
  }

  function updateRewardText()
  {
    scene.findObject("prize_desc_text").setValue(showItem.getName())
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    ::show_facebook_screenshot_button(scene, true)

    showSceneBtn("btn_rewards_list", false)
    showSceneBtn("open_chest_animation", false) //hack tooltip bug
    showSceneBtn("btn_ok", true)

    showSceneBtn("btn_take_air", false)
  }

  function onViewRewards()
  {
  }

  function onOpenAnimFinish()
  {
  }

  function onTakeNavBar()
  {
  }

  function afterModalDestroy()
  {
    if (afterFunc)
      afterFunc()
  }
}
