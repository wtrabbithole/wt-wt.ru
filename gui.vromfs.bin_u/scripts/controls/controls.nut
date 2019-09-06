local gamepadIcons = require("scripts/controls/gamepadIcons.nut")
local globalEnv = require_native("globalEnv")
local controllerState = require_native("controllerState")
local time = require("scripts/time.nut")

local shortcutsListModule = require("scripts/controls/shortcutsList/shortcutsList.nut")
local shortcutsAxisListModule = require("scripts/controls/shortcutsList/shortcutsAxis.nut")

::MAX_SHORTCUTS <- 3
::preset_changed <- false
::ps4ControlsModeActivatedParamName <- "ps4ControlsAdvancedModeActivated"
::hotas4_device_id <- "044F:B67B"
::hotas_one_device_id <- "044F:B68C"

::shortcuts_not_change_by_preset <- [
  "ID_INTERNET_RADIO", "ID_INTERNET_RADIO_PREV", "ID_INTERNET_RADIO_NEXT",
  "ID_PTT"
]

enum ConflictGroups {
  PLANE_FIRE,
  HELICOPTER_FIRE,
  TANK_FIRE,
  UFO_FIRE
}

::shortcutsList <- shortcutsListModule.types

function get_shortcut_by_id(shortcutId)
{
  return ::getTblValue(shortcutId, shortcutsListModule)
}

::autorestore_axis_table <- {
  ["AXIS_DECAL_MOVE_X"] = {
    type = ::AXIS_DECAL_MOVE_X
    id = 0 //gamepad - left stick - horizontal axis
  },
  ["AXIS_DECAL_MOVE_Y"] = {
    type = ::AXIS_DECAL_MOVE_Y
    id = 1 //gamepad - left stick - verical axis
  },
  ["AXIS_HANGAR_CAMERA_X"] = {
    type = ::AXIS_HANGAR_CAMERA_X
    id = 2 //gamepad - right stick - horizontal axis
  },
  ["AXIS_HANGAR_CAMERA_Y"] = {
    type = ::AXIS_HANGAR_CAMERA_Y
    id = 3 //gamepad - right stick - vertical axis
  }
}

function can_change_helpers_mode()
{
  if (!::is_in_flight())
    return true

  local missionBlk = ::DataBlock()
  ::get_current_mission_info(missionBlk)

  foreach(part, block in ::tutorials_to_check)
    if(block.tutorial == missionBlk.name)
      return false
  return true
}

function reset_default_control_settings()
{
  ::set_option_multiplier(::OPTION_AILERONS_MULTIPLIER,         0.79); //::USEROPT_AILERONS_MULTIPLIER
  ::set_option_multiplier(::OPTION_ELEVATOR_MULTIPLIER,         0.64); //::USEROPT_ELEVATOR_MULTIPLIER
  ::set_option_multiplier(::OPTION_RUDDER_MULTIPLIER,           0.43); //::USEROPT_RUDDER_MULTIPLIER
  ::set_option_multiplier(::OPTION_HELICOPTER_CYCLIC_ROLL_MULTIPLIER,   0.79); //
  ::set_option_multiplier(::OPTION_HELICOPTER_CYCLIC_PITCH_MULTIPLIER,  0.64); //
  ::set_option_multiplier(::OPTION_HELICOPTER_PEDALS_MULTIPLIER,        0.43); //
  ::set_option_multiplier(::OPTION_ZOOM_SENSE,                  0); //::USEROPT_ZOOM_SENSE
  ::set_option_multiplier(::OPTION_MOUSE_SENSE,                 0.5); //::USEROPT_MOUSE_SENSE
  ::set_option_multiplier(::OPTION_MOUSE_AIM_SENSE,             0.5); //::USEROPT_MOUSE_AIM_SENSE
  ::set_option_multiplier(::OPTION_GUNNER_VIEW_SENSE,           1); //::USEROPT_GUNNER_VIEW_SENSE
  ::set_option_multiplier(::OPTION_ATGM_AIM_SENS_HELICOPTER,    1);
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_DEADZONE,     0.1); //mouseJoystickDeadZone
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_DEADZONE,     0.1);
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENSIZE,   0.6); //mouseJoystickScreenSize
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENSIZE,   0.6);
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SENSITIVITY,  2); //mouseJoystickSensitivity
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SENSITIVITY,  2);
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENPLACE,  0); //mouseJoystickScreenPlace
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_JOYSTICK_SCREENPLACE,  0);
  ::set_option_multiplier(::OPTION_MOUSE_AILERON_RUDDER_FACTOR, 0.5); //mouseAileronRudderFactor
  ::set_option_multiplier(::OPTION_HELICOPTER_MOUSE_AILERON_RUDDER_FACTOR, 0.5);
  ::set_option_multiplier(::OPTION_CAMERA_SMOOTH,               0); //
  ::set_option_multiplier(::OPTION_CAMERA_SPEED,                1.13); //
  ::set_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED,          4); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_AIR,        0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_HELICOPTER, 0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_TANK,       0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SHIP,       0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUBMARINE,  0.0); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_AIR,        0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_HELICOPTER, 0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_TANK,       0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SHIP,       0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUBMARINE,  0.5); //

  ::set_option_mouse_joystick_square(0); //mouseJoystickSquare
  ::set_option_gain(1); //::USEROPT_FORCE_GAIN
}

function restore_shortcuts(scList, scNames)
{
  local changeList = []
  local changeNames = []
  local curScList = ::get_shortcuts(scNames)
  foreach(idx, sc in curScList)
  {
    local prevSc = scList[idx]
    if (!::isShortcutMapped(prevSc))
      continue

    if (::is_shortcut_equal(sc, prevSc))
      continue

    changeList.append(prevSc)
    changeNames.append(scNames[idx])
  }
  if (!changeList.len())
    return

  ::set_controls_preset("")
  ::set_shortcuts(changeList, changeNames)
}

function switch_helpers_mode_and_option(preset = "")
{
  local joyCurSettings = ::joystick_get_cur_settings()
  if (joyCurSettings.useMouseAim)
    ::set_helpers_mode_and_option(globalEnv.EM_MOUSE_AIM)
  else if (::is_platform_ps4 && preset == ::g_controls_presets.getControlsPresetFilename("thrustmaster_hotas4"))
  {
    if (::getCurrentHelpersMode() == globalEnv.EM_MOUSE_AIM)
      ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
  }
  else if (::is_ps4_or_xbox || ::is_platform_shield_tv())
    ::set_helpers_mode_and_option(globalEnv.EM_REALISTIC)
  else if (::getCurrentHelpersMode() == globalEnv.EM_MOUSE_AIM)
    ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
}

function apply_joy_preset_xchange(preset, updateHelpersMode = true)
{
  if (!preset)
    preset = ::get_controls_preset()

  if (!preset || preset == "")
    return

  local scToRestore = ::get_shortcuts(::shortcuts_not_change_by_preset)

  ::restore_default_controls(preset)
  ::set_controls_preset(preset)

  local joyCurSettings = ::joystick_get_cur_settings()
  local curJoyParams = ::JoystickParams()
  curJoyParams.setFrom(joyCurSettings)
  ::joystick_set_cur_values(curJoyParams)

  ::restore_shortcuts(scToRestore, ::shortcuts_not_change_by_preset)

  if (::is_platform_pc)
    ::switch_show_console_buttons(preset.find("xinput") != null)

  if (updateHelpersMode)
    ::switch_helpers_mode_and_option(preset)

  ::save_profile_offline_limited()
}

function isShortcutMapped(shortcut)
{
  foreach (button in shortcut)
    if (button && button.dev.len() >= 0)
      foreach(d in button.dev)
        if (d > 0 && d <= ::JOYSTICK_DEVICE_0_ID)
            return true
  return false
}

local axisMappedOnMouse = {
  mouse_aim_x            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.HORIZONTAL_AXIS : MOUSE_AXIS.NOT_AXIS
  mouse_aim_y            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.VERTICAL_AXIS : MOUSE_AXIS.NOT_AXIS
  gm_mouse_aim_x         = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_mouse_aim_y         = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_mouse_aim_x       = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_mouse_aim_y       = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_mouse_aim_x = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_mouse_aim_y = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_mouse_aim_x  = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_mouse_aim_y  = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  walker_mouse_aim_x     = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  walker_mouse_aim_y     = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  mouse_aim_x_ufo        = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  mouse_aim_y_ufo        = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS

  camx                   = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  camy                   = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  gm_camx                = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_camy                = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_camx              = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_camy              = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_camx        = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_camy        = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_camx         = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_camy         = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  walker_camx            = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  walker_camy            = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  camx_ufo               = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  camy_ufo               = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
}
function is_axis_mapped_on_mouse(shortcutId, helpersMode = null, joyParams = null)
{
  return get_mouse_axis(shortcutId, helpersMode, joyParams) != MOUSE_AXIS.NOT_AXIS
}

function get_mouse_axis(shortcutId, helpersMode = null, joyParams = null)
{
  local axis = axisMappedOnMouse?[shortcutId]
  if (axis)
    return axis((helpersMode ?? ::getCurrentHelpersMode()) == globalEnv.EM_MOUSE_AIM)

  if (!joyParams)
  {
    joyParams = ::JoystickParams()
    joyParams.setFrom(::joystick_get_cur_settings())
  }
  for (local i = 0; i < MouseAxis.NUM_MOUSE_AXIS_TOTAL; ++i)
  {
    if (shortcutId == joyParams.getMouseAxis(i))
      return 1 << ::min(i, MOUSE_AXIS.TOTAL - 1)
  }

  return MOUSE_AXIS.NOT_AXIS
}

function gui_start_controls()
{
  if (::is_ps4_or_xbox || ::is_platform_shield_tv())
  {
    local cdb = ::get_local_custom_settings_blk()
    if (!(ps4ControlsModeActivatedParamName in cdb) || cdb[ps4ControlsModeActivatedParamName])
    {
      ::gui_start_controls_console()
      return
    }
  }

  ::gui_start_advanced_controls()
}

function gui_start_advanced_controls()
{
  ::gui_start_modal_wnd(::gui_handlers.Hotkeys)
}

