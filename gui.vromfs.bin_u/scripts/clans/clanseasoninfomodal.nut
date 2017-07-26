function show_clan_season_info(difficulty)
{
  ::gui_start_modal_wnd(
    ::gui_handlers.clanSeasonInfoModal,
    {difficulty = difficulty}
  )
}

class ::gui_handlers.clanSeasonInfoModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanSeasonInfoModal.blk"

  difficulty = null

  rewardsListObj = null
  selectedIndex  = 0

  function initScreen()
  {
    if (!::g_clan_seasons.isEnabled())
      return goBack()
    rewardsListObj = scene.findObject("rewards_list")
    if (!::checkObj(rewardsListObj))
      return goBack()

    scene.findObject("wnd_title").setValue(::loc("clan/battle_season/title") + " - " + ::loc("mainmenu/rewardsList"))

    fillRewardsList()
    selectListItem()

    initFocusArray()
    restoreFocus()
  }

  function fillRewardsList()
  {
    local view = getRewardsView(difficulty)
    local markup = ::handyman.renderCached("gui/clans/clanSeasonInfoListItem", view)
    guiScene.appendWithBlk(rewardsListObj, markup, this)
  }

  function getRewardsView(difficulty)
  {
    local view = { rewardsList = [] }
    local rewards = ::g_clan_seasons.getSeasonRewardsList(difficulty)
    if (::u.isEmpty(rewards))
      return view

    local seasonName = ::g_clan_seasons.getSeasonName()
    foreach(reward in rewards)
    {
      local title = ""
      local medal = ""
      switch(reward.rType)
      {
        case CLAN_SEASON_MEDAL_TYPE.PLACE:
          title = ::loc("clan/season_award/place/place" + reward.place)
          medal = "place" + reward.place
          break
        case CLAN_SEASON_MEDAL_TYPE.TOP:
          title = ::loc("clan/season_award/place/top", { top = reward.place })
          medal = "top" + reward.place
          break
        case CLAN_SEASON_MEDAL_TYPE.RATING:
          title = ::loc("clan/season_award/rating", { ratingValue = reward.rating })
          medal = reward.rating + "rating"
          break
      }
      local medalIconMarkup = ::LayersIcon.getIconData(::format("clan_medal_%s_%s", medal, difficulty.egdLowercaseName),
        null, null, null, { season_title = { text = seasonName } })

      local condition = ""
      if (reward.placeMin)
        condition = ::loc("multiplayer/place") + ::loc("ui/colon") + reward.placeMin + ::loc("ui/mdash") + reward.placeMax
      else if (reward.place)
        condition = ::loc("multiplayer/place") + ::loc("ui/colon") + reward.place
      else if (reward.rating)
        condition = ::loc("userLog/clanDuelRewardClanRating") + " " + reward.rating

      local gold = ""
      if (reward.gold)
      {
        local value = reward.goldMin ? (reward.goldMin + ::loc("ui/mdash") + reward.goldMax) : reward.gold.tostring()
        value = ::colorize("activeTextColor", value) + ::loc("gold/short/colored")
        gold = ::loc("charServer/chapter/eagles") + ::loc("ui/colon") + value
      }

      local prizesList = {}
      local prizes = ::g_clan_seasons.getRegaliaPrizes(reward.regalia)
      local limits = ::g_clan_seasons.getUniquePrizesCounts(reward.regalia)
      foreach (prize in prizes)
      {
        local prizeType = prize.type
        local collection = []

        if (prizeType == "clanTag")
        {
          local myClanTagUndecorated = ::g_clans.stripClanTagDecorators(::clan_get_my_clan_tag())
          local tagTxt = ::u.isEmpty(myClanTagUndecorated) ? ::loc("clan/clan_tag/short") : myClanTagUndecorated
          local tooltipBase = ::loc("clan/clan_tag_decoration") + ::loc("ui/colon")
          local tagDecorators = ::g_clan_tag_decorator.getDecoratorsForClanDuelRewards(prize.list)
          foreach (decorator in tagDecorators)
            collection.append({
              start = decorator.start
              tag   = tagTxt
              end   = decorator.end
              tooltip = tooltipBase + ::colorize("activeTextColor", decorator.start + tagTxt + decorator.end)
            })
        }
        else if (prizeType == "decal")
        {
          local decorType = ::g_decorator_type.DECALS
          foreach (decalId in prize.list)
          {
            local decal = ::g_decorator.getDecorator(decalId, decorType)
            collection.append({
              id = decalId
              image = decorType.getImage(decal)
              ratio = ::clamp(decorType.getRatio(decal), 1, 2)
              tooltipId = ::g_tooltip_type.DECORATION.getTooltipId(decalId, decorType.unlockedItemType)
            })
          }
        }

        local uniqueCount = ::getTblValue(prizeType, limits, 0) || collection.len()
        local splitList = {
          unique = []
          bonus  = []
        }
        foreach (idx, item in collection)
          splitList[(idx < uniqueCount) ? "unique" : "bonus"].append(item)
        prizesList[prizeType] <- splitList
      }

      local uniqueClantags = ::getTblValueByPath("clanTag.unique", prizesList, [])
      local uniqueDecals   = ::getTblValueByPath("decal.unique",   prizesList, [])
      local bonusClantags  = ::getTblValueByPath("clanTag.bonus",  prizesList, [])
      local bonusDecals    = ::getTblValueByPath("decal.bonus",    prizesList, [])

      view.rewardsList.append({
        title      = title
        medalIcon  = medalIconMarkup
        condition  = condition
        gold       = gold
        hasBonuses = bonusClantags.len() > 0 || bonusDecals.len() > 0

        hasUniqueClantags = uniqueClantags.len() > 0
        hasUniqueDecals   = uniqueDecals.len()  > 0
        hasBonusClantags  = bonusClantags.len()  > 0
        hasBonusDecals    = bonusDecals.len()   > 0

        uniqueClantags = uniqueClantags.len() ? uniqueClantags : null
        uniqueDecals   = uniqueDecals.len()   ? uniqueDecals   : null
        bonusClantags  = bonusClantags.len()  ? bonusClantags  : null
        bonusDecals    = bonusDecals.len()    ? bonusDecals    : null
      })
    }

    return view
  }

  function onShowBonuses(obj)
  {
    local bonusesObj = ::checkObj(obj) ? obj.getParent().findObject("bonuses_panel") : null
    if (!::checkObj(bonusesObj))
      return
    local isShow = bonusesObj["toggled"] != "yes"
    bonusesObj["toggled"] = isShow ? "yes" : "no"
    bonusesObj.show(isShow)

    obj.setValue(isShow ? ::loc("mainmenu/btnCollapse") : (::loc("clan/season_award/desc/lower_places_awards_included") + ::loc("ui/ellipsis")))
    obj["tooltip"] = isShow ? "" : ::loc("mainmenu/btnExpand")
  }

  function selectListItem()
  {
    if (rewardsListObj.childrenCount() <= 0)
      return

    if (selectedIndex >= rewardsListObj.childrenCount())
      selectedIndex = rewardsListObj.childrenCount() - 1

    rewardsListObj.setValue(selectedIndex)
    rewardsListObj.select()
    rewardsListObj.getChild(selectedIndex).scrollToView()
  }

  function onItemSelect(obj)
  {
    local listChildrenCount = rewardsListObj.childrenCount()
    local prevSelectedIndex = selectedIndex
    local index = obj.getValue()
    selectedIndex = (index >= 0 && index < listChildrenCount) ? index : 0
  }

  function getMainFocusObj()
  {
    return rewardsListObj
  }
}
