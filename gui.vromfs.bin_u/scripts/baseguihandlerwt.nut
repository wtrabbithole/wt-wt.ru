local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local penalties = require("scripts/penitentiary/penalties.nut")
local time = require("scripts/time.nut")
local callback = ::require("sqStdLibs/helpers/callback.nut")

const MAIN_FOCUS_ITEM_IDX = 4

::stickedDropDown <- null

class ::gui_handlers.BaseGuiHandlerWT extends ::BaseGuiHandler
{
  defaultFocusArray = [
    function() { return getCurrentTopGCPanel() }     //gamercard top
    function() { return getCurGCDropdownMenu() }                    //gamercard menu
    function() { return ::get_menuchat_focus_obj() }
    function() { return ::get_contact_focus_obj() }
    function() { return getMainFocusObj() }       //main focus obj of handler
    function() { return getMainFocusObj2() }      //main focus obj of handler
    function() { return getMainFocusObj3() }      //main focus obj of handler
    function() { return getMainFocusObj4() }      //main focus obj of handler
    "crew_unlock_buttons",
    "autorefill-settings",
    function() { return getCurrentAirsTable() }   // slotbar
    function() { return getCurrentBottomGCPanel() }    //gamercard bottom
  ]
  currentFocusItem = MAIN_FOCUS_ITEM_IDX
  gamercardTopIds = [
    "gamercard_panel_left"
    "gamercard_panel_center"
    @() ::isInMenu() ? "gamercard_panel_right" : null
    function() { return rightSectionHandlerWeak && rightSectionHandlerWeak.getFocusObj() }
  ]
  gamercardBottomIds = [
    "slotbar-presetsList"
    function() { return squadWidgetHandlerWeak && squadWidgetHandlerWeak.getFocusObj() }
    "gamercard_bottom_right"
  ]
  currentTopGCPanelIdx = 0
  currentBottomGCPanelIdx = 2

  squadWidgetHandlerWeak = null
  squadWidgetNestObjId = "gamercard_squad_widget"

  rightSectionHandlerWeak = null

  slotbarScene = null
  slotbarActions = null
  slotbarParams = null
  getCurrentEdiff = ::get_current_ediff
  isSlotbarShaded = false

  ignoreCheckSlotbar = false
  skipCheckCountrySelect = false
  skipCheckAirSelect = false
  shouldCheckCrewsReady = false
  presetsListWeak = null

  curSlotCountryId = -1
  curSlotIdInCountry = -1

  afterSlotOp = null
  afterSlotOpError = null

  startFunc = null
  progressBox = null
  taskId = null
  task = null

  GCDropdownsList = ["gc_shop"]
  curGCDropdown = null

  mainOptionsMode = -1
  mainGameMode = -1
  wndOptionsMode = -1
  wndGameMode = -1

  wndControlsAllowMask = null //enum CtrlsInGui, when null, it set by wndType

  function constructor(gui_scene, params = {})
  {
    base.constructor(gui_scene, params)

    if (wndType == handlerType.MODAL || wndType == handlerType.BASE)
      enableHangarControls(false, wndType == handlerType.BASE)

    setWndGameMode()
    setWndOptionsMode()
  }

  function init()
  {
    fillGamercard()
    base.init()
  }

  function getNavbarMarkup()
  {
    local tplView = getNavbarTplView()
    if (!tplView)
      return null
    return ::handyman.renderCached("gui/commonParts/navBar", tplView)
  }

  function getNavbarTplView() { return null }

  function fillGamercard()
  {
    ::fill_gamer_card(null, true, "gc_", scene)
    initSquadWidget()
    initRightSection()
  }

  function initSquadWidget()
  {
    if (squadWidgetHandlerWeak)
      return

    local nestObj = scene.findObject(squadWidgetNestObjId)
    if (!::checkObj(nestObj))
      return

    squadWidgetHandlerWeak = ::init_squad_widget_handler(this, nestObj)
    registerSubHandler(squadWidgetHandlerWeak)
  }

  function initRightSection()
  {
    if (rightSectionHandlerWeak)
      return

    rightSectionHandlerWeak = ::gui_handlers.TopMenuButtonsHandler.create(scene.findObject("topmenu_menu_panel_right"),
                                                                          this,
                                                                          ::g_top_menu_right_side_sections,
                                                                          scene.findObject("right_gc_panel_free_width")
                                                                         )
    registerSubHandler(rightSectionHandlerWeak)
  }

  /**
   * @param filterFunc Optional filter function with mode id
   *                   as parameter and boolean return type.
   */
  function fillModeListBox(nest, select=0, needCallback = true, needNavImages = false, filterFunc = null)
  {
    if (!::checkObj(nest))
      return
    local modesObj = nest.findObject("modes_list")
    if (!::checkObj(modesObj))
      return

    local modesList = ::get_option(::USEROPT_DOMINATION_MODE).items
    if (!(select in modesList))
    {
      select = 0
      needCallback = true
    }
    local view = { tabs = [] }
    foreach(idx, mode in modesList)
    {
      if (filterFunc != null && !filterFunc(mode.id))
        continue

      view.tabs.append({
        tabName = mode.text,
        selected = select == idx,
        navImagesText = needNavImages? ::get_navigation_images_text(idx, modesList.len()) : ""
      })
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)

    if (!needCallback)
      return

    local selectCb = modesObj.on_select
    if (selectCb && (selectCb in this))
      this[selectCb](modesObj)
  }

  function onTopMenuGoBack(...)
  {
    checkedForward(function() {
      goForward(::gui_start_mainmenu, false)
    })
  }

  function afterSave()
  {
    dagor.debug("warning! empty afterSave!")
  }

