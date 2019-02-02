local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")

::top_menu_handler <- null
::top_menu_shop_active <- false

::top_menu_borders <- [[0.01, 0.99], [0.05, 0.86]] //[x1,x2], [y1, y2] *rootSize - border for chat and contacts
if (::is_platform_ps4)
  ::top_menu_borders <- [[0.01, 0.99], [0.09, 0.86]]

::g_script_reloader.registerPersistentData("topMenuGlobals", ::getroottable(), ["top_menu_shop_active"])


class ::gui_handlers.TopMenu extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.ROOT
  keepLoaded = true
  sceneBlkName = "gui/mainmenu/topMenuScene.blk"

  gamercardTopIds = [ //OVERRIDE
    function() { return leftSectionHandlerWeak && leftSectionHandlerWeak.getFocusObj() }
    "gamercard_panel_left"
    "gamercard_panel_right"
    function() { return rightSectionHandlerWeak && rightSectionHandlerWeak.getFocusObj() }
  ]

  leftSectionHandlerWeak = null

  topMenu = true
  topMenuInited = false
  menuConfig = null /*::topMenu_config*/

  shopWeak = null

  checkAdvertTimer = 0.0
  checkPriceTimer = 0.0

  isWaitForContentToActivateScene = false
  isInQueue = false

  constructor(gui_scene, params = {})
  {
    base.constructor(gui_scene, params)
    ::top_menu_handler = this
  }

  function initScreen()
  {
    fillGamercard()
    reinitScreen()
  }

  function reinitScreen(params = null)
  {
    if (!topMenuInited && ::g_login.isLoggedIn())
    {
      topMenuInited = true

      leftSectionHandlerWeak = ::gui_handlers.TopMenuButtonsHandler.create(
        scene.findObject("topmenu_menu_panel"),
        this,
        ::g_top_menu_left_side_sections,
        scene.findObject("left_gc_panel_free_width")
      )
      registerSubHandler(leftSectionHandlerWeak)

      if (::last_chat_scene_show)
        switchChatWindow()
      if (::last_contacts_scene_show)
        onSwitchContacts()

      initTopMenuTimer()
      instantOpenShopWnd()
      createSlotbar(
        {
          hasResearchesBtn = true
          mainMenuSlotbar = true
          onCountryDblClick = function() {
            if (!::top_menu_shop_active)
              shopWndSwitch()
          }.bindenv(this)
        },
        "nav-topMenu"
      )
      currentFocusItem = ::top_menu_shop_active? 2 : 11 //shop : slotbar
      initFocusArray()
    }
    delayedRestoreFocus()
  }

  function initTopMenuTimer()
  {
    local obj = getObj("top_menu_scene_timer")
    if (::checkObj(obj))
      obj.setUserData(this)
  }

  function getBaseHandlersContainer() //only for wndType = handlerType.ROOT
  {
    return scene.findObject("topMenu_content")
  }

  function onNewContentLoaded(handler)
  {
    checkAdvert()

    local hasResearch = ::getTblValue("hasTopMenuResearch", handler, true)
    showSceneBtn("topmenu_btn_shop_wnd", hasResearch)
    if (!hasResearch)
      closeShop()

    if (!::getTblValue("hasGameModeSelect", handler, true))
      closeGameModeSelect()

    if (isWaitForContentToActivateScene)
    {
      isWaitForContentToActivateScene = false
      onSceneActivate(true)
    }
  }

  function closeGameModeSelect()
  {
    if (!::handlersManager.isHandlerValid(::instant_domination_handler))
      return

    local gmHandler = ::instant_domination_handler.getGameModeSelectHandler()
    if (!gmHandler)
      return

    if (gmHandler.getShowGameModeSelect())
      gmHandler.setShowGameModeSelect(false)
  }

  function onTopMenuUpdate(obj, dt)
  {
    checkAdvertTimer -= dt
    if (checkAdvertTimer<=0)
    {
      checkAdvertTimer = 120.0
      checkAdvert()
    }

    ::configs.PRICE.checkUpdate()
    ::configs.ENTITLEMENTS_PRICE.checkUpdate()
  }

  function checkAdvert()
  {
    if (!is_news_adver_actual())
    {
      local t = req_news()
      if (t >= 0)
        return ::add_bg_task_cb(t, updateAdvert, this)
    }
    updateAdvert()
  }

  function updateAdvert()
  {
    local obj = scene.findObject("topmenu_advert")
    if (!::check_obj(obj))
      return

    local blk = ::DataBlock()
    ::get_news_blk(blk)
    local text = ::loc(blk.advert || "", "")
    SecondsUpdater(obj, function(obj, params)
    {
      local stopUpdate = text.find("{time_countdown=") == null
      local textResult = time.processTimeStamps(text)
      local objText = obj.findObject("topmenu_advert_text")
      objText.setValue(textResult)
      obj.show(textResult != "")
      return stopUpdate
    })
  }

  function onQueue(inQueue)
  {
    isInQueue = inQueue

    local slotbar = getSlotbar()
    if (slotbar)
      slotbar.shade(inQueue)
    updateSceneShade()

    if (inQueue)
    {
      if (::top_menu_shop_active)
        shopWndSwitch()

      ::broadcastEvent("SetInQueue")
    }
  }

  function updateSceneShade()
  {
    local obj = getObj("topmenu_backshade_dark")
    if (::check_obj(obj))
      obj.animation = isInQueue ? "show" : "hide"

    obj = getObj("topmenu_backshade_light")
    if (::check_obj(obj))
      obj.animation = !isInQueue && ::top_menu_shop_active ? "show" : "hide"
  }

  function getCurrentEdiff()
  {
    return (::top_menu_shop_active && shopWeak) ? shopWeak.getCurrentEdiff() : ::get_current_ediff()
  }

  function focusShopTable()
  {
    if (!::top_menu_shop_active)
        return restoreFocus()
    local obj = getObj("shop_items_list")
    if (::checkObj(obj))
      obj.select()
    checkCurrentFocusItem(obj)
  }

  function canShowShop()
  {
    return !::top_menu_shop_active
  }

  function canShowDmViewer()
  {
    return !::top_menu_shop_active
  }

  function onShop(obj)
  {
    if (!::top_menu_shop_active)
      shopWndSwitch()
  }

  function closeShop()
  {
    if (::top_menu_shop_active)
      shopWndSwitch()
  }

  function setShopUnitType(unitType)
  {
    if (unitType && shopWeak)
      shopWeak.setUnitType(unitType)
  }

  function shopWndSwitch(unitType = null)
  {
    if (!isValid())
      return

    ::top_menu_shop_active = !::top_menu_shop_active
    local shopMove = getObj("shop_wnd_move")
    shopMove.moveOut = ::top_menu_shop_active ? "yes" : "no"
    local closeResearch = getObj("research_closeButton")
    local showButton = shopMove.moveOut == "yes"

    ::dmViewer.update()

    if(showButton)
      ::play_gui_sound("menu_appear")
    if(::checkObj(closeResearch))
      closeResearch.show(showButton)
    activateShopImpl(::top_menu_shop_active, unitType)
    if (shopWeak && shopWeak.getCurrentEdiff() != ::get_current_ediff())
      shopWeak.updateSlotbarDifficulty()
    focusShopTable()

    ::broadcastEvent("ShopWndSwitched")
  }

  function openShop(unitType = null)
  {
    setShopUnitType(unitType)
    if (!::top_menu_shop_active)
      shopWndSwitch(unitType) //to load shp with correct unit type to avoid several shop updates
  }

  function instantOpenShopWnd()
  {
    if (::top_menu_shop_active)
    {
      local shopMove = getObj("shop_wnd_move")
      if (!::checkObj(shopMove))
        return

      local closeResearch = getObj("research_closeButton")
      if(::checkObj(closeResearch))
        closeResearch.show(true)

      shopMove.moveOut = "yes"
      shopMove["_size-timer"] = "1"
      shopMove.setFloatProp(::dagui_propid.add_name_id("_size-timer"), 1.0)
      shopMove.height = "sh"

      guiScene.performDelayed(this, function () { updateOnShopWndAnim(true) })

      activateShopImpl(true)
    }
  }

  function onShopWndAnimStarted(obj)
  {
    onHoverSizeMove(obj)
    updateOnShopWndAnim(!::top_menu_shop_active)
  }

  function onShopWndAnimFinished(obj)
  {
    updateOnShopWndAnim(::top_menu_shop_active)
  }

  function updateOnShopWndAnim(isVisible)
  {
    local isShow = ::top_menu_shop_active
    updateSceneShade()
    if (isVisible)
      ::broadcastEvent("ShopWndVisible", { isShopShow = isShow })
    ::broadcastEvent("ShopWndAnimation", { isShow = isShow, isVisible = isVisible })
  }

  function activateShopImpl(shouldActivate, unitType = null)
  {
    if (shopWeak)
      shopWeak.onShopShow(shouldActivate)

    if (shouldActivate)
    {
      //instanciate shop window
      if (!shopWeak)
      {
        local wndObj = getObj("shop_wnd_frame")
        local shopHandler = ::handlersManager.loadHandler(::gui_handlers.ShopMenuHandler,
          {
            scene = wndObj
            closeShop = ::Callback(shopWndSwitch, this)
            forceUnitType =unitType
          })
        if (shopHandler)
        {
          registerSubHandler(shopHandler)
          shopWeak = shopHandler.weakref()
        }
      }
      else if (unitType)
        shopWeak.setUnitType(unitType)
    }

    enableHangarControls(!shouldActivate, false)
  }

  function goBack(obj)
  {
    onTopMenuMain(obj, true)
  }

  function onTopMenuMain(obj, checkTopMenuButtons = false)
  {
    if (::top_menu_shop_active)
      shopWndSwitch()
    else if (::current_base_gui_handler && ("onTopMenuGoBack" in ::current_base_gui_handler))
      ::current_base_gui_handler.onTopMenuGoBack.call(::current_base_gui_handler, checkTopMenuButtons)
  }

  function onGCShop(obj)
  {
    shopWndSwitch()
  }

  function onSwitchContacts()
  {
    ::switchContactsObj(scene, this)
  }

  function fullReloadScene()
  {
    checkedForward(function() {
      if (::handlersManager.getLastBaseHandlerStartFunc())
      {
        ::handlersManager.clearScene()
        ::handlersManager.getLastBaseHandlerStartFunc()
      }
    })
  }

  function getMainFocusObjByIdx(idx)
  {
    local id = "getMainFocusObj" + ((idx == 1)? "" : idx)
    local focusHandler = null
    if (::top_menu_shop_active && shopWeak)
      focusHandler = shopWeak
    else
      focusHandler = ::handlersManager.getActiveBaseHandler()

    if (focusHandler && (id in focusHandler))
      return focusHandler[id].call(focusHandler)
    return null
  }

  function getMainFocusObj()  { return getMainFocusObjByIdx(1) }
  function getMainFocusObj2() { return getMainFocusObjByIdx(2) }
  function getMainFocusObj3() { return getMainFocusObjByIdx(3) }
  function getMainFocusObj4() { return getMainFocusObjByIdx(4) }

  function onSceneActivate(show)
  {
    if (show && !getCurActiveContentHandler())
    {
      isWaitForContentToActivateScene = true
      return
    }
    else if (!show && isWaitForContentToActivateScene)
    {
      isWaitForContentToActivateScene = false
      return
    }

    base.onSceneActivate(show)
    if (::top_menu_shop_active && shopWeak)
      shopWeak.onSceneActivate(show)
    if (show)
      ::set_show_aircraft(getCurSlotUnit())
  }

  function getWndHelpConfig()
  {
    local res = {
      textsBlk = "gui/mainmenu/instantActionHelp.blk"
    }

    local links = [
      //Top left
      { obj = "topmenu_menu_panel"
        msgId = "hint_mainmenu"
      }

      //airInfo
      {
        obj = ["slot_info_listbox", "slot_collapse"]
        msgId = "hint_unitInfo"
      }

      //Top center
      {obj = "gc_clanTag"
        msgId = "hint_clan"
      }
      { obj = "gc_profile"
        msgId = "hint_profile"
      }
      { obj = ["to_battle_button", "to_battle_console_image"]
        msgId = "hint_battle_button"
      }
      { obj=["game_mode_change_button"]
        msgId = "hint_game_mode_change_button"
      }

      //Top right
      { obj = ["gc_free_exp", "gc_warpoints", "gc_eagles"]
        msgId = "hint_currencies"
      }
      { obj = "topmenu_shop_btn"
        msgId = "hint_onlineShop"
      }
      { obj = "gc_PremiumAccount"
        msgId = "hint_premium"
      }
      { obj = "gc_inventory"
        msgId = "hint_inventory"
      }

      //Bottom left
      { obj = "topmenu_btn_shop_wnd"
        msgId = "hint_research"
      }
      { obj = ::top_menu_shop_active? null : "slots-autorepair"
        msgId = "hint_autorepair"
      }
      { obj = ::top_menu_shop_active? null : "slots-autoweapon"
        msgId = "hint_autoweapon"
      }

      //bottom right
      { obj = ::top_menu_shop_active ? null : "perform_action_recent_items_mainmenu_button"
        msgId = "hint_recent_items"
      }
      { obj = ["gc_invites_btn", "gc_contacts", "gc_chat_btn", "gc_userlog_btn"]
        msgId = "hint_social"
      }
      { obj = ::top_menu_shop_active ? null : "perform_action_invite_squad_mainmenu_button"
        msgId = "hint_play_with_friends"
      }
    ]

    //Bottom bars
    local slotbar = getSlotbar()
    if (slotbar)
    {
      links.append(
        { obj = slotbar.getBoxOfUnits()
          msgId = "hint_my_crews"
        })

      if (::unlocked_countries.len() > 1)
        links.append({
          obj = slotbar.getBoxOfCountries()
          msgId = "hint_my_country"
        })

      local presetsList = getSlotbarPresetsList()
      local listObj = presetsList.getListObj()
      local presetsObjList = ["btn_slotbar_presets"]

      if (listObj)
        for(local i = 0; i < presetsList.maxPresets; i++)
          presetsObjList.append(listObj.getChild(i))
      links.append(
        { obj = presetsObjList
          msgId = "hint_presetsPlace"
        })
    }

    res.links <- links
    return res
  }
}
