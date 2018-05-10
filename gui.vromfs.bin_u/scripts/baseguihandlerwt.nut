local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local penalties = require("scripts/penitentiary/penalties.nut")
local callback = ::require("sqStdLibs/helpers/callback.nut")

const MAIN_FOCUS_ITEM_IDX = 4

::stickedDropDown <- null

local defaultSlotbarActions = [ "autorefill", "aircraft", "weapons", "showroom", "testflight", "crew", "info", "repair" ]

class ::gui_handlers.BaseGuiHandlerWT extends ::BaseGuiHandler
{
  defaultFocusArray = [
    function() { return getCurrentTopGCPanel() }     //gamercard top
    function() { return getCurGCDropdownMenu() }                    //gamercard menu
    function() { return ::get_menuchat_focus_obj() }
    function() { return ::contacts_handler? ::contacts_handler.getCurFocusObj() : null }
    function() { return getMainFocusObj() }       //main focus obj of handler
    function() { return getMainFocusObj2() }      //main focus obj of handler
    function() { return getMainFocusObj3() }      //main focus obj of handler
    function() { return getMainFocusObj4() }      //main focus obj of handler
    "crew_unlock_buttons",
    "autorefill-settings",
    function() { return slotbarWeak && slotbarWeak.getFocusObj() }   // slotbar
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

  slotbarWeak = null
  presetsListWeak = null
  shouldCheckCrewsReady = false
  slotbarActions = null

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
  widgetsList = null

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
  function fillModeListBox(nest, selectedDiffCode=0, filterFunc = null)
  {
    if (!::checkObj(nest))
      return
    local modesObj = nest.findObject("modes_list")
    if (!::checkObj(modesObj))
      return

    local view = { tabs = [] }
    local isFoundSelected = false
    foreach(diff in ::g_difficulty.types)
    {
      if (!diff.isAvailable() || (filterFunc && !filterFunc(diff.crewSkillName)))
        continue

      local isSelected = selectedDiffCode == diff.diffCode
      isFoundSelected = isFoundSelected || isSelected
      view.tabs.append({
        tabName = diff.getLocName(),
        selected = isSelected,
      })
    }
    if (!isFoundSelected && view.tabs.len())
      view.tabs[0].selected = true

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)

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
    if (::is_online_available())
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
    goForwardIfOnline(function() {
        local closeFunc = null
        if (afterCloseShop)
          closeFunc = function() {
            if (handler)
              afterCloseShop.call(handler)
          }
        ::OnlineShopModel.launchOnlineShop(handler, type, closeFunc)
      }, false, true)
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
    if (!::isMenuChatActive())
    {
      if (!::ps4_is_chat_enabled())
        ::ps4_show_chat_restriction()
      ::g_chat.xboxIsChatEnabled(true)
    }

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
    {
      ::update_ps4_friends()
      ::g_contacts.updateXboxOneFriends()
    }

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

  function getSlotbar()
  {
    return rootHandlerWeak ? rootHandlerWeak.slotbarWeak : slotbarWeak
  }

  function getCurSlotUnit()
  {
    local slotbar = getSlotbar()
    return slotbar && slotbar.getCurSlotUnit()
  }

  function getCurCrew()
  {
    local slotbar = getSlotbar()
    return slotbar && slotbar.getCurCrew()
  }

  function getCurSlotbarCountry()
  {
    local slotbar = getSlotbar()
    return slotbar && slotbar.getCurCountry()
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

  function onSlotsChangeAutoRefill(obj)
  {
    set_autorefill_by_obj(obj)
  }

  //"nav-help" - navBar
  function createSlotbar(params = {}, nest = "nav-help")
  {
    if (slotbarWeak)
    {
      slotbarWeak.setParams(params)
      return
    }

    if (::u.isString(nest))
      nest = scene.findObject(nest)
    params.scene <- nest
    params.ownerWeak <- this.weakref()

    local slotbar = ::gui_handlers.SlotbarWidget.create(params)
    if (!slotbar)
      return

    slotbarWeak = slotbar.weakref()
    registerSubHandler(slotbar)
  }

  function reinitSlotbar() //!!FIX ME: Better to not use it.
  {
    local slotbar = getSlotbar()
    if (slotbar)
      slotbar.fullUpdate()
  }

  function destroySlotbar()
  {
    if (slotbarWeak)
      slotbarWeak.destroy()
    slotbarWeak = null
  }

  function getSlotbarActions()
  {
    return slotbarActions || defaultSlotbarActions
  }

  function openUnitActionsList(unitObj, closeOnUnhover, ignoreSelect = false)
  {
    if (!::checkObj(unitObj) || (closeOnUnhover && !unitObj.isHovered()))
      return
    local parentObj = unitObj.getParent()
    if (!::checkObj(parentObj) || (!ignoreSelect && parentObj.selected != "yes"))
      return

    local actionsArray = getSlotbarActions()
    local unit = ::getAircraftByName(unitObj.unit_name)
    if (!unit)
      return

    local actions = ::get_unit_actions_list(unit, this, actionsArray)
    if (!actions.actions.len())
      return

    actions.closeOnUnhover <- closeOnUnhover
    ::gui_handlers.ActionsList.open(unitObj, actions)
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true)
  }

  function onOpenActionsList(obj)
  {
    openUnitActionsList(obj.getParent().getParent(), false)
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
    if (!::handlersManager.isAnyModalHandlerActive())
      ::restoreHangarControls()
    base.onModalWndDestroy()
    ::checkMenuChatBack()
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

  function getWidgetsList()
  {
    local result = []
    if (widgetsList)
      foreach (widgetDesc in widgetsList)
      {
        result.append({ widgetId = widgetDesc.widgetId })
        if ("placeholderId" in widgetDesc)
          result.top()["transform"] <- getWidgetParams(widgetDesc.placeholderId)
      }
    return result
  }

  function getWidgetParams(placeholderId)
  {
    local placeholderObj = scene.findObject(placeholderId)
    if (!::checkObj(placeholderObj))
      return null

    return {
      pos = placeholderObj.getPosRC()
      size = placeholderObj.getSize()
    }
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
