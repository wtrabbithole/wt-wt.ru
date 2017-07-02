::show_aircraft <- null
::show_crew <- null

::g_script_reloader.registerPersistentData("DecalMenuGlobals", ::getroottable(), ["show_aircraft", "show_crew"])

enum decoratorEditState
{
  NONE     = 0x0001
  SELECT   = 0x0002
  REPLACE  = 0x0004
  ADD      = 0x0008
  PURCHASE = 0x0010
  EDITING  = 0x0020
}

function on_decal_job_complete(taskId)
{
  local callback = ::getTblValue(taskId, ::g_decorator_type.DECALS.jobCallbacksStack, null)
  if (callback)
  {
    callback()
    delete ::g_decorator_type.DECALS.jobCallbacksStack[taskId]
  }
}

function gui_start_decals()
{
  if (!::show_aircraft
      ||
        ( ::hangar_get_loaded_unit_name() == (::show_aircraft && ::show_aircraft.name)
        && !::is_loaded_model_high_quality()
        && !::check_package_and_ask_download("pkg_main"))
    )
    return

  ::handlersManager.loadHandler(::gui_handlers.DecalMenuHandler, { backSceneFunc = ::gui_start_mainmenu })
}

class ::gui_handlers.DecalMenuHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/customization.blk"
  unit = null
  owner = null

  access_Decals = false
  access_Attachables = false
  access_UserSkins = false
  access_SkinsUnrestrictedPreview = false
  access_SkinsUnrestrictedExport  = false

  editableDecoratorId = null

  skinList = null
  curSlot = 0
  curAttachSlot = 0
  previewSkinId = null

  currentType = ::g_decorator_type.UNKNOWN

  isLoadingRot = false
  isDecoratorsListOpen = false
  isDecoratorItemUsed = false

  is_unit_tank = false
  is_own = false
  isUnitBought = false

  currentState = decoratorEditState.NONE
  currentFocusItem = MAIN_FOCUS_ITEM_IDX + 2
  needToRestoreFocusOnTypeList = false

  function initScreen()
  {
    owner = this
    unit = ::show_aircraft

    access_UserSkins = ::is_platform_pc && ::has_feature("UserSkins")
    access_SkinsUnrestrictedPreview = ::has_feature("SkinsPreviewOnUnboughtUnits")
    access_SkinsUnrestrictedExport  = access_UserSkins && access_SkinsUnrestrictedExport

    ::enableHangarControls(true)
    scene.findObject("timer_update").setUserData(this)

    ::hangar_focus_model(true)

    registerSubHandler(::create_slot_info_panel(scene, false))
    initMainParams()
    showDecoratorsList()

    updateDecalActionsTexts()

    ::hangar_model_load_manager.loadModel(unit.name)

    initFocusArray()

    if (::has_feature("WikiUnitInfo"))
    {
      local infoBtn = scene.findObject("btn_info")
      infoBtn.isLink = "yes"
    }
  }

  function initMainParams()
  {
    ::cur_aircraft_name = unit.name

    access_Decals = ::g_decorator_type.DECALS.isAvailable(unit)
    access_Attachables = ::g_decorator_type.ATTACHABLES.isAvailable(unit)

    is_unit_tank = ::isTank(unit)
    is_own = unit.isUsable()
    isUnitBought = unit.isBought()
    setSceneTitle(::loc(is_own ? "mainmenu/showroom" : "mainmenu/btnPreview") + ::loc("ui/parentheses/space", { text = ::getUnitName(unit.name) }))

    local bObj = scene.findObject("btn_testflight")
    if (::checkObj(bObj))
    {
      bObj.setValue(unit.unitType.getTestFlightText())
      bObj.findObject("btn_testflight_image")["background-image"] = unit.unitType.testFlightIcon
    }

    createSkinSliders()
    updateMainGuiElements()
  }

  function updateMainGuiElements()
  {
    updateSlotsBlockByType()
    updateSkinList()
    updateUserSkinList()
    updateSkinSliders()
    updateButtons()
  }

  function getCurDecalsListObj(onlyDecalsList = true)
  {
    local decalsObj = scene.findObject("decals_list")
    if (!::checkObj(decalsObj))
      return null

    if (onlyDecalsList)
      return decalsObj

    local value = decalsObj.getValue()
    if (value < 0 || value >= decalsObj.childrenCount())
      return decalsObj

    local categoryObj = decalsObj.getChild(value)
    if (::checkObj(categoryObj) && categoryObj.collapsed == "no")
    {
      local categoryListObj = categoryObj.findObject("collapse_content_" + categoryObj.id)
      if (::checkObj(categoryListObj))
        return categoryListObj
    }

    return decalsObj
  }

  function getMainFocusObj()
  {
    if (isDecoratorsListOpen)
      return getCurDecalsListObj(false)
    return getObj("skins_navigator")
  }

  function getMainFocusObj2()
  {
    if (!isDecoratorsListOpen && is_unit_tank)
      return getObj("tank_skin_settings")
    return null
  }

  function getMainFocusObj3()
  {
    if (isDecoratorsListOpen)
      return getCurDecalsListObj(false)
    return getObj("slots_attachable_list")
  }

  function getMainFocusObj4()
  {
    if (isDecoratorsListOpen)
      return getCurDecalsListObj(false)
    return getObj("slots_list")
  }

  function updateDecalActionsTexts()
  {
    local bObj = null
    local shortcuts = []

    local hasKeyboard = ::is_platform_pc
    local hasGamepad = ::show_console_buttons

    //Flip
    local btn_toggle_mirror_text = ::loc("decals/flip") + (hasKeyboard ? " (F)" : "")
    bObj = scene.findObject("btn_toggle_mirror")
    if(::checkObj(bObj))
      bObj.setValue(btn_toggle_mirror_text)

    //TwoSided
    local btn_toggle_bf_text = ::loc("decals/twosided") + (hasKeyboard ? " (T)" : "")
    bObj = scene.findObject("btn_toggle_bf")
    if(::checkObj(bObj))
      bObj.setValue(btn_toggle_bf_text)

    //Size
    shortcuts = []
    if (hasGamepad)
      shortcuts.append(::loc("xinp/L1") + ::loc("ui/slash") + ::loc("xinp/R1"))
    if (hasKeyboard)
      shortcuts.append(::loc("key/Shift") + ::loc("keysPlus") + ::loc("key/Wheel"))
    bObj = scene.findObject("push_to_change_size")
    if (::checkObj(bObj))
      bObj.setValue(implode(shortcuts, ::loc("ui/comma")))

    //Rotate
    shortcuts = []
    if (hasGamepad)
      shortcuts.append(::loc("xinp/D.Left") + ::loc("ui/slash") + ::loc("xinp/D.Right"))
    if (hasKeyboard)
      shortcuts.append(::loc("key/Alt") + ::loc("keysPlus") + ::loc("key/Wheel"))
    bObj = scene.findObject("push_to_rotate")
    if (::checkObj(bObj))
      bObj.setValue(implode(shortcuts, ::loc("ui/comma")))
  }

  function getSelectedBuiltinSkinId()
  {
    return previewSkinId || ::hangar_get_last_skin(unit.name)
  }

  function getSampleUserSkin(obj)
  {
    if (!::hangar_is_loaded())
      return

    if (!::can_save_current_skin_template())
    {
      local message = ::format(::loc("decals/noUserSkinForCurUnit"), ::getUnitName(unit.name))
      msgBox("skin_template_export", message, [["ok", function(){}]], "ok")
      return
    }

    local allowCurrentSkin = access_SkinsUnrestrictedExport // true - current skin, false - default skin.
    local success = ::save_current_skin_template(allowCurrentSkin)

    local templateName = "template_" + unit.name
    local message = success ? ::format(::loc("decals/successfulLoadedSkinSample"), templateName) : ::loc("decals/failedLoadedSkinSample")
    msgBox("skin_template_export", message, [["ok", function(){}]], "ok")

    updateMainGuiElements()
  }

  function refreshSkinsList(obj)
  {
    if (!::hangar_is_loaded())
      return

    updateUserSkinList()
    if (::get_option(::USEROPT_USER_SKIN).value > 0)
      ::hangar_force_reload_model()
  }

  function onEventHangarModelLoaded(params = {})
  {
    updateMainGuiElements()

    if (::hangar_get_loaded_unit_name() == unit.name
        && !::is_loaded_model_high_quality())
      ::check_package_and_ask_download("pkg_main", null, null, this, "air_in_hangar", goBack)
  }

  function updateSkinList()
  {
    if (!is_own && !access_SkinsUnrestrictedPreview && !access_SkinsUnrestrictedExport)
      return

    skinList = ::g_decorator.getSkinsOption(unit.name, true)
    local curSkinId = getSelectedBuiltinSkinId()
    local curSkinIndex = ::find_in_array(skinList.values, curSkinId, 0)

    local skinItems = []
    foreach(i, decorator in skinList.decorators)
    {
      local access = skinList.access[i]
      local canBuy = decorator.canBuyUnlock(unit)
      local priceText = canBuy ? decorator.getCost().getTextAccordingToBalance() : ""
      local text = decorator.getName()
      if (canBuy)
        text = ::loc("ui/parentheses", {text = priceText}) + " " + text

      if (!access.isVisible)
        text = ::colorize("badTextColor", text)

      skinItems.append({
        text = text
        textStyle = "textStyle:t='textarea';"
        addDiv = getDecorationTooltipObjText(decorator.id, ::UNLOCKABLE_SKIN)
        image = decorator.isUnlocked() ? null : "#ui/gameuiskin#locked"
      })
    }

    renewDropright("skins_list", "skins_dropright", skinItems, curSkinIndex, "onSkinChange")
  }

  function renewDropright(nestObjId, listObjId, items, index, cb)
  {
    local nestObj = scene.findObject(listObjId)
    local needCreateList = false
    if (!::checkObj(nestObj))
    {
      needCreateList = true
      nestObj = scene.findObject(nestObjId)
      if (!::checkObj(nestObj))
        return
    }
    local skinsDropright = ::create_option_combobox(listObjId, items, index, cb, needCreateList)
    if (needCreateList)
      guiScene.prependWithBlk(nestObj, skinsDropright, this)
    else
      guiScene.replaceContentFromText(nestObj, skinsDropright, skinsDropright.len(), this)
  }

  function updateUserSkinList()
  {
    ::reload_user_skins()
    local userSkinsOption = ::get_option(::USEROPT_USER_SKIN)
    renewDropright("user_skins_list", "user_skins_dropright", userSkinsOption.items, userSkinsOption.value, "onUserSkinChanged")
  }

  function createSkinSliders()
  {
    if (!is_own || !is_unit_tank)
      return

    local options = [::USEROPT_TANK_CAMO_SCALE,
                     ::USEROPT_TANK_CAMO_ROTATION]
    if (::has_feature("SpendGold"))
      options.insert(0, ::USEROPT_TANK_SKIN_CONDITION)

    local view = { rows = [] }
    foreach(optType in options)
    {
      local option = ::get_option(optType)
      view.rows.append({
        id = option.id
        name = "#options/" + option.id
        option = ::create_option_slider(option.id, option.items, option.value, option.cb, true, "sliderProgress", option)
      })
    }
    local data = ::handyman.renderCached(("gui/options/verticalOptions"), view)
    local slObj = scene.findObject("tank_skin_settings")
    if (::checkObj(slObj))
      guiScene.replaceContentFromText(slObj, data, data.len(), this)

    updateSkinSliders()
  }

  function updateSkinSliders()
  {
    if (!is_own || !is_unit_tank)
      return

    local have_premium = ::havePremium()
    local option = null

    option = ::get_option(::USEROPT_TANK_SKIN_CONDITION)
    local tscId = option.id
    local tscTrObj = scene.findObject("tr_" + tscId)
    if (::checkObj(tscTrObj))
    {
      tscTrObj.inactiveColor = have_premium? "no" : "yes"
      tscTrObj.tooltip = have_premium ? "" : ::loc("mainmenu/onlyWithPremium")
      local sliderObj = scene.findObject(tscId)
      local value = have_premium ? option.value : 0
      sliderObj.setValue(value)
      updateSkinConditionValue(value, sliderObj)
    }

    option = ::get_option(::USEROPT_TANK_CAMO_SCALE)
    local tcsId = option.id
    local tcsTrObj = scene.findObject("tr_" + tcsId)
    if (::checkObj(tcsTrObj))
    {
      local sliderObj = scene.findObject(tcsId)
      sliderObj.setValue(option.value)
      onChangeTankCamoScale(sliderObj)
    }

    option = ::get_option(::USEROPT_TANK_CAMO_ROTATION)
    local tcrId = option.id
    local tcrTrObj = scene.findObject("tr_" + tcrId)
    if (::checkObj(tcrTrObj))
    {
      local sliderObj = scene.findObject(tcrId)
      sliderObj.setValue(option.value)
      onChangeTankCamoRotation(sliderObj)
    }
  }

  function onChangeTankSkinCondition(obj)
  {
    if (!::checkObj(obj))
      return

    local oldValue = ::get_option(::USEROPT_TANK_SKIN_CONDITION).value
    local newValue = obj.getValue()
    if (oldValue == newValue)
      return

    if (!::havePremium())
    {
      obj.setValue(oldValue)
      return askBuyPremium(::Callback(updateSkinSliders, this))
    }

    updateSkinConditionValue(newValue, obj)
  }

  function updateSkinConditionValue(value, obj)
  {
    local textObj = scene.findObject("value_" + obj.id)
    if (!::checkObj(textObj))
      return

    textObj.setValue(((value + 100) / 2).tostring() + "%")
    ::hangar_set_tank_skin_condition(value)
  }

  function onChangeTankCamoScale(obj)
  {
    if (!::checkObj(obj))
      return

    local textObj = scene.findObject("value_" + obj.id)
    if (::checkObj(textObj))
    {
      local value = obj.getValue()
      ::hangar_set_tank_camo_scale(value / TANK_CAMO_SCALE_SLIDER_FACTOR)
      textObj.setValue((hangar_get_tank_camo_scale_result_value() * 100 + 0.5).tointeger().tostring() + "%")
    }
  }

  function onChangeTankCamoRotation(obj)
  {
    if (!::checkObj(obj))
      return

    local textObj = scene.findObject("value_" + obj.id)
    if (::checkObj(textObj))
    {
      local value = obj.getValue()
      local visualValue = value * 180 / 100
      textObj.setValue((visualValue > 0 ? "+" : "") + visualValue.tostring())
      ::hangar_set_tank_camo_rotation(value)
    }
  }

  function getSum(categoryList, category)
  {
    local sum = 0
    local end = categoryList[category][0].num

    for(local c = 0; c <= end && c < categoryList.len(); c++)
    {
      foreach(cg, mas in categoryList)
        if(mas[0].num == c)
          sum += mas[0].sum
    }
    return sum
  }

  function updateAttachablesSlots()
  {
    if (!access_Attachables)
      return

    local view = {buttons = []}
    for (local i = 0; i < ::g_decorator_type.ATTACHABLES.getMaxSlots(); i++)
    {
      local button = getViewButtonTable(i, ::g_decorator_type.ATTACHABLES)
      button.id = "slot_attach_" + i
      button.onClick = "onAttachableSlotClick"
      button.onDblClick = "onAttachableSlotDoubleClick"
      button.onDeleteClick = "onDeleteAttachable"
      view.buttons.append(button)
    }

    local dObj = scene.findObject("attachable_div")
    if (!::checkObj(dObj))
      return

    local attachListObj = dObj.findObject("slots_attachable_list")
    if (!::checkObj(attachListObj))
      return

    dObj.show(true)
    local data = ::handyman.renderCached("gui/commonParts/imageButton", view)

    guiScene.replaceContentFromText(attachListObj, data, data.len(), this)
    attachListObj.setValue(curAttachSlot)
  }

  function updateDecalSlots()
  {
    local view = {buttons = []}
    for (local i = 0; i < ::g_decorator_type.DECALS.getMaxSlots(); i++)
    {
      local button = getViewButtonTable(i, ::g_decorator_type.DECALS)
      button.id = "slot_" + i
      button.onClick = "onDecalSlotClick"
      button.onDblClick = "onDecalSlotDoubleClick"
      button.onDeleteClick = "onDeleteDecal"
      view.buttons.append(button)
    }

    local dObj = scene.findObject("slots_list")
    if (::checkObj(dObj))
    {
      local data = ::handyman.renderCached("gui/commonParts/imageButton", view)
      guiScene.replaceContentFromText(dObj, data, data.len(), this)
    }

    dObj.setValue(curSlot)
  }

  function getViewButtonTable(slotIdx, decoratorType)
  {
    local canEditDecals = is_own && previewSkinId == null
    local slot = getSlotInfo(slotIdx, false, decoratorType)
    local decalId = slot.decalId
    local decorator = ::g_decorator.getDecorator(decalId, decoratorType)
    local slotRatio = ::clamp(decoratorType.getRatio(decorator), 1, 2)
    local buttonTooltip = slot.isEmpty ? ::loc(decoratorType.emptySlotLocId) : ""
    if (!is_own)
      buttonTooltip = "#mainmenu/decalUnitLocked"
    else if (!canEditDecals)
      buttonTooltip = "#mainmenu/decalSkinLocked"
    else if (!slot.unlocked)
      buttonTooltip = "#mainmenu/onlyWithPremium"

    return {
      id = null
      onClick = null
      onDblClick = null
      onDeleteClick = null
      ratio = slotRatio
      statusLock = slot.unlocked? getStatusLockText(decorator) : "noPremium_" + slotRatio
      unlocked = slot.unlocked && (!decorator || decorator.isUnlocked())
      emptySlot = slot.isEmpty || !decorator
      image = decoratorType.getImage(decorator)
      tooltipText = buttonTooltip
      tooltipId = slot.isEmpty? null : ::g_tooltip_type.DECORATION.getTooltipId(decalId, decoratorType.unlockedItemType)
    }
  }

  function afterBuyAircraftModal()
  {
    initMainParams()
  }

  function onWrapUp(obj)
  {
    base.onWrapUp(obj)
    updateButtons(getCurrentFocusedType(), false)
  }

  function onWrapDown(obj)
  {
    base.onWrapDown(obj)
    updateButtons(getCurrentFocusedType(), false)
  }

  function updateButtons(decoratorType = null, needUpdateSlotDivs = true)
  {
    local profile_info = ::get_profile_info()

    local can_buyUnitOnline = ::canBuyUnitOnline(unit)
    local can_buyUnitIngame = !can_buyUnitOnline && ::canBuyUnit(unit)

    guiScene.setUpdatesEnabled(false, false)

    local bObj = showSceneBtn("btn_buy", can_buyUnitIngame)
    if (::checkObj(bObj) && can_buyUnitIngame)
    {
      ::placePriceTextToButton(scene,
                               "btn_buy",
                               ::loc("mainmenu/btnOrder"),
                               ::Cost(::wp_get_cost(unit.name), ::wp_get_cost_gold(unit.name)))

      ::showUnitDiscount(bObj.findObject("buy_discount"), unit)
    }

    local bOnlineObj = showSceneBtn("btn_buy_online", can_buyUnitOnline)
    if (::checkObj(bOnlineObj) && can_buyUnitOnline)
      ::showUnitDiscount(bOnlineObj.findObject("buy_online_discount"), unit)

    local bObj = scene.findObject("btn_buy_skin")
    if (::checkObj(bObj))
    {
      local canBuySkin = false
      local price = ::Cost()

      if (is_own && previewSkinId && skinList)
      {
        local skinIndex = ::find_in_array(skinList.values, previewSkinId, 0)
        local decorator = skinList.decorators[skinIndex]

        canBuySkin = decorator.canBuyUnlock(unit)
        price = decorator.getCost()
      }

      bObj.show(canBuySkin)
      if (canBuySkin)
        ::placePriceTextToButton(scene, "btn_buy_skin", ::loc("mainmenu/btnOrder"), price)
    }

    local can_testflight = ::isTestFlightAvailable(unit)
    local can_createUserSkin = ::can_save_current_skin_template()

    local bObj = scene.findObject("btn_load_userskin_sample")
    if (::checkObj(bObj))
      bObj.inactiveColor = can_createUserSkin ? "no" : "yes"

    local isInEditMode = currentState & decoratorEditState.EDITING
    local bObj = showSceneBtn("btn_back", !::show_console_buttons || isInEditMode || !isDecoratorsListOpen)
    if (::checkObj(bObj))
    {
      local isCancel = isInEditMode
      bObj.text = ::loc(isCancel ? "mainmenu/btnCancel" : "mainmenu/btnBack")
    }

    if (decoratorType == null)
      decoratorType = currentType

    local focusedType = getCurrentFocusedType()
    local focusedSlot = getSlotInfo(getCurrentDecoratorSlot(focusedType), true, focusedType)
    ::showBtnTable(scene, {
          btn_apply = currentState & decoratorEditState.EDITING

          btn_testflight = !isInEditMode && !isDecoratorsListOpen && can_testflight
          btn_info       = !isInEditMode && !isDecoratorsListOpen && ::isUnitDescriptionValid(unit)
          btn_weapons    = !isInEditMode && !isDecoratorsListOpen

          btn_decal_edit   = ::show_console_buttons && !isInEditMode && !isDecoratorsListOpen && !focusedSlot.isEmpty && focusedSlot.unlocked
          btn_decal_delete = ::show_console_buttons && !isInEditMode && !isDecoratorsListOpen && !focusedSlot.isEmpty && focusedSlot.unlocked

          skins_div = !isInEditMode && !isDecoratorsListOpen && (is_own || access_SkinsUnrestrictedPreview || access_SkinsUnrestrictedExport)
          user_skins_block = access_UserSkins
          tank_skin_settings = is_unit_tank

          slot_info = !isInEditMode && !isDecoratorsListOpen
          btn_dm_viewer = !isInEditMode && !isDecoratorsListOpen && ::dmViewer.canUse()
    })

    if (needUpdateSlotDivs)
      updateSlotsDivsVisibility(decoratorType)

    local isHangarLoaded = ::hangar_is_loaded()
    ::enableBtnTable(scene, {
          decalslots_div     = isHangarLoaded
          slots_list         = isHangarLoaded
          skins_navigator    = isHangarLoaded
          tank_skin_settings = isHangarLoaded
    })

    updateDecoratorActions(isInEditMode, decoratorType)
    guiScene.setUpdatesEnabled(true, true)

    if (needUpdateSlotDivs)
      updateFocusItem()
  }

  function updateFocusItem()
  {
    if (!isNavigationAllowed())
    {
      scene.findObject("screen_button").select() //remove focus rom all active elements
      needToRestoreFocusOnTypeList = true
      return
    }

    if (needToRestoreFocusOnTypeList)
    {
      local listId = currentType.listId
      guiScene.performDelayed(this, (@(listId) function() {
        setCurrentFocusObj(scene.findObject(listId))
      })(listId))
      needToRestoreFocusOnTypeList = false
    }
    else
      delayedRestoreFocus()
  }

  function isNavigationAllowed()
  {
    return !(currentState & decoratorEditState.EDITING)
  }

  function restoreFocus(checkPrimaryFocus = true)
  {
    if (isNavigationAllowed())
      base.restoreFocus(checkPrimaryFocus)
  }

  function updateDecoratorActions(show, decoratorType)
  {
    local hintsObj = showSceneBtn("decals_hint", show)
    if (show && ::checkObj(hintsObj))
    {
      ::showBtnTable(hintsObj, {
        decals_hint_rotate = decoratorType.canRotate()
        decals_hint_resize = decoratorType.canResize()
      })
    }

    local showMirror = show && decoratorType.canMirror()
    local mirrorBtnObj = showSceneBtn("btn_toggle_mirror", showMirror)
    if (showMirror)
      updateOnMirrorButton(mirrorBtnObj)

    local showAbsBf = show && decoratorType.canToggle()
    local absBfBtnObj = showSceneBtn("btn_toggle_bf", showAbsBf)
    if (showAbsBf)
      updateOnAbsButton(absBfBtnObj)
  }

  function updateSlotsDivsVisibility(decoratorType = null)
  {
    local inBasicMode = currentState & decoratorEditState.NONE
    local showDecalsSlotDiv = access_Decals && is_own
      && (inBasicMode || (decoratorType == ::g_decorator_type.DECALS && currentState & decoratorEditState.SELECT))

    local showAttachableSlotsDiv = access_Attachables && is_own
      && (inBasicMode || (decoratorType == ::g_decorator_type.ATTACHABLES && currentState & decoratorEditState.SELECT))

    ::showBtnTable(scene, {
      decalslots_div = showDecalsSlotDiv
      attachable_div = showAttachableSlotsDiv
    })
  }

  function onUpdate(obj, dt)
  {
    showLoadingRot(!::hangar_is_loaded())
  }

  function getCurrentDecoratorSlot(decoratorType)
  {
    if (decoratorType == ::g_decorator_type.UNKNOWN)
      return

    if (decoratorType == ::g_decorator_type.ATTACHABLES)
      return curAttachSlot

    return curSlot
  }

  function setCurrentDecoratorSlot(slotIdx, decoratorType)
  {
    if (decoratorType == ::g_decorator_type.DECALS)
      curSlot = slotIdx
    else if (decoratorType == ::g_decorator_type.ATTACHABLES)
      curAttachSlot = slotIdx
  }

  function onSkinOptionSelect(obj)
  {
    if (!::checkObj(scene))
      return

    updateButtons()
  }

  function onDecalSlotSelect(obj)
  {
    if (!::checkObj(obj))
      return

    local slotId = obj.getValue()

    setCurrentDecoratorSlot(slotId, ::g_decorator_type.DECALS)
    updateButtons(::g_decorator_type.DECALS)
  }

  function onDecalSlotActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (!::checkObj(childObj))
      return

    onDecalSlotClick(childObj)
  }

  function onAttachSlotSelect(obj)
  {
    if (!::checkObj(obj))
      return

    local slotId = obj.getValue()

    setCurrentDecoratorSlot(slotId, ::g_decorator_type.ATTACHABLES)
    updateButtons(::g_decorator_type.ATTACHABLES)
  }

  function onAttachableSlotActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (!::checkObj(childObj))
      return

    onAttachableSlotClick(childObj)
  }

  function onDecalSlotCancel(obj)
  {
    onBtnBack()
  }

  function openDecorationsListForSlot(slotId, actionObj, decoratorType)
  {
    if (!checkCurrentUnit())
      return

    if (!checkCurrentSkin())
      return

    if (!checkSlotIndex(slotId, decoratorType))
      return

    local prevSlotId = actionObj.getParent().getValue()
    if (isDecoratorsListOpen && slotId == prevSlotId)
      return

    setCurrentDecoratorSlot(slotId, decoratorType)
    currentState = decoratorEditState.SELECT

    if (prevSlotId != slotId)
      actionObj.getParent().setValue(slotId)
    else
      updateButtons(decoratorType)

    local slot = getSlotInfo(slotId, false, decoratorType)
    if (!slot.isEmpty && decoratorType != ::g_decorator_type.ATTACHABLES)
      decoratorType.specifyEditableSlot(slotId)

    generateDecorationsList(slot, decoratorType)
  }

  function checkCurrentUnit()
  {
    if (is_own)
      return true

    local onOkFunc = function() {}
    if (::canBuyUnit(unit))
      onOkFunc = (@(unit) function() { ::buyUnit(unit) })(unit)

    msgBox("unit_locked", ::loc("decals/needToBuyUnit"), [["ok", onOkFunc ]], "ok")
    return false
  }

  function checkCurrentSkin()
  {
    if (::u.isEmpty(previewSkinId) || !skinList)
      return true

    local skinIndex = ::find_in_array(skinList.values, previewSkinId, 0)
    local skinDecorator = skinList.decorators[skinIndex]
    local access = skinList.access[skinIndex]

    if (skinDecorator.canBuyUnlock(unit))
    {
      local priceText = skinDecorator.getCost().getTextAccordingToBalance()
      local msgText = ::loc("decals/needToBuySkin", { purchase = skinDecorator.getName(), cost = priceText })
      msgBox("skin_locked", msgText,
        [["ok", (@(previewSkinId) function() { buySkin(previewSkinId) })(previewSkinId) ],
        ["cancel", function() {} ]], "ok")
    }
    else
      msgBox("skin_locked", ::loc("decals/skinLocked"), [["ok", function() {} ]], "ok")
    return false
  }

  function checkSlotIndex(slotIdx, decoratorType)
  {
    if (slotIdx < 0)
      return false

    if (slotIdx < decoratorType.getAvailableSlots(unit))
      return true

    if (::has_feature("EnablePremiumPurchase"))
    {
      msgBox("no_premium", ::loc("decals/noPremiumAccount"),
           [["ok", function()
            {
               onOnlineShopPremium()
               saveDecorators(true)
            }],
           ["cancel", function() {} ]], "ok")
    }
    else
    {
      msgBox("premium_not_available", ::loc("charServer/notAvailableYet"),
           [["cancel"]], "cancel")
    }
    return false
  }

  function onAttachableSlotClick(obj)
  {
    if (!::checkObj(obj))
      return

    local slotName = ::getObjIdByPrefix(obj, "slot_attach_")
    local slotId = slotName ? slotName.tointeger() : -1

    openDecorationsListForSlot(slotId, obj, ::g_decorator_type.ATTACHABLES)
  }

  function onDecalSlotClick(obj)
  {
    if (!::checkObj(obj))
      return

    local slotName = ::getObjIdByPrefix(obj, "slot_")
    local slotId = slotName ? slotName.tointeger() : -1

    openDecorationsListForSlot(slotId, obj, ::g_decorator_type.DECALS)
  }

  function onDecalSlotDoubleClick(obj)
  {
    onDecoratorSlotDoubleClick(::g_decorator_type.DECALS)
  }

  function onAttachableSlotDoubleClick(obj)
  {
    onDecoratorSlotDoubleClick(::g_decorator_type.ATTACHABLES)
  }

  function onDecoratorSlotDoubleClick(type)
  {
    local slotIdx = getCurrentDecoratorSlot(type)
    local slotInfo = getSlotInfo(slotIdx, false, type)
    if (slotInfo.isEmpty)
      return

    local decorator = ::g_decorator.getDecorator(slotInfo.decalId, type)
    currentState = decoratorEditState.REPLACE
    enterEditDecalMode(slotIdx, decorator)
  }

  function generateDecorationsList(slot, decoratorType)
  {
    if (::u.isEmpty(slot)
        || decoratorType == ::g_decorator_type.UNKNOWN
        || currentState & decoratorEditState.NONE)
      return

    local wObj = scene.findObject("decals_list")
    if (!::checkObj(wObj))
      return

    currentType = decoratorType

    local view = { collapsableBlocks = [] }

    local categoriesOrder = ::g_decorator.getCachedOrderByType(decoratorType)
    if (::u.isEmpty(categoriesOrder))
    {
      ::dagor.debug("DecalMenu: Result of getCachedOrderByType for type " + decoratorType.name + " is empty. Skip build list.")
      ::getstackinfos(0)
      return
    }

    foreach (idx, category in categoriesOrder)
      view.collapsableBlocks.append({
        id = decoratorType.categoryWidgetIdPrefix + category
        headerText = decoratorType.categoryPathPrefix + category
        collapsed = true
        type = "decoratorsList"
        onSelect = "onDecoratorItemSelect"
        onActivate = "onDecoratorItemActivate"
        onCancelEdit = "onDecalItemCancel"
      })

    local data = ::handyman.renderCached("gui/commonParts/collapsableBlock", view)
    guiScene.replaceContentFromText(wObj, data, data.len(), this)
    wObj.height = decoratorType == ::g_decorator_type.ATTACHABLES
                  ? "1@countAttachablesInHeight * 1@decalIconHeight"
                  : "1@countDecalsInHeight * 1@decalIconHeight"
    wObj.setValue(0)

    showDecoratorsList()

    local selCategoryId = ""
    if (slot.isEmpty)
      selCategoryId = ::loadLocalByAccount(decoratorType.currentOpenedCategoryLocalSafePath, "")
    else
    {
      local decal = ::g_decorator.getDecorator(slot.decalId, decoratorType)
      selCategoryId = decal ? decal.category : ""
    }

    if (selCategoryId != "")
    {
      local categoryObj = wObj.findObject(decoratorType.categoryWidgetIdPrefix + selCategoryId)
      if (::checkObj(categoryObj))
        onDecalCategoryClick(categoryObj)
    }
    else
      updateButtons(decoratorType)
  }

  function generateDecalCategoryContent(categoryId, decoratorType)
  {
    local curSlotDecalId = getSlotInfo(getCurrentDecoratorSlot(decoratorType), false, decoratorType).decalId
    local decoratorsData = ::g_decorator.getCachedDecoratorsDataByType(decoratorType)

    if (!(categoryId in decoratorsData))
      return ""

    local view = { buttons = [] }
    foreach (decorator in decoratorsData[categoryId])
      view.buttons.append(generateDecalButton(curSlotDecalId, decorator, decoratorType))

    return ::handyman.renderCached("gui/commonParts/imageButton", view)
  }

  function generateDecalButton(curSlotDecalId, decorator, decoratorType)
  {
    local statusLock = getStatusLockText(decorator)
    local lockCountryImg = ::get_country_flag_img("decal_locked_" + ::getUnitCountry(unit))
    local unitLocked = decorator.getUnitTypeLockIcon()
    local cost = decorator.canBuyUnlock(unit) ? decorator.getCost().getTextAccordingToBalance() : null
    local leftAmount = decorator.limit - decorator.getCountOfUsingDecorator(unit)

    return {
      id = "decal_" + decorator.id
      highlighted = decorator.id == curSlotDecalId
      onClick = "onDecoratorItemClick"
      onDblClick = "onDecalItemDoubleClick"
      ratio = ::clamp(decoratorType.getRatio(decorator), 1, 2)
      unlocked = decorator.canUse(unit)
      image = decoratorType.getImage(decorator)
      tooltipId = ::g_tooltip_type.DECORATION.getTooltipId(decorator.id, decoratorType.unlockedItemType)
      cost = cost
      statusLock = statusLock
      unitLocked = unitLocked
      leftAmount = leftAmount
      limit = decorator.limit
      unitLocked = unitLocked
      isMax = leftAmount <= 0
      showLimit = decorator.limit > 0 && !statusLock && !cost && !unitLocked
      lockCountryImg = lockCountryImg
    }
  }

  function getStatusLockText(decorator)
  {
    if (!decorator)
      return null

    if (decorator.canUse(unit))
      return null

    if (decorator.isLockedByCountry(unit))
      return "country"

    if (decorator.isLockedByUnit(unit))
      return "achievement"

    if (decorator.lockedByDLC)
      return "noDLC"

    if (!decorator.isUnlocked() && !decorator.canBuyUnlock(unit))
      return "achievement"

    return null
  }

  function getDecalAccessData(decal)
  {
    local text = []
    if (!decal || decal.canUse(unit))
      return ""

    if (decal.isLockedByCountry(unit))
      text.append(::loc("mainmenu/decalNotAvailable"))

    if (decal.isLockedByUnit(unit))
    {
      local unitsList = []
      foreach(unitName in decal.units)
        unitsList.append(::colorize("userlogColoredText", ::getUnitName(unitName)))
      text.append(::loc("mainmenu/decoratorAvaiblableOnlyForUnit", {
        decoratorName = ::colorize("activeTextColor", decal.getName()),
        unitsList = ::implode(unitsList, ",")}))
    }

    if (decal.lockedByDLC != null)
      text.append(::format(::loc("mainmenu/decalNoCampaign"), ::loc("charServer/entitlement/" + decal.lockedByDLC)))

    if (!text.len() && !decal.isUnlocked() && !decal.canBuyUnlock(unit))
      text.append(::loc("mainmenu/decalNoAchievement"))

    return ::implode(text, ", ")
  }

  function onDecoratorItemSelect(obj)
  {
    local categoryId = ::getObjIdByPrefix(obj, "collapse_content_" + currentType.categoryWidgetIdPrefix)
    scrollDecalsCategory(categoryId, currentType)
    updateButtons(null, false)
  }

  function getSelectedDecal(decoratorType)
  {
    local listObj = getCurDecalsListObj()
    if (!::checkObj(listObj))
      return null

    local value = listObj.getValue()
    local decalObj = (value >= 0 && value < listObj.childrenCount()) ? listObj.getChild(value) : null
    return getDecalInfoByObj(decalObj, decoratorType)
  }

  function getDecalInfoByObj(obj, decoratorType)
  {
    if (!::checkObj(obj))
      return null

    local decalId = ::getObjIdByPrefix(obj, "decal_") || ""

    return ::g_decorator.getDecorator(decalId, decoratorType)
  }

  function onDecoratorItemActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    onDecoratorItemClick(childObj)
  }

  function onDecalItemCancel(obj)
  {
    toggleDecalsCategory(currentType, null, false)
    local categoriesObj = getObj("decals_list")
    setCurrentFocusObj(categoriesObj)
  }

  function onDecoratorItemClick(obj)
  {
    local decorator = getDecalInfoByObj(obj, currentType)
    if (!decorator)
      return

    local decoratorsListObj = obj.getParent()
    if (decoratorsListObj.getValue() != decorator.catIndex)
      decoratorsListObj.setValue(decorator.catIndex)

    if (decorator.isOutOfLimit(unit))
      return ::g_popups.add("", ::loc("mainmenu/decoratorExceededLimit", {limit = decorator.limit}))

    local curSlotIdx = getCurrentDecoratorSlot(currentType)
    local isDecal = currentType == ::g_decorator_type.DECALS
    if (isDecal)
    {
      local restrictionText = getDecalAccessData(decorator)
      if (restrictionText != "")
        return ::g_popups.add("", restrictionText)

      if (decorator.canBuyUnlock(unit))
        return askBuyDecorator(decorator, (@(curSlotIdx, decorator) function() {
                                            enterEditDecalMode(curSlotIdx, decorator)
                                          })(curSlotIdx, decorator))
    }

    isDecoratorItemUsed = true

    if (isDecal)
    {
      //getSlotInfo is too slow for decals (~150ms)(because of code func hangar_get_decal_in_slot),
      // so it better to use as last check, so not to worry with lags
      local slotInfo = getSlotInfo(curSlotIdx, false, currentType)
      if (!slotInfo.isEmpty && decorator.id != slotInfo.decalId)
      {
        currentState = decoratorEditState.REPLACE
        currentType.replaceDecorator(curSlotIdx, decorator.id)
        return installDecorationOnUnit(decorator)
      }
    }

    currentState = decoratorEditState.ADD
    enterEditDecalMode(curSlotIdx, decorator)
  }

  function onDecalItemDoubleClick(obj)
  {
    if (!checkObj(obj))
      return

    local decalId = ::getObjIdByPrefix(obj, "decal_") || ""

    local decal = ::g_decorator.getDecorator(decalId, currentType)
    if (!decal)
      return

    if (!decal.canUse(unit))
      return

    local slotIdx = getCurrentDecoratorSlot(currentType)
    local slotInfo = getSlotInfo(slotIdx, false, currentType)
    if (!slotInfo.isEmpty)
      enterEditDecalMode(slotIdx, decal)
  }

  function onCollapse(obj)
  {
    if (!checkObj(obj))
      return
    local categoryObj = obj.getParent().getParent()
    onDecalCategoryClick(categoryObj)
  }

  function onDecalCategoryActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (!::checkObj(childObj))
      return

    onDecalCategoryClick(childObj)
  }

  function onDecalCategoryCancel(obj)
  {
    onBtnCloseDecalsMenu()
  }

  function onDecalCategoryClick(obj)
  {
    local categoryId = ::getObjIdByPrefix(obj, currentType.categoryWidgetIdPrefix)
    if (!categoryId)
      return

    local categoriesOrder = ::g_decorator.getCachedOrderByType(currentType)
    local index = ::find_in_array(categoriesOrder, categoryId)
    if (obj.getParent().getValue() != index)
      obj.getParent().setValue(index)

    local show = obj.collapsed == "yes"
    toggleDecalsCategory(currentType, categoryId, show)
  }

  function toggleDecalsCategory(decoratorType, categoryId = null, show = true)
  {
    local wObj = scene.findObject("decals_list")
    if (!::checkObj(wObj))
      return

    local categoriesOrder = ::g_decorator.getCachedOrderByType(decoratorType)
    foreach (idx, category in categoriesOrder)
    {
      local categoryBlockId = decoratorType.categoryWidgetIdPrefix + category
      local categoryObj = wObj.findObject(categoryBlockId)
      if (!::checkObj(categoryObj))
        continue

      local isToggledCategory = category == categoryId

      local isOpen = categoryObj.collapsed == "no"
      local open = isToggledCategory ? show : false

      if (open == isOpen)
        continue

      local decalsListObj = categoryObj.findObject("collapse_content_" + categoryBlockId)
      if (!::checkObj(decalsListObj))
        return

      categoryObj.collapsed = open ? "no" : "yes"
      decalsListObj.show(open)

      local data = open ? generateDecalCategoryContent(category, decoratorType) : ""
      guiScene.replaceContentFromText(decalsListObj, data, data.len(), this)

      if (isToggledCategory && open)
      {
        ::saveLocalByAccount(decoratorType.currentOpenedCategoryLocalSafePath, categoryId)

        local decalId = getSlotInfo(getCurrentDecoratorSlot(decoratorType), false, decoratorType).decalId
        local decal = ::g_decorator.getDecorator(decalId, decoratorType)
        local index = decal && decal.category == category? decal.catIndex : 0
        editableDecoratorId = decal? decalId : null

        decalsListObj.setValue(index)
        setCurrentFocusObj(decalsListObj)

        scrollDecalsCategory(categoryId, decoratorType)
      }
    }
  }

  function scrollDecalsCategory(categoryId, decoratorType)
  {
    if (!categoryId)
      return

    local categoryBlockId = decoratorType.categoryWidgetIdPrefix + categoryId
    local categoryObj = scene.findObject(categoryBlockId)
    if (!::checkObj(categoryObj))
      return

    guiScene.setUpdatesEnabled(true, true)

    local decalsListObj = categoryObj.findObject("collapse_content_" + categoryBlockId)
    local index = (::checkObj(decalsListObj) && decalsListObj.childrenCount()) ? decalsListObj.getValue() : -1
    local itemObj = (index >= 0) ? decalsListObj.getChild(index) : null

    if (::checkObj(itemObj))
    {
      local id = itemObj.id
      guiScene.performDelayed(this, (@(id) function() {
        if (!::checkObj(scene))
          return

        local itemObj = scene.findObject(id)
        if (!::checkObj(itemObj))
          return

        guiScene.setUpdatesEnabled(true, true)
        itemObj.scrollToView()
      })(id))
    }
    else
    {
      local headerObj = categoryObj.findObject("btn_" + categoryBlockId)
      if (::checkObj(headerObj))
        headerObj.scrollToView()
    }
  }

  function onBtnAccept()
  {
    stopDecalEdition(true)
  }

  function onBtnBack()
  {
    if (currentState & decoratorEditState.NONE)
      return goBack()

    if (currentState & decoratorEditState.SELECT)
      return onBtnCloseDecalsMenu()

    editableDecoratorId = null
    if (currentType == ::g_decorator_type.ATTACHABLES
        && currentState & (decoratorEditState.REPLACE | decoratorEditState.EDITING | decoratorEditState.PURCHASE))
      ::hangar_force_reload_model()
    stopDecalEdition()
  }

  function getDecorationTooltipObjText(id, decoratorType)
  {
    local tooltipId = ::g_tooltip_type.DECORATION.getTooltipId(id, decoratorType)
    return "tooltipObj {" +
         "tooltipId:t='" + tooltipId + "'; " +
         "on_tooltip_open:t='onGenericTooltipOpen'; on_tooltip_close:t='onTooltipObjClose';" +
         "max-width:t='8*@decalIconHeight+10*@sf/@pf'; tinyFont:t='yes'; display:t='hide';" +
      "} " +
      "title:t='$tooltipObj'; "
  }

  function buyDecorator(decorator, afterPurchDo = null)
  {
    if (!::check_balance_msgBox(decorator.getCost()))
      return false

    decorator.decoratorType.save(unit.name, false)

    local afterSuccessFunc = ::Callback((@(decorator, afterPurchDo) function() {
      ::update_gamercards()
      updateSelectedCategory(decorator)
      if (afterPurchDo)
        afterPurchDo()
    })(decorator, afterPurchDo), this)

    decorator.decoratorType.buyFunc(unit.name, decorator.id, afterSuccessFunc)
    return true
  }

  function updateSelectedCategory(decorator)
  {
    if (!isDecoratorsListOpen)
      return

    local categoryBlockId = decorator.decoratorType.categoryWidgetIdPrefix + decorator.category
    local categoryObj = getObj(categoryBlockId)

    if (!::checkObj(categoryObj) || categoryObj.collapsed != "no" )
      return

    local decalsListObj = categoryObj.findObject("collapse_content_" + categoryBlockId)
    if (::checkObj(decalsListObj))
    {
      local data = generateDecalCategoryContent(decorator.category, decorator.decoratorType)
      guiScene.replaceContentFromText(decalsListObj, data, data.len(), this)
      decalsListObj.getChild(decalsListObj.getValue()).selected = "yes"
    }
  }

  function enterEditDecalMode(slotIdx, decorator)
  {
    if ((currentState & decoratorEditState.EDITING) || !decorator)
      return

    local decoratorType = decorator.decoratorType
    decoratorType.specifyEditableSlot(slotIdx)

    if (!decoratorType.enterEditMode(decorator.id))
      return

    currentState = decoratorEditState.EDITING
    editableDecoratorId = decorator.id
    updateSceneOnEditMode(true, decoratorType)
  }

  function updateSceneOnEditMode(isInEditMode, decoratorType, contentUpdate = false)
  {
    if (decoratorType == ::g_decorator_type.DECALS)
      ::dmViewer.update()

    local slotInfo = getSlotInfo(getCurrentDecoratorSlot(decoratorType), true, decoratorType)
    if (contentUpdate)
    {
      updateSlotsBlockByType(decoratorType)
      if (isDecoratorItemUsed)
        generateDecorationsList(slotInfo, decoratorType)
    }

    showDecoratorsList()

    updateButtons(decoratorType)

    if (!isInEditMode)
      isDecoratorItemUsed = false
  }

  function stopDecalEdition(save = false)
  {
    if (!(currentState & decoratorEditState.EDITING))
      return

    local decorator = g_decorator.getDecorator(editableDecoratorId, currentType)
    if (!save || !decorator)
    {
      currentType.exitEditMode(false, false, ::Callback(afterStopDecalEdition, this))
      return
    }

    if (decorator.canBuyUnlock(unit))
      return askBuyDecoratorOnExitEditMode(decorator)

    local restrictionText = getDecalAccessData(decorator)
    if (restrictionText != "")
      return ::g_popups.add("", restrictionText)

    setDecoratorInSlot(decorator)
  }

  function askBuyDecoratorOnExitEditMode(decorator)
  {
    if (!currentType.exitEditMode(true, false,
              ::Callback((@(decorator) function() {
                          askBuyDecorator(decorator, function()
                            {
                              ::hangar_save_current_attachables()
                            })
                        })(decorator), this)))
      showFailedInstallPopup()
  }

  function askBuyDecorator(decorator, afterPurchDo = null)
  {
    local msgText = ::loc("shop/needMoneyQuestion_purchaseDecal", {
      purchase = ::colorize("userlogColoredText", decorator.getName()),
      cost = decorator.getCost().getTextAccordingToBalance()
    })
    msgBox("buy_decorator_on_preview", msgText,
      [["ok", (@(decorator, afterPurchDo) function() {
          currentState = decoratorEditState.PURCHASE
          if (!buyDecorator(decorator, afterPurchDo))
            return forceResetInstalledDecorators()

          local unlocked = decorator? decorator.isUnlocked() : false
          ::dmViewer.update()
          onFinishInstallDecoratorOnUnit(true)
        })(decorator, afterPurchDo)],
      ["cancel", onBtnBack]], "ok")
  }

  function forceResetInstalledDecorators()
  {
    currentType.removeDecorator(getCurrentDecoratorSlot(currentType), true)
    if (currentType == ::g_decorator_type.ATTACHABLES)
    {
      ::hangar_force_reload_model()
    }
    afterStopDecalEdition()
  }

  function setDecoratorInSlot(decorator)
  {
    if (!installDecorationOnUnit(decorator))
      return showFailedInstallPopup()

    if (currentType == ::g_decorator_type.DECALS)
      ::req_unlock_by_client("decal_applied", false)
  }

  function showFailedInstallPopup()
  {
    ::g_popups.add("", ::loc("mainmenu/failedInstallAttachable"))
  }

  function afterStopDecalEdition()
  {
    currentState = isDecoratorsListOpen? decoratorEditState.SELECT : decoratorEditState.NONE
    updateSceneOnEditMode(false, currentType)
  }

  function installDecorationOnUnit(decorator)
  {
    local unlocked = decorator? decorator.isUnlocked() : false
    return currentType.exitEditMode(true, unlocked,
      ::Callback( function () { onFinishInstallDecoratorOnUnit(true) }, this))
  }

  function onFinishInstallDecoratorOnUnit(isInstalled = false)
  {
    if (!isInstalled)
      return

    currentState = isDecoratorsListOpen? decoratorEditState.SELECT : decoratorEditState.NONE
    updateSceneOnEditMode(false, currentType, true)
  }

  function onOnlineShopEagles()
  {
    if (::has_feature("EnableGoldPurchase"))
      startOnlineShop("eagles", afterReplenishCurrency)
    else
      ::showInfoMsgBox(::loc("msgbox/notAvailbleGoldPurchase"))
  }

  function onOnlineShopLions()
  {
    startOnlineShop("warpoints", afterReplenishCurrency)
  }

  function onOnlineShopPremium()
  {
    startOnlineShop("premium", checkPremium)
  }

  function checkPremium()
  {
    if (!::havePremium())
      return

    ::update_gamercards()
    updateSlotsBlockByType()
    updateSkinSliders()
  }

  function afterReplenishCurrency()
  {
    if (!::checkObj(scene))
      return

    updateMainGuiElements()
  }

  function onSkinChange(obj)
  {
    local skinNum = obj.getValue()
    if (!skinList || !(skinNum in skinList.values))
    {
      ::callstack()
      ::dagor.assertf(false, "Error: try to set incorrect skin " + skinList + ", value = " + skinNum)
      return
    }

    local skinId = skinList.values[skinNum]
    local isSkinOwn = skinList.access[skinNum].isOwn

    if (isSkinOwn)
    {
      local curSkinId = ::hangar_get_last_skin(unit.name)
      if (previewSkinId
        || skinId != curSkinId && (skinId != "" || curSkinId != "default"))
      applySkin(skinId)
    }
    else if (skinId != previewSkinId)
      applySkin(skinId, true)
  }

  function onUserSkinChanged(obj)
  {
    local value = obj.getValue()
    local prevValue = ::get_option(::USEROPT_USER_SKIN).value
    if (prevValue == value)
      return

    ::set_option(::USEROPT_USER_SKIN, value)
    ::hangar_force_reload_model()
  }

  function applySkin(skinId, previewSkin = false)
  {
    if (previewSkin)
      ::hangar_apply_skin_preview(skinId)
    else
      ::hangar_apply_skin(skinId)

    previewSkinId = previewSkin? skinId : null

    if (!previewSkin)
    {
      ::save_online_single_job(3210)
      ::save_profile(false)
    }
  }

  function onBuySkin()
  {
    local skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
    local previewSkinDecorator = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
    if (!previewSkinDecorator)
      return

    local cost = previewSkinDecorator.getCost()
    local msgText = ::loc("shop/needMoneyQuestion_purchaseSkin",
                          { purchase = previewSkinDecorator.getName(),
                            cost = cost.getTextAccordingToBalance()
                          })

    msgBox("need_money", msgText,
          [["ok", (@(previewSkinId, cost) function() {
            if (::check_balance_msgBox(cost))
              buySkin(previewSkinId)
          })(previewSkinId, cost)],
          ["cancel", function() {} ]], "ok")
  }

  function buySkin(skinName)
  {
    local afterSuccessFunc = ::Callback((@(skinName) function() {
        ::update_gamercards()
        applySkin(skinName)
        updateMainGuiElements()
      })(skinName), this)

    ::g_decorator_type.SKINS.buyFunc(unit.name, skinName, afterSuccessFunc)
  }

  function getSlotInfo(slotId, checkDecalsList = false, decoratorType = null)
  {
    local isValid = 0 <= slotId
    local decalId = ""
    if (checkDecalsList && isDecoratorsListOpen && slotId == getCurrentDecoratorSlot(decoratorType))
    {
      local decal = getSelectedDecal(decoratorType)
      if (decal)
        decalId = decal.id
    }

    if (decalId == "" && isValid && decoratorType != null)
    {
      local liveryName = getSelectedBuiltinSkinId()
      decalId = decoratorType.getDecoratorNameInSlot(slotId, unit.name, liveryName, false)
      isValid = isValid && slotId < decoratorType.getMaxSlots()
    }

    return {
      id = isValid ? slotId : -1
      unlocked = isValid && slotId < decoratorType.getAvailableSlots(unit)
      decalId = decalId
      isEmpty = !decalId.len()
    }
  }

  function showLoadingRot(flag)
  {
    if (isLoadingRot == flag)
      return

    isLoadingRot = flag
    scene.findObject("loading_rot").show(flag)

    updateMainGuiElements()
  }

  function onTestFlight()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true }))
      return

    local afterCloseFunc = (@(owner, unit) function() {
      owner.previewSkinId = null
      local newUnitName = ::get_show_aircraft_name()
      if (unit.name != newUnitName)
      {
        owner.unit = ::getAircraftByName(newUnitName)
        if (owner && ("initMainParams" in owner) && owner.initMainParams)
          owner.initMainParams.call(owner)
      }
    })(owner, unit)

    saveDecorators(false)
    checkedNewFlight((@(afterCloseFunc) function() {
      ::test_flight_aircraft <- unit
      ::gui_start_testflight(afterCloseFunc)
    })(afterCloseFunc))
  }

  function onBuy()
  {
    ::buyUnit(unit)
  }

  function onBuyUnitOnline()
  {
    OnlineShopModel.showGoods({
      unitName = unit.name
    })
  }

  function onEventUnitBought(params)
  {
    initMainParams()
  }

  function onEventUnitRented(params)
  {
    initMainParams()
  }

  function onBtnDecoratorEdit()
  {
    currentType = getCurrentFocusedType()
    local curSlotIdx = getCurrentDecoratorSlot(currentType)
    local slotInfo = getSlotInfo(curSlotIdx, true, currentType)
    local decorator = ::g_decorator.getDecorator(slotInfo.decalId, currentType)
    enterEditDecalMode(curSlotIdx, decorator)
  }

  function onBtnDeleteDecal()
  {
    local decoratorType = getCurrentFocusedType()
    deleteDecorator(decoratorType, getCurrentDecoratorSlot(decoratorType))
  }

  function onDeleteDecal(obj)
  {
    if (!::checkObj(obj))
      return

    local slotName = ::getObjIdByPrefix(obj.getParent(), "slot_")
    local slotId = slotName.tointeger()

    deleteDecorator(::g_decorator_type.DECALS, slotId)
  }

  function onDeleteAttachable(obj)
  {
    if (!::checkObj(obj))
      return

    local slotName = ::getObjIdByPrefix(obj.getParent(), "slot_attach_")
    local slotId = slotName.tointeger()

    deleteDecorator(::g_decorator_type.ATTACHABLES, slotId)
  }

  function deleteDecorator(decoratorType, slotId)
  {
    local slotInfo = getSlotInfo(slotId, false, decoratorType)
    msgBox("delete_decal", ::loc(decoratorType.removeDecoratorLocId, {name = decoratorType.getLocName(slotInfo.decalId)}),
    [
      ["ok", (@(decoratorType, slotInfo) function() {
          decoratorType.removeDecorator(slotInfo.id, true)
          ::save_profile(false)

          generateDecorationsList(slotInfo, decoratorType)
          updateSlotsBlockByType(decoratorType)
          updateButtons(decoratorType, false)
        })(decoratorType, slotInfo)
      ],
      ["cancel", function(){} ]
    ], "cancel")
  }

  function updateSlotsBlockByType(decoratorType = ::g_decorator_type.UNKNOWN)
  {
    local all = decoratorType == ::g_decorator_type.UNKNOWN
    if (all || decoratorType == ::g_decorator_type.ATTACHABLES)
      updateAttachablesSlots()

    if (all || decoratorType == ::g_decorator_type.DECALS)
      updateDecalSlots()

    updatePenaltyText()
  }

  function onShowCrew()
  {
    if (::show_crew==null)
      return
    local crew = get_crew_by_id(::show_crew)
    if (crew)
      ::gui_modal_crew(crew.countryId, crew.idInCountry)
  }

  function onWeaponsInfo(obj)
  {
    ::aircraft_for_weapons = unit.name
    ::gui_modal_weapons(afterBuyAircraftModal)
  }

  function onMirror(obj)
  {
    hangar_mirror_current_decal()
    updateOnMirrorButton(obj)
  }

  function updateOnMirrorButton(obj)
  {
    local enabled = get_hangar_mirror_current_decal()
    local icon = "#ui/gameuiskin#btn_flip_decal" + (enabled ? "_active" : "")
    local btnObj = obj.findObject("btn_toggle_mirror_img")
    btnObj["background-image"] = icon
    btnObj.getParent().active = enabled ? "yes" : "no"
  }

  function onAbs(obj)
  {
    hangar_toggle_abs()
    updateOnAbsButton(obj)
  }

  function updateOnAbsButton(obj)
  {
    local enabled = get_hangar_abs()
    local icon = "#ui/gameuiskin#btn_two_sided_printing" + (enabled ? "_active" : "")
    local btnObj = obj.findObject("btn_toggle_bf_img")
    btnObj["background-image"] =  icon
    btnObj.getParent().active = enabled ? "yes" : "no"
  }

  function onInfo()
  {
    if (::has_feature("WikiUnitInfo"))
      ::open_url(::format(::loc("url/wiki_objects"), unit.name), false, false, "customization_wnd")
    else
      ::gui_start_aircraft_info(unit.name)
  }

  function clearCurrentDecalSlotAndShow()
  {
    if (!::checkObj(scene))
      return

    updateSlotsBlockByType()
  }

  function saveDecorators(withProgressBox = false)
  {
    ::g_decorator_type.DECALS.save(unit.name, withProgressBox)
    ::g_decorator_type.ATTACHABLES.save(unit.name, withProgressBox)
  }

  function showDecoratorsList()
  {
    local show = !!(currentState & decoratorEditState.SELECT)

    isDecoratorsListOpen = show
    local slotsObj = scene.findObject(currentType.listId)
    if (::checkObj(slotsObj))
    {
      local sel = slotsObj.getValue()
      for (local i = 0; i < slotsObj.childrenCount(); i++)
      {
        local selectedItem = sel == i && show
        slotsObj.getChild(i).highlighted = selectedItem? "yes" : "no"
      }
    }

    ::hangar_notify_decal_menu_visibility(show)

    local mObj = scene.findObject("decals_wnd")
    if (!::checkObj(mObj))
      return

    mObj.show(show)

    local headerObj = mObj.findObject("decals_wnd_header")
    if (::checkObj(headerObj))
      headerObj.setValue(::loc(currentType.listHeaderLocId))

    local focusObj = show ? getCurDecalsListObj(false) : slotsObj
    if (::checkObj(focusObj))
      setCurrentFocusObj(focusObj)
  }

  function onScreenClick()
  {
    if (currentState == decoratorEditState.NONE)
      return

    if (currentState == decoratorEditState.EDITING)
      return stopDecalEdition(true)

    local curSlotIdx = getCurrentDecoratorSlot(currentType)
    local curSlotInfo = getSlotInfo(curSlotIdx, false, currentType)
    if (curSlotInfo.isEmpty)
      return

    local curSlotDecoratorId = curSlotInfo.decalId
    if (curSlotDecoratorId == "")
      return

    local curSlotDecorator = ::g_decorator.getDecorator(curSlotDecoratorId, currentType)
    enterEditDecalMode(curSlotIdx, curSlotDecorator)
  }

  function onBtnCloseDecalsMenu()
  {
    currentState = decoratorEditState.NONE
    showDecoratorsList()
    currentType = ::g_decorator_type.UNKNOWN
    updateButtons()
  }

  function goBack()
  {
    if (unit)
    {
      if (currentState & decoratorEditState.EDITING)
        currentType.exitEditMode(false, false)

      saveDecorators(true)
      ::save_profile(true)

      if (previewSkinId)
      {
        applySkin(::hangar_get_last_skin(unit.name), true)
        previewSkinId = null
      }
    }

    guiScene.performDelayed(this, base.goBack)
  }

  function onAirInfoToggleDMViewer(obj)
  {
    ::dmViewer.toggle(obj.getValue())
  }

  function onDestroy()
  {
    ::hangar_exit_decal_mode(false)
    ::hangar_set_current_decal_slot(-1)
    ::hangar_apply_skin_preview(::hangar_get_last_skin(unit.name))
  }

  function getCurrentFocusedType()
  {
    local obj = getFocusItemObj(currentFocusItem, false)
    if (obj)
      return ::g_decorator_type.getTypeByListId(obj.id)
    return ::g_decorator_type.UNKNOWN
  }

  function canShowDmViewer()
  {
    return currentState && !(currentState & decoratorEditState.EDITING)
  }

  function updatePenaltyText()
  {
    local show = ::is_decals_disabled()
    local objText = showSceneBtn("decal_text_area", show)
    if (!::checkObj(objText) || !show)
      return

    local txt = ""
    local time = ::get_time_till_decals_disabled()
    if (time == 0)
    {
      local st = ::get_player_penalty_status()
      if ("seconds_left" in st)
        time = st.seconds_left
    }

    if (time == 0)
      txt = ::format(::loc("charServer/decal/permanent"))
    else
      txt = ::format(::loc("charServer/decal/timed"), ::hoursToString(time/TIME_HOUR_IN_SECONDS_F, false))
    objText.setValue(txt)
  }
}
