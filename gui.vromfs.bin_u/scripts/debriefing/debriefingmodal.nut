function gui_start_debriefingFull(params = {})
{
  ::handlersManager.loadHandler(::gui_handlers.DebriefingModal, params)
}

function gui_start_debriefing_replay()
{
  gui_start_debriefing()

  ::add_msg_box("replay_question", ::loc("mainmenu/questionSaveReplay"), [
        ["yes", function()
        {
          local guiScene = ::get_gui_scene()
          guiScene.performDelayed(getroottable(), function()
          {
            if (::debriefing_handler != null)
            {
              ::debriefing_handler.onSaveReplay(null)
            }
          })
        }],
        ["no", function() { if (::debriefing_handler != null) ::debriefing_handler.onSelect(null) } ],
        ["viewAgain", function()
        {
          local guiScene = ::get_gui_scene()
          guiScene.performDelayed(getroottable(), function()
              {
            if (::debriefing_handler != null)
              ::debriefing_handler.onViewReplay(null)
          })
        }]
        ], "yes")
  ::update_msg_boxes()
}

function gui_start_debriefing()
{
  if (::need_logout_after_session)
  {
    ::destroy_session_scripted()
    //need delay after destroy session before is_multiplayer become false
    ::get_gui_scene().performDelayed(::getroottable(), ::gui_start_logout)
    return
  }

  local gm = ::get_game_mode()
  local handler = null
  if (::back_from_replays != null)
  {
     dagor.debug("gui_nav gui_start_debriefing back_from_replays");
     local temp_func = ::back_from_replays
     dagor.debug("gui_nav back_from_replays = null");
     ::back_from_replays = null
     temp_func()
     ::update_gamercards()
     return
  }
  else
  {
    dagor.debug("gui_nav gui_start_debriefing back_from_replays is null");
    ::debriefing_result = null
  }

  if (gm == ::GM_BENCHMARK)
  {
    local title = ::loc_current_mission_name()
    local benchmark_data = ::stat_get_benchmark()
    ::gui_start_mainmenu()
    ::gui_start_modal_wnd(::gui_handlers.BenchmarkResultModal, {title = title benchmark_data = benchmark_data})
    return
  }
  if (gm == ::GM_CREDITS || gm == ::GM_TRAINING)
  {
     ::gui_start_mainmenu();
     return
  }
  if (gm == ::GM_TEST_FLIGHT)
  {
    if (::last_called_gui_testflight)
      ::last_called_gui_testflight()
    else
      ::gui_start_decals();
    ::update_gamercards()
    return
  }

  ::gui_start_debriefingFull()
}

class ::gui_handlers.DebriefingModal extends ::gui_handlers.MPStatistics
{
  sceneBlkName = "gui/statistics/debriefing.blk"

  static awardsListsConfig = {
    streaks = {
      filter = {
          show = [::EULT_NEW_STREAK]
          unlocks = [::UNLOCKABLE_STREAK]
          filters = { popupInDebriefing = [false, null] }
          currentRoomOnly = true
          disableVisible = true
        }
      align = "left",
      listObjId = "streaks_awards_list"
    }
    unlocks = {
      filter = {
        show = [::EULT_NEW_UNLOCK]
        unlocks = [::UNLOCKABLE_AIRCRAFT, ::UNLOCKABLE_SKIN, ::UNLOCKABLE_DECAL, ::UNLOCKABLE_WEAPON,
                   ::UNLOCKABLE_DIFFICULTY, ::UNLOCKABLE_ENCYCLOPEDIA, ::UNLOCKABLE_PILOT,
                   ::UNLOCKABLE_MEDAL, ::UNLOCKABLE_CHALLENGE, ::UNLOCKABLE_ACHIEVEMENT]
        filters = { popupInDebriefing = [false, null] }
        currentRoomOnly = true
        disableVisible = true
      }
      align = "right",
      listObjId = "unlocks_awards_list"
    }
  }

  static armyStateAfterBattle = {
    EASAB_UNKNOWN = "unknown"
    EASAB_UNCHANGED = "unchanged"
    EASAB_RETREATING = "retreating"
    EASAB_DEAD = "dead"
  }

  isTeamplay = false
  isSpectator = false
  gameType = null

  pveRewardInfo = null

  debugUnlocks = 0  //show at least this amount of unlocks received from userlogs even disabled.

  function initScreen()
  {
    gameType = ::get_game_type()
    isTeamplay = ::is_mode_with_teams(gameType)

    if (::disable_network()) //for correct work in disable_menu mode
      ::update_gamercards()
    showTab("") //hide all tabs

    isSpectator = ::SessionLobby.isInRoom() && ::SessionLobby.spectator
    ::set_presence_to_player("menu")
    ::SessionLobby.checkLeaveRoomInDebriefing()
    isMp = ::is_multiplayer()
    ::close_cur_voicemenu()

    lastProgressRank = {}

    if (isInited || !::debriefing_result)
    {
      ::gather_debriefing_result()
      scene.findObject("debriefing_timer").setUserData(this)
    }
    playerStatsObj = scene.findObject("stat_table")
    numberOfWinningPlaces = ::getTblValue("numberOfWinningPlaces", ::debriefing_result, -1)
    pveRewardInfo = ::getTblValue("pveRewardInfo", ::debriefing_result)
    foreach(idx, row in ::debriefing_rows)
      if (row.show)
      {
        curStatsIdx = idx
        break
      }

    handleActiveWager()
    handlePveReward()

    //update title
    scene.findObject("mission_name").setValue(::loc_current_mission_name())
    local resTitle = ""
    local warningMessage = ""
    local headerImgTag = "in_progress"

    if (isMp)
    {
      local mpResult = ::debriefing_result.exp.result
      resTitle = ::loc("MISSION_IN_PROGRESS")

      if (isSpectator
           && (gameType & ::GT_VERSUS)
           && (mpResult == ::STATS_RESULT_SUCCESS
                || mpResult == ::STATS_RESULT_FAIL))
      {
        if (isTeamplay)
        {
          local myTeam = Team.A
          foreach(player in ::debriefing_result.mplayers_list)
            if (::getTblValue("isLocal", player, false))
            {
              myTeam = player.team
              break
            }
          local winner = ((myTeam == Team.A) == ::debriefing_result.isSucceed) ? "A" : "B"
          resTitle = ::loc("multiplayer/team_won") + ::loc("ui/colon") + ::loc("multiplayer/team" + winner)
          headerImgTag = "win"
        }
        else
        {
          resTitle = ::loc("MISSION_FINISHED")
          headerImgTag = "win"
        }
      }
      else if (mpResult == ::STATS_RESULT_SUCCESS)
      {
        resTitle = ::loc("MISSION_SUCCESS")
        headerImgTag = "win"
      }
      else if (mpResult == ::STATS_RESULT_FAIL)
      {
        resTitle = ::loc("MISSION_FAIL")
        headerImgTag = "loose"
      }
      else if (mpResult == ::STATS_RESULT_ABORTED_BY_KICK)
        warningMessage = ::loc("MISSION_ABORTED_BY_KICK")
    }
    else
    {
      resTitle = ::loc(::debriefing_result.isSucceed ? "MISSION_SUCCESS" : "MISSION_FAIL")
      headerImgTag = ::debriefing_result.isSucceed ? "win" : "loose"
    }

    if (resTitle != "")
      scene.findObject("result-title").setValue(resTitle)
    else if (warningMessage != "")
      scene.findObject("result-warning").setValue(warningMessage)

    scene.findObject("header-image")["background-image"] = ::format("#ui/images/debriefing_%s.jpg?P1", headerImgTag)

    gatherAwardsLists()

    //update mp table
    needPlayersTbl = isMp && !(gameType & ::GT_COOPERATIVE) && isDebriefingResultFull()
    setSceneTitle(getCurMpTitle(false, is_show_ww_casualties()))

    if (!isDebriefingResultFull())
    {
      if (isMp && ::get_game_mode() == ::GM_DOMINATION)
        scene.findObject("stat_info_top_text").setValue(::loc("debriefing/most_award_after_battle"))
      foreach(tName in ["air_item_text", "research_list_text"])
      {
        local obj = scene.findObject(tName)
        if (::checkObj(obj))
          obj.setValue(::loc("MISSION_IN_PROGRESS"))
      }
    }

    isReplay = ::is_replay_playing()
    if (!isReplay)
    {
      setGoNext()
      if (::get_game_mode() == ::GM_DYNAMIC)
      {
        ::save_profile(true)
        if (::dynamic_result > ::MISSION_STATUS_RUNNING)
          ::destroy_session_scripted()
        else
          ::g_squad_manager.setReadyFlag(true)
      }
    }
    ::first_generation <- false //for dynamic campaign
    isInited = false
    check_logout_scheduled()

    ::g_squad_utils.updateMyCountryData() //to update broken airs for squad.

    handleNoAwardsCaption()
  }