class ::gui_handlers.Hotkeys extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controls.blk"
  sceneNavBlkName = null

  filterValues = null
  filterObjId = null
  filter = null
  lastFilter = null

  navigationHandlerWeak = null
  shouldUpdateNavigationSection = true

  shortcuts = null
  shortcutNames = null
  shortcutItems = null
  modifierSymbols = null

  dontCheckControlsDupes = null
  notAssignedAxis = null

  deviceMapping = null

  inputBox = null

  curJoyParams = null
  backAfterSave = true

  setupAxisMode = -1
  bindAxisNum = -1
  joysticks = null

  controlsGroupsIdList = []
  curGroupId = ""

  forceLoadWizard = false
  changeControlsMode = false
  applyApproved = false

  isAircraftHelpersChangePerformed = false

  filledControlGroupTab = null

  updateButtonsHandler = null
  optionTableId = "controls_tbl"

  currentFocusItem = 7

  function getMainFocusObj()
  {
    return ::show_console_buttons? "header_buttons" : null
  }

  function getMainFocusObj2()
  {
    return "filter_edit_box"
  }

  function getMainFocusObj3()
  {
    return "helpers_mode"
  }

  function getMainFocusObj4()
  {
    return optionTableId
  }

  function initScreen()
  {
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    setupAxisMode = -1
    scene.findObject("hotkeys_update").setUserData(this)

    if (::is_low_width_screen())
    {
      local helpersModeObj = scene.findObject("helpers_mode")
      if (::check_obj(helpersModeObj))
        helpersModeObj.smallFont = "yes"
    }

    shortcuts = []
    shortcutNames = []
    shortcutItems = []
    dontCheckControlsDupes = []
    notAssignedAxis = []
    deviceMapping = []

    initNavigation()
    initMainParams()

    if (!fetch_devices_inited_once())
      ::gui_start_controls_type_choice()

    initFocusArray()

    if (controllerState?.add_event_handler) {
      updateButtonsHandler = updateButtons.bindenv(this)
      controllerState.add_event_handler(updateButtonsHandler)
    }
  }

  function onDestroy()
  {
    if (updateButtonsHandler && controllerState?.remove_event_handler)
      controllerState.remove_event_handler(updateButtonsHandler)
  }

  function onSwitchModeButton()
  {
    changeControlsWindowType(true)
    goBack()
  }

  function initMainParams()
  {
    initShortcutsNames()
    curJoyParams = ::JoystickParams()
    curJoyParams.setFrom(::joystick_get_cur_settings())
    updateButtons()

    ::g_controls_manager.restoreHardcodedKeys(::MAX_SHORTCUTS)
    shortcuts = ::get_shortcuts(shortcutNames)
    deviceMapping = ::u.copy(::g_controls_manager.getCurPreset().deviceMapping)

    fillControlsType()
  }

  function initNavigation()
  {
    local handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene = scene.findObject("control_navigation")
        onSelectCb = ::Callback(doNavigateToSection, this)
        panelWidth        = "0.35@sf, ph"
        // Align to helpers_mode and table first row
        headerHeight      = "0.05@sf + @sf/@pf"
        headerOffsetX     = "0.015@sf"
        headerOffsetY     = "0.015@sf"
        collapseShortcut  = "LB"
        navShortcutGroup  = ::get_option(::USEROPT_GAMEPAD_CURSOR_CONTROLLER).value ? null : "RS"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
  }

  function fillFilterObj()
  {
    if (filterObjId)
    {
      local filterObj = scene.findObject(filterObjId)
      if (::checkObj(filterObj) && filterValues && filterObj.childrenCount()==filterValues.len() && !::preset_changed)
        return //no need to refill filters
    }

    local modsBlock = null
    foreach(block in ::shortcutsList)
      if ("isFilterObj" in block && block.isFilterObj)
      {
        modsBlock = block
        break
      }

    if (modsBlock == null)
      return

    local options = ::get_option(modsBlock.optionType)

    filterObjId = modsBlock.id
    filterValues = options.values

    local view = { items = [] }
    foreach (idx, item in options.items)
      view.items.append({
        id = "option_" + options.values[idx]
        text = item.text
        selected = options.value == idx
        tooltip = item.tooltip
      })

    local listBoxObj = scene.findObject(modsBlock.id)
    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)
    onOptionsFilter()
  }

  function fillControlsType()
  {
    fillFilterObj()
  }

  function onFilterEditBoxActivate() {}
  function onFilterEditBoxChangeValue()
  {
    if (::u.isEmpty(filledControlGroupTab))
      return

    local filterEditBox = scene.findObject("filter_edit_box")
    if (!::checkObj(filterEditBox))
      return

    local filterText = ::english_russian_to_lower_case(filterEditBox.getValue())

    foreach (idx, data in filledControlGroupTab)
    {
      local show = filterText == "" || data.text.find(filterText) != null
      showSceneBtn(data.id, show)
    }
  }

  function onFilterEditBoxCancel(obj = null)
  {
    if (obj.getValue() == "")
      goBack()
    else
      resetSearch()
  }

  function resetSearch()
  {
    local filterEditBox = scene.findObject("filter_edit_box")
    if ( ! ::checkObj(filterEditBox))
      return

    filterEditBox.setValue("")
  }

  function isScriptOpenFileDialogAllowed()
  {
    return ::has_feature("ScriptImportExportControls")
      && "export_current_layout_by_path" in ::getroottable()
      && "import_current_layout_by_path" in ::getroottable()
  }

  function updateButtons()
  {
    local isTutorial = ::get_game_mode() == ::GM_TRAINING
    local isImportExportAllowed = !isTutorial
      && (isScriptOpenFileDialogAllowed() || ::is_platform_windows)

    showSceneBtn("btn_exportToFile", isImportExportAllowed)
    showSceneBtn("btn_importFromFile", isImportExportAllowed)
    showSceneBtn("btn_switchMode", ::is_ps4_or_xbox || ::is_platform_shield_tv())
    showSceneBtn("btn_backupManager", ::gui_handlers.ControlsBackupManager.isAvailable())
    local showWizard = !::is_platform_xboxone
      || (controllerState?.is_keyboard_connected || @() false) ()
      || (controllerState?.is_mouse_connected || @() false) ()
    showSceneBtn("btn_controlsWizard", !isTutorial && showWizard)
    showSceneBtn("btn_controlsDefault", !isTutorial && !showWizard)
    showSceneBtn("btn_clearAll", !isTutorial)
  }

  function fillControlGroupsList()
  {
    local groupsList = scene.findObject("controls_groups_list")
    if (!::checkObj(groupsList))
      return

    local curValue = 0
    controlsGroupsIdList = []
    local currentUnit = ::get_player_cur_unit()
    local unitType = ::g_unit_type.INVALID
    local unitClassType = ::g_unit_class_type.UNKNOWN
    local unitTags = []
    if (curGroupId == "" && currentUnit)
    {
      unitType = currentUnit.unitType
      unitClassType = currentUnit.expClass
      unitTags = ::getTblValue("tags", currentUnit, [])
    }

    for(local i=0; i < ::shortcutsList.len(); i++)
      if (::shortcutsList[i].type == CONTROL_TYPE.HEADER)
      {
        local header = ::shortcutsList[i]
        if ("filterShow" in header)
          if (!isInArray(filter, header.filterShow))
            continue
        if ("showFunc" in header)
          if (!header.showFunc.bindenv(this)())
            continue

        controlsGroupsIdList.append(header.id)
        local isSuitable = unitType != ::g_unit_type.INVALID
          && unitType == header?.unitType
        if (isSuitable && "unitClassTypes" in header)
          isSuitable = ::isInArray(unitClassType, header.unitClassTypes)
        if (isSuitable && "unitTag" in header)
          isSuitable = ::isInArray(header.unitTag, unitTags)
        if (isSuitable)
          curGroupId = header.id
        if (header.id == curGroupId)
          curValue = controlsGroupsIdList.len()-1
      }

    local view = { tabs = [] }
    foreach(idx, group in controlsGroupsIdList)
      view.tabs.append({
        id = group
        tabName = "#hotkeys/" + group
        navImagesText = ::get_navigation_images_text(idx, controlsGroupsIdList.len())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(groupsList, data, data.len(), this)

    local listValue = groupsList.getValue()
    if (groupsList.getValue() != curValue)
      groupsList.setValue(curValue)
    if (listValue <= 0 && curValue == 0) //when list value == -1 it doesnt send on_select event when we switch value to 0
      onControlsGroupChange()
  }

  function onControlsGroupChange()
  {
    doControlsGroupChange()
  }

  function doControlsGroupChange(forceUpdate = false)
  {
    if (!::checkObj(scene))
      return

    local groupId = scene.findObject("controls_groups_list").getValue()
    if (groupId < 0)
      groupId = 0

    if (!(groupId in controlsGroupsIdList))
      return

    local newGroupId = controlsGroupsIdList[groupId]
    local isGroupChanged = curGroupId != newGroupId
    if (!isGroupChanged && filter==lastFilter && !::preset_changed && !forceUpdate)
      return

    lastFilter = filter
    if (!::preset_changed)
      doApplyJoystick()
    curGroupId = newGroupId
    fillControlGroupTab(curGroupId)

    if (isGroupChanged)
    {
      local controlTblObj = scene.findObject(optionTableId)
      if (::checkObj(controlTblObj))
        controlTblObj.setValue(::getNearestSelectableChildIndex(controlTblObj, -1, 1))
      onTblChangeFocus()
    }
  }

  function fillControlGroupTab(groupId)
  {
    local data = "";
    local joyParams = ::joystick_get_cur_settings();
    local gRow = 0  //for even and odd color by groups
    local isSectionShowed = true
    local isHelpersVisible = false

    local navigationItems = []
    filledControlGroupTab = []

    for(local n=0; n < ::shortcutsList.len(); n++)
    {
      if (::shortcutsList[n].id != groupId)
        continue

      isHelpersVisible = ::getTblValue("isHelpersVisible", ::shortcutsList[n])
      for(local i=n+1; i < ::shortcutsList.len(); i++)
      {
        local entry = ::shortcutsList[i]
        if (entry.type == CONTROL_TYPE.HEADER)
          break
        if (entry.type == CONTROL_TYPE.SECTION)
        {
          isSectionShowed =
            (!("filterHide" in entry) || !::isInArray(filter, entry.filterHide)) &&
            (!("filterShow" in entry) || ::isInArray(filter, entry.filterShow)) &&
            (!("showFunc" in entry) || entry.showFunc.call(this))
          if (isSectionShowed)
            navigationItems.append({
              id = entry.id
              text = "#hotkeys/" + entry.id
            })
        }
        if (!isSectionShowed)
          continue

        local hotkeyData = ::buildHotkeyItem(i, shortcuts, entry, joyParams, gRow%2 == 0)
        filledControlGroupTab.append(hotkeyData)
        if (hotkeyData.markup == "")
          continue

        data += hotkeyData.markup
        gRow++
      }

      break
    }

    local controlTblObj = scene.findObject(optionTableId);
    if (::checkObj(controlTblObj))
      guiScene.replaceContentFromText(controlTblObj, data, data.len(), this);
    showSceneBtn("helpers_mode", isHelpersVisible)
    if (navigationHandlerWeak)
    {
      navigationHandlerWeak.setNavItems(navigationItems)
      onTblChangeFocus()
    }
    updateSceneOptions()
    optionsFilterApply()
    onFilterEditBoxChangeValue()
    restoreFocus()
  }

  function doNavigateToSection(navItem)
  {
    local sectionId = navItem.id
    shouldUpdateNavigationSection = false
    local rowIdx = getRowIdxBYId(sectionId)
    local rowId = "table_row_" + rowIdx
    local rowObj = scene.findObject(rowId)

    rowObj.scrollToView(true)
    selectRowByRowIdx(rowIdx)
    shouldUpdateNavigationSection = true
  }

  function checkCurrentNavagationSection()
  {
    local item = getCurItem()
    if (!navigationHandlerWeak || !shouldUpdateNavigationSection || !item)
      return

    local navItems = navigationHandlerWeak.getNavItems()
    if (navItems.len() > 1)
    {
      local navId = null
      for (local i = 0; i < ::shortcutsList.len(); i++)
      {
        local entry = ::shortcutsList[i]
        if (entry.type == CONTROL_TYPE.SECTION)
          navId = entry.id
        if (entry.id != item.id)
          continue

        local curItem = ::u.search(navItems, @(it) it.id == navId)
        if (curItem != null)
          navigationHandlerWeak.setCurrentItem(curItem)

        break
      }
    }
  }

  function onUpdate(obj, dt)
  {
    if (!::preset_changed)
      return

    initMainParams()
    ::preset_changed = false
    if (forceLoadWizard)
    {
      forceLoadWizard = false
      onControlsWizard()
    }
  }

  function initShortcutsNames()
  {
    local axisScNames = []
    modifierSymbols = {}

    foreach (item in shortcutsAxisListModule.types)
    {
      if (item.type != CONTROL_TYPE.AXIS_SHORTCUT || ::isInArray(item.id, axisScNames))
        continue

      axisScNames.append(item.id)
      if ("symbol" in item)
        modifierSymbols[item.id] <- ::loc(item.symbol) + ::loc("ui/colon")
    }

    shortcutNames = []
    shortcutItems = []

    local addShortcutNames = function(arr)
    {
      for(local i=0; i < arr.len(); i++)
        if (arr[i].type == CONTROL_TYPE.SHORTCUT)
        {
          arr[i].shortcutId = shortcutNames.len()
          shortcutNames.append(arr[i].id)
          shortcutItems.append(arr[i])
        }
    }
    addShortcutNames(::shortcutsList)
    addShortcutNames(shortcutsAxisListModule.types)

    for(local i=0; i < ::shortcutsList.len(); i++)
    {
      local item = ::shortcutsList[i]

      if (item.type != CONTROL_TYPE.AXIS)
        continue

      item.modifiersId = {}
      foreach(name in axisScNames)
      {
        item.modifiersId[name] <- shortcutNames.len()
        shortcutNames.append(item.axisName + ((name=="")?"" : "_" + name))
        shortcutItems.append(item)
      }
    }
  }

  function getSymbol(name)
  {
    if (name in modifierSymbols)
      return "<color=@axisSymbolColor>" + modifierSymbols[name] + "</color>"
    return ""
  }

  function updateAxisText(device, item)
  {
    local itemTextObj = scene.findObject("txt_" + item.id)
    if (!::checkObj(itemTextObj))
      return

    if (device == null)
    {
      itemTextObj.setValue(::loc("joystick/no_available_joystick"))
      return
    }

    local axis = item.axisIndex >= 0
      ? curJoyParams.getAxis(item.axisIndex)
      : ControlsPreset.getDefaultAxis()
    local axisText = ""
    local data = ""
    local curPreset = ::g_controls_manager.getCurPreset()
    if (axis.axisId >= 0)
      axisText = ::remapAxisName(curPreset, axis.axisId)

    if ("modifiersId" in item)
    {
      if ("" in item.modifiersId)
      {
        local activationShortcut = ::get_shortcut_text(shortcuts, item.modifiersId[""], false)
        if (activationShortcut != "")
          data += activationShortcut + " + "
      }
      if (axisText!="")
        data += ::addHotkeyTxt(getSymbol("") + axisText, "")

      //--- options controls list  ---
      foreach(modifier, id in item.modifiersId)
        if (modifier != "")
        {
          local scText = ::get_shortcut_text(shortcuts, id, false)
          if (scText!="")
          {
            data += (data=="" ? "" : ";  ") +
              getSymbol(modifier) +
              scText;
          }
        }
    } else
      data = ::addHotkeyTxt(axisText)

    local notAssignedId = ::find_in_array(notAssignedAxis, item)
    if (data == "")
    {
      data = ::loc("joystick/axis_not_assigned")
      if (notAssignedId<0)
        notAssignedAxis.append(item)
    } else
      if (notAssignedId>=0)
        notAssignedAxis.remove(notAssignedId)

    itemTextObj.setValue(data)
  }

  function updateSceneOptions()
  {
    local device = ::joystick_get_default()

    for(local i=0; i < ::shortcutsList.len(); i++)
    {
      if (::shortcutsList[i].type == CONTROL_TYPE.AXIS && ::shortcutsList[i].axisIndex>=0)
        updateAxisText(device, ::shortcutsList[i])
      else
      if (::shortcutsList[i].type== CONTROL_TYPE.SLIDER)
        updateSliderValue(::shortcutsList[i])
    }
  }

  function getRowIdx(rowObj)
  {
    local id = rowObj.id
    if (!id || id.len() <= 10 || id.slice(0, 10) != "table_row_")
      return -1
    return id.slice(10).tointeger()
  }

  function getRowIdxBYId(id)
  {
    return ::u.searchIndex(::shortcutsList, (@(id) function(s) { return s.id == id })(id))
  }

  function getCurItem()
  {
    local objTbl = scene.findObject(optionTableId)
    if (!::check_obj(objTbl))
      return null

    local idx = objTbl.getValue()
    if (idx < 0 || objTbl.childrenCount() <= idx)
      return null

    local rowObj = objTbl.getChild(idx)
    local sel = getRowIdx(rowObj)

    if (setupAxisMode >= 0)
      return shortcutsAxisListModule.types?[sel]
    if (sel < 0 || sel >= ::shortcutsList.len())
      return null
    return ::shortcutsList[sel]
  }

  function checkOptionValue(optName, checkValue)
  {
    local obj = scene.findObject(optName)
    if (!obj)
      return false

    local value = obj.getValue()
    return value == checkValue
  }

  function getMouseUsageMask()
  {
    local usage = ::g_aircraft_helpers.getOptionValue(
      ::USEROPT_MOUSE_USAGE)
    local usageNoAim = ::g_aircraft_helpers.getOptionValue(
      ::USEROPT_MOUSE_USAGE_NO_AIM)
    return (usage ? usage : 0) | (usageNoAim ? usageNoAim : 0)
  }

  function applyAirHelpersChange(obj = null)
  {
    if (isAircraftHelpersChangePerformed)
      return
    isAircraftHelpersChangePerformed = true

    if (::checkObj(obj))
    {
      local valueIdx = obj.getValue()
      local item = null
      for(local i = 0; i < ::shortcutsList.len(); i++)
        if (obj.id == ::shortcutsList[i].id)
        {
          item = ::shortcutsList[i]
          break
        }
      if (item != null && "optionType" in item)
        ::set_option(item.optionType, valueIdx)
    }

    local options = ::u.values(::g_aircraft_helpers.controlHelpersOptions)
    foreach (optionId in options)
    {
      if (optionId == ::USEROPT_HELPERS_MODE)
        continue
      local option = ::get_option(optionId)
      for (local i = 0; i < ::shortcutsList.len(); i++)
        if (::shortcutsList[i]?.optionType == optionId)
        {
          local object = scene.findObject(::shortcutsList[i].id)
          if (::checkObj(object) && object.getValue() != option.value)
            object.setValue(option.value)
        }
    }

    curJoyParams.mouseJoystick = ::getTblValue("mouseJoystick",
      ::g_controls_manager.getCurPreset().params, false)

    isAircraftHelpersChangePerformed = false
  }

  function onAircraftHelpersChanged(obj = null)
  {
    if (isAircraftHelpersChangePerformed)
      return

    applyAirHelpersChange(obj)
    doControlsGroupChangeDelayed(obj)
  }

  function onOptionsFilter(obj = null)
  {
    applyAirHelpersChange(obj)

    if (!filterObjId)
      return

    local filterObj = scene.findObject(filterObjId)
    if (!::checkObj(filterObj))
      return

    local filterId = filterObj.getValue()
    if (!(filterId in filterValues))
      return

    if (!::can_change_helpers_mode() && filter!=null)
    {
      foreach(idx, value in filterValues)
        if (value == filter)
        {
          if (idx != filterId)
            msgBox("cant_change_controls", ::loc("msgbox/tutorial_controls_type_locked"),
                   [["ok", (@(filterObj, idx) function() {
                       if (::checkObj(filterObj))
                         filterObj.setValue(idx)
                     })(filterObj, idx)
                   ]], "ok")
          break
        }
      return
    }
    ::set_control_helpers_mode(filterId);
    filter = filterValues[filterId];
    fillControlGroupsList();
    //doControlsGroupChange();
  }

  function selectRowByControlObj(obj)
  {
    selectRowByRowIdx(getRowIdxBYId(obj.id))
  }

  function selectRowByRowIdx(idx)
  {
    local controlTblObj = scene.findObject(optionTableId)
    if (!::checkObj(controlTblObj) || idx < 0)
      return

    local id = "table_row_" + idx
    for(local i = 0; i < controlTblObj.childrenCount(); i++)
      if (controlTblObj.getChild(i).id == id)
      {
        if (controlTblObj.getValue() != i)
          controlTblObj.setValue(::getNearestSelectableChildIndex(controlTblObj, i, 1))
        break
      }
  }

  function getFilterObj()
  {
    if (!::check_obj(scene) || !filterObjId)
      return null
    return scene.findObject(filterObjId)
  }

  delayedControlsGroupStrated = false
  function doControlsGroupChangeDelayed(obj = null)
  {
    if (obj)
      selectRowByControlObj(obj) //to correct scroll after refill page

    delayedControlsGroupStrated = true
    guiScene.performDelayed(this, function()
    {
      delayedControlsGroupStrated = false
      local filterOption = ::get_option(::USEROPT_HELPERS_MODE)
      local filterObj = getFilterObj()
      if (::checkObj(filterObj) && filterObj.getValue() != filterOption.value)
        filterObj.setValue(filterOption.value)
      doControlsGroupChange(true)
    })
  }

  function updateHidden()
  {
    for(local i = 0; i < ::shortcutsList.len(); i++)
    {
      local item = ::shortcutsList[i]
      local show = true
      local canBeHidden = true

      if ("filterHide" in item)
      {
        show = !isInArray(filter, item.filterHide)
      } else
      if ("filterShow" in item)
      {
        show = isInArray(filter, item.filterShow)
      } else
        canBeHidden = false

      if ("showFunc" in item)
      {
        show = show && item.showFunc.bindenv(this)()
        canBeHidden = true
      }
      if (!canBeHidden)
        continue

      item.isHidden = !show
    }
  }

  function optionsFilterApply()
  {
    updateHidden()
    local mainTbl = scene.findObject(optionTableId)
    if (!::checkObj(mainTbl))
      return

    local curRow = mainTbl.cur_row.tointeger()
    local totalRows = mainTbl.childrenCount()

    for(local i=0; i<totalRows; i++)
    {
      local obj = mainTbl.getChild(i)
      local itemIdx = getRowIdx(obj)
      if (itemIdx < 0)
        continue

      local item = ::shortcutsList[itemIdx]
      local show = !item.isHidden

      if (obj)
      {
        obj.hiddenTr = show ? "no" : "yes"
        obj.inactive = (show && item.type != CONTROL_TYPE.HEADER
          && item.type != CONTROL_TYPE.SECTION) ? null : "yes"
      }

      if (curRow == i && !show)
      {
        ::gui_bhv.OptionsNavigator.onShortcutUp.call(::gui_bhv.OptionsNavigator, mainTbl, true)
        curRow=mainTbl.cur_row.tointeger()
      }
    }

    if ((curRow < mainTbl.childrenCount()) && (curRow >= 0))
    {
      local rowObj = mainTbl.getChild(curRow)
      guiScene.performDelayed(this, function() {
        if (::checkObj(rowObj))
          rowObj.scrollToView()
      })
    }

    showSceneBtn("btn_preset", filter!=globalEnv.EM_MOUSE_AIM)
    showSceneBtn("btn_defaultpreset", filter==globalEnv.EM_MOUSE_AIM)

    dontCheckControlsDupes = ::refillControlsDupes()
  }

  function loadPresetWithMsg(msg, presetSelected, askKeyboardDefault=false)
  {
    msgBox(
      "controls_restore_question", msg,
      [
        ["yes", function() {
          if (askKeyboardDefault)
          {
            local presetNames = ::recomended_control_presets
            local presets = presetNames.map(@(name) [
              name,
              function() {
                applyChoosedPreset(::get_controls_preset_by_selected_type(name).fileName)
              }
            ])
            msgBox("ask_kbd_type", ::loc("controls/askKeyboardWasdType"), presets, "classic")
            return
          }

          local preset = "empty_ver1"
          local opdata = ::get_option(::USEROPT_CONTROLS_PRESET)
          if (presetSelected in opdata.values)
            preset = opdata.values[presetSelected]
          else
          {
            if (::is_platform_ps4)
              preset = "empty.ps4"
            else if (::is_platform_xboxone)
              preset = "empty.xboxone"
            else
              forceLoadWizard = true
          }
          preset = ::g_controls_presets.parsePresetName(preset)
          preset = ::g_controls_presets.getHighestVersionPreset(preset)
          applyChoosedPreset(preset.fileName)
          ::reset_fast_voice_messages()
        }],
        ["cancel", @() null],
      ], "cancel"
    )
  }

  function applyChoosedPreset(preset)
  {
    ::reset_default_control_settings()
    ::apply_joy_preset_xchange(preset);
    ::preset_changed=true
  }

  function onClearAll()
  {
    backAfterSave = false
    doApply()
    loadPresetWithMsg(::loc("hotkeys/msg/clearAll"), -1)
  }

  function onDefaultPreset()
  {
    backAfterSave = false
    doApply()
    loadPresetWithMsg(::loc("controls/askRestoreDefaults"), 0, true)
  }

  function onButtonReset()
  {
    local item = getCurItem()
    if (!item) return
    if (item.type == CONTROL_TYPE.AXIS)
      return onAxisReset()
    if (!(item.shortcutId in shortcuts))
      return

    guiScene.performDelayed(this, function() {
      if (scene && scene.isValid())
      {
        local obj = scene.findObject("controls_input_root")
        if (obj) guiScene.destroyElement(obj)
      }

      if (!item) return

      shortcuts[item.shortcutId] = []
      ::set_controls_preset("")
      updateShortcutText(item.shortcutId)
    })
  }

  function onWrapUp(obj)
  {
    base.onWrapUp(obj)
    onTblChangeFocus()
  }

  function onWrapDown(obj)
  {
    base.onWrapDown(obj)
    onTblChangeFocus()
  }

  function onTblSelect()
  {
    updateButtonsChangeValue()
  }

  function onTblChangeFocus()
  {
    guiScene.performDelayed(this,
      function () {
        if (isValid())
          updateButtonsChangeValue()
      }
    )
  }

  function isCurrentRowSelected()
  {
    local tableObj = scene.findObject(optionTableId)
    local tableValue = tableObj.getValue()
    local rowObj = tableObj.getChild(tableValue)

    return rowObj.selected == "yes"
  }

  function updateButtonsChangeValue()
  {
    local item = getCurItem()
    if (!item)
      return

    local isItemRowSelected = isCurrentRowSelected()
    local showScReset = isItemRowSelected &&
      (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
    local showAxisReset = isItemRowSelected && item.type == CONTROL_TYPE.AXIS
    local showPerform = isItemRowSelected && item.type == CONTROL_TYPE.BUTTON

    local btnA = scene.findObject("btn_assign")
    if (::check_obj(btnA))
    {
      local btnText = ""
      if (showAxisReset)
        btnText = ::loc("mainmenu/btnEditAxis")
      else if (showScReset)
        btnText = ::loc("mainmenu/btnAssign")
      else if (showPerform)
        btnText = ::loc("mainmenu/btnPerformAction")

      btnA.show(btnText != "")
      btnA.setValue(btnText)
    }

    showSceneBtn("btn_reset_shortcut", showScReset)
    showSceneBtn("btn_reset_axis", showAxisReset)

    checkCurrentNavagationSection()
  }

  function onTblDblClick()
  {
    local item = getCurItem()
    if (!item) return

    if (item.type == CONTROL_TYPE.AXIS)
      openAxisBox(item)
    else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      openShortcutInputBox()
    else if (item.type == CONTROL_TYPE.BUTTON)
      doItemAction(item)
  }

  function openShortcutInputBox()
  {
    ::assignButtonWindow(this, onAssignButton)
  }

  function onAssignButton(dev, btn)
  {
    if (dev.len() > 0 && dev.len() == btn.len())
    {
      local item = getCurItem()
      if (item)
        bindShortcut(dev, btn, item.shortcutId)
    }
  }

  function doBind(devs, btns, shortcutId)
  {
    local event = shortcuts[shortcutId]
    event.append({dev = devs, btn = btns})
    if (event.len() > ::MAX_SHORTCUTS)
      event.remove(0)

    ::set_controls_preset(""); //custom mode
    updateShortcutText(shortcutId)
  }

  function updateShortcutText(shortcutId)
  {
    if (!(shortcutId in shortcuts))
      return

    local item = shortcutItems[shortcutId]
    local obj = scene.findObject("txt_sc_"+shortcutNames[shortcutId])

    if (obj)
      obj.setValue(::get_shortcut_text(shortcuts, shortcutId))

    if (item.type == CONTROL_TYPE.AXIS)
    {
      local device = ::joystick_get_default()
      if (device != null)
        updateAxisText(device, item)
    }
  }

  function bindShortcut(devs, btns, shortcutId)
  {
    if (!(shortcutId in shortcuts))
      return false

    local curBinding = findButtons(devs, btns, shortcutId)
    if (!curBinding || curBinding.len() == 0)
    {
      doBind(devs, btns, shortcutId)
      return false
    }

    for(local i = 0; i < curBinding.len(); i++)
      if (curBinding[i][0]==shortcutId)
        return false

    local msg = ::loc("hotkeys/msg/unbind_question", {
      action = ::g_string.implode(
        curBinding.map((@(b) ::loc("hotkeys/"+shortcutNames[b[0]])).bindenv(this)),
        ::loc("ui/comma")
      )
    })
    msgBox("controls_unbind_question", msg, [
      ["add", (@(curBinding, devs, btns, shortcutId) function() {
        doBind(devs, btns, shortcutId)
      })(curBinding, devs, btns, shortcutId)],
      ["replace", (@(curBinding, devs, btns, shortcutId) function() {
        for(local i = curBinding.len() - 1; i >= 0; i--)
        {
          local binding = curBinding[i]
          if (!(binding[1] in shortcuts[binding[0]]))
            continue

          shortcuts[binding[0]].remove(binding[1])
          updateShortcutText(binding[0])
        }
        doBind(devs, btns, shortcutId)
      })(curBinding, devs, btns, shortcutId)],
      ["cancel", function() { }],
    ], "cancel")
    return true
  }

  function findButtons(devs, btns, shortcutId)
  {
    local visibilityMap = getShortcutsVisibilityMap()

    if (::find_in_array(dontCheckControlsDupes, shortcutNames[shortcutId]) >= 0)
      return null

    local res = []

    foreach (index, event in shortcuts)
      if ((shortcutItems[index].checkGroup & shortcutItems[shortcutId].checkGroup) &&
        ::getTblValue(shortcutNames[index], visibilityMap) &&
        (shortcutItems[index]?.conflictGroup == null ||
          shortcutItems[index]?.conflictGroup != shortcutItems[shortcutId]?.conflictGroup))
        foreach (button_index, button in event)
        {
          if (!button || button.dev.len() != devs.len())
            continue
          local numEqual = 0
          for (local i = 0; i < button.dev.len(); i++)
            for (local j = 0; j < devs.len(); j++)
              if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]))
                numEqual++

          if (numEqual == btns.len() && ::find_in_array(dontCheckControlsDupes, shortcutNames[index]) < 0)
            res.append([index, button_index])
        }
    return res
  }

  function openAxisBox(axisItem)
  {
    if (!curJoyParams || !axisItem || axisItem.axisIndex < 0 )
      return

    local params = {
      axisItem = axisItem,
      curJoyParams = curJoyParams,
      shortcuts = shortcuts,
      shortcutItems = shortcutItems
    }

    ::gui_start_modal_wnd(::gui_handlers.AxisControls, params)
  }

  function onAxisReset()
  {
    local axisMode = -1
    local item = getCurItem()
    if (item && item.type == CONTROL_TYPE.AXIS)
      axisMode = item.axisIndex

    if (axisMode<0)
      return

    ::set_controls_preset("");
    local axis = curJoyParams.getAxis(axisMode)
    axis.inverse = false
    axis.innerDeadzone = 0
    axis.nonlinearity = 0
    axis.kAdd = 0
    axis.kMul = 1.0
    axis.relSens = 1.0
    axis.relStep = 0
    axis.relative = ::getTblValue("def_relative", item, false)

    if (item)
      foreach(name, idx in item.modifiersId)
        shortcuts[idx] = []

    curJoyParams.bindAxis(axisMode, -1)
    local device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    updateSceneOptions()
  }

  function setAxisBind(axisIdx, axisNum)
  {
    ::set_controls_preset("");
    curJoyParams.bindAxis(axisIdx, axisNum)
    local device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    updateSceneOptions()
  }

  function onChangeAxisRelative(obj)
  {
    if (!obj)
      return

    local isRelative = obj.getValue() == 1
    local txtObj = scene.findObject("txt_rangeMax")
    if (txtObj) txtObj.setValue(::loc(isRelative? "hotkeys/rangeInc" : "hotkeys/rangeMax"))
    txtObj = scene.findObject("txt_rangeMin")
    if (txtObj) txtObj.setValue(::loc(isRelative? "hotkeys/rangeDec" : "hotkeys/rangeMin"))
  }

  function getUnmappedByGroups()
  {
    local currentHeader = null
    local unmapped = []
    local mapped = {}

    foreach(item in ::shortcutsList)
    {
      if (item.type == CONTROL_TYPE.HEADER)
      {
        local isHeaderVisible = !("showFunc" in item) || item.showFunc.call(this)
        if (isHeaderVisible)
          currentHeader = "hotkeys/" + item.id
        else
          currentHeader = null
      }
      if (!currentHeader || item.isHidden || !item.checkAssign)
        continue
      if (filter == globalEnv.EM_MOUSE_AIM && !item.reqInMouseAim)
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT)
      {
        if ((item.shortcutId in shortcuts)
            && !::isShortcutMapped(shortcuts[item.shortcutId]))
          unmapped.append({ item = item, header = currentHeader })
        else if ("alternativeIds" in item)
        {
          mapped[item.id] <- true
          foreach (alternativeId in item.alternativeIds)
            mapped[alternativeId] <- true
        }
      }
      else if (item.type == CONTROL_TYPE.AXIS)
      {
        local isMapped = false
        if (::is_axis_mapped_on_mouse(item.id, filter, curJoyParams))
          isMapped = true

        if (!isMapped)
        {
          local axisId = item.axisIndex >= 0
            ? curJoyParams.getAxis(item.axisIndex).axisId : -1
          if (axisId >= 0 || !("modifiersId" in item))
            isMapped = true
        }

        if (!isMapped)
          foreach(name in ["rangeMin", "rangeMax"])
            if (name in item.modifiersId)
            {
              local id = item.modifiersId[name]
              if (!(id in shortcuts) || ::isShortcutMapped(shortcuts[id]))
              {
                isMapped = true
                break
              }
            }

        if (!isMapped)
          unmapped.append({ item = item, header = currentHeader })
        else if ("alternativeIds" in item)
        {
          mapped[item.id] <- true
          foreach (alternativeId in item.alternativeIds)
            mapped[alternativeId] <- true
        }
      }
    }

    local unmappedByGroups = {}
    local unmappedList = []
    foreach(unmappedItem in unmapped)
    {
      local item = unmappedItem.item
      if ("alternativeIds" in item || mapped?[item.id])
        continue

      local header = unmappedItem.header
      local unmappedGroup = unmappedByGroups?[header]
      if (!unmappedGroup)
      {
        unmappedGroup = { id = header, list = [] }
        unmappedByGroups[header] <- unmappedGroup
        unmappedList.append(unmappedGroup)
      }

      if (item.type == CONTROL_TYPE.SHORTCUT)
        unmappedGroup.list.append("hotkeys/" + shortcutNames[item.shortcutId])
      else if (item.type == CONTROL_TYPE.AXIS)
        unmappedGroup.list.append("controls/" + item.axisName)
    }
    return unmappedList
  }

  function updateSliderValue(item)
  {
    local valueObj = scene.findObject(item.id+"_value")
    if (!valueObj) return
    local vlObj = scene.findObject(item.id)
    if (!vlObj) return

    local value = vlObj.getValue()
    local valueText = ""
    if ("showValueMul" in item)
      valueText = (item.showValueMul * value).tostring()
    else
      valueText = value * (("showValuePercMul" in item)? item.showValuePercMul : 1) + "%"
    valueObj.setValue(valueText)
  }

  function onSliderChange(obj)
  {
    if (!obj)
      return

    if (setupAxisMode >= 0)
      updateSliderValue(shortcutsAxisListModule?[obj.id])
    else
      updateSliderValue(shortcutsListModule?[obj.id])
  }

  function onActionButtonClick(obj) {
    selectRowByControlObj(obj)
    local item = shortcutsListModule[obj.id]
    doItemAction(item)
  }

  function doItemAction(item) {
    saveShortcutsAndAxes()
    if (item.onClick())
      doControlsGroupChangeDelayed()
  }

  function doApplyJoystick()
  {
    if (curJoyParams == null)
      return

    local axis = null
    if (setupAxisMode>=0)
      axis = curJoyParams.getAxis(setupAxisMode)

    local itemsList = axis? shortcutsAxisListModule.types : shortcutsListModule.types
    foreach (item in itemsList)
    {
      if ((("condition" in item) && !item.condition())
          || item.type == CONTROL_TYPE.SHORTCUT)
        continue

      local obj = scene.findObject(item.id)
      if (!::checkObj(obj)) continue

      if ("optionType" in item)
      {
        local value = obj.getValue()
        ::set_option(item.optionType, value)
        continue
      }

      if (item.type== CONTROL_TYPE.MOUSE_AXIS && ("axis_num" in item))
      {
        local value = obj.getValue()
        if (value in item.values)
          if (item.values[value] == "none")
            curJoyParams.setMouseAxis(item.axis_num, "")
          else
            curJoyParams.setMouseAxis(item.axis_num, item.values[value])
      }

      if (!("setValue" in item))
        continue

      local value = obj.getValue()
      if ((item.type == CONTROL_TYPE.SPINNER || item.type== CONTROL_TYPE.DROPRIGHT || item.type== CONTROL_TYPE.LISTBOX)
          && (item.options.len() > 0))
        if (value in item.options)
          item.setValue(axis? axis : curJoyParams, value)

      if (item.type == CONTROL_TYPE.SLIDER)
        item.setValue(axis? axis : curJoyParams, value)
      else if (item.type == CONTROL_TYPE.SWITCH_BOX)
        item.setValue(axis? axis : curJoyParams, value)
    }

    ::joystick_set_cur_settings(curJoyParams)
  }

  function onEventControlsMappingChanged(realMapping)
  {
    shortcuts = fix_shortcuts_and_axes_mapping(deviceMapping, realMapping,
      shortcuts, shortcutNames, CONTROL_TYPE.AXIS, ::shortcutsList)
    deviceMapping = ::u.copy(realMapping)
    fillControlGroupTab(curGroupId)
  }

  function onEventControlsChangedShortcuts(p)
  {
    foreach (sc in p.changedShortcuts)
      updateShortcutText(sc)
  }

  function onEventControlsChangedAxes(p)
  {
    local device = ::joystick_get_default()
    foreach (axis in p.changedAxes)
      updateAxisText(device, axis)
  }

  function doApply()
  {
    if (!::checkObj(scene))
      return

    applyApproved = true
    saveShortcutsAndAxes()
    save(false)
    backAfterSave = true
  }

  function buildMsgFromGroupsList(list)
  {
    local text = ""
    local colonLocalized = ::loc("ui/colon")
    foreach(groupIdx, group in list)
    {
      if (groupIdx > 0)
        text += "\n"
      text += ::loc(group.id) + colonLocalized + "\n"
      foreach(idx, locId in group.list)
      {
        if (idx != 0)
          text += ", "
        text += ::loc(locId)
      }
    }
    return text
  }

  function changeControlsWindowType(value)
  {
    if (changeControlsMode==value)
      return

    changeControlsMode = value
    ::switchControlsMode(value)
  }

  function goBack()
  {
    onApply()
  }

  function onApply()
  {
    doApply()
  }

  function closeWnd()
  {
    restoreMainOptions()
    base.goBack()
  }

  function afterSave()
  {
    if (!backAfterSave)
      return

    local reqList = getUnmappedByGroups()
    if (!reqList.len())
      return closeWnd()

    local msg = ::loc("controls/warningUnmapped") + ::loc("ui/colon") + "\n" +
      buildMsgFromGroupsList(reqList)
    msgBox("not_all_mapped", msg,
    [
      ["resetToDefaults", function()
      {
        changeControlsWindowType(false)
        guiScene.performDelayed(this, onDefaultPreset)
      }],
      ["backToControls", function() {
        changeControlsWindowType(false)
      }],
      ["stillContinue", function()
      {
        guiScene.performDelayed(this, closeWnd)
      }]
    ], "backToControls")
  }

  function onMouseWheel(obj)
  {
    local item = getCurItem()
    if (!item || !("values" in item) || !obj)
      return

    ::set_controls_preset("")
    local value = obj.getValue()
    local axisName = ::getTblValue(value, item.values)
    local zoomPostfix = "zoom"
    if (axisName && axisName.len() >= zoomPostfix.len() && axisName.slice(-4) == zoomPostfix)
    {
      local zoomAxisIndex = ::get_axis_index(axisName)
      if (zoomAxisIndex<0) return

      local axis = curJoyParams.getAxis(zoomAxisIndex)
      if (axis.axisId<0) return

      if (filter==globalEnv.EM_MOUSE_AIM)
      {
        setAxisBind(zoomAxisIndex, -1)
        return
      }

      local curPreset = ::g_controls_manager.getCurPreset()
      local msg = format(::loc("msg/zoomAssignmentsConflict"),
        ::remapAxisName(curPreset, axis.axisId))
      guiScene.performDelayed(this, @()
        msgBox("zoom_axis_assigned", msg,
        [
          ["replace", (@(zoomAxisIndex) function() {
            setAxisBind(zoomAxisIndex, -1)
          })(zoomAxisIndex)],
          ["cancel", function() {
            if (::check_obj(obj))
              obj.setValue(0)
          }]
        ], "replace"))
    }
    else if (axisName && (axisName == "camx" || axisName == "camy")
      && item.axis_num == MouseAxis.MOUSE_SCROLL)
    {
      local isMouseView = AIR_MOUSE_USAGE.VIEW ==
        ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE)
      local isMouseViewWhenNoAim = AIR_MOUSE_USAGE.VIEW ==
        ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE_NO_AIM)

      if (isMouseView || isMouseViewWhenNoAim)
      {
        local msg = isMouseView
          ? ::loc("msg/replaceMouseViewToScroll")
          : ::loc("msg/replaceMouseViewToScrollNoAim")
        guiScene.performDelayed(this, @()
          msgBox("mouse_used_for_view", msg,
          [
            ["replace", function() {
              ::g_aircraft_helpers.setOptionValue(
                ::USEROPT_MOUSE_USAGE, AIR_MOUSE_USAGE.AIM)
              ::g_aircraft_helpers.setOptionValue(
                ::USEROPT_MOUSE_USAGE_NO_AIM, AIR_MOUSE_USAGE.JOYSTICK)
              onAircraftHelpersChanged(null)
            }],
            ["cancel", function() {
              if (::check_obj(obj))
                obj.setValue(0)
            }]
          ], "cancel"))
      }
    }
  }

  function onControlsHelp()
  {
    backAfterSave = false
    doApply()
    ::gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
  }

  function onControlsWizard()
  {
    backAfterSave = false
    doApply()
    ::gui_modal_controlsWizard()
  }

  function saveShortcutsAndAxes()
  {
    ::set_shortcuts(shortcuts, shortcutNames)
    doApplyJoystick()
  }

  function updateCurPresetForExport()
  {
    saveShortcutsAndAxes()
    ::g_controls_manager.clearGuiOptions()
    local curPreset = ::g_controls_manager.getCurPreset()
    local mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)
    foreach (item in ::shortcutsList)
      if ("optionType" in item && item.optionType in ::user_option_name_by_idx)
      {
        local optionName = ::user_option_name_by_idx[item.optionType]
        local value = ::get_option(item.optionType).value
        if (value != null)
          curPreset.params[optionName] <- value
      }
    ::set_gui_options_mode(mainOptionsMode)
  }

  function onManageBackup()
  {
    updateCurPresetForExport()
    ::gui_handlers.ControlsBackupManager.open()
  }

  function onExportToFile()
  {
    updateCurPresetForExport()

    if (isScriptOpenFileDialogAllowed())
    {
      ::gui_start_modal_wnd(::gui_handlers.FileDialog, {
        isSaveFile = true
        dirPath = ::get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          local isSaved = ::export_current_layout_by_path(path)
          if (!isSaved)
            ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
          return isSaved
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else if (!::export_current_layout())
      msgBox("errorSavingPreset", ::loc("msgbox/errorSavingPreset"),
             [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onImportFromFile()
  {
    if (isScriptOpenFileDialogAllowed())
    {
      ::gui_start_modal_wnd(::gui_handlers.FileDialog, {
        isSaveFile = false
        dirPath = ::get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          local isOpened = ::import_current_layout_by_path(path)
          if (isOpened)
            ::preset_changed = true
          else
            ::showInfoMsgBox(::loc("msgbox/errorLoadingPreset"))
          return isOpened && ::is_last_load_controls_succeeded
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else
    {
      if (::import_current_layout())
        ::preset_changed = true
      else
        msgBox("errorLoadingPreset", ::loc("msgbox/errorLoadingPreset"),
               [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
    }
  }

  function afterModalDestroy()
  {
    if (changeControlsMode && applyApproved)
      ::gui_start_controls_console()
  }

  function onOptionsListboxDblClick(obj) {}

  function getShortcutsVisibilityMap()
  {
    local helpersMode = ::getCurrentHelpersMode()
    local isHeaderShowed = true
    local isSectionShowed = true

    local visibilityMap = {}

    foreach (entry in ::shortcutsList)
    {
      local isShowed =
        (!("filterHide" in entry) || !::isInArray(helpersMode, entry.filterHide)) &&
        (!("filterShow" in entry) || ::isInArray(helpersMode, entry.filterShow)) &&
        (!("showFunc" in entry) || entry.showFunc.call(this))
      if (entry.type == CONTROL_TYPE.HEADER)
      {
        isHeaderShowed = isShowed
        isSectionShowed = true
      }
      else if (entry.type == CONTROL_TYPE.SECTION)
        isSectionShowed = isShowed
      visibilityMap[entry.id] <- isShowed && isHeaderShowed && isSectionShowed
    }

    return visibilityMap
  }
}

function refillControlsDupes()
{
  local arr = []
  for(local i = 0; i < ::shortcutsList.len(); i++)
  {
    local item = ::shortcutsList[i]
    if ((item.type == CONTROL_TYPE.SHORTCUT)
        && (item.isHidden || (("dontCheckDupes" in item) && item.dontCheckDupes)))
      arr.append(item.id)
  }
  return arr
}

function buildHotkeyItem(rowIdx, shortcuts, item, params, even, rowParams = "")
{
  local hotkeyData = {
    id = "table_row_" + rowIdx
    markup = ""
    text = ""
  }

  if (("condition" in item) && !item.condition())
    return hotkeyData

  local trAdd = ::format("id:t='%s'; even:t='%s'; %s", hotkeyData.id, even? "yes" : "no", rowParams)
  local res = ""
  local elemTxt = ""
  local elemIdTxt = "controls/" + item.id

  if (item.type == CONTROL_TYPE.SECTION)
  {
    local hotkeyId = "hotkeys/" + item.id
    res = ::format("tr { %s inactive:t='yes';" +
                   "td { width:t='@controlsLeftRow'; overflow:t='visible';" +
                     "optionBlockHeader { text:t='#%s'; }}\n" +
                   "td { width:t='pw-1@controlsLeftRow'; }\n" +
                 "}\n", trAdd, hotkeyId)

    hotkeyData.text = ::english_russian_to_lower_case(::loc(hotkeyId))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
  {
    local trName = "hotkeys/" + ((item.id=="")? "enable" : item.id)
    res = ::format("tr { %s " +
                   "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext{id:t='%s'; text:t='#%s'; }}\n" +
                   "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad';" +
                   " textareaNoTab {id:t='%s'; pos:t='0, 0.5ph-0.5h'; position:t='relative'; text:t='%s'; }}\n" +
                 "}\n",
                 trAdd,
                 "txt_" + item.id,
                 trName,
                 "txt_sc_" + item.id,
                 ::get_shortcut_text(shortcuts, item.shortcutId, true, true))

    hotkeyData.text = ::english_russian_to_lower_case(::loc(trName))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.AXIS && item.axisIndex >= 0)
  {
    res = ::format("tr { id:t='%s'; %s " +
                   "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext{text:t='%s'; }}\n" +
                   "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad';" +
                   " textareaNoTab {id:t='%s'; pos:t='0, 0.5ph-0.5h'; position:t='relative'; text:t=''; }}\n" +
                 "}\n",
                 "axis_" + item.axisIndex, trAdd, "#controls/"+item.id, "txt_"+item.id)

    hotkeyData.text = ::english_russian_to_lower_case(::loc("controls/"+item.id))
    hotkeyData.markup = res
  }
  else if (item.type == CONTROL_TYPE.SPINNER || item.type== CONTROL_TYPE.DROPRIGHT)
  {
    local createOptFunc = ::create_option_list
    if (item.type== CONTROL_TYPE.DROPRIGHT)
      createOptFunc = ::create_option_dropright

    local callBack = ("onChangeValue" in item)? item.onChangeValue : null

    if ("optionType" in item)
    {
      local config = ::get_option(item.optionType)
      elemIdTxt = "options/" + config.id
      elemTxt = createOptFunc(item.id, config.items, config.value, callBack, true)
    }
    else if ("options" in item && (item.options.len() > 0))
    {
      local value = ("value" in item)? item.value(params) : 0
      elemTxt = createOptFunc(item.id, item.options, value, callBack, true)
    }
    else
      dagor.debug("Error: No optionType nor options field");
  }
  else if (item.type== CONTROL_TYPE.SLIDER)
  {
    if ("optionType" in item)
    {
      local config = ::get_option(item.optionType)
      elemIdTxt = "options/" + config.id
      elemTxt = ::create_option_slider(item.id, config.value, "onSliderChange", true, "slider", config)
    }
    else
    {
      local value = ("value" in item)? item.value(params) : 50
      elemTxt = ::create_option_slider(item.id, value.tointeger(), "onSliderChange", true, "slider", item)
    }

    elemTxt += format("activeText{ id:t='%s'; margin-left:t='0.01@sf' } ", item.id+"_value")
  }
  else if (item.type== CONTROL_TYPE.SWITCH_BOX)
  {
    local config = null
    if ("optionType" in item)
    {
      config = ::get_option(item.optionType)
      elemIdTxt = "options/" + config.id
      config.id = item.id
    }
    else
    {
      local value = ("value" in item)? item.value(params) : false
      config = {
        id = item.id
        value = value
      }
    }
    config.cb <- ::getTblValue("onChangeValue", item)
    elemTxt = ::create_option_switchbox(config)
  }
  else if (item.type== CONTROL_TYPE.MOUSE_AXIS && (item.values.len() > 0) && ("axis_num" in item))
  {
    local value = params.getMouseAxis(item.axis_num)
    local callBack = ("onChangeValue" in item)? item.onChangeValue : null
    local options = []
    for (local i = 0; i < item.values.len(); i++)
      options.append("#controls/" + item.values[i])
    local sel = ::find_in_array(item.values, value)
    if (!(sel in item.values))
      sel = 0
    elemTxt = ::create_option_list(item.id, options, sel, callBack, true)
  }
  else if (item.type == CONTROL_TYPE.BUTTON)
  {
    elemIdTxt = "";
    elemTxt = ::handyman.renderCached("gui/commonParts/button", {
      id = item.id
      text = "#controls/" + item.id
      funcName = "onActionButtonClick"
    })
  }
  else
  {
    res = "tr { display:t='hide'; td {} td { tdiv{} } }"
    ::dagor.debug("Error: wrong shortcut - " + item.id)
  }

  if (elemTxt!="")
  {
    res = ::format("tr { css-hier-invalidate:t='all'; width:t='pw'; %s " +
                   "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext { text:t ='%s'; }} " +
                   "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad'; %s } " +
                 "}\n",
                 trAdd, elemIdTxt != "" ? "#" + elemIdTxt : "", elemTxt)
    hotkeyData.text = ::english_russian_to_lower_case(::loc(elemIdTxt))
    hotkeyData.markup = res
  }
  return hotkeyData
}

function get_shortcut_text(shortcuts, shortcutId, cantBeEmpty = true, strip_tags = false)
{
  if (!(shortcutId in shortcuts))
    return ""

  local data = ""
  for (local i = 0; i < shortcuts[shortcutId].len(); i++)
  {
    local text = ""
    local sc = shortcuts[shortcutId][i]
    local curPreset = ::g_controls_manager.getCurPreset()
    for (local j = 0; j < sc.dev.len(); j++)
      text += ((j != 0)? " + ":"") + ::getLocalizedControlName(curPreset, sc.dev[j], sc.btn[j])

    if (text=="")
      continue

    data = ::addHotkeyTxt(strip_tags? ::g_string.stripTags(text) : text, data)
  }

  if (cantBeEmpty && data=="")
    data = "---"

  return data
}

function addHotkeyTxt(hotkeyTxt, baseTxt="")
{
  return ((baseTxt!="")? baseTxt+", " : "") + "<color=@hotkeyColor>" + hotkeyTxt + "</color>"
}

//works like get_shortcut_text, but returns only first binded shortcut for action
//needed wor hud
function get_first_shortcut_text(shortcutData)
{
  local text = ""
  if (shortcutData.len() > 0)
  {
    local sc = shortcutData[0]

    local curPreset = ::g_controls_manager.getCurPreset()
    for (local j = 0; j < sc.btn.len(); j++)
      text += ((j != 0)? " + " : "") + ::getLocalizedControlName(curPreset, sc.dev[j], sc.btn[j])
  }

  return text
}

function get_shortcut_gamepad_textures(shortcutData)
{
  local res = []
  foreach(sc in shortcutData)
  {
    if (sc.dev.len() <= 0 || sc.dev[0] != ::JOYSTICK_DEVICE_0_ID)
      continue

    for (local i = 0; i < sc.dev.len(); i++)
      res.append(gamepadIcons.getTextureByButtonIdx(sc.btn[i]))
    return res
  }
  return res
}

//*************************Functions***************************//

function applySelectedPreset(presetName)
{
  if(::isInArray(presetName, ["keyboard", "keyboard_shooter"]))
    ::set_option(::USEROPT_HELPERS_MODE, globalEnv.EM_MOUSE_AIM)
  return ("config/hotkeys/hotkey." + presetName + ".blk")
}

function getSeparatedControlLocId(text)
{
  local txt = text
  local index_txt = ""

  if (txt.find("Button ") == 0) //"Button 1" in "Button" and "1"
    index_txt = " " + txt.slice("Button ".len())
  else if (txt.find("Button") == 0) //"Button1" in "Button" and "1"
    index_txt = " " + txt.slice("Button".len())

  if (index_txt != "")
    txt = ::loc("key/Button") + index_txt

  return txt
}

function getLocaliazedPS4controlName(text)
{
  return ::loc("xinp/" + text, "")
}

function getLocalizedControlName(preset, deviceId, buttonId)
{
  local text = preset.getButtonName(deviceId, buttonId)
  local locText = ::loc("key/" + text, "")
  if (locText != "")
    return locText

  if (deviceId != STD_KEYBOARD_DEVICE_ID) {
    locText = getLocaliazedPS4controlName(text)
    if (locText != "")
      return locText
  }

  return ::getSeparatedControlLocId(text)
}
function getLocalizedControlShortName(preset, deviceId, buttonId)
{
  local locText = getLocalizedControlName(preset, deviceId, buttonId)
  local replaces = ::is_platform_xboxone ? [
    [ "FirePrimary", "F1" ],
    [ "FireSecondary", "F2" ],
    [ "ExtraButton", "B" ]
  ] : []
  foreach (replace in replaces)
    locText = ::stringReplace(locText, replace[0], replace[1])
  return locText
}

function remapAxisName(preset, axisId)
{
  local text = preset.getAxisName(axisId)
  if (text == null)
    return "?"

  if (text.find("Axis ") == 0) //"Axis 1" in "Axis" and "1"
  {
    return ::loc("composite/axis")+text.slice("Axis ".len());
  }
  else if (text.find("Axis") == 0) //"Axis1" in "Axis" and "1"
  {
    return ::loc("composite/axis")+text.slice("Axis".len());
  }

  local locText = ::loc("joystick/" + text, "")
  if (locText != "")
    return locText

  locText = ::loc("key/" + text, "")
  if (locText != "")
    return locText

  locText = ::getLocaliazedPS4controlName(text)
  if (locText != "")
    return locText
  return text
}

function hackTextAssignmentForR2buttonOnPS4(mainText)
{
  if (::is_platform_ps4)
  {
    local hack = ::getLocaliazedPS4controlName("R2") + " + " + ::getLocaliazedPS4controlName("MouseLB")
    if (mainText.len() >= hack.len())
    {
      local replaceButtonText = ::getLocaliazedPS4controlName("R2")
      if (mainText.slice(0, hack.len()) == hack)
        mainText = replaceButtonText + mainText.slice(hack.len())
      else if (mainText.slice(mainText.len() - hack.len()) == hack)
        mainText = mainText.slice(0, mainText.len() - hack.len()) + replaceButtonText
    }
  }
  return mainText
}

function switchControlsMode(value)
{
  local cdb = ::get_local_custom_settings_blk()
  if (value == cdb[ps4ControlsModeActivatedParamName])
    return

  cdb[ps4ControlsModeActivatedParamName] = value
  ::save_profile_offline_limited()
}

function getUnmappedControlsForCurrentMission()
{
  local gm = ::get_game_mode()
  if (gm == ::GM_BENCHMARK)
    return []

  local unit = ::get_player_cur_unit()
  local helpersMode = ::getCurrentHelpersMode()
  local required = ::getRequiredControlsForUnit(unit, helpersMode)

  local unmapped = ::getUnmappedControls(required, helpersMode, true, false)
  if (::is_in_flight() && gm == ::GM_TRAINING)
  {
    local tutorialUnmapped = ::getUnmappedControlsForTutorial(::current_campaign_mission, helpersMode)
    foreach (id in tutorialUnmapped)
      ::u.appendOnce(id, unmapped)
  }
  return unmapped
}

function getCurrentHelpersMode()
{
  local difficulty = ::is_in_flight() ? ::get_mission_difficulty_int() : ::get_current_shop_difficulty().diffCode
  if (difficulty == 2)
    return (::is_platform_pc ? globalEnv.EM_FULL_REAL : globalEnv.EM_REALISTIC)
  local option = ::get_option_in_mode(::USEROPT_HELPERS_MODE, ::OPTIONS_MODE_GAMEPLAY)
  return option.values[option.value]
}

function getUnmappedControlsForTutorial(missionId, helpersMode)
{
  local res = []

  local mis_file = null
  local chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (m.name == missionId)
      {
        mis_file = m.mis_file
        break
      }
  local missionBlk = mis_file && ::DataBlock(mis_file)
  if (!missionBlk || !missionBlk.triggers)
    return res

  local tutorialControlAliases = {
    ["ANY"]                = null,
    ["ID_CONTINUE"]        = null,
    ["ID_SKIP_CUTSCENE"]   = null,
    ["ID_FIRE"]            = "ID_FIRE_MGUNS",
    ["ID_TRANS_GEAR_UP"]   = "gm_throttle",
    ["ID_TRANS_GEAR_DOWN"] = "gm_throttle",
    ["ID_ELEVATOR_UP"]     = "elevator",
    ["ID_ELEVATOR_DOWN"]   = "elevator",
    ["ID_AILERONS_LEFT"]   = "ailerons",
    ["ID_AILERONS_RIGHT"]  = "ailerons",
    ["ID_RUDDER_LEFT"]     = "rudder",
    ["ID_RUDDER_RIGHT"]    = "rudder",
  }

  local isXinput = ::is_xinput_device()
  local isAllowedCondition = @(condition) condition.gamepadControls == null || condition.gamepadControls == isXinput

  local conditionsList = []
  foreach (trigger in missionBlk.triggers)
  {
    if (typeof(trigger) != "instance")
      continue

    local condition = (trigger.props && trigger.props.conditionsType != "ANY") ? "ALL" : "ANY"

    local shortcuts = []
    if (trigger.conditions)
    {
      foreach (playerShortcutPressed in trigger.conditions % "playerShortcutPressed")
        if (playerShortcutPressed.control && isAllowedCondition(playerShortcutPressed))
        {
          local id = playerShortcutPressed.control
          local alias = (id in tutorialControlAliases) ? tutorialControlAliases[id] : id
          if (alias && !::isInArray(alias, shortcuts))
            shortcuts.append(alias)
        }

      foreach (playerWhenOptions in trigger.conditions % "playerWhenOptions")
        if (playerWhenOptions.currentView)
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_TOGGLE_VIEW" ] })

      foreach (unitWhenInArea in trigger.conditions % "unitWhenInArea")
        if (unitWhenInArea.target == "gears_area")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_GEAR" ] })

      foreach (unitWhenStatus in trigger.conditions % "unitWhenStatus")
        if (unitWhenStatus.object_type == "isTargetedByPlayer")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_LOCK_TARGET" ] })

      foreach (playerWhenCameraState in trigger.conditions % "playerWhenCameraState")
        if (playerWhenCameraState.state == "fov")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_ZOOM_TOGGLE" ] })
    }

    if (shortcuts.len())
      conditionsList.append({ condition = condition, shortcuts = shortcuts })
  }

  foreach (cond in conditionsList)
    if (cond.shortcuts.len() == 1)
      cond.condition = "ALL"

  for (local i = conditionsList.len() - 1; i >= 0; i--)
  {
    local duplicate = false
    for (local j = i - 1; j >= 0; j--)
      if (::u.isEqual(conditionsList[i], conditionsList[j]))
      {
        duplicate = true
        break
      }
    if (duplicate)
      conditionsList.remove(i)
  }

  local controlsList = []
  foreach (cond in conditionsList)
    foreach (id in cond.shortcuts)
      if (!::isInArray(id, controlsList))
        controlsList.append(id)
  local unmapped = ::getUnmappedControls(controlsList, helpersMode, false, false)

  foreach (cond in conditionsList)
  {
    if (cond.condition == "ALL")
      foreach (id in cond.shortcuts)
        if (::isInArray(id, unmapped) && !::isInArray(id, res))
          res.append(id)
  }

  foreach (cond in conditionsList)
  {
    if (cond.condition == "ANY" || cond.condition == "ONE")
    {
      local allUnmapped = true
      foreach (id in cond.shortcuts)
        if (!::isInArray(id, unmapped) || ::isInArray(id, res))
        {
          allUnmapped = false
          break
        }
      if (allUnmapped)
        foreach (id in cond.shortcuts)
          if (!::isInArray(id, res))
          {
            res.append(id)
            if (cond.condition == "ONE")
              break
          }
    }
  }

  res = ::getUnmappedControls(res, helpersMode, true, false)
  return res
}

local function getWeaponFeatures(weaponsBlkList)
{
  local res = {
    gotMachineGuns = false
    gotCannons = false
    gotAdditionalGuns = false
    gotBombs = false
    gotTorpedoes = false
    gotRockets = false
    gotAGM = false // air-to-ground missiles, anti-tank guided missiles
    gotAAM = false // air-to-air missiles
    gotWeaponLock = false
    gotGunnerTurrets = false
    gotSchraegeMusik = false
  }

  foreach (weaponSet in weaponsBlkList)
  {
    if (!weaponSet)
      continue

    foreach (w in (weaponSet % "Weapon"))
    {
      if (!w.blk || w.dummy)
        continue

      if (w.trigger == "machine gun")
        res.gotMachineGuns = true
      if (w.trigger == "cannon")
        res.gotCannons = true
      if (w.trigger == "additional gun")
        res.gotAdditionalGuns = true
      if (w.trigger == "bombs")
        res.gotBombs = true
      if (w.trigger == "torpedoes")
        res.gotTorpedoes = true
      if (w.trigger == "rockets")
        res.gotRockets = true
      if (w.trigger == "agm" || w.trigger == "atgm")
        res.gotAGM = true
      if (w.trigger == "aam")
        res.gotAAM = true
      if (::g_string.startsWith(w.trigger || "", "gunner"))
        res.gotGunnerTurrets = true
      if (::is_platform_pc && w.schraegeMusikAngle != null)
        res.gotSchraegeMusik = true
      local weaponBlk = ::DataBlock(w.blk)
      if (weaponBlk?.rocket?.guidance)
        res.gotWeaponLock = true
    }
  }

  return res
}

function getRequiredControlsForUnit(unit, helpersMode)
{
  local controls = []
  if (!unit || ::use_touchscreen)
    return controls

  local unitId = unit.name
  local unitType = unit.unitType

  local preset = ::g_controls_manager.getCurPreset()
  local actionBarShortcutFormat = null

  local unitBlk = null
  local blkCommonWeapons = null
  local blkWeaponPreset = null
  local hasControllableRadar = false

  unitBlk = ::get_full_unit_blk(unitId)
  blkCommonWeapons = ::getCommonWeaponsBlk(unitBlk, ::get_last_primary_weapon(unit)) || ::DataBlock()
  local curWeaponPresetId = ::is_in_flight() ? ::get_cur_unit_weapon_preset() : ::get_last_weapon(unitId)
  blkWeaponPreset = ::DataBlock()
  if (unitBlk.weapon_presets)
    foreach (idx, presetBlk in (unitBlk.weapon_presets % "preset"))
      if (presetBlk.name == curWeaponPresetId || (curWeaponPresetId == "" && idx == 0))
      {
        blkWeaponPreset = ::DataBlock(presetBlk.blk)
        break
      }

  if (unitBlk.sensors)
    foreach (sensor in (unitBlk.sensors % "sensor"))
      hasControllableRadar = hasControllableRadar || ::DataBlock(sensor.blk ?? "").type == "radar"

  local isMouseAimMode = helpersMode == globalEnv.EM_MOUSE_AIM

  if (unitType == ::g_unit_type.AIRCRAFT && unit.isUfo())
  {
    controls = [ "thrust_vector_forward_ufo" ]

    if (isMouseAimMode)
      controls.extend([ "mouse_aim_x_ufo", "mouse_aim_y_ufo" ])

    local w = getWeaponFeatures([ blkCommonWeapons, blkWeaponPreset ])

    if (preset.getAxis("fire").axisId == -1)
    {
      if (w.gotMachineGuns || (!w.gotCannons && w.gotGunnerTurrets)) // Gunners require either Mguns or Cannons shortcut.
        controls.append("ID_FIRE_LASERGUNS_UFO")
      if (w.gotCannons)
        controls.append("ID_FIRE_RAILGUNS_UFO")
    }
    if (w.gotTorpedoes)
      controls.append("ID_TORPEDOES_UFO")
  }
  else if (unitType == ::g_unit_type.AIRCRAFT)
  {
    local fmBlk = ::get_fm_file(unitId, unitBlk)
    local unitControls = fmBlk.AvailableControls || ::DataBlock()

    local gotInstructor = isMouseAimMode || helpersMode == globalEnv.EM_INSTRUCTOR
    local option = ::get_option_in_mode(::USEROPT_INSTRUCTOR_GEAR_CONTROL, ::OPTIONS_MODE_GAMEPLAY)
    local instructorGearControl = gotInstructor && option.value

    controls = [ "ID_TOGGLE_ENGINE", "throttle" ]

    if (isMouseAimMode)
      controls.extend([ "mouse_aim_x", "mouse_aim_y" ])
    else
    {
      if (unitControls.hasAileronControl)
        controls.append("ailerons")
      if (unitControls.hasElevatorControl)
        controls.append("elevator")
      if (unitControls.hasRudderControl)
        controls.append("rudder")
    }

    if (unitControls.hasGearControl && !instructorGearControl)
      controls.append("ID_GEAR")
    if (unitControls.hasAirbrake)
      controls.append("ID_AIR_BRAKE")
    if (unitControls.hasFlapsControl)
    {
      local shortcuts = ::get_shortcuts([ "ID_FLAPS", "ID_FLAPS_UP", "ID_FLAPS_DOWN" ])
      local flaps   = ::isShortcutMapped(shortcuts[0])
      local flapsUp = ::isShortcutMapped(shortcuts[1])
      local flapsDn = ::isShortcutMapped(shortcuts[2])

      if (!flaps && !flapsUp && !flapsDn)
        controls.append("ID_FLAPS")
      else if (!flaps && !flapsUp && flapsDn)
        controls.append("ID_FLAPS_UP")
      else if (!flaps && flapsUp && !flapsDn)
        controls.append("ID_FLAPS_DOWN")
    }

    if (unitBlk.parachutes)
      controls.append("ID_CHUTE")

    local w = getWeaponFeatures([ blkCommonWeapons, blkWeaponPreset ])

    if (preset.getAxis("fire").axisId == -1)
    {
      if (w.gotMachineGuns || (!w.gotCannons && (w.gotGunnerTurrets || w.gotSchraegeMusik))) // Gunners require either Mguns or Cannons shortcut.
        controls.append("ID_FIRE_MGUNS")
      if (w.gotCannons)
        controls.append("ID_FIRE_CANNONS")
      if (w.gotAdditionalGuns)
        controls.append("ID_FIRE_ADDITIONAL_GUNS")
    }
    if (w.gotBombs || w.gotTorpedoes)
      controls.append("ID_BOMBS")
    if (w.gotRockets)
      controls.append("ID_ROCKETS")
    if (w.gotAGM)
      controls.append("ID_AGM")
    if (w.gotAAM)
      controls.append("ID_AAM")
    if (w.gotSchraegeMusik)
      controls.append("ID_SCHRAEGE_MUSIK")
    if (w.gotWeaponLock)
      controls.append("ID_WEAPON_LOCK")

    if (hasControllableRadar)
    {
      controls.append("ID_SENSOR_SWITCH")
      controls.append("ID_SENSOR_TARGET_SWITCH")
      controls.append("ID_SENSOR_TARGET_LOCK")
    }
  }
  else if (unitType == ::g_unit_type.HELICOPTER)
  {
    controls = [ "helicopter_collective", "helicopter_climb", "helicopter_cyclic_roll" ]

    if (::is_xinput_device())
      controls.extend([ "helicopter_mouse_aim_x", "helicopter_mouse_aim_y" ])

    local w = getWeaponFeatures([ blkCommonWeapons, blkWeaponPreset ])

    if (preset.getAxis("fire").axisId == -1)
    {
      if (w.gotMachineGuns || (!w.gotCannons && w.gotGunnerTurrets)) // Gunners require either Mguns or Cannons shortcut.
        controls.append("ID_FIRE_MGUNS_HELICOPTER")
      if (w.gotCannons)
        controls.append("ID_FIRE_CANNONS_HELICOPTER")
      if (w.gotAdditionalGuns)
        controls.append("ID_FIRE_ADDITIONAL_GUNS_HELICOPTER")
    }
    if (w.gotBombs || w.gotTorpedoes)
      controls.append("ID_BOMBS_HELICOPTER")
    if (w.gotRockets)
      controls.append("ID_ROCKETS_HELICOPTER")
    if (w.gotAGM)
      controls.append("ID_ATGM_HELICOPTER")
    if (w.gotAAM)
      controls.append("ID_AAM_HELICOPTER")
    if (w.gotWeaponLock)
      controls.append("ID_WEAPON_LOCK_HELICOPTER")
  }
  else if (unitType == ::g_unit_type.TANK && unit.isWalker())
  {
    controls = [ "walker_throttle", "walker_steering", "walker_mouse_aim_x", "walker_mouse_aim_y",
      "ID_TOGGLE_VIEW_WALKER", "ID_FIRE_WALKER", "ID_FIRE_WALKER_SPECIAL_GUN" ]
  }
  else if (unitType == ::g_unit_type.TANK)
  {
    controls = [ "gm_throttle", "gm_steering", "gm_mouse_aim_x", "gm_mouse_aim_y", "ID_TOGGLE_VIEW_GM", "ID_FIRE_GM", "ID_REPAIR_TANK" ]

    if (::is_platform_pc && !::is_xinput_device())
    {
      if (::shop_is_modification_enabled(unitId, "manual_extinguisher"))
        controls.append("ID_ACTION_BAR_ITEM_6")
      if (::shop_is_modification_enabled(unitId, "art_support"))
      {
        controls.append("ID_ACTION_BAR_ITEM_5")
        controls.append("ID_SHOOT_ARTILLERY")
      }
    }

    if (hasControllableRadar)
    {
      controls.append("ID_SENSOR_TARGET_SWITCH_TANK")
      controls.append("ID_SENSOR_TARGET_LOCK_TANK")
    }

    local gameParams = ::dgs_get_game_params()
    local missionDifficulty = ::get_mission_difficulty()
    local difficultyName = ::g_difficulty.getDifficultyByName(missionDifficulty).settingsName
    local difficultySettings = gameParams?.difficulty_settings?.baseDifficulty?[difficultyName]

    local tags = unit?.tags || []
    local scoutPresetId = difficultySettings?.scoutPreset || ""
    if (::has_feature("ActiveScouting") && tags.find("scout") != null
      && gameParams?.scoutPresets?[scoutPresetId]?.enabled)
      controls.append("ID_SCOUT")

    actionBarShortcutFormat = "ID_ACTION_BAR_ITEM_%d"
  }
  else if (unitType == ::g_unit_type.SHIP)
  {
    controls = ["ship_steering", "ID_TOGGLE_VIEW_SHIP"]

    local isSeperatedEngineControl =
      ::get_gui_option_in_mode(::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, ::OPTIONS_MODE_GAMEPLAY)
    if (isSeperatedEngineControl)
      controls.extend(["ship_port_engine", "ship_star_engine"])
    else
      controls.append("ship_main_engine")

    local weaponGroups = [
      {
        triggerGroup = "primary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_PRIMARY"]
      }
      {
        triggerGroup = "secondary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_SECONDARY"]
      }
      {
        triggerGroup = "machinegun"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_MACHINEGUN"]
      }
      {
        triggerGroup = "torpedoes"
        shortcuts = ["ID_SHIP_WEAPON_TORPEDOES"]
      }
      {
        triggerGroup = "depth_charge"
        shortcuts = ["ID_SHIP_WEAPON_DEPTH_CHARGE"]
      }
      {
        triggerGroup = "mortar"
        shortcuts = ["ID_SHIP_WEAPON_MORTAR"]
      }
      {
        triggerGroup = "rockets"
        shortcuts = ["ID_SHIP_WEAPON_ROCKETS"]
      }
    ]

    foreach (weaponSet in [ blkCommonWeapons, blkWeaponPreset ])
    {
      if (!weaponSet)
        continue

      foreach (weapon in (weaponSet % "Weapon"))
      {
        if (!weapon.blk || weapon.dummy)
          continue

        foreach (group in weaponGroups)
        {
          if ("isRequired" in group ||
            group.triggerGroup != ::getTblValue("triggerGroup", weapon))
            continue

          group.isRequired <- true
          break
        }
      }
    }

    foreach (group in weaponGroups)
      if ("isRequired" in group)
      {
        local isMapped = false
        foreach (shortcut in group.shortcuts)
          if (preset.getHotkey(shortcut).len() > 0)
          {
            isMapped = true
            break
          }
        if (!isMapped)
          foreach (shortcut in group.shortcuts)
            if (controls.find(shortcut) < 0)
              controls.append(shortcut)
      }

    actionBarShortcutFormat = "ID_SHIP_ACTION_BAR_ITEM_%d"
  }

  if (actionBarShortcutFormat)
  {
    if (::is_platform_pc && !::is_xinput_device())
    {
      local bulletsChoice = 0
      for (local groupIndex = 0; groupIndex < ::BULLETS_SETS_QUANTITY; groupIndex++)
      {
        if (::isBulletGroupActive(unit, groupIndex))
        {
          local bullets = ::get_unit_option(unitId, ::USEROPT_BULLET_COUNT0 + groupIndex)
          if (bullets != null && bullets > 0)
            bulletsChoice++
        }
      }
      if (bulletsChoice > 1)
        for (local i = 0; i < bulletsChoice; i++)
          controls.append(::format(actionBarShortcutFormat, i + 1))
    }
  }

  return controls
}

function getUnmappedControls(controls, helpersMode, getLocNames = true, shouldCheckRequirements = false)
{
  local unmapped = []

  local joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())

  foreach (item in ::shortcutsList)
  {
    if (::isInArray(item.id, controls))
    {
      if ((("filterHide" in item) && ::isInArray(helpersMode, item.filterHide))
        || (("filterShow" in item) && !::isInArray(helpersMode, item.filterShow))
        || (shouldCheckRequirements && helpersMode == globalEnv.EM_MOUSE_AIM && !item.reqInMouseAim))
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT)
      {
        local shortcuts = ::get_shortcuts([ item.id ])
        if (shortcuts.len() && !::isShortcutMapped(shortcuts[0]))
          unmapped.append((getLocNames ? "hotkeys/" : "") + item.id)
      }
      else if (item.type == CONTROL_TYPE.AXIS)
      {
        if (::is_axis_mapped_on_mouse(item.id, helpersMode, joyParams))
          continue

        local axisIndex = ::get_axis_index(item.id)
        local axisId = axisIndex >= 0
          ? joyParams.getAxis(axisIndex).axisId : -1
        if (axisId == -1)
        {
          local modifiers = ["rangeMin", "rangeMax"]
          local shortcutsCount = 0
          foreach (modifier in modifiers)
          {
            if (!("hideAxisOptions" in item) || !::isInArray(modifier, item.hideAxisOptions))
            {
              local shortcuts = ::get_shortcuts([ item.id + "_" + modifier ])
              if (shortcuts.len() && ::isShortcutMapped(shortcuts[0]))
                shortcutsCount++
            }
          }
          if (shortcutsCount < modifiers.len())
            unmapped.append((getLocNames ? "controls/" : "") + item.axisName)
        }
      }
    }
  }

  return unmapped
}

function autorestore_preset()
{
  if (::get_controls_preset() != "")
    return

  local pList = ::g_controls_presets.getControlsPresetsList()
  local curPreset = ""

  local scNames = ::get_full_shortcuts_list()
  local curSc = ::get_shortcuts(scNames)

  foreach(preset in pList)
  {
    local blk = ::DataBlock()
    blk.load(::g_controls_presets.getControlsPresetFilename(preset))
    if (!blk)
      continue

    if (!blk.hotkeys || !blk.joysticks)
      continue

    if (!::compare_axis_with_blk(blk.joysticks))
      continue

    if (!::compare_shortcuts_with_blk(scNames, curSc, blk.hotkeys))
      continue

    curPreset = preset
    break
  }

  if (curPreset == "")
    return

  ::g_controls_manager.getCurPreset().setDefaultBasePresetName(curPreset)
  dagor.debug("PRESETS: Autorestore defaultBasePreset to " + curPreset)
}

function get_full_shortcuts_list()
{
  local res = []
  res.extend(::shortcuts_not_change_by_preset)

  local axisScNames = shortcutsAxisListModule.types.filter(@(idx, item) item.type == CONTROL_TYPE.AXIS_SHORTCUT)
  foreach(item in ::shortcutsList)
    if (item.type == CONTROL_TYPE.SHORTCUT)
      ::u.appendOnce(item.id, res)
    else if (item.type == CONTROL_TYPE.AXIS)
      foreach(name in axisScNames)
        ::u.appendOnce(item.axisName + ((name=="")?"" : "_" + name), res)
  return res
}

function compare_shortcuts_with_blk(names, scList, scBlk, dbg = false)
{
  if (names.len() != scList.len())
    return false

  local res = true
  //some shortcuts exist in blk twice, and merged in code. So need to get a full list before analize it.
  local scbList = ::get_shortcuts_from_blk(names, scBlk)
  foreach(idx, scb in scbList)
  {
    local sc = scList[idx]

    if (!scb)
    {
      if (!::isShortcutMapped(sc))
        continue

      res = false
      if (dbg)
      {
        dagor.debug("PRESETS: found unmapped shortcut: " + names[idx])
        debugTableData(sc)
        continue
      }
      break
    }

    if (!::is_shortcut_equal(sc, scb))
    {
      res = false
      if (dbg)
      {
        dagor.debug("PRESETS: not equal shortcuts: " + names[idx])
        debugTableData(sc)
        debugTableData(scb)
        continue
      }
      break
    }
  }
  return res
}

function is_shortcut_equal(sc1, sc2)
{
  if (sc1.len() != sc2.len())
    return false

  foreach(i, sb in sc2)
    if (!::is_bind_in_shortcut(sb, sc1))
      return false
  return true
}

function is_shortcut_display_equal(sc1, sc2)
{
  foreach(i, sb in sc1)
    if (::is_bind_in_shortcut(sb, sc2))
      return true
  return false
}

function is_bind_in_shortcut(bind, shortcut)
{
  foreach(sc in shortcut)
    if (sc.btn.len() == bind.btn.len())
    {
      local same = true
      foreach(ib, btn in bind.btn)
      {
        local i = ::find_in_array(sc.btn, btn)
        if (i < 0 || sc.dev[i] != bind.dev[ib])
        {
          same = false
          break
        }
      }
      if (same)
        return true
    }
  return false
}

function get_shortcuts_from_blk(names, scBlk)
{
  local res = array(names.len(), null)
  foreach(event in scBlk % "event")
  {
    local idx = ::find_in_array(names, event.name)
    if (idx >= 0)
      res[idx] = ::get_shortcut_data_from_blk(event, res[idx])
  }
  return res
}

function get_shortcut_data_from_blk(blk, mergedRes = null)
{
  if (!mergedRes)
    mergedRes = []
  foreach(scBlk in blk % "shortcut")
  {
    local sc = { btn = [], dev = [] }
    foreach(btn in scBlk % "button")
      if (btn.deviceId != null && btn.buttonId != null)
      {
        sc.btn.append(btn.buttonId)
        sc.dev.append(btn.deviceId)
      }
    if (!::is_bind_in_shortcut(sc, mergedRes))
      mergedRes.append(sc)
  }
  return mergedRes
}

function compare_axis_with_blk(blk)
{
  local joyBlk = blk.joystickSettings
  if (!joyBlk)
    return true

  local joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())

  local paramsList = ["isHatViewMouse"
                    "trackIrZoom"
                    "trackIrForLateralMovement"
                    "trackIrAsHeadInTPS"
                    "isMouseLookHold"
                    "holdThrottleForWEP"
                    "useJoystickMouseForVoiceMessage"
                    "useMouseForVoiceMessage"
                    "mouseJoystick"]
  foreach(p in paramsList)
    if (joyBlk[p] != null && joyBlk[p] != joyParams[p])
      return false

  foreach(item in ::shortcutsList)
  {
    if (item.type != CONTROL_TYPE.AXIS)
      continue

    local axisBlk = joyBlk[item.id]
    local axis = joyParams.getAxis(item.axisIndex)
    if (!axisBlk || !axis)
      continue

    if (!::compare_blk_axis(axisBlk, axis))
      return false
  }

  if (joyBlk.mouse)
    foreach(i, value in joyBlk.mouse % "axis")
    {
      local name = ::get_axis_name(value) || ""
      if (name != joyParams.getMouseAxis(i)) //cant get mouse index from joyParams w/o code change
        return false
    }
  return true
}

function compare_blk_axis(blk, axis)
{
  local axisBase = ["axisId",
                    "inverse", "relative",
                    "keepDisabledValue",
                    /*"useSliders"*/ //nonLinearity sliers not use yet
                   ]
  foreach(p in axisBase)
    if (blk[p] != null && blk[p] != axis[p])
      return false

  local axisFloats = ["innerDeadzone", /*"outerDeadzone",*/
                      /*"rangeMin", "rangeMax", */
                      "nonlinearity",
                      "kAdd", "kMul",
                      "relSens", "relStep",
                     ]
  foreach(p in axisFloats)
    if (blk[p] != null && fabs(blk[p] - axis[p]) > 0.001)
      return false

  /*  //nonLinearitySliders not used yet.
  if (blk.useSliders)
    foreach(idx, value in axis.nonLinearitySliders)
      if (blk["nonLinearitySlider" + idx] != value)
        return false
  */
  return true
}

function toggle_shortcut(shortcutName)
{
  ::activate_shortcut(shortcutName, true, true)
}

function set_shortcut_on(shortcutName)
{
  ::activate_shortcut(shortcutName, true, false)
}

function set_shortcut_off(shortcutName)
{
  ::activate_shortcut(shortcutName, false, false)
}

function is_device_connected(devId = null)
{
  if (!devId)
    return false

  local blk = ::DataBlock()
  ::fill_joysticks_desc(blk)

  for (local i = 0; i < blk.blockCount(); i++)
  {
    local device = blk.getBlock(i)
    if (device.disconnected)
      continue

    if (device.devId && device.devId.tolower() == devId.tolower())
      return true
  }

  return false
}

function check_joystick_thustmaster_hotas(changePreset = true)
{
  local deviceId =
    ::is_platform_ps4 ? ::hotas4_device_id :
    ::is_platform_xboxone ? ::hotas_one_device_id :
    null

  if (deviceId == null || !::g_login.isLoggedIn())
    return false

  if (!::is_device_connected(deviceId))
    return false

  return changePreset ? ::ask_hotas_preset_change() : true
}

function ask_hotas_preset_change()
{
  if (!::is_ps4_or_xbox || ::loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  local preset = ::g_controls_presets.getCurrentPreset()
  local is_ps4_non_gamepad_preset = ::is_platform_ps4
    && preset.name.find("dualshock4") == null
    && preset.name.find("default") == null
  local is_xboxone_non_gamepad_preset = ::is_platform_xboxone
    && preset.name.find("xboxone_ma") == null
    && preset.name.find("xboxone_simulator") == null

  ::saveLocalByAccount("wnd/detectThrustmasterHotas", true)

  if (is_ps4_non_gamepad_preset && is_xboxone_non_gamepad_preset)
    return

  local questionLocId =
    ::is_platform_ps4 ? "msgbox/controller_hotas4_found" :
    ::is_platform_xboxone ? "msgbox/controller_hotas_one_found" :
    ::unreachable()

  local mainAction = function() {
    local presetName =
      ::is_platform_ps4 ? "thrustmaster_hotas4" :
      ::is_platform_xboxone ? "xboxone_thrustmaster_hotas_one" :
      ::unreachable()
    ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename(presetName))
  }

  ::g_popups.add(
    null,
    ::loc(questionLocId),
    mainAction,
    [{
      id = "yes",
      text = ::loc("msgbox/btn_yes"),
      func = mainAction
    },
    { id = "no",
      text = ::loc("msgbox/btn_no")
    }],
    null,
    null,
    time.secondsToMilliseconds(time.minutesToSeconds(10))
  )
}