  function save(onlineSave = true)
  {
    local handler = this
    dagor.debug("save")
    if (::is_save_device_selected())
    {
      local saveRes = ::SAVELOAD_OK;
      saveRes = ::save_profile(onlineSave && ::is_online_available())

      if (saveRes != ::SAVELOAD_OK)
      {
        dagor.debug("saveRes = "+saveRes.tostring())
        local txt = "x360/noSaveDevice"
        if (saveRes == ::SAVELOAD_NO_SPACE)
          txt = "x360/noSpace"
        else if (saveRes == ::SAVELOAD_NOT_SELECTED)
          txt = "xbox360/questionSelectDevice"
        msgBox("no_save_device", ::loc(txt),
        [
          ["yes", (@(handler, onlineSave) function() {
              dagor.debug("performDelayed save")
              handler.guiScene.performDelayed(handler, (@(handler, onlineSave) function() {
                ::select_save_device(true)
                save(onlineSave)
                handler.afterSave()
              })(handler, onlineSave))
          })(handler, onlineSave)],
          ["no", (@(handler) function() {
            handler.afterSave()
          })(handler)
          ]
        ], "yes")
      }
      else
        handler.afterSave()
    }
    else
    {
      msgBox("no_save_device", ::loc("xbox360/questionSelectDevice"),
      [
        ["yes", (@(handler, onlineSave) function() {

            dagor.debug("performDelayed save")
            handler.guiScene.performDelayed(handler, (@(handler, onlineSave) function() {
              ::select_save_device(true)
              save(onlineSave)
            })(handler, onlineSave))
        })(handler, onlineSave)],
        ["no", (@(handler) function() {
          handler.afterSave()
        })(handler)
        ]
      ], "yes")
    }
  }

  function goForwardCheckEntitlement(start_func, entitlement)
  {
    guiScene = ::get_cur_gui_scene()
    local handler = this

    startFunc = start_func

    if (typeof(entitlement) == "table")
      task = entitlement;
    else
      task = {loc = entitlement, entitlement = entitlement}

    task.gm <- ::get_game_mode()

    taskId = ::update_entitlements()
    if (::is_dev_version && taskId < 0)
      goForward(start_func)
    else
    {
      local taskOptions = {
        showProgressBox = true
        progressBoxText = ::loc("charServer/checking")
      }
      local taskSuccessCallback = ::Callback(function ()
        {
          if (::checkAllowed.bindenv(this)(task))
            goForward(startFunc)
        }, this)
      ::g_tasker.addTask(taskId, taskOptions, taskSuccessCallback)
    }
  }

  function goForwardOrJustStart(start_func, start_without_forward)
  {
    if (start_without_forward)
      start_func();
    else
      goForward(start_func)
  }

  function goForwardIfOnline(start_func, skippable, start_without_forward = false)
  {
    if (::is_connected_to_matching())
    {
      goForwardOrJustStart(start_func, start_without_forward)
      return
    }

    local successCb = ::Callback((@(start_func, start_without_forward) function() {
      goForwardOrJustStart(start_func, start_without_forward)
    })(start_func, start_without_forward), this)
    local errorCb = skippable ? successCb : null

    ::g_matching_connect.connect(successCb, errorCb)
  }

  function destroyProgressBox()
  {
    if(::checkObj(progressBox))
    {
      guiScene.destroyElement(progressBox)
      ::broadcastEvent("ModalWndDestroy")
    }
    progressBox = null
  }

  function onShowHud(show = true)
  {
    if (!isSceneActive())
      return
    if (rootHandlerWeak)
      return rootHandlerWeak.onShowHud(show)

    guiScene.showCursor(show);
    if (!::check_obj(scene))
      return

    scene.show(show)
    guiScene.applyPendingChanges(false) //to correct work isVisible() for scene objects after event
  }

  function startOnlineShop(type=null, afterCloseShop = null)
  {
    local handler = this
    goForwardIfOnline((@(handler, type, afterCloseShop) function() {
        local closeFunc = null
        if (afterCloseShop)
          closeFunc = (@(handler, afterCloseShop) function() {
            if (handler)
              afterCloseShop.call(handler)
          })(handler, afterCloseShop)
        ::gui_modal_onlineShop(handler, type, closeFunc)
      })(handler, type, afterCloseShop), false, true)
  }

  function onOnlineShop(obj)          { startOnlineShop() }
  function onOnlineShopPremium()      { startOnlineShop("premium")}
  function onOnlineShopLions()        { startOnlineShop("warpoints") }

  function onOnlineShopEagles()
  {
    if (::has_feature("EnableGoldPurchase"))
      startOnlineShop("eagles")
    else
      ::showInfoMsgBox(::loc("msgbox/notAvailbleGoldPurchase"))
  }

  function onItemsShop() { ::gui_start_itemsShop() }
  function onInventory() { ::gui_start_inventory() }

  function askBuyPremium(afterCloseFunc)
  {
    local msgText = ::loc("msgbox/noEntitlement/PremiumAccount")
    msgBox("no_premium", msgText,
         [["ok", (@(afterCloseFunc) function() { startOnlineShop("premium", afterCloseFunc)})(afterCloseFunc) ],
         ["cancel", function() {} ]], "ok", { checkDuplicateId = true })
  }

  function onOnlineShopEaglesMsg(obj)
  {
    onOnlineShopEagles()
    /*
    msgBox("buy-eagles", ::loc("charServer/web_recharge"),
      [["ok", onOnlineShopEagles ],
       ["cancel", function() {} ]
      ], "ok", { cancel_fn = function() {}})
    */
  }