  function gatherAwardsLists()
  {
    awardsList = []

    streakAwardsList = getAwardsList(awardsListsConfig.streaks.filter)

    local wpBattleTrophy = ::getTblValue("wpBattleTrophy", ::debriefing_result.exp, 0)
    if (wpBattleTrophy > 0)
      streakAwardsList.append(::getFakeUnlockDataByWpBattleTrophy(wpBattleTrophy))

    unlockAwardsList = getAwardsList(awardsListsConfig.unlocks.filter)

    awardsList.extend(streakAwardsList)
    awardsList.extend(unlockAwardsList)

    currentAwardsList = streakAwardsList
    currentAwardsListConfig = awardsListsConfig.streaks
  }

  function getAwardsList(filter)
  {
    local res = []
    local logsList = getUserLogsList(filter)
    logsList = ::combineSimilarAwards(logsList)
    for (local i = logsList.len()-1; i >= 0; i--)
      res.append(::build_log_unlock_data(logsList[i]))

    //add debugUnlocks
      if (debugUnlocks <= res.len())
    return res

    local filter = clone filter
    filter.currentRoomOnly = false
    logsList = getUserLogsList(filter)
    if (!logsList.len())
    {
      dlog("Not found any unlocks in userlogs for debug")
      return res
    }

    local addAmount = debugUnlocks - res.len()
    for(local i = 0; i < addAmount; i++)
      res.append(::build_log_unlock_data(logsList[i % logsList.len()]))

    return res
  }

  function handleNoAwardsCaption()
  {
    local noAwardsCaptionObj = scene.findObject("no_awards_caption")
    if ( ! ::checkObj(noAwardsCaptionObj))
      return
    if(::getTblValue("haveTeamkills", ::debriefing_result, false))
      noAwardsCaptionObj.setValue(::loc("debriefing/noAwardsCaption"))
    else if (pveRewardInfo && pveRewardInfo.warnLowActivity)
      noAwardsCaptionObj.setValue(::loc("debriefing/noAwardsCaption/noMinActivity"))
  }

  function reinitTotal()
  {
    if (isSpectator)
      return

    if (state != debrState.showMyStats && state != debrState.showBonuses)
      return

    //find and update Total
    totalRow = ::get_debriefing_row_by_id("Total")
    if (!totalRow)
      return

    if (totalCurValues == null)
      totalCurValues = {}

    local currencyArray = ["wp", "exp", "gold"]
    totalTarValues = {}
    foreach(currency in currencyArray)
    {
      if (!(currency in totalCurValues))
        totalCurValues[currency] <- 0

      local totalKey = ::get_counted_result_id(totalRow, state, currency)
      totalTarValues[currency] <- ::getTblValue(totalKey, ::debriefing_result.counted_result_by_debrState, 0)
    }

    totalObj = scene.findObject("wnd_total")
    totalObj.show(true)
    updateTotal(0.0)
  }

  function handleActiveWager()
  {
    local iconObj = scene.findObject("active_wager_icon")
    if (!::checkObj(iconObj))
      return
    if (::getTblValue("activeWager", ::debriefing_result, null) == null)
      return
    local activeWagerData = ::debriefing_result.activeWager

    local wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null) // This can happen if item ended and was removed from shop.
      return

    local wagerResult = activeWagerData.wagerResult
    if (wagerResult == "WagerStageWin" || wagerResult == "WagerStageFail")
      showActiveWagerResultIcon(wagerResult == "WagerStageWin")

    iconObj.show(true)
    wager.setIcon(iconObj, {bigPicture = false})

    local wagerEnded = wagerResult == "WagerWin" || wagerResult == "WagerFail"
    local wagerHasResult = wagerResult != null
    local tooltipObj = scene.findObject("active_wager_tooltip")
    if (::checkObj(tooltipObj))
    {
      tooltipObj.setUserData(activeWagerData)
      tooltipObj.enable(!wagerEnded && wagerHasResult)
    }
    local containerObj = scene.findObject("active_wager_container")
    if (::checkObj(containerObj))
    {
      if (!wagerHasResult)
        containerObj.tooltip = ::loc("debriefing/wager_result_will_be_later")
      else if (wagerEnded)
      {
        local endedWagerText = activeWagerData.wagerText
        endedWagerText += "\n" + ::loc("items/wager/numWins", {
          numWins = activeWagerData.wagerNumWins,
          maxWins = wager.maxWins
        })
        endedWagerText += "\n" + ::loc("items/wager/numFails", {
          numFails = activeWagerData.wagerNumFails,
          maxFails = wager.maxFails
        })
        containerObj.tooltip = endedWagerText
      }
    }

