function gui_start_open_trophy_rewards_list(params = {})
{
  local rewardsArray = params?.rewardsArray
  if (!rewardsArray || !rewardsArray.len())
    return

  ::gui_start_modal_wnd(::gui_handlers.trophyRewardsList, params)
}

class ::gui_handlers.trophyRewardsList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/trophyRewardsList.blk"

  rewardsArray = []
  tittleLocId = "mainmenu/rewardsList"

  function initScreen()
  {
    local listObj = scene.findObject("items_list")
    if (!::checkObj(listObj))
      return goBack()

    local titleObj = scene.findObject("title")
    if (::check_obj(titleObj))
      titleObj.setValue(::loc(tittleLocId))

    local data = getItemsImages()
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    if (rewardsArray.len() > 3)
      listObj.width = (listObj.getSize()[0] + guiScene.calcString("1@scrollBarSize", null)).tostring()

    listObj.select()
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

    local infoObj = scene.findObject("item_info")
    if (!::checkObj(infoObj))
      return

    local text = [::trophyReward.getName(reward_config)]
    text.append(::trophyReward.getDecription(reward_config, true))
    infoObj.setValue(::g_string.implode(text, "\n"))
  }
}
