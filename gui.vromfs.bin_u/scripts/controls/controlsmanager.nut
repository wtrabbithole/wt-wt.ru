::g_script_reloader.loadOnce("scripts/controls/controlsPreset.nut")
::g_script_reloader.loadOnce("scripts/controls/controlsGlobals.nut")
::g_script_reloader.loadOnce("scripts/controls/controlsCompatibility.nut")

local GAMEPAD_ENTER_SHORTCUT = ::ps4_is_circle_selected_as_enter_button() ?
                                 ::SHORTCUT.GAMEPAD_B.btn[0] :
                                 ::SHORTCUT.GAMEPAD_A.btn[0]

::g_controls_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["curPreset"]

  // PRIVATE VARIABLES
  curPreset = ::ControlsPreset()
  isControlsCommitPerformed = false
  cachedDeviceMappingBlk = null

  fixesList = [
    {
      isAppend = true
      source = "ID_FLIGHTMENU"
      target = "ID_FLIGHTMENU_SETUP"
      value = [{
        deviceId = ::ControlsPreset.deviceIdByType.joyButton
        buttonId = 4 // Gamepad Start
      }]
      shouldAppendIfEmptyOnXInput = true
    }
    {
      isAppend = true
      source = "ID_CONTINUE",
      target = "ID_CONTINUE_SETUP"
      value = [{
        deviceId = ::ControlsPreset.deviceIdByType.joyButton
        buttonId = GAMEPAD_ENTER_SHORTCUT
      }]
      shouldAppendIfEmptyOnXInput = true
    }
    {
      target = "ID_FLIGHTMENU"
      value = [[{
        deviceId = ::ControlsPreset.deviceIdByType.keyboardKey
        buttonId = 1 // Escape key
      }]]
    }
    {
      target = "ID_CONTINUE"
      valueFunction = function()
      {
        return [[::is_xinput_device() ? {
          deviceId = ::ControlsPreset.deviceIdByType.joyButton
          buttonId = GAMEPAD_ENTER_SHORTCUT // used in mission hints
        } :
        {
          deviceId = ::ControlsPreset.deviceIdByType.keyboardKey
          buttonId = 57 // Space key
        }]]
      }
    }
  ]

  hardcodedShortcuts = [
    {
      condition = function() { return ::is_platform_pc }
      list = [
        {name = "ID_SCREENSHOT", combo = [{deviceId = 2, buttonId = 183} /*PrtSc*/ ]}
      ]
    }
  ]

  /****************************************************************/
  /*********************** PUBLIC FUNCTIONS ***********************/
  /****************************************************************/

  function getCurPreset()
  {
    return curPreset
  }

  function setCurPreset(otherPreset)
  {
    ::dagor.debug("ControlsManager: curPreset updated")
    curPreset = otherPreset
    cachedDeviceMappingBlk = null
    fixDeviceMapping()
    ::broadcastEvent("ControlsReloaded")
    commitControls()
  }

  function notifyPresetModified()
  {
    commitControls()
  }

  function fixDeviceMapping()
  {
    local usedMapping = curPreset.deviceMapping
    local realMapping = []

    local blkDeviceMapping = ::DataBlock()
    ::fill_joysticks_desc(blkDeviceMapping)

    if (::u.isEqual(cachedDeviceMappingBlk, blkDeviceMapping))
      return

    if (!cachedDeviceMappingBlk)
      cachedDeviceMappingBlk = ::DataBlock()
    cachedDeviceMappingBlk.setFrom(blkDeviceMapping)

    foreach (blkJoy in blkDeviceMapping)
      realMapping.push({
        name          = blkJoy["name"]
        devId         = blkJoy["devId"]
        buttonsOffset = blkJoy["btnOfs"]
        buttonsCount  = blkJoy["btnCnt"]
        axesOffset    = blkJoy["axesOfs"]
        axesCount     = blkJoy["axesCnt"]
        connected     = !::getTblValue("disconnected", blkJoy, false)
      })


    local mappingChanged =
      ::g_controls_manager.getCurPreset().fixDeviceMapping(realMapping)

    if (mappingChanged)
      ::broadcastEvent("ControlsMappingChanged", realMapping)
  }

  cachedShortcutGroupMap = null
  function getShortcutGroupMap()
  {
    if (!cachedShortcutGroupMap)
    {
      if (!("shortcutsList" in ::getroottable()))
        return {}

      local axisShortcutSuffixesList = []
      foreach (axisShortcut in ::shortcutsAxisList)
        if (axisShortcut.type == CONTROL_TYPE.AXIS_SHORTCUT)
          axisShortcutSuffixesList.append(axisShortcut.id)

      cachedShortcutGroupMap = {}
      foreach (shortcut in ::shortcutsList)
      {
        if (shortcut.type == CONTROL_TYPE.SHORTCUT || shortcut.type == CONTROL_TYPE.AXIS)
          cachedShortcutGroupMap[shortcut.id] <- shortcut.checkGroup
        if (shortcut.type == CONTROL_TYPE.AXIS)
          foreach (suffix in axisShortcutSuffixesList)
            cachedShortcutGroupMap[shortcut.id + "_" + suffix] <- shortcut.checkGroup
      }
    }
    return cachedShortcutGroupMap
  }

  /* Commit controls to game client */
  function commitControls(fixMappingIfRequired = true)
  {
    if (isControlsCommitPerformed)
      return
    isControlsCommitPerformed = true

    if (fixMappingIfRequired && ::is_platform_ps4)
      fixDeviceMapping()
    fixControls()

    commitGuiOptions()

    // Check helpers options and fix if nessesary
    ::broadcastEvent("BeforeControlsCommit")

    // Send controls to C++ client
    ::set_controls_preset_ext(
      ::getTblValue("default", curPreset.basePresetPaths, ""))

    ::set_shortcuts_ext(curPreset.hotkeys)

    ::joystick_set_cur_controls({
      axes        = curPreset.axes
      params      = curPreset.params
      squarePairs = curPreset.squarePairs
    })

    ::set_shortcuts_groups(::g_controls_manager.getShortcutGroupMap())

    isControlsCommitPerformed = false
  }

  function setDefaultRelativeAxes()
  {
    if (!("shortcutsList" in ::getroottable()))
      return

    foreach (shortcut in ::shortcutsList)
      if (shortcut.type == CONTROL_TYPE.AXIS &&
        ::getTblValue("def_relative", shortcut) && ::getTblValue("isAbsOnlyWhenRealAxis", shortcut))
      {
        local axis = curPreset.getAxis(shortcut.id)
        if (axis.axisId == -1)
          axis.relative = true
      }
  }

  function fixControls()
  {
    foreach (fixData in fixesList)
    {
      local value = "valueFunction" in fixData ?
        fixData.valueFunction() : fixData.value
      if (::getTblValue("isAppend", fixData))
      {
        if (curPreset.isHotkeyShortcutBinded(fixData.source, value) ||
          (fixData.shouldAppendIfEmptyOnXInput && ::is_xinput_device() &&
            curPreset.getHotkey(fixData.target).len() == 0))
          curPreset.addHotkeyShortcut(fixData.target, value)
      }
      else
        curPreset.setHotkey(fixData.target, value)
    }
    foreach (shortcutsGroup in hardcodedShortcuts)
      if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
        foreach (shortcut in shortcutsGroup.list)
          curPreset.removeHotkeyShortcut(shortcut.name, shortcut.combo)
    setDefaultRelativeAxes()
  }

  function restoreHardcodedKeys(maxShortcutCombinations)
  {
    foreach (shortcutsGroup in hardcodedShortcuts)
      if (!("condition" in shortcutsGroup) || shortcutsGroup.condition())
        foreach (shortcut in shortcutsGroup.list)
          if (curPreset.getHotkey(shortcut.name).len() < maxShortcutCombinations)
            curPreset.addHotkeyShortcut(shortcut.name, shortcut.combo)
  }

  function clearGuiOptions()
  {
    local prefix = "USEROPT_"
    foreach (type, value in curPreset.params)
      if (type.len() > prefix.len() && type.slice(0, prefix.len()) == prefix)
        delete curPreset.params[type]
  }

  function commitGuiOptions()
  {
    if (!::g_login.isProfileReceived())
      return

    local mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)
    local prefix = "USEROPT_"
    foreach (type, value in curPreset.params)
      if (type.len() > prefix.len() && type.slice(0, prefix.len()) == prefix)
      {
        if (type in getroottable())
          ::set_option(getroottable()[type], value)
      }
    ::set_gui_options_mode(mainOptionsMode)
    clearGuiOptions()
  }

  // While controls reloaded on PS4 from uncrorrect blk when mission started
  // it is required to commit controls when mission start.
  function onEventMissionStarted(params)
  {
    if (::is_platform_ps4)
      commitControls()
  }
}

::subscribe_handler(::g_controls_manager)

::g_script_reloader.registerPersistentDataFromRoot("g_controls_manager")