  function onConvertExp(obj)
  {
    ::gui_modal_convertExp(null, this)
  }

  function notAvailableYetMsgBox()
  {
    msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onUserLog(obj)
  {
    if (::has_feature("UserLog"))
      ::gui_modal_userLog()
    else
      notAvailableYetMsgBox()
  }

  function onProfile(obj)
  {
    ::gui_start_profile()
  }

  function onMyClanOpen()
  {
    ::gui_modal_clans("my_clan")
  }

  function onGC_chat(obj)
  {
    if (!::isMenuChatActive() && !::ps4_is_chat_enabled())
      ::ps4_show_chat_restriction()

    switchChatWindow()
  }

  function switchChatWindow()
  {
    if (gchat_is_enabled() && ::has_feature("Chat"))
      switchMenuChatObj(getChatDiv(scene))
    else
      notAvailableYetMsgBox()
  }

  function onSwitchContacts()
  {
    ::switchContactsObj(scene, this)
  }
  function onGC_contacts(obj)
  {
    if (!::has_feature("Friends"))
      return notAvailableYetMsgBox()

    if (!::isContactsWindowActive())
      ::update_ps4_friends()

    onSwitchContacts()
  }
  function onGC_invites(obj)
  {
    ::gui_start_invites()
  }
  function onInviteSquad(obj)
  {
    ::gui_start_search_squadPlayer()
  }

  function getSlotIdByObjId(slotObjId, countryId)
  {
    local prefix = "td_slot_"+countryId+"_"
    if (!::g_string.startsWith(slotObjId, prefix))
      return -1
    return ::to_integer_safe(slotObjId.slice(prefix.len()), -1)
  }

  function getSelSlotDataByObj(obj)
  {
    local res = {
      isValid = false
      countryId = -1
      crewIdInCountry = -1
    }

    local countryIdStr = ::getObjIdByPrefix(obj, "airs_table_")
    if (!countryIdStr)
      return res
    res.countryId = countryIdStr.tointeger()

    local curCol = obj.cur_col.tointeger()
    if (curCol < 0)
      return res
    local trObj = obj.getChild(0)
    if (curCol >= trObj.childrenCount())
      return res

    local curTdId = trObj.getChild(curCol).id
    res.crewIdInCountry = getSlotIdByObjId(curTdId, res.countryId)
    res.isValid = res.crewIdInCountry >= 0
    return res
  }

  function onSlotbarSelect(obj)
  {
    if (!::checkObj(obj))
      return

    if (::slotbar_oninit || skipCheckAirSelect || !(slotbarParams?.shouldCheckQueue ?? !::is_in_flight()))
    {
      onSlotbarSelectImpl(obj)
      skipCheckAirSelect = false
    }
    else
      checkedAirChange(
        (@(obj) function() {
          if (::checkObj(obj))
            onSlotbarSelectImpl(obj)
        })(obj),
        (@(obj) function() {
          if (::checkObj(obj))
          {
            skipCheckAirSelect = true
            selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
          }
        })(obj)
      )
  }

  function onSlotbarSelectImpl(obj)
  {
    if (!::check_obj(obj))
      return

    local selSlot = getSelSlotDataByObj(obj)
    if (!selSlot.isValid)
      return
    if (curSlotCountryId == selSlot.countryId
        && curSlotIdInCountry == selSlot.crewIdInCountry)
      return

    if (slotbarParams?.beforeSlotbarSelect)
      slotbarParams.beforeSlotbarSelect.call(
        this,
        ::Callback(@() ::check_obj(obj) && applySlotSelection(obj, selSlot), this),
        ::Callback(@() ::check_obj(obj) && selectTblAircraft(obj, curSlotIdInCountry), this),
        selSlot
      )
    else
      applySlotSelection(obj, selSlot)
  }

  function applySlotSelection(obj, selSlot)
  {
    curSlotCountryId = selSlot.countryId
    curSlotIdInCountry = selSlot.crewIdInCountry

    if (::slotbar_oninit)
      return afterSlotbarSelect()

    local needActionsWithEmptyCrews = slotbarParams?.needActionsWithEmptyCrews ?? true
    local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    if (needActionsWithEmptyCrews && !crew && (curSlotCountryId in ::g_crews_list.get()))
    {
      local country = ::g_crews_list.get()[curSlotCountryId].country

      local rawCost = ::get_crew_slot_cost(country)
      local cost = rawCost && ::Cost(rawCost.cost, rawCost.costGold)
      if (cost && ::old_check_balance_msgBox(cost.wp, cost.gold))
      {
        if (cost > ::zero_money)
        {
          local msgText = format(::loc("shop/needMoneyQuestion_purchaseCrew"), cost.tostring())
          ignoreCheckSlotbar = true
          msgBox("need_money", msgText,
            [["ok", (@(country) function() {
                      ignoreCheckSlotbar = false
                      purchaseNewSlot(country)
                    })(country) ],
             ["cancel", (@(obj, curSlotCountryId) function() {
                          ignoreCheckSlotbar = false
                          selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
                        })(obj, curSlotCountryId) ]
            ], "ok")
        }
        else
          purchaseNewSlot(country)
      }
      else
        selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
    }
    else if (crew && ("aircraft" in crew))
    {
      showAircraft(crew.aircraft)
      select_crew(curSlotCountryId, curSlotIdInCountry)
    }
    else if (needActionsWithEmptyCrews && crew && !("aircraft" in crew))
      onSlotChangeAircraft()

    if (slotbarParams?.hasActions ?? true)
    {
      local slotItem = ::get_slot_obj(obj, curSlotCountryId, ::to_integer_safe(obj.cur_col))
      openUnitActionsList(slotItem, true)
    }

    afterSlotbarSelect()
  }

  function afterSlotbarSelect()
  {
    if (slotbarParams?.afterSlotbarSelect)
      slotbarParams.afterSlotbarSelect.call(this)
  }

  function selectTblAircraft(tblObj, slotIdInCountry=0)
  {
    if (tblObj && tblObj.isValid() && slotIdInCountry>=0)
    {
      local slotIdx = getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
      if (slotIdx < 0)
        return
      ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, tblObj, 0, slotIdx)
    }
  }

