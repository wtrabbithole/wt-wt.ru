class ::gui_handlers.WwRewards extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanSeasonInfoModal.blk"

  isPlayerRewards = false
  rewardsBlk = null
  lbMode    = null
  lbDay     = null
  lbMap     = null
  lbCountry = null

  rewardsListObj = null
  rewards = null

  function initScreen()
  {
    rewardsListObj = scene.findObject("rewards_list")
    if (!::check_obj(rewardsListObj))
      return goBack()

    local wndTitle = ::g_string.implode([
      (lbMode ? ::loc("worldwar/leaderboard/" + lbMode) : ""),
      (lbDay ? ::loc("enumerated_day", {number=lbDay}) : isPlayerRewards ? ::loc("worldwar/allSeason") : ""),
      (lbMap ? lbMap.getNameText() : ::loc("worldwar/allMaps")),
      (lbCountry ? ::loc(lbCountry) : ::loc("worldwar/allCountries")),
    ], ::loc("ui/comma")) + " " + ::loc("ui/mdash") + " " + ::loc("worldwar/btn_rewards")
    scene.findObject("wnd_title").setValue(wndTitle)

    rewards = []
    foreach (rewardBlk in rewardsBlk)
    {
      local reward = getRewardData(rewardBlk)
      if (!reward)
        continue

      local blockCount = rewardBlk.blockCount()
      if (blockCount)
      {
        reward.internalRewards <- []
        for (local i = 0; i < rewardBlk.blockCount(); i++)
        {
          local internalReward = getRewardData(rewardBlk.getBlock(i), false)
          if (internalReward)
            reward.internalRewards.append(internalReward)
        }
      }

      rewards.append(reward)
    }

    local markup = ::handyman.renderCached("gui/worldWar/wwRewardItem", getRewardsView())
    guiScene.replaceContentFromText(rewardsListObj, markup, markup.len(), this)
  }

  function getRewardData(rewardBlk, needPlace = true)
  {
    local reward = {}
    for (local i = 0; i < rewardBlk.paramCount(); i++)
      reward[rewardBlk.getParamName(i)] <- rewardBlk.getParamValue(i)

    return (!needPlace || (reward?.tillPlace ?? 0)) ? reward : null
  }

  function getItemsMarkup(items)
  {
    local view = { items = [] }
    foreach (item in items)
      view.items.append(item.getViewData({
        ticketBuyWindow = false
        hasButton = false
        contentIcon = false
        hasTimer = false
        addItemName = false
      }))

    return ::handyman.renderCached("gui/items/item", view)
  }

  getPlaceText = @(tillPlace, prevPlace)
    tillPlace
      ? ::loc("multiplayer/place") + ::loc("ui/colon")
        + ((tillPlace - prevPlace == 1) ? tillPlace : (prevPlace + 1) + ::loc("ui/mdash") + tillPlace)
      : ::loc("multiplayer/place/to_other")

  function getRewardTitle(tillPlace, prevPlace)
  {
    if (!tillPlace)
      return ::loc("multiplayer/place/to_other")

    if (tillPlace - prevPlace == 1)
      return tillPlace <= 3
        ? ::loc("clan/season_award/place/place" + tillPlace)
        : ::loc("clan/season_award/place/placeN", { placeNum = tillPlace })

    return ::loc("clan/season_award/place/top", { top = tillPlace })
  }

  function getRewardsView()
  {
    local prevPlace = 0
    return {
      isPlayerRewards = isPlayerRewards
      rewardsList = ::u.map(rewards, function(reward) {
        local rewardRowView = {
          title = getRewardTitle(reward.tillPlace, prevPlace)
          condition = getPlaceText(reward.tillPlace, prevPlace)
        }
        prevPlace = reward.tillPlace

        local trophyId = reward?.itemdefid
        if (trophyId)
        {
          local trophyItem = ::ItemsManager.findItemById(trophyId)
          if (trophyItem)
          {
              rewardRowView.trophyMarkup <- getItemsMarkup([trophyItem])
              rewardRowView.trophyName <- trophyItem.getName()
          }
        }

        local internalRewards = reward?.internalRewards
        if (internalRewards)
        {
          rewardRowView.internalRewardsList <- []

          local internalRewardsList = []
          local internalPrevPlace = 0
          foreach (internalReward in internalRewards)
          {
            local internalTrophyId = internalReward?.itemdefid
            if (internalTrophyId)
            {
              local internalTrophyItem = ::ItemsManager.findItemById(internalTrophyId)
              if (internalTrophyItem)
                internalRewardsList.append({
                  internalTrophyMarkup = getItemsMarkup([internalTrophyItem])
                  internalCondition = getPlaceText(internalReward?.tillPlace, internalPrevPlace)
                })
            }
            internalPrevPlace = internalReward?.tillPlace ?? 0
          }
          if (internalRewardsList.len())
          {
            rewardRowView.internalRewardsList <- internalRewardsList
            rewardRowView.hasInternalRewards <- true
          }
        }

        return rewardRowView
      }.bindenv(this))
    }
  }

  function onItemSelect(obj)
  {
  }

  function onEventItemsShopUpdate(obj)
  {
    local markup = ::handyman.renderCached("gui/worldWar/wwRewardItem", getRewardsView())
    guiScene.replaceContentFromText(rewardsListObj, markup, markup.len(), this)
  }
}

return {
  open = function(params) {
    if (!params?.rewardsBlk)
      return

    ::handlersManager.loadHandler(::gui_handlers.WwRewards, params)
  }
}
