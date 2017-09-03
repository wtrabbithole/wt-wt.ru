function gui_start_open_trophy_rewards_list(rewardsArray = [])
{
  if (!rewardsArray.len())
    return

  ::gui_start_modal_wnd(::gui_handlers.trophyRewardsList, {rewardsArray = rewardsArray})
}

class ::gui_handlers.trophyRewardsList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/trophyRewardsList.blk"

  rewardsArray = []

  function initScreen()
  {
    local listObj = scene.findObject("items_list")
    if (!::checkObj(listObj))
      return goBack()

    local data = getItemsImages()

    guiScene.replaceContentFromText(listObj, data, data.len(), this)
    local height = ::max(listObj.getSize()[1], guiScene.calcString("3@itemHeight", null))
    scene.findObject("trophy_rewards_list").height = height
    listObj.select()

    guiScene.setUpdatesEnabled(true, true)
  }

  function getItemsImages()
  {
    local data = ""
    foreach(idx, reward in rewardsArray)
      data += ::trophyReward.getImageByConfig(reward, false, "trophy_reward_place", true)

    return data
  }

  function updateItemInfo(obj)
  {
    local val = obj.getValue()
    local reward_config = rewardsArray[val]

    local obj = scene.findObject("item_info")
    if (!::checkObj(obj))
      return

    local text = [::trophyReward.getName(reward_config)]
    text.append(::trophyReward.getDecription(reward_config, true))
    obj.setValue(::g_string.implode(text, "\n"))
  }
}