  function showAircraft(airName)
  {
    local air = getAircraftByName(airName)
    if (!air)
      return
    ::show_aircraft = air
    if (wndType != handlerType.MODAL)
      ::hangar_model_load_manager.loadModel(airName)
  }

  function onSlotbarDblClick(obj=null)
  {
    local onSlotDblClick = slotbarParams?.onSlotDblClick
      ?? function(crew) {
           local unit = ::g_crew.getCrewUnit(crew)
           if (unit)
             ::open_weapons_for_unit(unit)
         }

    onSlotDblClick(getCurCrew())
  }

  function checkSelectCountryByIdx(obj)
  {
    local idx = obj.getValue()
    local countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(idx), "slotbar-country"), curSlotCountryId)
    if (curSlotCountryId >= 0 && curSlotCountryId != countryIdx && countryIdx in ::g_crews_list.get()
        && !::isCountryAvailable(::g_crews_list.get()[countryIdx].country) && ::isAnyBaseCountryUnlocked())
    {
      msgBox("notAvailableCountry", ::loc("mainmenu/countryLocked/tooltip"),
             [["ok", (@(obj) function() {
               if (::checkObj(obj))
                 obj.setValue(curSlotCountryId)
             })(obj) ]], "ok")
      return false
    }
    return true
  }

  function onSlotbarCountry(obj)
  {
    if (::slotbar_oninit || skipCheckCountrySelect)
    {
      onSlotbarCountryAction(obj)
      skipCheckCountrySelect = false
    }
    else
    {
      if (!checkSelectCountryByIdx(obj))
        return

      checkedCrewModify((@(obj) function() {
          if (::checkObj(obj))
            onSlotbarCountryAction(obj)
        })(obj),
        (@(obj) function() {
          if (::checkObj(obj))
            setCountry(::get_profile_info().country)
        })(obj))
    }
  }

  function setCountry(country)
  {
    if (!::checkObj(slotbarScene))
      return
    foreach(idx, c in ::g_crews_list.get())
      if (c.country == country)
      {
        local cObj = slotbarScene.findObject("slotbar-countries")
        if (cObj && cObj.getValue()!=idx)
        {
          skipCheckCountrySelect = true
          skipCheckAirSelect = true
          cObj.setValue(idx)
        }
        break
      }
  }

  function onSlotbarCountryAction(obj)
  {
    if (!::checkObj(obj))
      return

    local curValue = obj.getValue()
    if (obj.childrenCount() <= curValue)
      return

    local countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(curValue), "slotbar-country"), curSlotCountryId)

    if (!slotbarParams?.singleCountry)
    {
      if (!checkSelectCountryByIdx(obj))
        return

      onSlotbarSelect(obj.findObject("airs_table_"+countryIdx))
      local c = ::g_crews_list.get()[countryIdx].country
      ::switch_profile_country(c)
    }
    else
      onSlotbarSelect(obj.findObject("airs_table_"+countryIdx))
    if (presetsListWeak)
      presetsListWeak.update()
    updateAdvert()
  }

  function setSlotbarCountry(country)
  {
    if (!::checkObj(slotbarScene))
      return

    foreach(idx, c in ::g_crews_list.get())
      if (c.country == country)
      {
        if (idx != curSlotCountryId)
        {
          local cObj = slotbarScene.findObject("slotbar-countries")
          if (::checkObj(cObj))
            cObj.setValue(idx)
        }
        break
      }
  }

  function prevCountry(obj) { switchCountry(-1) }

  function nextCountry(obj) { switchCountry(1) }

  function switchCountry(way)
  {
    if (slotbarParams?.singleCountry || !::checkObj(slotbarScene))
      return

    local hObj = slotbarScene.findObject("slotbar-countries")
    if (hObj.childrenCount() <= 1)
      return

    local curValue = hObj.getValue()
    local value = ::getNearestSelectableChildIndex(hObj, curValue, way)
    if(value != curValue)
      hObj.setValue(value)
  }

  function getCurSlotUnit()
  {
    return getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
  }

  function getCurCrew()
  {
    return getSlotItem(curSlotCountryId, curSlotIdInCountry)
  }

  function getSlotIdxBySlotIdInCountry(tblObj,slotIdInCountry)
  {
    if (!tblObj.childrenCount())
      return -1
    local slotListObj = tblObj.getChild(0)
    if (!::checkObj(slotListObj))
      return -1
    local prefix = "td_slot_" + curSlotCountryId +"_"
    for(local i = 0; i < slotListObj.childrenCount(); i++)
    {
      local id = ::getObjIdByPrefix(slotListObj.getChild(i), prefix)
      if (!id)
      {
        local objId = slotListObj.getChild(i).id
        ::script_net_assert_once("bad slot id", "Error: Bad slotbar slot id")
        continue
      }

      if (::to_integer_safe(id) == slotIdInCountry)
        return i
    }

    return -1
  }

  function onEventCrewSkillsChanged(params)
  {
    local crew = ::getTblValue("crew", params)
    if (crew)
      ::update_slotbar_crew(this, ::get_slotbar_unit_slots(this, null, crew.id))
  }

  function onEventQualificationIncreased(params)
  {
    local unit = ::getTblValue("unit", params)
    if (unit)
      ::update_slotbar_crew(this, ::get_slotbar_unit_slots(this, unit.name))
  }

  function onTake(unit = null)
  {
    checkedCrewAirChange( (@(unit) function () {
      local curUnit = unit ? unit : getCurAircraft()
      if (!curUnit || !curUnit.isUsable() || ::isUnitInSlotbar(curUnit))
        return

      ::gui_start_selecting_crew({unit = curUnit, unitObj = scene.findObject(curUnit.name)})
    })(unit))
  }

  function onSlotChangeAircraft(crew = null)
  {
    ignoreCheckSlotbar = true
    checkedCrewAirChange((@(crew) function() {
        ignoreCheckSlotbar = false
        onSlotChangeAircraftAction(crew)
      })(crew),
      function() {
        ignoreCheckSlotbar = false
        checkSlotbar()
      }
    )
  }

  function onSlotChangeAircraftAction(crew)
  {
    if (::u.isTable(crew))
    {
      curSlotCountryId = crew.countryId
      curSlotIdInCountry = crew.idInCountry
    }

    ::gui_start_select_unit(curSlotCountryId, curSlotIdInCountry, this, slotbarParams)
  }

  function onSlotbarNextAir(obj)
  {
    ::nextSlotbarAir(slotbarScene, curSlotCountryId, 1)
  }

  function onSlotbarPrevAir(obj)
  {
    ::nextSlotbarAir(slotbarScene, curSlotCountryId, -1)
  }

  function onSlotsChangeAutoRefill(obj)
  {
    set_autorefill_by_obj(obj)
  }

  function onEventAutorefillChanged(params)
  {
    if (!::checkObj(slotbarScene) || !("id" in params) || !("value" in params))
      return

    local obj = slotbarScene.findObject(params.id)
    if (obj && obj.getValue!=params.value) obj.setValue(params.value)
  }

  //"nav-help" - navBar
  function createSlotbar(params = {}, nest = "nav-help")
  {
    if (::u.isString(nest))
      nest = scene.findObject(nest)
    ::init_slotbar(this, nest, params)
  }

  function reinitSlotbar()
  {
    if (::checkObj(slotbarScene))
      doWhenActiveOnce("reinitSlotbarAction")
  }

  function reinitSlotbarAction()
  {
    if (ignoreCheckSlotbar || !::checkObj(slotbarScene))
      return

    ::init_slotbar(this, slotbarScene, slotbarParams)
    shadeSlotbar(isSlotbarShaded)
    if (isSceneActiveNoModals())
      restoreFocus()
  }

  function checkSlotbar()
  {
    if (ignoreCheckSlotbar || !::isInMenu() || !::checkObj(slotbarScene))
      return

    if (!(curSlotCountryId in ::g_crews_list.get())
        || ::g_crews_list.get()[curSlotCountryId].country != ::get_profile_info().country
        || curSlotIdInCountry != ::selected_crews[curSlotCountryId])
      reinitSlotbarAction()
  }

  function shadeSlotbar(show)
  {
    isSlotbarShaded = show
    if(::checkObj(slotbarScene))
    {
      local shadeObj = slotbarScene.findObject("slotbar_shade")
      if(::checkObj(shadeObj))
        shadeObj.animation = isSlotbarShaded ? "show" : "hide"
      if (::show_console_buttons)
        showSceneBtn("slotbar_nav_block", !isSlotbarShaded)
    }
  }

  function openUnitActionsList(unitObj, closeOnUnhover, ignoreSelect = false)
  {
    if (!::checkObj(unitObj) || (closeOnUnhover && !unitObj.isHovered()))
      return
    local parentObj = unitObj.getParent()
    if (!::checkObj(parentObj) || (!ignoreSelect && parentObj.selected != "yes"))
      return

    local actionsArray = slotbarActions ? slotbarActions : ::defaultSlotbarActions
    local unit = ::getAircraftByName(unitObj.unit_name)
    if (!unit)
      return

    local actions = ::get_unit_actions_list(unit, this, actionsArray)
    if (!actions.actions.len())
      return

    actions.closeOnUnhover <- closeOnUnhover
    ::gui_handlers.ActionsList(unitObj, actions)
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true)
  }

  function onOpenActionsList(obj)
  {
    openUnitActionsList(obj.getParent().getParent(), false)
  }

  function getCurrentAirsTable()
  {
    local slotbar = getSlotbarScene()
    if (::checkObj(slotbar))
      return slotbar.findObject("airs_table_" + getCurSlotCountryId())
    return null
  }

  function getCurrentCrewSlot()
  {
    local airsTable = getCurrentAirsTable()
    if (!::checkObj(airsTable))
      return null

    local curIdInCountry = getCurSlotIdInCountry()
    if (airsTable.getChild(0).childrenCount() > curIdInCountry)
      return airsTable.getChild(0).getChild(curIdInCountry).getChild(1)
    return null
  }

  function getSlotbarPresetsList()
  {
    return rootHandlerWeak ? rootHandlerWeak.presetsListWeak : presetsListWeak
  }

  function setSlotbarPresetsListAvailable(isAvailable)
  {
    if (isAvailable)
    {
      if (presetsListWeak)
        presetsListWeak.update()
      else
        presetsListWeak = SlotbarPresetsList(this).weakref()
    } else
      if (presetsListWeak)
        presetsListWeak.destroy()
  }

  function getSlotbarScene()
  {
    return rootHandlerWeak ? rootHandlerWeak.slotbarScene : slotbarScene
  }

  function getCurSlotCountryId()
  {
    return rootHandlerWeak ? rootHandlerWeak.curSlotCountryId : curSlotCountryId
  }

  function getCurSlotIdInCountry()
  {
    return rootHandlerWeak ? rootHandlerWeak.curSlotIdInCountry : curSlotIdInCountry
  }

  /**
   * Selects crew in slotbar with specified id
   * as if player clicked slot himself.
   */
  function selectCrew(crewId)
  {
    if (rootHandlerWeak)
      return rootHandlerWeak.selectCrew(crewId)

    local objId = "airs_table_" + getCurSlotCountryId().tostring()
    local obj = getSlotbarScene().findObject(objId)
    if (::checkObj(obj))
      selectTblAircraft(obj, crewId)
  }

  function slotOpCb(id, type, result)
  {
    if (id != taskId)
    {
      dagor.debug("wrong ID in char server cb, ignoring");
      ::g_tasker.charCallback(id, type, result)
      return
    }
    ::g_tasker.restoreCharCallback()
    destroyProgressBox()

    penalties.showBannedStatusMsgBox(true)

    if (result != 0)
    {
      local handler = this
      local text = ::loc("charServer/updateError/"+result.tostring())

      if (("EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS" in getroottable())
        && ("get_char_extended_error" in getroottable()))
        if (result == ::EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS)
        {
          local notAllowedChars = ::get_char_extended_error()
          text = ::format(text, notAllowedChars)
        }

      handler.msgBox("char_connecting_error", text,
      [
        ["ok", (@(result) function() { if (afterSlotOpError != null) afterSlotOpError(result);})(result) ]
      ], "ok")
      return
    }
    else if (afterSlotOp != null)
      afterSlotOp();
  }

  function showTaskProgressBox(text = null, cancelFunc = null, delayedButtons = 30)
  {
    if (::checkObj(progressBox))
      return

    if (text == null)
      text = ::loc("charServer/purchase0")

    if (cancelFunc == null)
      cancelFunc = function(){}

    progressBox = msgBox("char_connecting",
        text,
        [["cancel", cancelFunc]], "cancel",
        { waitAnim = true,
          delayedButtons = delayedButtons
        })
  }

  function purchaseNewSlot(country)
  {
    ignoreCheckSlotbar = true

    local onTaskSuccess = ::Callback(function()
    {
      ignoreCheckSlotbar = false
      ::update_gamercards()
      ::g_crews_list.refresh()
      onSlotChangeAircraft()
    }, this)

    local onTaskFail = ::Callback(function(result) { ignoreCheckSlotbar = false }, this)

    if (!::g_crew.purchaseNewSlot(country, onTaskSuccess, onTaskFail))
      ignoreCheckSlotbar = false
  }

  function onGenericTooltipOpen(obj)
  {
    ::g_tooltip.open(obj, this)
  }

  function onModificationTooltipOpen(obj)
  {
    local modName = ::getObjIdByPrefix(obj, "tooltip_")
    local unitName = obj.unitName
    if (!modName || !unitName)
      return obj["class"] = "empty"

    local unit = ::getAircraftByName(unitName)
    if (!unit)
      return

    local mod = ::getModificationByName(unit, modName) || { name = modName, isDefaultForGroup = (obj.groupIdx || 0).tointeger() }
    mod.type <- weaponsItem.modification
    ::weaponVisual.updateWeaponTooltip(obj, unit, mod, this)
  }

  function onTooltipObjClose(obj)
  {
    ::g_tooltip.close.call(this, obj)
  }

  function onContactTooltipOpen(obj)
  {
    local uid = obj.uid
    local canShow = false
    local contact = null
    if (uid)
    {
      contact = ::getContact(uid)
      canShow = canShowContactTooltip(contact)
    }
    obj["class"] = canShow ? "" : "empty"

    if (canShow)
      ::fillContactTooltip(obj, contact, this)
  }

  function canShowContactTooltip(contact)
  {
    return contact != null
  }

  function onQueuesTooltipOpen(obj)
  {
    guiScene.replaceContent(obj, "gui/queue/queueInfoTooltip.blk", this)
    SecondsUpdater(obj.findObject("queue_tooltip_root"), function(obj, params)
    {
      obj.findObject("text").setValue(::queues.getQueuesInfoText())
    })
  }

  function onProjectawardTooltipOpen(obj)
  {
    if (!::checkObj(obj)) return
    local img = obj.img || ""
    local title = obj.title || ""
    local desc = obj.desc || ""

    guiScene.replaceContent(obj, "gui/decalTooltip.blk", this)
    obj.findObject("header").setValue(title)
    obj.findObject("description").setValue(desc)
    local imgObj = obj.findObject("image")
    imgObj["background-image"] = img
    local picDiv = imgObj.getParent()
    picDiv["size"] = "128*@sf/@pf_outdated, 128*@sf/@pf_outdated"
    picDiv.show(true)
  }

  function onViewImage(obj)
  {
    ::view_fullscreen_image(obj)
  }

  function onFaq()             { ::open_url(::loc("url/faq")) }
  function onForum()           { ::open_url(::loc("url/forum")) }
  function onSupport()         { ::open_url(::loc("url/support")) }
  function onWiki()            { ::open_url(::loc("url/wiki")) }

  function onSquadCreate(obj)
  {
    if (::g_squad_manager.isInSquad())
      msgBox("already_in_squad", ::loc("squad/already_in_squad"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
    else
      ::chatInviteToSquad(null, this)
  }

  function unstickLastDropDown(newObj = null)
  {
    if (::checkObj(::stickedDropDown) && (!newObj || !::stickedDropDown.isEqual(newObj)))
    {
      ::stickedDropDown.stickHover = "no"
      ::stickedDropDown.getScene().applyPendingChanges(false)
      onStickDropDown(::stickedDropDown, false)
      ::stickedDropDown = null
    }
  }

  function onDropDown(obj)
  {
    if (!obj)
      return

    local canStick = !::use_touchscreen || !obj.isHovered()

    if(obj["class"]!="dropDown")
      obj = obj.getParent()
    if(obj["class"]!="dropDown")
      return

    local stickTxt = obj.stickHover
    local stick = !stickTxt || stickTxt=="no"
    if (!canStick && stick)
      return

    obj.stickHover = stick? "yes" : "no"
    unstickLastDropDown(obj)

    guiScene.applyPendingChanges(false)
    ::stickedDropDown = stick? obj : null
    onStickDropDown(obj, stick)
  }

  function onHoverSizeMove(obj)
  {
    if(obj["class"]!="dropDown")
      obj = obj.getParent()
    unstickLastDropDown(obj)
  }

  function onGCDropdown(obj)
  {
    local id = obj.id
    local ending = "_panel"
    if (id && id.len() > ending.len() && id.slice(id.len()-ending.len())==ending)
      id = id.slice(0, id.len()-ending.len())
    if (!::isInArray(id, GCDropdownsList))
      return

    local btnObj = obj.findObject(id + "_btn")
    if (::checkObj(btnObj))
      onDropDown(btnObj)
  }

  function onStickDropDown(obj, show)
  {
    if (!::checkObj(obj))
      return

    local id = obj.id
    if (!show || !::isInArray(id, GCDropdownsList))
    {
      curGCDropdown = null
      restoreFocus(false)
      return
    }

    curGCDropdown = id
    guiScene.performDelayed(this, function() {
      local focusObj = getCurGCDropdownMenu()
      if (!::checkObj(focusObj))
        return

      ::play_gui_sound("menu_appear")
      focusObj.select()
      checkCurrentFocusItem(focusObj)
    })
    return
  }

  function getCurGCDropdownMenu()
  {
    return curGCDropdown? getObj(curGCDropdown + "_focus") : null
  }

  function unstickGCDropdownMenu()
  {
    if (!curGCDropdown)
      return
    local btnObj = getObj(curGCDropdown + "_btn")
    if (::checkObj(btnObj))
      onDropDown(btnObj)
  }

  function checkGCDropdownMenu(focusObj)
  {
    local ddObj = getCurGCDropdownMenu()
    if (ddObj && !ddObj.isEqual(focusObj))
      unstickGCDropdownMenu()
  }

  function setSceneTitle(text)
  {
    ::set_menu_title(text, scene)
  }

  function restoreMainOptions()
  {
    if (mainOptionsMode >= 0)
      ::set_gui_options_mode(mainOptionsMode)
    if (mainGameMode >= 0)
      ::set_mp_mode(mainGameMode)
  }

  function setWndGameMode()
  {
    if (wndGameMode < 0)
      return
    mainGameMode = ::get_mp_mode()
    ::set_mp_mode(wndGameMode)
  }

  function setWndOptionsMode()
  {
    if (wndOptionsMode < 0)
      return
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(wndOptionsMode)
  }

  function checkAndStart(onSuccess, onCancel, checkName, checkParam = null)
  {
    ::queues.checkAndStart(callback.make(onSuccess, this), callback.make(onCancel, this),
      checkName, checkParam)
  }

  function checkedNewFlight(func, cancelFunc=null)
                   { checkAndStart(func, cancelFunc, "isCanNewflight") }
  function checkedForward(func, cancelFunc=null)
                   { checkAndStart(func, cancelFunc, "isCanGoForward") }
  function checkedCrewModify(func, cancelFunc=null)
                   { checkAndStart(func, cancelFunc, "isCanModifyCrew") }
  function checkedAirChange(func, cancelFunc=null)  //change selected air
                   { checkAndStart(func, cancelFunc, "isCanAirChange") }
  function checkedCrewAirChange(func, cancelFunc=null) //change air in slot
  {
    checkAndStart(
      (@(func, cancelFunc) function() {
        ::g_squad_utils.checkSquadUnreadyAndDo(this, func, cancelFunc, shouldCheckCrewsReady)
      })(func, cancelFunc),
      cancelFunc, "isCanModifyCrew")
  }
  function checkedModifyQueue(type, func, cancelFunc=null)
  {
    checkAndStart(func, cancelFunc, "isCanModifyQueueParams", type)
  }

  function onFacebookPostScrnshot(saved_screenshot_path)
  {
    ::make_facebook_login_and_do((@(saved_screenshot_path) function() {::start_facebook_upload_screenshot(saved_screenshot_path)})(saved_screenshot_path), this)
  }

  function onFacebookLoginAndPostScrnshot()
  {
    ::make_screenshot_and_do(onFacebookPostScrnshot, this)
  }

  function onFacebookLoginAndAddFriends()
  {
    ::make_facebook_login_and_do(function()
         {
           ::scene_msg_box("facebook_login", null, ::loc("facebook/downloadingFriends"), null, null)
           ::facebook_load_friends(::EPL_MAX_PLAYERS_IN_LIST)
         }, this)
  }

  function checkDiffTutorial(diff, unitType, needMsgBox = true, cancelFunc = null)
  {
    if (!::check_diff_pkg(diff, !needMsgBox))
      return true
    if (!::is_need_check_tutorial(diff))
      return false
    if (::g_squad_manager.isNotAloneOnline())
      return false

    if (::isDiffUnlocked(diff, unitType))
      return false

    local reqName = ::get_req_tutorial(unitType)
    local mData = ::get_uncompleted_tutorial_data(reqName, diff)
    if (!mData)
      return false

    local msgText = ::loc((diff==2)? "msgbox/req_tutorial_for_real" : "msgbox/req_tutorial_for_hist")
    msgText += "\n\n" + format(::loc("msgbox/req_tutorial_for_mode"), ::loc("difficulty" + diff))

    msgText += "\n<color=@userlogColoredText>" + ::loc("missions/" + mData.mission.name) + "</color>"

    if(needMsgBox)
      msgBox("req_tutorial_msgbox", msgText,
        [
          ["startTutorial", (@(mData, diff) function() {
            mData.mission.setStr("difficulty", ::get_option(::USEROPT_DIFFICULTY).values[diff])
            ::select_mission(mData.mission, true)
            ::current_campaign_mission = mData.mission.name
            ::save_tutorial_to_check_reward(mData.mission)
            goForward(::gui_start_flight)
          })(mData, diff)],
          ["cancel", cancelFunc]
        ], "cancel")
    else if(cancelFunc)
      cancelFunc()
    return true
  }

  function updateAdvert()
  {
    local blk = ::DataBlock()
    ::get_news_blk(blk)

    local obj = guiScene["topmenu_advert"]
    if (::checkObj(obj))
    {
      local text = ""
      if (blk.advert)
      {
        text += ::loc(blk.advert, "")
        SecondsUpdater(obj, (@(text) function(obj, params) {
          local stopUpdate = text.find("{time_countdown=") == null
          local textResult = time.processTimeStamps(text)
          local objText = obj.findObject("topmenu_advert_text")
          objText.setValue(textResult)
          obj.show(textResult != "")
          return stopUpdate
        })(text))
      }
    }
  }

  function proccessLinkFromText(obj, itype, link)
  {
    ::open_url(link, false, false, obj.bqKey || obj.id)
  }

  function onFacebookPostPurchaseChange(obj)
  {
    ::FACEBOOK_POST_WALL_MESSAGE = obj.getValue()
  }

  function onOpenGameModeSelect(obj)
  {
    if (!::handlersManager.isHandlerValid(::instant_domination_handler))
      return
    ::instant_domination_handler.checkQueue((@(obj) function () {
      if (!::checkObj(obj))
        return
      if (::top_menu_handler != null)
        ::top_menu_handler.closeShop()
      local handler = ::instant_domination_handler.getGameModeSelectHandler()
      handler.setShowGameModeSelect(!handler.getShowGameModeSelect())
    })(obj).bindenv(this))
  }

  function onGCWrap(obj, moveRight, ids, currentIdx)
  {
    if (!::checkObj(scene))
      return currentIdx

    local dir = moveRight ? 1 : -1
    local total = ids.len()
    for(local i = 1; i < total; i++)
    {
      local idx = (total + currentIdx + dir * i) % total
      local newObj = getObjByConfigItem(ids[idx])

      if (::checkObj(newObj) && newObj.isEnabled() && newObj.isVisible())
      {
        newObj.select()
        return idx
      }
    }

    return currentIdx
  }

  function onTopGCPanelLeft(obj)
  {
    currentTopGCPanelIdx = onGCWrap(obj, false, gamercardTopIds, currentTopGCPanelIdx)
  }
  function onTopGCPanelRight(obj)
  {
    currentTopGCPanelIdx = onGCWrap(obj, true, gamercardTopIds, currentTopGCPanelIdx)
  }

  function onBottomGCPanelLeft(obj)
  {
    currentBottomGCPanelIdx = onGCWrap(obj, false, gamercardBottomIds, currentBottomGCPanelIdx)
  }

  function onBottomGCPanelRight(obj)
  {
    currentBottomGCPanelIdx = onGCWrap(obj, true, gamercardBottomIds, currentBottomGCPanelIdx)
  }

  function getCurrentTopGCPanel()
  {
    return getObjByConfigItem(gamercardTopIds[currentTopGCPanelIdx])
  }

  function getCurrentBottomGCPanel()
  {
    return getObjByConfigItem(gamercardBottomIds[currentBottomGCPanelIdx])
  }

  function onFocusItemSelected(obj)
  {
    checkGCDropdownMenu(obj)
  }

  function onModalWndDestroy()
  {
    ::restoreHangarControls()
    base.onModalWndDestroy()
    ::checkMenuChatBack()
    ::checkContactsBack()
  }

  function onSceneActivate(show)
  {
    if (show)
    {
      setWndGameMode()
      setWndOptionsMode()
    } else
      restoreMainOptions()

    if (::is_hud_visible())
      onShowHud()

    base.onSceneActivate(show)

    if (checkActiveForDelayedAction())
      checkSlotbar()
  }

  function onEventModalWndDestroy(p)
  {
    base.onEventModalWndDestroy(p)

    if (checkActiveForDelayedAction())
      checkSlotbar()
  }

  function getControlsAllowMask()
  {
    return wndControlsAllowMask
  }

  function switchControlsAllowMask(mask)
  {
    if (mask == wndControlsAllowMask)
      return

    wndControlsAllowMask = mask
    ::handlersManager.updateControlsAllowMask()
  }

  function onHeaderTabSelect() {} //empty frame
  function dummyCollapse(obj) {}

  function onFacebookLoginAndPostMessage() {}
  function sendInvitation() {}
  function onFacebookPostLink() {}

  function onModActionBtn(){}
  function onModItemClick(){}
  function onModItemDblClick(){}
  function onModCheckboxClick(){}
  function onAltModAction(){}
  function onModChangeBulletsSlider(){}

  function onShowMapRenderFilters(){}
}
