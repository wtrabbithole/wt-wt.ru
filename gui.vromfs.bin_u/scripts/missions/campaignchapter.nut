local progressMsg = require("sqDagui/framework/progressMsg.nut")
local { missionsListCampaignId } = require("scripts/missions/getMissionsListCampaignId.nut")

::current_campaign <- null
::current_campaign_name <- ""
::g_script_reloader.registerPersistentData("current_campaign_globals", ::getroottable(), ["current_campaign", "current_campaign_name"])
const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"

class ::gui_handlers.CampaignChapter extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.BASE
  applyAtClose = false

  missions = []
  return_func = null
  curMission = null
  curMissionIdx = -1
  missionDescWeak = null

  misListType = ::g_mislist_type.BASE
  canSwitchMisListType = false

  isOnlyFavorites = false

  gm = ::GM_SINGLE_MISSION
  missionName = null
  missionBlk = null
  isRestart = false

  canCollapseCampaigns = false
  canCollapseChapters = false

  showAllCampaigns = false

  collapsedCamp = []

  filterDataArray = []
  filterText = ""

  needCheckDiffAfterOptions = false

  function initScreen()
  {
    showWaitAnimation(true)

    gm = ::get_game_mode()
    loadCollapsedChapters()
    initCollapsingOptions()

    initMisListTypeSwitcher()
    updateFavorites()
    updateWindow()
    initDescHandler()
  }

  function initDescHandler()
  {
    local descHandler = ::gui_handlers.MissionDescription.create(getObj("mission_desc"), curMission)
    registerSubHandler(descHandler)
    missionDescWeak = descHandler.weakref()
  }

  function initCollapsingOptions()
  {
    canCollapseCampaigns = gm != ::GM_SKIRMISH
    canCollapseChapters = gm == ::GM_SKIRMISH
  }

  function loadCollapsedChapters()
  {
    local collapsedList = ::load_local_account_settings(getCollapseListSaveId(), "")
    collapsedCamp = ::g_string.split(collapsedList, ";")
  }

  function saveCollapsedChapters()
  {
    ::save_local_account_settings(getCollapseListSaveId(), ::g_string.implode(collapsedCamp, ";"))
  }

  function getCollapseListSaveId()
  {
    return "mislist_collapsed_chapters/" + ::get_game_mode_name(gm)
  }

  function updateWindow()
  {
    local title = ""
    if (gm == ::GM_CAMPAIGN)
      title = ::loc("mainmenu/btnCampaign")
    else if (gm == ::GM_SINGLE_MISSION)
      title = (canSwitchMisListType || misListType != ::g_mislist_type.UGM)
              ? ::loc("mainmenu/btnSingleMission")
              : ::loc("mainmenu/btnUserMission")
    else if (gm == ::GM_SKIRMISH)
      title = ::loc("mainmenu/btnSkirmish")
    else
      title = ::loc("chapters/" + ::current_campaign_id)

    initMissionsList(title)
  }

  function initMissionsList(title)
  {
    local customChapterId = (gm == ::GM_DYNAMIC) ? ::current_campaign_id : missionsListCampaignId.value
    local customChapters = null
    if (!showAllCampaigns && (gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION))
      customChapters = ::current_campaign

    if (gm == ::GM_DYNAMIC)
    {
      local info = DataBlock()
      dynamic_get_visual(info)
      local l_file = info.getStr("layout","")
      local dynLayouts = ::get_dynamic_layouts()
      for (local i = 0; i < dynLayouts.len(); i++)
        if (dynLayouts[i].mis_file == l_file)
        {
          title = ::loc("dynamic/" + dynLayouts[i].name)
          break
        }
    }

    local obj = getObj("chapter_name")
    if (obj != null)
      obj.setValue(title)

    misListType.requestMissionsList(showAllCampaigns,
      ::Callback(updateMissionsList, this),
      customChapterId, customChapters)
  }

  function updateMissionsList(new_missions)
  {
    showWaitAnimation(false)

    missions = new_missions
    if (missions.len() <= 0 && !canSwitchMisListType && !misListType.canBeEmpty)
    {
      msgBox("no_missions", ::loc("missions/no_missions_msgbox"), [["ok"]], "ok")
      goBack()
      return
    }

    fillMissionsList()
  }

  function fillMissionsList()
  {
    local listObj = getObj("items_list")
    if (!listObj)
      return

    local selMisConfig = curMission || misListType.getCurMission()

    local view = { items = [] }
    local selIdx = -1
    local foundCurrent = false
    local hasVideoToPlay = false

    foreach(idx, mission in missions)
    {
      if (mission.isHeader)
      {
        view.items.append({
          itemTag = mission.isCampaign? "campaign_item" : "chapter_item_unlocked"
          id = mission.id
          itemText = misListType.getMissionNameText(mission)
          isCollapsable = (mission.isCampaign && canCollapseCampaigns) || canCollapseChapters
        })
        continue
      }

      if (selIdx == -1)
        selIdx = idx

      if (!foundCurrent)
      {
        local isCurrent = false
        if (gm ==::GM_TRAINING
            || (gm == ::GM_CAMPAIGN && !selMisConfig))
          isCurrent = ::getTblValue("progress", mission, -1) == MIS_PROGRESS.UNLOCKED
        else
          isCurrent = selMisConfig == null || selMisConfig.id == mission.id

        if (isCurrent)
        {
          selIdx = idx
          foundCurrent = isCurrent
          if (gm == ::GM_CAMPAIGN && ::getTblValue("progress", mission, -1) == MIS_PROGRESS.UNLOCKED)
            hasVideoToPlay = true
        }
      }

      if (::g_mislist_type.isUrlMission(mission))
      {
        local medalIcon = misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite" : ""
        view.items.append({
          itemIcon = medalIcon
          id = mission.id
          itemText = misListType.getMissionNameText(mission)
        })
        continue
      }

      local elemCssId = "mission_item_locked"
      local medalIcon = "#ui/gameuiskin#locked"
      if (gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION || gm == ::GM_TRAINING)
        switch (mission.progress)
        {
          case 0:
            elemCssId = "mission_item_completed"
            medalIcon = "#ui/gameuiskin#mission_complete_arcade"
            break
          case 1:
            elemCssId = "mission_item_completed"
            medalIcon = "#ui/gameuiskin#mission_complete_realistic"
            break
          case 2:
            elemCssId = "mission_item_completed"
            medalIcon = "#ui/gameuiskin#mission_complete_simulator"
            break
          case 3:
            elemCssId = "mission_item_unlocked"
            medalIcon = ""
            break
        }
      else if (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH)
      {
        elemCssId = "mission_item_unlocked"
        medalIcon = misListType.isMissionFavorite(mission) ? "#ui/gameuiskin#favorite" : ""
      }
      else if (mission.isUnlocked)
      {
        elemCssId = "mission_item_unlocked"
        medalIcon = ""
      }

      view.items.append({
        itemTag = elemCssId
        itemIcon = medalIcon
        id = mission.id
        itemText = misListType.getMissionNameText(mission)
      })
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    if (selIdx >= 0 && selIdx < listObj.childrenCount())
    {
      local mission = missions[selIdx]
      if (hasVideoToPlay && gm == ::GM_CAMPAIGN)
        playChapterVideo(mission.chapter, true)

      listObj.setValue(selIdx)
    }
    else if (selIdx < 0)
      onItemSelect(listObj)

    local filterObj = scene.findObject("filter_edit_box")
    if (::checkObj(filterObj))
      filterObj.select()
    else
      listObj.select()

    createFilterDataArray()
    applyMissionFilter()
    updateCollapsedItems()
  }

  function createFilterDataArray()
  {
    local listObj = getObj("items_list")

    filterDataArray = []
    foreach(idx, mission in missions)
    {
      local locText = misListType.getMissionNameText(mission)
      local locString = ::g_string.utf8ToLower(locText)
      filterDataArray.append({
        locString = ::stringReplace(locString, "\t", "") //for japan and china localizations
        misObject = listObj.getChild(idx)
        mission = mission
        isHeader = mission.isHeader
        isCampaign = mission.isHeader && mission.isCampaign
        filterCheck = true
      })
    }
  }

  function playChapterVideo(chapterName, checkSeen = false)
  {
    local videoName = "video/" + chapterName
    if (checkSeen && ::was_video_seen(videoName))
      return

    if (!::check_package_and_ask_download("hc_pacific"))
      return

    guiScene.performDelayed(this, (@(videoName) function(obj) {
      if (!::is_system_ui_active())
      {
        ::play_movie(videoName, false, true, true)
        ::add_video_seen(videoName)
      }
    })(videoName))
  }

  function getSelectedMissionIndex(needCheckFocused = true)
  {
    local list = getObj("items_list")
    if (list != null && (!needCheckFocused || list.isFocused()))
    {
      local index = list.getValue()
      if (index >=0 && index < list.childrenCount())
        return index
    }
    return -1
  }

  function getSelectedMission(needCheckFocused = true)
  {
    curMissionIdx = getSelectedMissionIndex(::show_console_buttons && needCheckFocused)
    curMission = ::getTblValue(curMissionIdx, missions, null)
    return curMission
  }

  function onItemSelect(obj)
  {
    getSelectedMission(false)
    if (missionDescWeak)
    {
      local previewBlk = null
      if (gm == ::GM_DYNAMIC)
        previewBlk = ::getTblValue(curMissionIdx, ::mission_settings.dynlist)
      missionDescWeak.setMission(curMission, previewBlk)
    }
    updateButtons()

    if (::checkObj(obj))
    {
      local value = obj.getValue()
      if (value > 0 && value < obj.childrenCount())
        obj.getChild(value).scrollToView()
    }
  }

  function onEventSquadDataUpdated(params)
  {
    doWhenActiveOnce("updateWindow")
  }

  function onEventSquadStatusUpdated(params)
  {
    doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionChanged(params)
  {
    doWhenActiveOnce("updateWindow")
  }

  function onEventUrlMissionAdded(params)
  {
    doWhenActiveOnce("updateWindow")
  }

  function getFavoritesSaveId()
  {
    return "wnd/isOnlyFavoriteMissions/" + misListType.id
  }

  function updateFavorites()
  {
    if (!misListType.canMarkFavorites())
    {
      isOnlyFavorites = false
      return
    }

    isOnlyFavorites = ::loadLocalByAccount(getFavoritesSaveId(), false)
    local checkObj = showSceneBtn("favorite_missions_switch", true)
    if (checkObj)
      checkObj.setValue(isOnlyFavorites)
  }

  function onOnlyFavoritesSwitch(obj)
  {
    local value = obj.getValue()
    if (value == isOnlyFavorites)
      return

    isOnlyFavorites = value
    ::saveLocalByAccount(getFavoritesSaveId(), isOnlyFavorites)
    applyMissionFilter()
    updateCollapsedItems()
  }

  function onFav()
  {
    if (!curMission || curMission.isHeader)
      return

    misListType.toggleFavorite(curMission)
    updateButtons()

    local listObj = getObj("items_list")
    if (curMissionIdx < 0 || curMissionIdx >= listObj.childrenCount())
      return

    local medalObj = listObj.getChild(curMissionIdx).findObject("medal_icon")
    if (medalObj)
      medalObj["background-image"] = misListType.isMissionFavorite(curMission) ? "#ui/gameuiskin#favorite" : ""
  }

  function goBack()
  {
    if( ! filterText.len())
      saveCollapsedChapters()
    local gt = ::get_game_type()
    if ((gm == ::GM_DYNAMIC) && (gt & ::GT_COOPERATIVE) && ::SessionLobby.isInRoom())
    {
      ::first_generation <- false
      goForward(::gui_start_dynamic_summary)
      return
    }
    else if (::SessionLobby.isInRoom())
    {
      if (wndType != handlerType.MODAL)
      {
        goForward(::gui_start_mp_lobby)
        return
      }
    }
    base.goBack()
  }

  function checkStartBlkMission(showMsgbox = false)
  {
    if (!("blk" in curMission))
      return true

    if (!curMission.isUnlocked && ("mustHaveUnit" in curMission))
    {
      if (showMsgbox)
      {
        local unitNameLoc = ::colorize("activeTextColor", ::getUnitName(curMission.mustHaveUnit))
        local requirements = ::loc("conditions/char_unit_exist/single", { value = unitNameLoc })
        ::showInfoMsgBox(::loc("charServer/needUnlock") + "\n\n" + requirements)
      }
      return false
    }
    if ((gm == ::GM_SINGLE_MISSION) && (curMission.progress >= 4))
    {
      if (showMsgbox)
      {
        local unlockId = curMission.blk.chapter + "/" + curMission.blk.name
        local msg = ::loc("charServer/needUnlock") + "\n\n" + ::get_unlock_description(unlockId, 1)
        ::showInfoMsgBox(msg, "in_demo_only_singlemission_unlock")
      }
      return false
    }
    if ((gm == ::GM_CAMPAIGN) && (curMission.progress >= 4))
    {
      if (showMsgbox)
        ::showInfoMsgBox(::loc("campaign/unlockPrevious"))
      return false
    }
    if ((gm != ::GM_CAMPAIGN) && !curMission.isUnlocked)
    {
      if (showMsgbox)
      {
        local msg = ::loc("ui/unavailable")
        if ("mustHaveUnit" in curMission)
          msg = ::format("%s\n%s", ::loc("unlocks/need_to_unlock"), ::getUnitName(curMission.mustHaveUnit))
        ::showInfoMsgBox(msg)
      }
      return false
    }
    return true
  }

  function onStart()
  {
    if (!curMission)
      return

    if (curMission.isHeader)
    {
      if ((curMission.isCampaign && canCollapseCampaigns) || canCollapseChapters)
        if (filterText.len() == 0)
          return collapse(curMission.id)
        else
          return

      if (gm != ::GM_CAMPAIGN)
        return

      if (curMission.isUnlocked)
        playChapterVideo(curMission.id)
      else
        showInfoMsgBox( ::loc("campaign/unlockPreviousChapter"))
      return
    }

    if (!::g_squad_utils.canJoinFlightMsgBox({
           isLeaderCanJoin = ::can_play_gamemode_by_squad(gm),
           showOfflineSquadMembersPopup = true
           maxSquadSize = ::get_max_players_for_gamemode(gm)
         }))
      return

    if( ! filterText.len())
      saveCollapsedChapters()

    if (::getTblValue("blk", curMission) == null && ::g_mislist_type.isUrlMission(curMission))
    {
      local misBlk = curMission.urlMission.getMetaInfo()
      if (misBlk)
        curMission.blk <- misBlk
      else
      {
        ::g_url_missions.loadBlk(curMission, ::Callback(onUrlMissionLoaded, this))
        return
      }
    }

    if (!checkStartBlkMission(true))
      return

    setMission()
  }

  function setMission()
  {
    ::mission_settings.postfix = null
    ::current_campaign_id = curMission.chapter
    ::current_campaign_mission = curMission.id
    if (gm == ::GM_DYNAMIC)
      ::mission_settings.currentMissionIdx <- curMissionIdx

    openMissionOptions(curMission)
    if (gm == ::GM_TRAINING && ("blk" in curMission))
      save_tutorial_to_check_reward(curMission.blk)
  }

  function onUrlMissionLoaded(success, mission)
  {
    if (!success || !checkStartBlkMission(true))
      return

    curMission = mission
    curMission.blk <- curMission.urlMission.getMetaInfo()
    setMission()
  }

  function onListItemsFocusChange(obj)
  {
    guiScene.performDelayed(this, function() {
      if (!isValid())
        return

      getSelectedMission()
      updateButtons()
    })
  }

  function updateButtons()
  {
    local isHeader = curMission?.isHeader ?? false

    local isShowFavoritesBtn = misListType.canMarkFavorites() && curMission != null && !isHeader
    showSceneBtn("btn_favorite", isShowFavoritesBtn)
    if (isShowFavoritesBtn)
    {
      local favObj = getObj("btn_favorite")
      if (favObj)
        favObj.setValue(misListType.isMissionFavorite(curMission) ?
                        ::loc("mainmenu/btnFavoriteUnmark") : ::loc("mainmenu/btnFavorite"))
    }

    local startText = ""
    if (!isHeader)
      startText = ::loc("multiplayer/btnStart")
    else if (filterText.len() == 0 && ((curMission?.isCampaign && canCollapseCampaigns) || (isHeader && canCollapseChapters)))
      startText = ::loc(::isInArray(curMission.id, collapsedCamp) ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
    else if (gm == ::GM_CAMPAIGN)
      startText = ::loc("mainmenu/btnWatchMovie")

    local showStartBtn = curMission && startText != ""
    local objButton = showSceneBtn("btn_select", showStartBtn)
    if (::checkObj(objButton) && showStartBtn)
    {
      local enabled = isHeader || (curMission && checkStartBlkMission())
      objButton.inactiveColor = enabled ? "no" : "yes"
      setDoubleTextToButton(scene, "btn_select", startText)
    }

    local isNeedSquadBtn = ::is_gamemode_coop(gm) && ::can_play_gamemode_by_squad(gm) && ::g_squad_manager.canInviteMember()
    if (gm == ::GM_SINGLE_MISSION)
      isNeedSquadBtn = isNeedSquadBtn && !isHeader && curMission!=null
                       && (!("blk" in curMission)
                          || (curMission.blk.getBool("gt_cooperative", false) && !::is_user_mission(curMission.blk)))
    showSceneBtn("btn_inviteSquad", curMission!= null && isNeedSquadBtn)

    showSceneBtn("btn_refresh", misListType.canRefreshList)
    showSceneBtn("btn_refresh_console", misListType.canRefreshList && ::show_console_buttons)
    showSceneBtn("btn_add_mission", misListType.canAddToList)
    showSceneBtn("btn_modify_mission", curMission != null && misListType.canModify(curMission))
    showSceneBtn("btn_delete_mission", curMission != null && misListType.canDelete(curMission))

    local linkData = misListType.getInfoLinkData()
    local linkObj = showSceneBtn("btn_user_missions_info_link", linkData != null)
    if (linkObj && linkData)
    {
      linkObj.link = linkData.link
      linkObj.tooltip = linkData.tooltip
      linkObj.setValue(linkData.text)
    }

    if (gm == ::GM_CAMPAIGN)
      showSceneBtn("btn_purchase_campaigns", ::has_feature("OnlineShopPacks") && ::get_not_purchased_campaigns().len() > 0)
  }

  function getEmptyListMsg()
  {
    return ::g_squad_manager.isNotAloneOnline() ? ::loc("missions/noCoopMissions") : ::loc("missions/emptyList")
  }

  function updateCollapsedItems(selCamp=null)
  {
    local listObj = getObj("items_list")
    if (!listObj) return

    guiScene.setUpdatesEnabled(false, false)
    local collapsed = false
    local wasIdx = listObj.getValue()
    local selIdx = -1
    local hasAnyVisibleMissions = false
    local isFilteredMissions = filterText.len() > 0
    foreach(idx, m in missions)
    {
      local isVisible = true
      if ((m.isHeader && canCollapseChapters) || (m.isCampaign && canCollapseCampaigns))
      {
        collapsed = !isFilteredMissions && ::isInArray(m.id, collapsedCamp)

        local obj = listObj.getChild(idx)
        if (obj)
        {
          obj.collapsed = collapsed? "yes" : "no"
          local collapseBtnObj = obj.findObject("btn_" + obj.id)
          if (::check_obj(collapseBtnObj))
            collapseBtnObj.show(!isFilteredMissions)
        }

        if (selCamp && selCamp==m.id)
          selIdx = idx
      }
      else
        isVisible = !collapsed

      local obj = listObj.getChild(idx)
      if (!obj)
        continue

      local filterData = filterDataArray[idx]
      isVisible = isVisible && filterData.filterCheck
      if (isVisible && (selIdx < 0 || wasIdx == idx))
        selIdx = idx

      obj.enable(isVisible)
      obj.show(isVisible)
      hasAnyVisibleMissions = hasAnyVisibleMissions || isVisible
    }

    guiScene.setUpdatesEnabled(true, true)
    if (selIdx>=0)
    {
      if (selIdx != wasIdx)
      {
        listObj.setValue(selIdx)
        onItemSelect(listObj)
      } else
        listObj.getChild(selIdx).scrollToView()
    }

    local listText = hasAnyVisibleMissions ? "" : getEmptyListMsg()
    scene.findObject("items_list_msg").setValue(listText)
  }

  function collapse(campId, forceOpen = false, shouldUpdate = true)
  {
    local hide = !forceOpen
    foreach(idx, camp in collapsedCamp)
      if (camp == campId)
      {
        collapsedCamp.remove(idx)
        hide = false
        break
      }
    if (hide)
      collapsedCamp.append(campId)

    if (!shouldUpdate)
      return

    updateCollapsedItems(campId)
    updateButtons()
  }

  function onCollapse(obj)
  {
    if (!obj) return
    local id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_")
      collapse(id.slice(4))
  }

  function openMissionOptions(mission)
  {
    local campaignName = ::current_campaign_id

    missionName = ::current_campaign_mission

    if (campaignName == null || missionName == null)
      return

    missionBlk = ::DataBlock()
    missionBlk.setFrom(mission.blk)

    local isUrlMission = ::g_mislist_type.isUrlMission(mission)
    if (isUrlMission)
      missionBlk.url = mission.urlMission.url

    local coopAvailable = ::is_gamemode_coop(gm) && ::can_play_gamemode_by_squad(gm) && !::is_user_mission(missionBlk)
    ::mission_settings.coop = missionBlk.getBool("gt_cooperative", false) && coopAvailable

    missionBlk.setInt("_gameMode", gm)

    if ((::SessionLobby.isCoop() && ::SessionLobby.isInRoom()) || ::is_gamemode_coop(gm))
    {
      ::mission_settings.players = 4;
      missionBlk.setInt("_players", 4)
      missionBlk.setInt("maxPlayers", 4)
      missionBlk.setBool("gt_use_lb", false)
      missionBlk.setBool("gt_use_replay", true)
      missionBlk.setBool("gt_use_stats", true)
      missionBlk.setBool("gt_sp_restart", false)
      missionBlk.setBool("isBotsAllowed", true)
      missionBlk.setBool("autoBalance", false)
    }

    if (isUrlMission)
      ::select_mission_full(missionBlk, mission.urlMission.fullMissionBlk)
    else
      ::select_mission(missionBlk, gm != ::GM_DOMINATION && gm != ::GM_SKIRMISH)

    local gt = ::get_game_type()
    local optionItems = ::get_briefing_options(gm, gt, missionBlk)
    local diffOption = ::u.search(optionItems, function(item) { return ::getTblValue(0, item) == ::USEROPT_DIFFICULTY })
    needCheckDiffAfterOptions = diffOption != null

    local cb = ::Callback(afterMissionOptionsApply, this)
    createModalOptions(optionItems, (@(cb, missionBlk) function() {
      ::gui_handlers.Briefing.finalApply.call(this, missionBlk) //!!FIX ME: DIRTY HACK - called brifing function in modalOptions enviroment
      cb()
    })(cb, missionBlk))
  }

  function afterMissionOptionsApply()
  {
    local diffCode = ::mission_settings.diff
    if (!::check_diff_pkg(diffCode))
      return

    checkedNewFlight(function() {
      if (needCheckDiffAfterOptions && ::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
        ::gui_start_cd_options(::briefing_options_apply, this)
      else
        ::briefing_options_apply.call(this) //!!FIX ME: DIRTY HACK
    })
  }

  function createModalOptions(optionItems, applyFunc)
  {
    local params = getModalOptionsParam(optionItems, applyFunc)
    local handler = ::handlersManager.loadHandler(::gui_handlers.GenericOptionsModal, params)

    if (!optionItems.len())
      handler.applyOptions()
  }

  function getModalOptionsParam(optionItems, applyFunc)
  {
    return {
      options = optionItems
      optionsConfig = { missionName = curMission && curMission.id }
      applyAtClose = false
      wndOptionsMode = ::get_options_mode(gm)
      owner = this
      applyFunc = applyFunc
    }
  }

  function showNav(show)
  {
    local obj = getObj("nav-help")
    if (obj)
    {
      obj.show(show)
      obj.enable(show)
    }
  }

  function onRefresh(obj)
  {
    if (misListType.canRefreshList)
      updateWindow()
  }

  function initMisListTypeSwitcher()
  {
    if (!canSwitchMisListType)
      return
    local tabsObj = scene.findObject("chapter_top_list")
    if (!::checkObj(tabsObj))
    {
      canSwitchMisListType = false
      return
    }

    local curMisListType = ::g_mislist_type.BASE
    if (::SessionLobby.isInRoom())
      curMisListType = ::SessionLobby.getMisListType()
    else
    {
      local typeName = ::loadLocalByAccount("wnd/chosenMisListType", "")
      curMisListType = ::g_mislist_type.getTypeByName(typeName)
    }

    local typesList = []
    local selIdx = 0
    foreach(mlType in ::g_mislist_type.types)
      if (mlType.canCreate(gm))
      {
        typesList.append(mlType)
        if (mlType == curMisListType)
          selIdx = typesList.len() - 1
      }

    if (typesList.len())
       misListType = typesList[selIdx]

    if (typesList.len() < 2)
    {
      canSwitchMisListType = false
      return
    }

    tabsObj.show(true)
    tabsObj.enable(true)
    fillHeaderTabs(tabsObj, typesList, selIdx)
    scene.findObject("chapter_name").show(false)
  }

  function fillHeaderTabs(tabsObj, typesList, selIdx)
  {
    local view = {
      tabs = []
    }
    foreach(idx, mlType in typesList)
      view.tabs.append({
        id = mlType.id
        tabName = mlType.getTabName()
        navImagesText = ::get_navigation_images_text(idx, typesList.len())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(selIdx)
  }

  function onChapterSelect(obj)
  {
    if (!canSwitchMisListType)
      return

    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    local typeName = obj.getChild(value).id
    misListType = ::g_mislist_type.getTypeByName(typeName)
    ::saveLocalByAccount("wnd/chosenMisListType", misListType.id)
    updateFavorites()
    updateWindow()
  }

  function onFilterEditBoxActivate()
  {
    onStart()
  }

  function onFilterEditBoxChangeValue()
  {
    applyMissionFilter()
    updateCollapsedItems()
    updateButtons()
  }

  function onFilterEditBoxCancel()
  {
    goBack()
  }

  function checkfilterData(filterData)
  {
    if (filterData.isHeader) //need update headers by missions content. see applyMissionsfilter
      return true

    local res = !filterText.len() || filterData.locString.indexof(filterText) != null
    if (res && isOnlyFavorites)
      res = misListType.isMissionFavorite(filterData.mission)
    return res
  }

  function applyMissionFilter()
  {
    local filterEditBox = scene.findObject("filter_edit_box")
    if (!::checkObj(filterEditBox))
      return

    filterText = ::g_string.utf8ToLower(filterEditBox.getValue())

    local showChapter = false
    local showCampaign = false
    for (local idx = filterDataArray.len() - 1; idx >= 0; --idx)
    {
      local filterData = filterDataArray[idx]
      local filterCheck = checkfilterData(filterData)
      if (!filterData.isHeader)
      {
        if (filterCheck)
        {
          showChapter = true
          showCampaign = true
        }
      }
      else if (filterData.isCampaign)
      {
        filterCheck = showCampaign
        showCampaign = false
      }
      else
      {
        filterCheck = showChapter
        showChapter = false
      }

      filterData.filterCheck = filterCheck
    }
  }

  function onAddMission()
  {
    if (misListType.canAddToList)
      misListType.addToList()
  }

  function onModifyMission()
  {
    if (curMission && misListType.canModify(curMission))
      misListType.modifyMission(curMission)
  }

  function onDeleteMission()
  {
    if (curMission && misListType.canDelete(curMission))
      misListType.deleteMission(curMission)
  }

  function onBuyCampaign()
  {
    ::purchase_any_campaign()
  }

  function onEventProfileUpdated(p)
  {
    if (p.transactionType == ::EATT_UPDATE_ENTITLEMENTS)
      updateWindow()
  }
}

class ::gui_handlers.SingleMissions extends ::gui_handlers.CampaignChapter
{
  sceneBlkName = "gui/chapter.blk"
  sceneNavBlkName = "gui/backSelectNavChapter.blk"
  shouldBlurSceneBg = true

  function initScreen()
  {
    scene.findObject("optionlist-container").mislist = "yes"
    base.initScreen()
  }
}

class ::gui_handlers.SingleMissionsModal extends ::gui_handlers.SingleMissions
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chapterModal.blk"
  sceneNavBlkName = "gui/backSelectNavChapter.blk"
  owner = null

  function initScreen()
  {
    local navObj = scene.findObject("nav-help")
    if(::checkObj(navObj))
    {
      local backBtn = navObj.findObject("btn_back")
      if (::checkObj(backBtn)) guiScene.destroyElement(backBtn)

      showSceneBtn("btn_inviteSquad", ::enable_coop_in_SingleMissions)
    }

    local frameObj = scene.findObject("header_buttons")
    if (frameObj)
      guiScene.replaceContent(frameObj, "gui/frameHeaderRefresh.blk", this)

    if (wndGameMode == ::GM_SKIRMISH || wndGameMode == ::GM_SINGLE_MISSION)
    {
      local listboxFilterHolder = scene.findObject("listbox_filter_holder")
      guiScene.replaceContent(listboxFilterHolder, "gui/chapter_include_filter.blk", this)
    }

    initFocusArray()

    base.initScreen()
  }

  function getMainFocusObj()
  {
    return scene.findObject("filter_edit_box")
  }

  function getMainFocusObj2()
  {
    return getObj("items_list")
  }

  function afterModalDestroy()
  {
    restoreMainOptions()
  }

  function showWaitAnimation(isVisible)
  {
    if (isVisible)
      progressMsg.create(SAVEDATA_PROGRESS_MSG_ID, {text = ::loc("wait/missionListLoading")})
    else
      progressMsg.destroy(SAVEDATA_PROGRESS_MSG_ID)
  }
}