class ::gui_handlers.TopMenuButtonsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/mainmenu/topmenu_menuPanel"

  parentHandlerWeak = null
  sectionsStructure = null

  GCDropdownsList = null
  focusArray = null
  isPrimaryFocus = false

  maxSectionsCount = 0
  sectionsOrder = null

  ON_ESC_SECTION_OPEN = "menu"

  static function create(nestObj, parentHandler, sectionsStructure)
  {
    if (!::check_obj(nestObj))
      return null

    return ::handlersManager.loadHandler(::gui_handlers.TopMenuButtonsHandler, {
                                           scene = nestObj
                                           parentHandlerWeak = parentHandler,
                                           sectionsStructure = sectionsStructure
                                        })
  }

  function getSceneTplView()
  {
    GCDropdownsList = []
    focusArray = ["top_menu_panel_place"]
    return {
      section = getSectionsView()
    }
  }

  function initScreen()
  {
    if (parentHandlerWeak)
      parentHandlerWeak = parentHandlerWeak.weakref()

    scene.show(true)
    updateButtonsStatus()
    initFocusArray()
  }

  function getFocusObj()
  {
    if (curGCDropdown)
      return findObjInFocusArray(false)

    return scene.findObject("top_menu_panel_place")
  }

  function getMaxSectionsCount()
  {
    if (!::check_obj(scene))
      return 1

    if (!::has_feature("SeparateTopMenuButtons"))
      return 1

    local freeWidth = scene.getSize()[0]
    local singleButtonMinWidth = guiScene.calcString("1@topMenuButtonWidth", null)
    return freeWidth / singleButtonMinWidth || 1
  }

  function initSectionsOrder()
  {
    if (sectionsOrder)
      return

    maxSectionsCount = getMaxSectionsCount()
    sectionsOrder = ::g_top_menu_sections.getSectionsOrder(sectionsStructure, maxSectionsCount)
  }

  function getSectionsView()
  {
    if (!::check_obj(scene))
      return {}

    initSectionsOrder()

    local sectionsView = []
    foreach (topMenuButtonIndex, sectionData in sectionsOrder)
    {
      local columnsCount = sectionData.buttons.len()
      local columns = []

      foreach (idx, column in sectionData.buttons)
      {
        columns.append({
          buttons = column
          addNewLine = idx != (columnsCount - 1)
          columnIndex = (idx+1)
        })
      }

      local tmId = getTopMenuButtonDiv(sectionData)
      ::append_once(tmId, GCDropdownsList)

      sectionsView.append({
        tmId = tmId
        tmText = sectionData.getText(maxSectionsCount)
        tmImage = sectionData.getImage(maxSectionsCount)
        tmOnClick = sectionData.onClick
        columnsCount = columnsCount
        columns = columns
        btnName = sectionData.btnName
      })
    }
    return sectionsView
  }

  function getTopMenuButtonDiv(section)
  {
    return "topmenu_" + section.name
  }

  function updateButtonsStatus()
  {
    local needHideVisDisabled = ::has_feature("HideDisabledTopMenuActions")
    local isInQueue = ::checkIsInQueue()

    foreach (idx, section in sectionsOrder)
    {
      local sectionId = getTopMenuButtonDiv(section)
      local sectionObj = scene.findObject(sectionId)
      if (!::check_obj(sectionObj))
        continue

      local isVisibleAnyButton = false
      foreach (column in section.buttons)
      {
        foreach (button in column)
        {
          local btnObj = sectionObj.findObject(button.id)
          if (!::checkObj(btnObj))
            continue

          local isVisualDisable = button.isVisualDisabled()
          local show = !button.isHidden()
          if (show && isVisualDisable)
            show = !needHideVisDisabled

          btnObj.show(show)
          btnObj.enable(show)
          isVisibleAnyButton = isVisibleAnyButton || show

          if (!show)
            continue

          isVisualDisable = isVisualDisable || button.isInactiveInQueue && isInQueue
          btnObj.inactiveColor = isVisualDisable? "yes" : "no"
        }
      }

      sectionObj.show(isVisibleAnyButton)
      sectionObj.enable(isVisibleAnyButton)
    }
  }

  function hideHoverMenu(name)
  {
    local obj = getObj(name)
    if (!::check_obj(obj))
      return

    obj["_size-timer"] = "0"
    obj.setFloatProp(::dagui_propid.add_name_id("_size-timer"), 0.0)
    obj.height = "0"
  }

  function onBuilder(obj)
  {
    ::gui_start_builder_screen2(this)
  }

  function onSingleMission(obj)
  {
    ::checkAndCreateGamemodeWnd(this, ::GM_SINGLE_MISSION)
  }

  function onUserMission(obj)
  {
    ::checkAndCreateGamemodeWnd(this, ::GM_USER_MISSION)
  }

  function onDynamic(obj)
  {
    ::checkAndCreateGamemodeWnd(this, ::GM_DYNAMIC)
  }

  function onControlsHelp(obj)    { ::gui_modal_help(false, HELP_CONTENT_SET.CONTROLS) }
  function onLeaderboards(obj)    { goForwardIfOnline(::gui_modal_leaderboards, false, true) }
  function onClans(obj)
  {
    if (::has_feature("Clans"))
      ::gui_modal_clans()
    else
      notAvailableYetMsgBox()
  }

  function onSkirmish(obj)
  {
    if (!::is_custom_battles_enabled())
      return notAvailableYetMsgBox()
    if (!::check_gamemode_pkg(::GM_SKIRMISH))
      return

    checkedNewFlight(function() {
      goForwardIfOnline(::gui_start_skirmish, false)
    })
  }

  function onMissions(obj)
  {
    checkedNewFlight(function() {
      goForwardIfOnline(::gui_start_missions, false)
    })
  }

  function onGameplay(obj)     { ::gui_start_gameplay(this) }
  function onControls(obj)     { ::gui_start_controls() }

  function onBenchmark(obj)
  {
    checkedNewFlight(function() {::gui_start_benchmark()})
  }

  function onReplays(obj)
  {
    if (::is_platform_ps4)
      notAvailableYetMsgBox()
    else
      checkedNewFlight(function() {::gui_start_replays()})
  }

  function onTutorial(obj)
  {
    checkedNewFlight(function() {::gui_start_tutorial()})
  }

  function onCampaign(obj)
  {
    if(!::ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN))
      return msgBox("question_wait_download", ::loc("mainmenu/campaignDownloading"),
                    [["ok", function() {} ]],
                    "ok", { cancel_fn = function() {}})

    if (::is_any_campaign_available())
      return checkedNewFlight(function() { ::gui_start_campaign() })


    if (!::has_feature("OnlineShopPacks"))
      return notAvailableYetMsgBox()

    msgBox("question_buy_campaign", ::loc("mainmenu/questionBuyHistorical"),
      [
        ["yes", function() {
          if (::is_platform_ps4)
            ::gui_modal_onlineShop(this)
          else
            ::OnlineShopModel.doBrowserPurchase("wop_starter_pack_3_gift")
        }],
        ["no", function() {}]
      ], "yes", { cancel_fn = function() {}})
  }

  function onCredits(obj)
  {
    checkedForward(function() {
      unstickLastDropDown()
      if (::top_menu_shop_active)
        ::top_menu_handler.shopWndSwitch()
      goForward(::gui_start_credits, false)
    })
  }

  function onWorldwar(obj)
  {
    if (::is_worldwar_enabled())
      goForwardIfOnline(function() { ::g_world_war.openOperationsOrQueues() }, false)
    else
      notAvailableYetMsgBox()
  }

  function onTournamentsAndEvents(obj)
  {
    if (::has_feature("Events"))
      ::gui_start_modal_events(null)
  }

  function onTournamentLb(obj)
  {
    notAvailableYetMsgBox()
  }

  function onDebugUnlock(obj)
  {
    ::gui_do_debug_unlock();
    msgBox("debug unlock", "Debug unlock enabled", [["ok", function() {}]], "ok")
  }

  function onExit(obj)
  {
    if (::current_base_gui_handler && ("onExit" in ::current_base_gui_handler))
      ::current_base_gui_handler.onExit.call(::current_base_gui_handler)
    else
      msgBox("question_quit_game", ::loc("mainmenu/questionQuitGame"),
        [
          ["yes", ::exit_game],
          ["no", function() { }]
        ], "no", { cancel_fn = function() {}})
  }

  function onGetLink(obj)
  {
    ::show_viral_acquisition_wnd(this)
  }

  function onLink(obj)
  {
    ::g_url.openByObj(obj, true)
  }

  function switchDropDownMenu()
  {
    local section = sectionsStructure.getSectionByName(ON_ESC_SECTION_OPEN)
    if (::u.isEmpty(section))
      return

    local buttonObj = scene.findObject(getTopMenuButtonDiv(section))
    if (::checkObj(buttonObj))
      this[section.onClick](buttonObj)
  }

  function topmenuMenuActivate(obj)
  {
    local selObj = obj.getChild(obj.getValue())
    if (!::checkObj(selObj))
      return
    local eventName = selObj._on_click || selObj.on_click
    if (!eventName || !(eventName in this))
      return

    this[eventName](selObj)
  }

  function onWrapLeft(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.onTopGCPanelLeft(obj)
  }

  function onWrapRight(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.onTopGCPanelRight(obj)
  }

  function onEventGameModesAvailability(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventQueueChangeState(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventActiveHandlersChanged(p)
  {
    if (!isSceneActiveNoModals())
      unstickLastDropDown()
  }
}