    handleActiveWagerText(activeWagerData)
  }

  function handleActiveWagerText(activeWagerData)
  {
    local wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    local wagerResult = activeWagerData.wagerResult
    if (wagerResult != "WagerWin" && wagerResult != "WagerFail")
      return
    local textObj = scene.findObject("active_wager_text")
    if (::checkObj(textObj))
      textObj.setValue(activeWagerData.wagerText)
  }

  function onWagerTooltipOpen(obj)
  {
    if (!::checkObj(obj))
      return
    local activeWagerData = obj.getUserData()
    if (activeWagerData == null)
      return
    local wager = ::ItemsManager.findItemByUid(activeWagerData.wagerInventoryId, itemType.WAGER) ||
                  ::ItemsManager.findItemById(activeWagerData.wagerShopId)
    if (wager == null)
      return
    local wagerResult = activeWagerData.wagerResult
    guiScene.replaceContent(obj, "gui/items/itemTooltip.blk", this)
    ::ItemsManager.fillItemDescr(wager, obj, this)
  }

  function showActiveWagerResultIcon(success)
  {
    local iconId = "active_wager_icon_" + (success ? "success" : "fail")
    local iconObj = scene.findObject(iconId)
    if (::checkObj(iconObj))
      iconObj.show(true)
  }

  function handlePveReward()
  {
    local isVisible = !!pveRewardInfo && pveRewardInfo.isVisible

    local bgImage = scene.findObject("header-image");
    bgImage.set_prop_latent("color-factor", isVisible ? 153 : 255)
    bgImage.updateRendElem()

    if (! isVisible)
      return

    local trophyItemReached =  ::ItemsManager.findItemById(pveRewardInfo.reachedTrophyName)
    local trophyItemReceived = ::ItemsManager.findItemById(pveRewardInfo.receivedTrophyName)

    fillPveRewardProgressBar()
    fillPveRewardTrophyChest(trophyItemReached)
    fillPveRewardTrophyContent(trophyItemReceived, pveRewardInfo.isRewardReceivedEarlier)
  }

  function fillPveRewardProgressBar()
  {
    local pveTrophyPlaceObj = scene.findObject("pve_trophy_progress")
    if (!::check_obj(pveTrophyPlaceObj))
      return

    pveTrophyPlaceObj.show(true)

    local receivedTrophyName = pveRewardInfo.receivedTrophyName
    local rewardTrophyStages = pveRewardInfo.stagesTime
    local showTrophiesOnBar  = ! pveRewardInfo.isRewardReceivedEarlier
    local maxValue = pveRewardInfo.victoryStageTime
    local stage = rewardTrophyStages.len()? [] : null
    foreach (stageIndex, val in rewardTrophyStages)
    {
      if (val < 0 || val > maxValue)
        continue

      local isVictoryStage = val == maxValue

      local text = isVictoryStage ? ::loc("debriefing/victory")
       : ::secondsToString(val, true, true)

      local trophyName = ::get_pve_trophy_name(val, isVictoryStage)
      local isReceivedInLastBattle = trophyName && trophyName == receivedTrophyName
      local trophy = showTrophiesOnBar && trophyName ?
        ::ItemsManager.findItemById(trophyName, itemType.TROPHY) : null

      stage.append({
        posX = val.tofloat() / maxValue
        text = text
        trophy = trophy ? trophy.getNameMarkup(0, false) : null
        isReceived = isReceivedInLastBattle
      })
    }

    local view = {
      maxValue = maxValue
      value = 0
      stage = stage
    }

    local data = ::handyman.renderCached("gui/statistics/debriefingPvEReward", view)
    guiScene.replaceContentFromText(pveTrophyPlaceObj, data, data.len(), this)
  }

  function fillPveRewardTrophyChest(trophyItem)
  {
    local trophyPlaceObj = scene.findObject("pve_trophy_chest")
    if (!trophyItem || !::check_obj(trophyPlaceObj))
      return

    trophyPlaceObj.show(true)
    local imageData = trophyItem.getOpenedBigIcon()
    guiScene.replaceContentFromText(trophyPlaceObj, imageData, imageData.len(), this)
  }

  function fillPveRewardTrophyContent(trophyItem, isRewardReceivedEarlier)
  {
    local obj = scene.findObject("pve_award_already_received")
    if(::check_obj(obj))
      obj.show(isRewardReceivedEarlier)
    if (!trophyItem)
      return

    local trophyContentPlaceObj = scene.findObject("pve_trophy_content")
    if (!::check_obj(trophyContentPlaceObj))
      return

    local layersData = ""
    local filteredLogs = ::getUserLogsList({
      show = [::EULT_OPEN_TROPHY]
      currentRoomOnly = true
      checkFunc = function(userlog) { return trophyItem.id == userlog.body.id }
    })

    foreach(log in filteredLogs)
    {
      local layer = ::trophyReward.getImageByConfig(log, false)
      if (layer != "")
      {
        layersData += layer
        break
      }
    }

    local layerId = "item_place_container"
    local layerCfg = ::LayersIcon.findLayerCfg(trophyItem.iconStyle + "_" + layerId)
    if (!layerCfg)
      layerCfg = ::LayersIcon.findLayerCfg(layerId)

    local data = ::LayersIcon.genDataFromLayer(layerCfg, layersData)
    guiScene.replaceContentFromText(trophyContentPlaceObj, data, data.len(), this)
  }

  function updatePvEReward(dt)
  {
    if (!pveRewardInfo)
      return
    local pveTrophyPlaceObj = scene.findObject("pve_trophy_progress")
    if (!::check_obj(pveTrophyPlaceObj))
      return

    local newSliderObj = pveTrophyPlaceObj.findObject("new_progress_box")
    if (!::check_obj(newSliderObj))
      return

    local targetValue = pveRewardInfo.sessionTime
    local newValue = 0
    if (skipAnim)
      newValue = targetValue
    else
      newValue = ::blendProp(newSliderObj.getValue(), targetValue, statsTime, dt).tointeger()

    newSliderObj.setValue(newValue)
  }

  function showTab(tabName)
  {
    foreach(name in tabsList)
    {
      local obj = scene.findObject(name + "_tab")
      if (obj) obj.show(tabName == name)
    }
    curTab = tabName
    updateListsButtons()

    if (state==debrState.done)
      isModeStat = tabName=="players_stats"

    showCasualtiesHead(tabName == "ww_casualties")
  }

  function showCasualtiesHead(isShow)
  {
    scene.findObject("basic_head_div").show(!isShow)
    scene.findObject("ww_casualties_head_div").show(isShow)
  }

  function animShowTab(tabName)
  {
    local obj = scene.findObject(tabName + "_tab")
    if (!obj) return

    obj.show(true)
    obj["color-factor"] = "0"
    obj["_transp-timer"] = "0"
    obj["animation"] = "show"
    curTab = tabName

    ::play_gui_sound("deb_players_off")
  }

  function onUpdate(obj, dt)
  {
    needPlayCount = false
    if (isSceneActiveNoModals() && ::debriefing_result)
    {
      if (state != debrState.done && !updateState(dt))
        switchState()
      updateTotal(dt)
    }
    playCountSound(needPlayCount)
  }

  function playCountSound(play)
  {
    if (::is_platform_ps4)
      return

    play = play && !isInProgress
    if (play != isCountSoundPlay)
    {
      if (play)
        ::start_gui_sound("deb_count")
      else
        ::stop_gui_sound("deb_count")
      isCountSoundPlay = play
    }
  }

  function updateState(dt)
  {
    switch(state)
    {
      case debrState.showPlayers:
        return updatePlayersTable(dt)

      case debrState.showAwards:
        return updateAwards(dt)

      case debrState.showMyStats:
        return updateMyStats(dt)

      case debrState.showBonuses:
        return updateBonusStats(dt)
    }
    return false
  }

  function switchState()
  {
    if (state >= debrState.done)
      return

    state++
    statsTimer = 0
    reinitTotal()
    if (state == debrState.showPlayers)
    {
      if (!needPlayersTbl)
        return switchState()

      showTab("players_stats")
      skipAnim = skipAnim && ::debriefing_skip_all_at_once
      if (!skipAnim)
        ::play_gui_sound("deb_players_on")
      initPlayersTable()
      loadBattleLog()
      loadChatHistory()
      loadCasualtiesHistory()
    }
    if (state == debrState.showAwards)
    {
      skipAnim = skipAnim && ::debriefing_skip_all_at_once
      if (awardDelay * awardsList.len() > awardsAppearTime)
        awardDelay = awardsAppearTime / awardsList.len()
    }
    else if (state == debrState.showMyStats)
    {
      if (isSpectator)
        return switchState()

      animShowTab("my_stats")
      skipAnim = skipAnim && ::debriefing_skip_all_at_once
    }
    else if (state == debrState.showBonuses)
    {
      statsTimer = statsBonusDelay

      if (isSpectator)
        return switchState()
      if (!totalRow)
        return switchState()

      local objPlace = scene.findObject("bonus_ico_place")
      if (!::checkObj(objPlace))
        return switchState()

      //Gather rewards info:
      local textArray = []

      if (::debriefing_result.mulsList.len())
        textArray.append(::loc("bonus/xpFirstWinInDayMul/tooltip"))

      local bonusNames = {
        premAcc = "charServer/chapter/premium"
        premMod = "modification/premExpMul"
        booster = "itemTypes/booster"
      }
      local tblTotal = ::getTblValue("tblTotal", ::debriefing_result.exp, {})
      local bonusesTotal = []
      foreach (bonusType in [ "premAcc", "premMod", "booster" ])
      {
        local bonusExp = ::getTblValue(bonusType + "Exp", tblTotal, 0)
        local bonusWp  = ::getTblValue(bonusType + "Wp",  tblTotal, 0)
        if (!bonusExp && !bonusWp)
          continue
        bonusesTotal.append(::loc(::getTblValue(bonusType, bonusNames, "")) + ::loc("ui/colon") +
          ::implode([ ::getRpPriceText(bonusExp, true), ::getPriceText(bonusWp) ], ::loc("ui/comma")))
      }
      if (!::u.isEmpty(bonusesTotal))
        textArray.append(::implode(bonusesTotal, "\n"))

      local boostersText = getBoostersText()
      if (!::u.isEmpty(boostersText))
        textArray.append(boostersText)

      if (::u.isEmpty(textArray)) //no bonus
        return switchState()

      if (!isDebriefingResultFull() &&
          !(gameType & ::GT_RACE &&
            ::debriefing_result.exp.result == ::STATS_RESULT_IN_PROGRESS))
        textArray.append(::loc("debriefing/most_award_after_battle"))

      local objTarget = objPlace.findObject("bonus_ico")
      if (::checkObj(objTarget))
      {
        objTarget["background-image"] = ::havePremium() ?
          "#ui/gameuiskin#medal_premium" : "#ui/gameuiskin#medal_bonus"
        objTarget.show(true)
        objTarget.tooltip = ::implode(textArray, "\n\n")
      }

      if (!skipAnim)
      {
        local objStart = scene.findObject("start_bonus_place")
        ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = statsBonusTime })
        ::play_gui_sound("deb_medal")
      }
    }
    else if (state == debrState.done)
    {
      scene.findObject("btn_next").setValue(::loc("mainmenu/btnOk"))
      scene.findObject("btn_next_text").setValue(::loc("mainmenu/btnOk"))
      scene.findObject("skip_button").show(false)
      scene.findObject("start_bonus_place").show(false)
      fillLeaderboardChanges()
      updateInfoText()
      showTabsList()
      updateListsButtons()
      initFocusArray()
      fillResearchingMods()
      fillResearchingUnits()
      selectLocalPlayer()
      checkDestroySession()
      checkPopupWindows()
      throwBattleEndEvent()
      guiScene.performDelayed(this, function() {ps4SendActivityFeed() })
    }
    else
      skipAnim = skipAnim && ::debriefing_skip_all_at_once
  }

  function ps4SendActivityFeed()
  {
    if (!::is_platform_ps4
      || !isMp
      || !::debriefing_result
      || ::debriefing_result.exp.result != ::STATS_RESULT_SUCCESS)
      return

    local config = {
      locId = "win_session"
      subType = ps4_activity_feed.MISSION_SUCCESS
    }

    ::prepareMessageForWallPostAndSend(config, {}, bit_activity.PS4_ACTIVITY_FEED)
  }

  function updateMyStats(dt)
  {
    if (curStatsIdx < 0)
      return false //nextState

    statsTimer -= dt

    local haveChanges = false
    local upTo = min(curStatsIdx, ::debriefing_rows.len()-1)
    for (local i = 0; i <= upTo; i++)
      if (::debriefing_rows[i].show)
        haveChanges = !updateStat(::debriefing_rows[i], playerStatsObj, skipAnim? 10*dt : dt, i==upTo) || haveChanges

    if (haveChanges || curStatsIdx < ::debriefing_rows.len())
    {
      if ((statsTimer < 0 || skipAnim) && curStatsIdx < ::debriefing_rows.len())
      {
        do
          curStatsIdx++
        while (curStatsIdx < ::debriefing_rows.len() && !::debriefing_rows[curStatsIdx].show)
        statsTimer += statsNextTime
      }
      return true
    }
    return false
  }

  function updateBonusStats(dt)
  {
    statsTimer -= dt
    if (statsTimer < 0 || skipAnim)
    {
      local haveChanges = false
      foreach(row in ::debriefing_rows)
        if (row.show)
          haveChanges = !updateStat(row, playerStatsObj, skipAnim? 10*dt : dt, false) || haveChanges
      return haveChanges
    }
    return true
  }

  function updateStat(row, tblObj, dt, needScroll)
  {
    local finished = true
    local justCreated = false
    local rowId = "row_" + row.id
    local rowObj = tblObj.findObject(rowId)

    if (!("curValues" in row) || !::checkObj(rowObj))
      row.curValues <- { value = 0, reward = 0 }
    if (!::checkObj(rowObj))
    {
      guiScene.setUpdatesEnabled(false, false)
      rowObj = guiScene.createElementByObject(tblObj, "gui/statistics/debriefingRow.blk", "tr", this)
      rowObj.id = rowId
      rowObj.findObject("tooltip_").id = "tooltip_" + row.id
      rowObj.findObject("name").setValue(row.getName())

      if (!::debriefing_result.needRewardColumn)
        guiScene.destroyElement(rowObj.findObject(row.canShowRewardAsValue? "td_value" : "td_reward"))
      justCreated = true

      if ("tooltip" in row)
        rowObj.title = ::loc(row.tooltip)
      if ("actionFunc" in row && (!("showAction" in row) || row.showAction()))
      {
        local actionObj = rowObj.findObject("btn_action")
        actionObj.show(true)
        actionObj.id = "btn_action_" + row.id
        if ("buttonVisualStyle" in row)
          actionObj.visualStyle = row.buttonVisualStyle
        if ("actionName" in row)
        {
          local actionText = (typeof(row.actionName)=="string")? ::loc(row.actionName) : row.actionName()
          actionObj.findObject("btn_action_text").setValue(actionText)
        }
        rowObj.buttonRow = "yes"
      }

      local rowProps = ::getTblValue("rowProps", row, null)
      if(::u.isFunction(rowProps))
        rowProps = rowProps()

      if (rowProps != null)
        foreach(name, value in rowProps)
          rowObj[name] = value
      guiScene.setUpdatesEnabled(true, true)
    }
    if (needScroll)
      rowObj.scrollToView()

    foreach(p in ["value", "reward"])
    {
      local obj = rowObj.findObject(p)
      if (!checkObj(obj))
        continue

      local targetValue = 0
      if (p != "value" || ::isInArray(row.type, ["wp", "exp", "gold"]))
      {
        local tblKey = ::get_counted_result_id(row, state, p == "value"? row.type : row.rewardType)
        targetValue = ::getTblValue(tblKey, ::debriefing_result.counted_result_by_debrState, 0)
      }

      if (targetValue == 0)
        targetValue = getStatValue(row, p)

      if (targetValue == null || (!justCreated && targetValue == row.curValues[p]))
        continue

      local nextValue = 0
      if (!skipAnim)
      {
        nextValue = ::blendProp(row.curValues[p], targetValue, row.isOverall? totalStatsTime : statsTime, dt)
        if (nextValue != targetValue)
          finished = false
        if (p != "value" || !::isInArray(row.type, ["mul", "tim", "pct", "ptm", "tnt"]))
          nextValue = nextValue.tointeger()
      }
      else
        nextValue = targetValue

      row.curValues[p] = nextValue
      local showEmpty = ((p == "value") != row.isOverall) && row.isVisibleWhenEmpty()
      local type = p == "value" ? row.type : row.rewardType

      if (row.isFreeRP && type=="exp")
        type = "frp" //show exp as FreeRP currency

      local text = getTextByType(nextValue, type, showEmpty)
      obj.setValue(text)
    }
    needPlayCount = needPlayCount || !finished
    return finished
  }

  function getStatValue(row, name, tgtName=null)
  {
    if (!tgtName)
      tgtName = "base"
    return !::u.isTable(row[name]) ? row[name] : ::getTblValue(tgtName, row[name], null)
  }

  function getTextByType(value, type, showEmpty = false)
  {
    if (!showEmpty && (value==0 || (value==1 && type=="mul")))
      return ""
    switch(type)
    {
      case "wp":  return ::getWpPriceText(value, true)
      case "gold": return ::getGpPriceText(value, true)
      case "exp": return ::getRpPriceText(value, true)
      case "frp": return ::getFreeRpPriceText(value, true)
      case "num": return value.tostring()
      case "sec": return value + ::loc("debriefing/timeSec")
      case "mul": return "x" + value
      case "pct": return floor(100.0*value + 0.5) + "%"
      case "tim": return ::secondsToString(value, false)
      case "ptm": return ::getRaceTimeFromSeconds(value)
      case "tnt": return ::roundToDigits(value * ::ZONE_HP_TO_TNT_EQUIVALENT_TONS, 3).tostring()
    }
    return ""
  }

  function updateTotal(dt)
  {
    if (!isInited && (!totalCurValues || ::u.isEqual(totalCurValues, totalTarValues)))
      return

    if (isInited)
    {
      local country = getDebriefingCountry()
      if (country in ::debriefing_countries && ::debriefing_countries[country] >= ::max_country_rank)
      {
        totalTarValues.exp = getStatValue(totalRow, "exp", "prem")
        dt = 1000 //force fast blend
      }
    }

    foreach(p in ["wp", "gold", "exp"])
      if (totalCurValues[p] != totalTarValues[p])
      {
        totalCurValues[p] = skipAnim ? totalTarValues[p] :
          ::blendProp(totalCurValues[p], totalTarValues[p], totalStatsTime, dt).tointeger()
        local obj = totalObj.findObject(p)
        if (::checkObj(obj))
          obj.setValue(totalCurValues[p].tostring())
        needPlayCount = true
      }
  }

  function getModExp(airData)
  {
    if (::getTblValue("expModuleCapped", airData, false))
      return airData.expInvestModule
    return airData.expModsTotal //expModsTotal recounted by bonus mul.
  }

  function fillResearchingMods()
  {
    if (!isDebriefingResultFull())
      return

    local usedUnitsList = []
    foreach(unitName, unitData in ::debriefing_result.exp.aircrafts)
    {
      local unit = ::getAircraftByName(unitName)
      if (unit && ::getTblValue("expTotal", unitData) && ::getTblValue("sessionTime", unitData))
        usedUnitsList.append({ unit = unit, unitData = unitData })
    }

    usedUnitsList.sort(function(a,b)
    {
      local haveInvestA = a.unitData.investModuleName == ""
      local haveInvestB = b.unitData.investModuleName == ""
      if (haveInvestA!=haveInvestB)
        return haveInvestA? 1 : -1
      local expA = a.unitData.expTotal
      local expB = b.unitData.expTotal
      if (expA!=expB)
        return (expA > expB)? -1 : 1
      return 0
    })

    local tabObj = scene.findObject("modifications_objects_place")
    guiScene.replaceContentFromText(tabObj, "", 0, this)
    foreach(data in usedUnitsList)
      fillResearchMod(tabObj, data.unit, data.unitData)
  }

  function fillResearchingUnits()
  {
    if (!isDebriefingResultFull())
      return

    local obj = scene.findObject("air_item_place")
    local data = ""
    local unitItems = []
    foreach (ut in ::g_unit_type.types)
    {
      local unitItem = getResearchUnitMarkupData(ut.name)
      if (unitItem)
      {
        data += ::build_aircraft_item(unitItem.id, unitItem.unit, unitItem.params)
        unitItems.append(unitItem)
      }
    }

    guiScene.replaceContentFromText(obj, data, data.len(), this)
    foreach (unitItem in unitItems)
      ::fill_unit_item_timers(obj.findObject(unitItem.id), unitItem.unit, unitItem.params)

    if (!unitItems.len())
    {
      local expInvestUnitTotal = 0
      foreach (unitId, unitData in ::debriefing_result.exp.aircrafts)
        expInvestUnitTotal += ::getTblValue("expInvestUnitTotal", unitData, 0)

      if (expInvestUnitTotal > 0)
      {
        local msg = ::format(::loc("debriefing/all_units_researched"), ::getRpPriceText(expInvestUnitTotal, true))
        local noUnitObj = scene.findObject("no_air_text")
        if (::checkObj(noUnitObj))
          noUnitObj.setValue(::stripTags(msg))
      }
    }
  }

  function onEventUnitBought(p)
  {
    //local unit = getAircraftByName(::getTblValue("unitName", p, ""))
    //if (!unit) return

    fillResearchingUnits()
  }

  function onEventUnitRented(p)
  {
    fillResearchingUnits()
  }

  function getResearchUnitMarkupData(unitTypeName)
  {
    local unitName = ::getTblValue("investUnitName" + unitTypeName, ::debriefing_result.exp, "")
    local unit = ::getAircraftByName(unitName)
    if (!unit)
      return null
    local expInvest = ::getTblValue("expInvestUnit" + unitTypeName, ::debriefing_result.exp, 0)
    expInvest = applyItemExpMultiplicator(expInvest)
    if (expInvest <= 0)
      return null

    return {
      id = unitName
      unit = unit
      params = {
        diffExp = expInvest
        tooltipParams = {
          researchExpInvest = expInvest
          boosterEffects = getBoostersTotalEffects()
        }
      }
    }
  }

  function applyItemExpMultiplicator(itemExp)
  {
    local multBonus = 0
    if(::debriefing_result.mulsList.len() > 0)
      foreach(idx, table in ::debriefing_result.mulsList)
        multBonus += ::getTblValue("exp", table, 0)

    itemExp = multBonus == 0? itemExp : itemExp * multBonus
    return itemExp
  }

  function getResearchModFromAirData(air, airData)
  {
    local curResearch = airData.investModuleName
    if (curResearch != "")
      return ::getModificationByName(air, curResearch)
    return null
  }

  function fillResearchMod(holderObj, air, airData)
  {
    local modRowObj = guiScene.createElementByObject(holderObj, "gui/statistics/modificationProgress.blk", "tdiv", this)

    local unitItemParams = {
      tooltipParams = {
        boosterEffects = getBoostersTotalEffects()
      }
    }
    local data = ::build_aircraft_item(air.name, air, unitItemParams)
    local airObj = modRowObj.findObject("air_item_place")
    guiScene.replaceContentFromText(airObj, data, data.len(), this)
    ::fill_unit_item_timers(airObj.findObject(air.name), air, unitItemParams)

    local mod = getResearchModFromAirData(air, airData)
    if (mod)
    {
      local diffExp = getModExp(airData)
      local modIconNest = modRowObj.findObject("modification_place")
      local modItemObj = ::weaponVisual.createItem("mod_" + air.name, mod, weaponsItem.modification, modIconNest, this)
      ::weaponVisual.updateItem(air, mod, modItemObj, false, this, getParamsForModItem(diffExp))
    } else
    {
      local msg = "debriefing/but_all_mods_researched"
      if (::find_any_not_researched_mod(air))
        msg = "debriefing/but_not_any_research_active"
      msg = format(::loc(msg), ::getRpPriceText(getModExp(airData) || airData.expTotal, true))
      modRowObj.findObject("no_mod_text").setValue(msg)
    }
  }

  function getCurrentEdiff()
  {
    return ::get_mission_mode()
  }

  function onEventModBought(p)
  {
    local unitId = ::getTblValue("unitName", p, "")
    local modId = ::getTblValue("modName", p, "")
    updateResearchMod(unitId, modId)
  }

  function onEventUnitModsRecount(p)
  {
    local unitId = ::getTblValueByPath("unit.name", p)
    updateResearchMod(unitId, "")
  }

  function updateResearchMod(unitId, modId)
  {
    local airData = ::getTblValueByPath("exp.aircrafts." + unitId, ::debriefing_result)
    if (!airData)
      return
    local unit = ::getAircraftByName(unitId)
    local mod = getResearchModFromAirData(unit, airData)
    if (!mod || (modId != "" && modId != mod.name))
      return

    local obj = scene.findObject("research_list")
    local modObj = ::checkObj(obj) ? obj.findObject("mod_" + unitId) : null
    if (!::checkObj(modObj))
      return
    local diffExp = getModExp(airData)
    ::weaponVisual.updateItem(unit, mod, modObj, false, this, getParamsForModItem(diffExp))
  }

  function getParamsForModItem(diffExp)
  {
    return { diffExp = diffExp }
  }

  function onModificationTooltipOpen(obj)
  {
    if (!checkShowTooltip(obj))
      return

    local airName = ::getObjIdByPrefix(obj, "tooltip_mod_")
    if (!airName || !(airName in ::debriefing_result.exp.aircrafts))
      return
    local air = ::getAircraftByName(airName)
    if (!air)
      return

    local airData = ::debriefing_result.exp.aircrafts[airName]
    local diffExp = getModExp(airData)
    local modItem = getResearchModFromAirData(air, airData)
    if (modItem)
      ::weaponVisual.updateWeaponTooltip(obj, air, modItem, this, { diffExp = diffExp })
  }

  function fillLeaderboardChanges()
  {
    local lbWindgetsNestObj = scene.findObject("leaderbord_stats")
    if (!::checkObj(lbWindgetsNestObj))
      return

    local logs = ::getUserLogsList({
        show = [::EULT_SESSION_RESULT]
        currentRoomOnly = true
      })

    if (logs.len() == 0)
      return

    if (!("tournamentResult" in logs[0]))
      return

    local now = ::getTblValue("newStat", logs[0].tournamentResult)
    local was = ::getTblValue("oldStat", logs[0].tournamentResult)

    local blk = ""
    local lbDiff = ::leaderboarsdHelpers.getLbDiff(now, was)
    local lbStatsBlk = ""
    foreach (lbFieldsConfig in ::events.eventsTableConfig)
    {
      if (!(lbFieldsConfig.field in now))
        continue
      blk += ::getLeaderboardItemWidget(lbFieldsConfig,
        now[lbFieldsConfig.field],
        ::getTblValue(lbFieldsConfig.field, lbDiff, null),
        "0.24@scrn_tgt")
    }
    guiScene.replaceContentFromText(lbWindgetsNestObj, blk, blk.len() this)
    lbWindgetsNestObj.scrollToView()
  }

  function onSkip()
  {
    skipAnim = true
  }

  function checkShowTooltip(obj)
  {
    local showTooltip = skipAnim || state==debrState.done
    obj["class"] = showTooltip? "" : "empty"
    return showTooltip
  }

  function onTrTooltipOpen(obj)
  {
    if (!checkShowTooltip(obj) || !::debriefing_result)
      return

    local id = getTooltipObjId(obj)
    if (!id) return
    if (!("exp" in ::debriefing_result) || !("aircrafts" in ::debriefing_result.exp))
      return obj["class"] = "empty"

    local tRow = ::get_debriefing_row_by_id(id)
    if (!tRow)
      return obj["class"] = "empty"

    local rowsCfg = []
    if (tRow.isCountedInUnits)
    {
      foreach (unitId, unitData in ::debriefing_result.exp.aircrafts)
        rowsCfg.append({
          row     = tRow
          name    = ::getUnitName(unitId)
          expData = unitData
        })
    }
    else
    {
      rowsCfg.append({
        row     = tRow
        name    = tRow.getName()
        expData = ::debriefing_result.exp
      })
    }

    if (tRow.tooltipExtraRows)
    {
      foreach (id in tRow.tooltipExtraRows())
      {
        local extraRow = ::get_debriefing_row_by_id(id)
        if (extraRow.show)
          rowsCfg.append({
            row     = extraRow
            name    = extraRow.getName()
            expData = ::debriefing_result.exp
          })
      }
    }

    if (!rowsCfg.len())
      return obj["class"] = "empty"

    local tooltipView = {
      rows = getTrTooltipRowsView(rowsCfg)
      tooltipComment = tRow.tooltipComment ? tRow.tooltipComment() : null
    }

    local markup = ::handyman.renderCached("gui/statistics/debriefRowTooltip", tooltipView)
    guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }

  function getTrTooltipRowsView(rowsCfg)
  {
    local view = []

    local boosterEffects = getBoostersTotalEffects()

    foreach(cfg in rowsCfg)
    {
      local rowView = {
        name = cfg.name
      }

      local rowTbl = ::getTblValue(::get_table_name_by_id(cfg.row), cfg.expData)

      foreach(currency in [ "exp", "wp" ])
      {
        if (cfg.row.type != currency && cfg.row.rewardType != currency)
          continue
        local currencySourcesView = {}
        foreach (source in [ "noBonus", "premAcc", "premMod", "booster" ])
        {
          local val = ::getTblValue(source + ::g_string.toUpper(currency, 1), rowTbl, 0)
          if (val <= 0)
            continue
          local extra = ""
          if (source == "booster")
          {
            local effect = ::getTblValue((currency == "exp" ? "xp" : currency) + "Rate", boosterEffects, 0)
            if (effect)
              extra = ::colorize("fadedTextColor", ::loc("ui/parentheses", { text = effect.tointeger().tostring() + "%" }))
          }
          currencySourcesView[source] <- getTextByType(val, currency) + extra
        }
        if (currencySourcesView.len() > 1)
        {
          if (!("bonuses" in rowView))
            rowView.bonuses <- []
          rowView.bonuses.append(currencySourcesView)
        }
      }

      foreach(p in ["time", "value", "reward", "info"])
      {
        local text = ""

        local type = (p == "reward")? cfg.row.rewardType : p
        local pId = type + cfg.row.id
        local showEmpty = false
        if (p == "time")
        {
          pId = "sessionTime"
          type = "tim"
          if (cfg.row.id == "sessionTime")
            pId = ""
          else
            showEmpty = true
        }
        else if (p == "reward" || p == "value")
        {
          if (p == "value")
          {
            type = cfg.row.type
            pId = cfg.row.customValueName? cfg.row.customValueName : cfg.row.type + cfg.row.id
          }
        }
        else if (p=="info")
        {
          pId = ::getTblValue("infoName", cfg.row, "")
          type = ::getTblValue("infoType", cfg.row, "")
        }

        text = getTextByType(::getTblValue(pId, cfg.expData, 0), type, showEmpty)
        rowView[p] <- text
      }

      view.append(rowView)
    }

    local showColumns = { time = false, value = false, reward = false, info = false }
    foreach (rowView in view)
      foreach (col, isShow in showColumns)
        if (!::u.isEmpty(rowView[col]))
          showColumns[col] = true
    foreach (rowView in view)
      foreach (col, isShow in showColumns)
        if (isShow && ::u.isEmpty(rowView[col]))
          rowView[col] = ::nbsp

    return view
  }

  function onRowAction(obj)
  {
    local id = ::getObjIdByPrefix(obj, "btn_action_")
    if (!id)
      return

    foreach(row in ::debriefing_rows)
      if (row.id == id && "actionFunc" in row)
        return row.actionFunc.call(this)
  }

  function onBuyPremiumAward()
  {
    if (::havePremium())
      return
    local entName = ::get_entitlement_with_award()
    if (!entName)
    {
      ::dagor.assertf(false, "Error: not found entitlement with premium award")
      return
    }

    local ent = ::get_entitlement_config(entName)
    local entNameText = ::get_entitlement_name(ent)
    local goldCost = ("goldCost" in ent)? ent.goldCost : 0
    local cb = ::Callback(onBuyPremiumAward, this)

    local msgText = format(::loc("msgbox/EarnNow"), entNameText, ::get_cur_award_text(), getPriceText(0, goldCost))
    msgBox("not_all_mapped", msgText,
    [
      ["ok", (@(entName, goldCost, cb) function() {
        if (!::old_check_balance_msgBox(0, goldCost, cb))
          return false

        taskId = ::purchase_entitlement_and_get_award(entName)
        if (taskId >= 0)
        {
          ::set_char_cb(this, slotOpCb)
          showTaskProgressBox()
          afterSlotOp = function() { addPremium() }
        }
      })(entName, goldCost, cb)],
      ["cancel", function() {}]
    ], "ok")
  }

  function addPremium()
  {
    if (!::havePremium())
      return

    ::debriefing_add_virtual_prem_acc()

    foreach(row in ::debriefing_rows)
      if (!row.show)
        showSceneBtn("row_" + row.id, row.show)

    reinitTotal()
    skipAnim = false
    state = debrState.showBonuses - 1
    switchState()
    ::update_gamercards()
  }

  function updateAwards(dt)
  {
    statsTimer -= dt

    updatePvEReward(dt)

    if (statsTimer < 0 || skipAnim)
    {
      if (awardsList && curAwardIdx < awardsList.len())
      {
        if (currentAwardsListIdx >= currentAwardsList.len())
        {
          currentAwardsList = unlockAwardsList
          currentAwardsListConfig = awardsListsConfig.unlocks
          currentAwardsListIdx = 0
        }

        addAward()
        statsTimer += awardDelay
        curAwardIdx++
        currentAwardsListIdx++
      }
      else if (curAwardIdx == awardsList.len())
      {
        //finish awards update
        statsTimer += nextWndDelay
        curAwardIdx++
      }
      else
        return false
    }
    return true
  }

  function countAwardsOffset(obj, tgtObj)
  {
    local size = obj.getSize()
    local maxSize = tgtObj.getSize()
    local awardsWidth = size[0] * currentAwardsList.len()

    if (awardsWidth > maxSize[0] && currentAwardsList.len() > 1)
      awardOffset = ((maxSize[0] - awardsWidth) / (currentAwardsList.len()-1) - 1).tointeger()
    else
      tgtObj.width = awardsWidth.tostring()
  }

  function addAward()
  {
    local config = currentAwardsList[currentAwardsListIdx]
    local objId = "award_" + curAwardIdx

    local listObj = scene.findObject(currentAwardsListConfig.listObjId)
    local obj = guiScene.createElementByObject(listObj, "gui/statistics/debriefAward.blk", "awardPlace", this)
    obj.id = objId

    local tooltipObj = obj.findObject("tooltip_")
    tooltipObj.id = "tooltip_" + curAwardIdx
    tooltipObj.setUserData(config)

    if ("needFrame" in config && config.needFrame)
      obj.findObject("move_part")["class"] = "unlockFrame"

    if (currentAwardsListIdx == 0) //firstElem
      countAwardsOffset(obj, listObj)
    else if (currentAwardsListConfig.align == "left" && awardOffset != 0)
      obj.pos = awardOffset + ", 0"

    if (currentAwardsListConfig.align == "right")
      if (currentAwardsListIdx == 0)
        obj.pos = "pw - w, 0"
      else
        obj.pos = "-2w -" + awardOffset + " ,0"

    local icoObj = obj.findObject("award_img")
    set_unlock_icon_by_config(icoObj, config)
    local awMultObj = obj.findObject("award_multiplier")
    if (::checkObj(awMultObj))
    {
      local show = config.amount > 1
      awMultObj.show(show)
      if (show)
      {
        local amObj = awMultObj.findObject("amount_text")
        if (::checkObj(amObj))
          amObj.setValue("x" + config.amount)
      }
    }

    if (!skipAnim)
    {
      local objStart = scene.findObject("start_award_place")
      local objTarget = obj.findObject("move_part")
      ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = awardFlyTime })

      obj["_size-timer"] = "0"
      obj.width = "0"
      ::play_gui_sound("deb_achivement")
    }
  }

  function onAwardTooltipOpen(obj)
  {
    if (!checkShowTooltip(obj))
      return

    local config = obj.getUserData()
    ::build_unlock_tooltip_by_config(obj, config, this)
  }

  function onViewAwards(obj = null)
  {
    if ((skipAnim || state == debrState.done) && !::u.isEmpty(awardsList))
      ::showUnlocksGroupWnd([{
        unlocksList = awardsList
        titleText = ::loc("debriefing/awards_list")
      }])
  }

  function buildPlayersTable()
  {
    playersTbl = []
    curPlayersTbl = [[], []]
    if (isTeamplay)
    {
      for(local t = 0; t < 2; t++)
      {
        local tbl = getMplayersListByTeam(t+1)
        sortTable(tbl)
        playersTbl.append(tbl)
      }
    }
    else
    {
      sortTable(::debriefing_result.mplayers_list)
      playersTbl.append([])
      playersTbl.append([])
      foreach(i, player in ::debriefing_result.mplayers_list)
      {
        local tblIdx = i >= PLAYERS_IN_FIRST_TABLE_IN_FFA ? 1 : 0
        playersTbl[tblIdx].append(player)
      }
    }

    foreach(tbl in playersTbl)
      foreach(player in tbl)
      {
        player.state = ::PLAYER_IN_FLIGHT //dont need to show laast player state in debriefing.
        player.isDead = false
      }
  }

  function initPlayersTable()
  {
    initStats()

    if (needPlayersTbl)
      buildPlayersTable()

    updatePlayersTable(0.0)
    showMyPlaceInTable()
  }

  function getMplayersListByTeam(teamNum)
  {
    if (!::debriefing_result)
      return []

    local array = []
    foreach(player in ::debriefing_result.mplayers_list)
      if (teamNum == player.team)
        array.append(player)

    return array
  }

  function updatePlayersTable(dt)
  {
    if (!playersTbl || !::debriefing_result)
      return false

    statsTimer -= dt
    minPlayersTime -= dt
    if (statsTimer <= 0 || skipAnim)
    {
      if (playersTblDone)
        return minPlayersTime > 0

      playersTblDone = true
      for(local t = 0; t < 2; t++)
      {
        local idx = curPlayersTbl[t].len()
        if (idx in playersTbl[t])
          curPlayersTbl[t].append(playersTbl[t][idx])
        playersTblDone = playersTblDone && curPlayersTbl[t].len() == playersTbl[t].len()
      }
      updateStats(curPlayersTbl, ::debriefing_result.mpTblTeams)
      statsTimer += playersRowTime
      if (playersTblDone)
        selectLocalPlayer()
    }
    return true
  }

  function showMyPlaceInTable()
  {
    if (!playersTbl
        || isSpectator
        || pveRewardInfo && pveRewardInfo.isVisible)
      return

    local place = 0
    foreach(t, tbl in playersTbl)
      foreach(i, player in tbl)
        if (("isLocal" in player) && player.isLocal)
        {
          place = i + 1
          if (!isTeamplay && t)
            place += playersTbl[0].len()
          break
        }
    if (place==0)
      return

    local label = isTeamplay ? ::loc("debriefing/placeInMyTeam")
      : (::loc("mainmenu/btnMyPlace") + ::loc("ui/colon"))

    local objTarget = scene.findObject("my_place_move_box")
    objTarget.show(true)
    scene.findObject("my_place_label").setValue(label)
    scene.findObject("my_place_in_mptable").setValue(place.tostring())

    if (!skipAnim)
    {
      local objStart = scene.findObject("my_place_move_box_start")
      ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = myPlaceTime })
    }
  }

  function loadBattleLog(filterIdx = null)
  {
    if (!needPlayersTbl)
      return
    local filters = ::HudBattleLog.getFilters()

    if (filterIdx == null)
    {
      filterIdx = ::loadLocalByAccount("wnd/battleLogFilterDebriefing", 0)

      local obj = scene.findObject("battle_log_filter")
      if (::checkObj(obj))
      {
        local data = ""
        foreach (f in filters)
          data += ::format("RadioButton { text:t='#%s'; RadioButtonImg{} }\n", f.title)
        guiScene.replaceContentFromText(obj, data, data.len(), this)
        obj.setValue(filterIdx)
      }
    }

    local obj = scene.findObject("battle_log_div")
    if (::checkObj(obj))
    {
      local logText = ::HudBattleLog.getText(filters[filterIdx].id, 0)
      obj.findObject("battle_log").setValue(logText)
    }
  }

  function loadChatHistory()
  {
    if (!needPlayersTbl)
      return
    local logText = ::get_gamechat_log_text()
    if (logText == "")
      return
    local obj = scene.findObject("chat_history_div")
    if (::checkObj(obj))
      obj.findObject("chat_log").setValue(logText)
  }

  function loadCasualtiesHistory()
  {
    if (!is_show_ww_casualties())
      return

    local logs = ::getUserLogsList({
      show = [
        ::EULT_SESSION_RESULT
      ]
      currentRoomOnly = true
    })

    if (!logs.len())
      return

    local view = ::WwBattleResults().updateFromUserlog(logs[0]).getView()

    local tabMarkup = ::handyman.renderCached("gui/statistics/battleCasualties", view)
    local contentObj = scene.findObject("ww_casualties_div")
    if (::checkObj(contentObj))
      guiScene.replaceContentFromText(contentObj, tabMarkup, tabMarkup.len(), this)

    local headMarkup = ::handyman.renderCached("gui/statistics/battleCasualtiesHead", view)
    local headObj = scene.findObject("ww_casualties_head_block")
    if (::checkObj(headObj))
      guiScene.replaceContentFromText(headObj, headMarkup, headMarkup.len(), this)

    local headTextObj = scene.findObject("ww_casualties_head_text")
    if (::checkObj(headTextObj))
    {
      local isWinner = ::debriefing_result.exp.result == ::STATS_RESULT_SUCCESS
      headTextObj.setValue(::loc(isWinner ? "debriefing/victory" : "debriefing/defeat"))
    }
  }

  function showTabsList()
  {
    local tabsObj = scene.findObject("tabs_list")
    tabsObj.show(true)
    local data = ""
    local defaultTabValue = 0
    local defaultTabName = is_show_ww_casualties() ? "ww_casualties" : ""
    local tabCounter = 0
    foreach(tabName in tabsList)
    {
      local checkName = "is_show_" + tabName
      if (!(checkName in this) || this[checkName]())
      {
        data += format("shopFilter { id:t='%s'; text:t='%s' } ", tabName, "#debriefing/" + tabName)
        if (tabName == defaultTabName)
          defaultTabValue = tabCounter
        tabCounter++
      }
    }
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(defaultTabValue)
    onChangeTab(tabsObj)
  }

  function is_show_my_stats()
  {
    return !isSpectator
  }
  function is_show_players_stats()
  {
    return needPlayersTbl
  }
  function is_show_battle_log()
  {
    return needPlayersTbl && ::HudBattleLog.getLength() > 0
  }
  function is_show_chat_history()
  {
    return needPlayersTbl && ::get_gamechat_log_text() != ""
  }
  function is_show_ww_casualties()
  {
    return needPlayersTbl && ::is_worldwar_enabled() && ::g_mis_custom_state.getCurMissionRules().isWorldWar
  }
  function is_show_research_list()
  {
    local show = false
    foreach (name, block in ::debriefing_result.exp.aircrafts)
      if ("investModuleName" in block && block.investModuleName != "")
      {
        show = true
        break
      }
    return show
  }

  function onChangeTab(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    showTab(obj.getChild(value).id)
  }

  function updateListsButtons()
  {
    local isAnimDone = state==debrState.done
    local isReplayReady = ::has_feature("Replays") && ::is_replay_present() && ::is_replay_turned_on()
    local player = getSelectedPlayer()
    local buttonsList = {
      btn_view_replay = isAnimDone && isReplayReady && !isMp
      btn_save_replay = isAnimDone && isReplayReady && !::is_replay_saved()
      btn_usercard = isAnimDone && (curTab == "players_stats") && player && !player.isBot
      btn_rewards_list = isAnimDone && !::u.isEmpty(awardsList)
    }

    foreach(btn, show in buttonsList)
      showSceneBtn(btn, show)

    local showFacebookBtn = isAnimDone && (curTab == "my_stats" || curTab == "players_stats")
    ::show_facebook_screenshot_button(scene, showFacebookBtn)
  }

  function onChatLinkClick(obj, itype, link)
  {
    if (link.len() > 3 && link.slice(0, 3) == "PL_")
    {
      local name = link.slice(3)
      ::gui_modal_userCard({ name = name })
    }
  }

  function onChatLinkRClick(obj, itype, link)
  {
    if (link.len() > 3 && link.slice(0, 3) == "PL_")
    {
      local name = link.slice(3)
      local player = getPlayerInfo(name)
      if (player)
        ::session_player_rmenu(this, player)
    }
  }

  function onChangeBattlelogFilter(obj)
  {
    if (!::checkObj(obj))
      return
    local filterIdx = obj.getValue()
    ::saveLocalByAccount("wnd/battleLogFilterDebriefing", filterIdx)
    loadBattleLog(filterIdx)
  }

  function onViewReplay(obj)
  {
    if (isInProgress)
      return

    ::set_presence_to_player("replay")
    ::req_unlock_by_client("view_replay", false)
    ::on_view_replay("")
    isInProgress = true
  }

  function onSaveReplay(obj)
  {
    if (isInProgress)
      return
    if (::is_replay_saved() || !::is_replay_present())
      return

    local afterFunc = function(newName)
    {
      local result = ::on_save_replay(newName);
      if (!result)
      {
        msgBox("save_replay_error", ::loc("replays/save_error"),
          [
            ["ok", function() { } ]
          ], "ok")
      }
      updateListsButtons()
    }
    ::gui_modal_name_and_save_replay(this, afterFunc);
  }

  function checkDestroySession()
  {
    if (::is_mplayer_peer())
      ::destroy_session_scripted()
  }

  function setGoNext()
  {
    if (::is_worldwar_enabled() && ::g_world_war.isLastFlightWasWwBattle)
    {
      ::go_debriefing_next_func = function() {
        ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu) //do not need to back to debriefing
        ::g_world_war.openMainWnd()
      }
      return
    }

    local gm = ::get_game_mode()
    local isMpMode = (gameType & ::GT_COOPERATIVE) || (gameType & ::GT_VERSUS)

    ::go_debriefing_next_func = ::gui_start_mainmenu //default func
    if (::SessionLobby.status == lobbyStates.IN_DEBRIEFING && ::SessionLobby.haveLobby())
      return
    if (isMpMode && !::is_connected_to_matching())
      return

    if (isMpMode && ::go_lobby_after_statistics() && gm != ::GM_DYNAMIC)
    {
      ::go_debriefing_next_func = ::gui_start_mp_lobby_next_mission
      if ((gt & ::GT_COOPERATIVE) && !::debriefing_result.isSucceed)
        ::go_debriefing_next_func = ::gui_start_mp_lobby
      return
    }

    if (gm == ::GM_CAMPAIGN)
    {
      if (::debriefing_result.isSucceed)
      {
        dagor.debug("VIDEO: campaign = "+ ::current_campaign_id + "mission = "+ ::current_campaign_mission)
        if ((::current_campaign_mission == "jpn_guadalcanal_m4")
            || (::current_campaign_mission == "us_guadalcanal_m4"))
          ::check_for_victory <- true;
        ::select_next_avail_campaign_mission(::current_campaign_id, ::current_campaign_mission)
      }
      ::go_debriefing_next_func = ::gui_start_menuCampaign
    } else
    if (gm==::GM_TEST_FLIGHT)
      ::go_debriefing_next_func = ::gui_start_menuShop
    else
    if (gm==::GM_DYNAMIC)
    {
      if (isMpMode)
      {
        if (::SessionLobby.isInRoom() && ::dynamic_result == ::MISSION_STATUS_RUNNING)
        {
          ::go_debriefing_next_func = ::gui_start_dynamic_summary
          if (::is_mplayer_host())
            recalcDynamicLayout()
        }
        else
          ::go_debriefing_next_func = ::gui_start_dynamic_summary_f
        return
      }

      if (::dynamic_result == ::MISSION_STATUS_RUNNING)
      {
        local settings = DataBlock();
        ::mission_settings.dynlist <- ::dynamic_get_list(settings, false)

        local add = []
        for (local i = 0; i < ::mission_settings.dynlist.len(); i++)
        {
          local misblk = ::mission_settings.dynlist[i].mission_settings.mission
          misblk.setStr("mis_file", ::mission_settings.layout)
          misblk.setStr("chapter", ::get_cur_game_mode_name());
          misblk.setStr("type", ::get_cur_game_mode_name());
          add.append(misblk)
        }
        ::add_mission_list_full(::GM_DYNAMIC, add, ::mission_settings.dynlist)
        ::go_debriefing_next_func = ::gui_start_dynamic_summary
      } else
        ::go_debriefing_next_func = ::gui_start_dynamic_summary_f
    } else if (gm == ::GM_SINGLE_MISSION)
      ::go_debriefing_next_func = ::gui_start_menuSingleMissions
    else if (gm == ::GM_BUILDER)
      ::go_debriefing_next_func = ::gui_start_menu_builder
    else
      ::go_debriefing_next_func = ::gui_start_mainmenu
  }

  function recalcDynamicLayout()
  {
    mission_settings.layout <- ::dynamic_get_layout();
    // FIXME : workaroud for host migration assert (instead of back to lobby - disconnect)
    // http://www.gaijin.lan/mantis/view.php?id=36502
    if (mission_settings.layout)
    {
      local settings = DataBlock();
      ::mission_settings.dynlist <- ::dynamic_get_list(settings, false)

      local add = []
      for (local i = 0; i < ::mission_settings.dynlist.len(); i++)
      {
        local misblk = ::mission_settings.dynlist[i].mission_settings.mission
        misblk.setStr("mis_file", ::mission_settings.layout)
        misblk.setStr("chapter", ::get_cur_game_mode_name());
        misblk.setStr("type", ::get_cur_game_mode_name());
        misblk.setBool("gt_cooperative", true)
        add.append(misblk)
      }
      ::add_mission_list_full(::GM_DYNAMIC, add, ::mission_settings.dynlist)
      ::mission_settings.currentMissionIdx <- 0
      local misBlk = ::mission_settings.dynlist[::mission_settings.currentMissionIdx].mission_settings.mission
      misBlk.setInt("_gameMode", ::GM_DYNAMIC)
      ::mission_settings.missionFull = ::mission_settings.dynlist[::mission_settings.currentMissionIdx]
      ::select_mission_full(misBlk, ::mission_settings.missionFull);
      ::apply_host_settings(misBlk);
    }
    else
    {
      dagor.debug("no mission_settings.layout, destroy session")
      ::destroy_session_scripted()
    }
  }

  function afterSave()
  {
    applyReturn()
  }

  function applyReturn()
  {
    if (::go_debriefing_next_func != ::gui_start_dynamic_summary)
      ::destroy_session_scripted()

    ::debriefing_result = null
    playCountSound(false)
    isInProgress = false

    ::HudBattleLog.reset()

    if (!::SessionLobby.goForwardAfterDebriefing())
      goForward(::go_debriefing_next_func)
  }

  function goBack()
  {
    if (state != debrState.done && !skipAnim)
    {
      onSkip()
      return
    }

    if (isInProgress)
      return

    isInProgress = true

    autosave_replay();

    if (!::go_debriefing_next_func)
      ::go_debriefing_next_func = ::gui_start_mainmenu

    if (isReplay)
      applyReturn()
    else
    {  //do_finalize_debriefing
      save()
    }
    playCountSound(false)
    ::my_stats.markStatsReset()
  }

  function onEventMatchingDisconnect(p)
  {
    ::go_debriefing_next_func = ::gui_start_logout
  }

  function isDelayedLogoutOnDisconnect()
  {
    return true
  }

  function throwBattleEndEvent()
  {
    local logs = ::getUserLogsList({
      show = [::EULT_SESSION_RESULT]
      currentRoomOnly = true
    })

    if (logs.len())
    {
      local eventId = ::getTblValue("eventId", logs[0])
      if (eventId)
        ::broadcastEvent("EventBattleEnded", {eventId = eventId})
    }
    ::broadcastEvent("BattleEnded")
  }

  function checkPopupWindows()
  {
    local country = getDebriefingCountry()

    //check unlocks windows
    local wnd_unlock_gained = getUserLogsList({
      show = [::EULT_NEW_UNLOCK]
      unlocks = [::UNLOCKABLE_AIRCRAFT, ::UNLOCKABLE_AWARD]
      filters = { popupInDebriefing = [true] }
      currentRoomOnly = true
      disableVisible = true
    })
    foreach(log in wnd_unlock_gained)
      ::showUnlockWnd(::build_log_unlock_data(log))

    //check new rank and unlock country by exp gained
    local new_rank = ::get_player_rank_by_country(country)
    local old_rank = (country in ::debriefing_countries)? ::debriefing_countries[country] : new_rank

    if (country!="" && country!="country_0" &&
        !::isCountryAvailable(country) && ::get_player_exp_by_country(country)>0)
    {
      unlockCountry(country)
      old_rank = -1 //new country unlocked!
    }

    if (new_rank > old_rank)
    {
      local gained_ranks = [];

      for (local i = old_rank+1; i<=new_rank; i++)
        gained_ranks.append(i);
      ::checkRankUpWindow(country, old_rank, new_rank);
    }

    //check country unlocks by N battle
    local country_unlock_gained = getUserLogsList({
      show = [::EULT_NEW_UNLOCK]
      unlocks = [::UNLOCKABLE_COUNTRY]
      currentRoomOnly = true
      disableVisible = true
    })
    foreach(log in country_unlock_gained)
    {
      ::showUnlockWnd(::build_log_unlock_data(log))
      if (("unlockId" in log) && log.unlockId!=country && ::isInArray(log.unlockId, ::shopCountriesList))
        unlockCountry(log.unlockId)
    }

    //check userlog entry for tournament special rewards
    local tornament_special_rewards = ::getUserLogsList({
      show = [::EULT_CHARD_AWARD]
      currentRoomOnly = true
      disableVisible = true
      filters = { rewardType = ["TournamentReward"] }
    })

    local rewardsArray = []
    foreach(log in tornament_special_rewards)
      rewardsArray.extend(::getTournamentRewardData(log))

    foreach(rewardConfig in rewardsArray)
      ::showUnlockWnd(rewardConfig)
  }

  function updateInfoText()
  {
    if (::debriefing_result == null)
      return
    local infoText = ""
    local info = ::get_profile_info()
    local isVersus = (gameType & ::GT_VERSUS)

    local gm = ::get_game_mode()
    local wpdata = ::get_session_warpoints()

    if ((gm == ::GM_DYNAMIC || gm == ::GM_BUILDER) && wpdata.isRewardReduced)
      infoText = ::loc("debriefing/award_reduced")
    else
    {
      local hasAnyReward = false
      foreach (source in [ "Total", "Mission" ])
        foreach (currency in [ "exp", "wp", "gold" ])
          if (::getTblValue(currency + source, ::debriefing_result.exp, 0) > 0)
            hasAnyReward = true

      if (!hasAnyReward)
      {
        if (gm == ::GM_SINGLE_MISSION || gm == ::GM_CAMPAIGN || gm == ::GM_TRAINING)
        {
          if (::debriefing_result.isSucceed)
            infoText = ::loc("debriefing/award_already_received")
        }
        else if (isMp && ::debriefing_result.exp.result == ::STATS_RESULT_IN_PROGRESS && !(gameType & ::GT_RACE))
          infoText = ::loc("debriefing/exp_and_reward_will_be_later")
      }
    }

    local infoObj = scene.findObject("stat_info_text")
    infoObj.setValue(infoText)
    guiScene.setUpdatesEnabled(true, true)
    infoObj.scrollToView()
  }

  function getBoostersText()
  {
    local textsList = []
    local activeBoosters = ::getTblValue("activeBoosters", ::debriefing_result, [])
    if (activeBoosters.len() > 0)
      foreach(effectType in ::BoosterEffectType)
      {
        local boostersArray = []
        foreach(idx, block in activeBoosters)
        {
          local item = ::ItemsManager.findItemById(block.itemId)
          if (item && effectType.checkBooster(item))
            boostersArray.append(item)
        }

        if (boostersArray.len())
          textsList.append(::ItemsManager.getActiveBoostersDescription(boostersArray, effectType))
      }
    return ::implode(textsList, "\n\n")
  }

  function getBoostersTotalEffects()
  {
    local activeBoosters = ::getTblValue("activeBoosters", ::debriefing_result, [])
    local boostersArray = []
    foreach(block in activeBoosters)
    {
      local item = ::ItemsManager.findItemById(block.itemId)
      if (item)
        boostersArray.append(item)
    }
    return ::ItemsManager.getBoostersEffects(boostersArray)
  }

  function getMainFocusObj()
  {
    return getObj("tabs_list")
  }

  function getMainFocusObj2()
  {
    return getObj("my_stats_scroll_block")
  }

  isInited = true
  state = 0
  skipAnim = false
  isMp = false
  isReplay = false
  //haveCountryExp = true

  tabsList = ["my_stats", "ww_casualties", "players_stats", "battle_log", "chat_history"]
  curTab = ""
  nextWndDelay = 1.0

  needPlayersTbl = false
  playersTbl = null
  curPlayersTbl = null
  playersRowTime = 0.05
  playersTblDone = false
  myPlaceTime = 0.7
  minPlayersTime = 0.7

  playerStatsObj = null
  isCountSoundPlay = false
  needPlayCount = false
  statsTimer = 0.0
  statsTime = 0.3
  statsNextTime = 0.15
  totalStatsTime = 0.6
  statsBonusTime = 0.3
  statsBonusDelay = 0.2
  curStatsIdx = -1

  totalObj = null
  totalTimer = 0.0
  totalRow = null
  totalCurValues = null
  totalTarValues = null

  lastProgressRank = null
  progressData = [{ type = "prem",  id = "expProgress"}
                  { type = "bonus", id = "expProgressBonus"}
                  //{ type = "base",  id = "expProgressBonus"}
                  { type = "init",  id = "expProgressOld"}
                 ]

  awardsList = null
  curAwardIdx = 0

  streakAwardsList = null
  unlockAwardsList = null
  currentAwardsList = null
  currentAwardsListConfig = null
  currentAwardsListIdx = 0

  awardOffset = 0
  awardsAppearTime = 2.0 //can be lower than this, not higher
  awardDelay = 0.25
  awardFlyTime = 0.5

  usedUnitTypes = null

  isInProgress = false
}
