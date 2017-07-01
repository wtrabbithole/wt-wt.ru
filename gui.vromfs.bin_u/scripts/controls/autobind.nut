function get_shortcut_autobind(shortcut)
{
  if (!("autobind" in shortcut))
    return []
  else if (::u.isArray(shortcut.autobind))
    return shortcut.autobind
  else if (::u.isFunction(shortcut.autobind))
    return shortcut.autobind()
  else
    return []
}

function get_autobind_raw(item)
{
  if (!("autobind_raw" in item))
    return null
  if (::u.isTable(item.autobind_raw))
    return item.autobind_raw
  if (::u.isFunction(item.autobind_raw))
    return item.autobind_raw()
  return null
}

function is_shortcut_buttons_used(targetShortcut, sourceHotkey)
{
  local preset = ::g_controls_manager.getCurPreset()
  foreach(otherShortcut in ::shortcutsList)
    if ((targetShortcut.checkGroup & otherShortcut.checkGroup) &&
      !::isInArray(otherShortcut.id, ::get_shortcut_autobind(targetShortcut)) &&
      !::isInArray(targetShortcut.id, ::get_shortcut_autobind(otherShortcut)))
      foreach (sourceHotkeyShortcut in sourceHotkey)
        if (preset.isHotkeyShortcutBinded(otherShortcut.id, sourceHotkeyShortcut))
          return true
  return false
}

function autobind_shortcuts(checkAutorestore = false)
{
  const AUTOBIND_TEST_SHORTCUT = "AUTOBIND_TEST_SHORTCUT"
  local preset = ::g_controls_manager.getCurPreset()
  if (checkAutorestore)
    autorestore_preset()

  if (::get_controls_preset() != "")
    return

  local haveChanges = false
  foreach(targetShortcut in ::shortcutsList)
  {
    if (targetShortcut.type != CONTROL_TYPE.SHORTCUT)
      continue

    local autobind = getTblValue("autobind", targetShortcut)
    local autobind_sc = getTblValue("autobind_sc", targetShortcut)
    if (!autobind && !autobind_sc)
      continue

    local targetHotkey = preset.getHotkey(targetShortcut.id)
    if (targetHotkey.len() > 0 && targetHotkey[0].len() > 0)
      continue

    local mapped = false
    if (autobind)
    {
      if (type(autobind) == "function")
        autobind = autobind()
      if (type(autobind) != "array")
        continue
      foreach(sourceShortcutId in autobind)
      {
        local sourceShortcut = ::getTblValue(sourceShortcutId, ::shortcuts_map)
        if (!sourceShortcut)
          continue
        local sourceHotkey = preset.getHotkey(sourceShortcutId)
        if (!sourceHotkey.len() || ::is_shortcut_buttons_used(targetShortcut, sourceHotkey))
          continue

        preset.setHotkey(targetShortcut.id, sourceHotkey)
        haveChanges = true
        mapped = true
        break
      }
    }
    if (!mapped && autobind_sc)
    {
      if (type(autobind_sc) == "function")
        autobind_sc = autobind_sc()
      if (type(autobind_sc) != "array")
        continue
      ::set_shortcuts([autobind_sc], [AUTOBIND_TEST_SHORTCUT])
      local sourceHotkey = preset.getHotkey(AUTOBIND_TEST_SHORTCUT)
      if (!sourceHotkey.len() || ::is_shortcut_buttons_used(targetShortcut, sourceHotkey))
        continue

      preset.setHotkey(targetShortcut.id, sourceHotkey)
      haveChanges = true
    }
  }

  if (AUTOBIND_TEST_SHORTCUT in preset.hotkeys)
    delete preset.hotkeys[AUTOBIND_TEST_SHORTCUT]

  //FIX incorrect autobind schraege musik shortcut
  local curSc = ::get_shortcuts(["ID_SCHRAEGE_MUSIK"])
  if (::isShortcutMapped(curSc[0]))
  {
    local wrongAutobind = ::get_shortcuts(["ID_FIRE_ADDITIONAL_GUNS", "ID_FIRE_CANNONS", "ID_FIRE_MGUNS"])
    foreach(sc in wrongAutobind)
      if (::u.isEqual(curSc[0], sc))
      {
        ::set_shortcuts([[]], ["ID_SCHRAEGE_MUSIK"])
        haveChanges = true
        break
      }
  }

  //FIX incorrect autobind artillery mode switch shortcut on ps4
  if (::is_platform_ps4)
  {
    local curSc = ::get_shortcuts(["ID_CHANGE_ARTILLERY_TARGETING_MODE"])
    local wrongAutobind = [[{ btn = [2], dev = [1] }]] // Middle mouse button
    if (::u.isEqual(curSc, wrongAutobind))
    {
      local goodAutobind = [[{ btn = [15], dev = [3] }]] // Gamepad Y
      ::set_shortcuts(goodAutobind, ["ID_CHANGE_ARTILLERY_TARGETING_MODE"])
      haveChanges = true
    }
  }

  if (::autobind_relative_axis_centering())
    haveChanges = true

  if (::autobind_axes())
    haveChanges = true

  if (::autobind_hidden_axises())
    haveChanges = true

  if (haveChanges)
    ::save_profile_offline_limited()
}

function autobind_relative_axis_centering()
{
  local haveChanges = false
  local preset = ::g_controls_manager.getCurPreset()
  local allowedButtonType = ::ControlsPreset.deviceIdByType.keyboardKey
  foreach (axisName, axis in preset.axes)
    if (axis.rangeMin < 0 && axis.rangeMax > 0 && axis.relative)
    {
      local rangeSetHotkeyName = axisName + "_rangeSet"
      local rangeSetHotkey = preset.getHotkey(rangeSetHotkeyName)
      if (rangeSetHotkey.len() > 0 && rangeSetHotkey[0].len() > 0)
        continue
      preset.resetHotkey(rangeSetHotkeyName)
      local rangeMinHotkey = preset.getHotkey(axisName + "_rangeMin")
      local rangeMaxHotkey = preset.getHotkey(axisName + "_rangeMax")
      local numCombinations = ::min(rangeMinHotkey.len(), rangeMaxHotkey.len())
      for (local j = 0; j < numCombinations; j++)
      {
        local rangeMinShortcut = rangeMinHotkey[j]
        local rangeMaxShortcut = rangeMaxHotkey[j]
        if (rangeMinShortcut.len() != 1 || rangeMaxShortcut.len() != 1 ||
          ::getTblValue("deviceId", rangeMinShortcut[0]) != allowedButtonType ||
          ::getTblValue("deviceId", rangeMaxShortcut[0]) != allowedButtonType)
          continue
        local rangeSetShortcut = [rangeMinShortcut[0], rangeMaxShortcut[0]]
        local axisInControls = ::getTblValue(axisName, ::shortcuts_map)
        if (axisInControls && ::is_shortcut_buttons_used(axisInControls, [rangeSetShortcut]))
          continue
        preset.addHotkeyShortcut(rangeSetHotkeyName, rangeSetShortcut)
        haveChanges = true
      }
    }
  return haveChanges
}

function autobind_axes()
{
  local curJoyParams = ::JoystickParams()
  curJoyParams.setFrom(::joystick_get_cur_settings())

  local haveChanges = false
  foreach(item in ::shortcutsList)
  {
    if (item.type != CONTROL_TYPE.AXIS)
      continue

    if (item.axisIndex < 0)
      continue

    local autobind = get_shortcut_autobind(item)
    foreach (entry in autobind)
    {
      local boundAxisIndex = ::get_axis_index(entry)
      if (boundAxisIndex < 0)
        continue

      local mapped = false
      foreach (shortcut in ::shortcutsAxisList)
      {
        if (shortcut.type == CONTROL_TYPE.AXIS_SHORTCUT)
        {
          local toName = item.id + (shortcut.id != "" ? "_" + shortcut.id : "")
          local proper = ::get_shortcuts([toName])
          if (proper.len())
            foreach(sc in proper)
              if (::isShortcutMapped(sc))
              {
                mapped = true
                break
              }
        }
        if (mapped)
          break
      }
      if (mapped) //already have shortcuts
        continue

      local axisAutoBound = false
      foreach (shortcut in ::shortcutsAxisList)
        if (shortcut.type == CONTROL_TYPE.AXIS_SHORTCUT)
        {
          local toName = item.id + (shortcut.id != "" ? "_" + shortcut.id : "")
          local fromName = entry + (shortcut.id != "" ? "_" + shortcut.id : "")
          local sample = ::get_shortcuts([fromName])
          if (!sample.len()) //no sample found
            continue
          foreach (sc in sample)
            if (::isShortcutMapped(sc))
            {
              ::set_shortcuts([sc], [toName])
              axisAutoBound = true
              break
            }
        }
      local axisFrom = curJoyParams.getAxis(boundAxisIndex)
      local axisTo = curJoyParams.getAxis(item.axisIndex)
      if ((axisAutoBound || axisFrom.axisId != -1) && axisTo.axisId == -1)
      {
        axisTo.inverse = axisFrom.inverse
        if (::getTblValue("autobind_inversed", item, false))
          axisTo.inverse = !axisTo.inverse;
        axisTo.inverse = axisFrom.inverse
        axisTo.innerDeadzone = axisFrom.innerDeadzone
        axisTo.nonlinearity = axisFrom.nonlinearity
        axisTo.kAdd = axisFrom.kAdd
        axisTo.kMul = axisFrom.kMul
        axisTo.relSens = axisFrom.relSens
        axisTo.relStep = axisFrom.relStep
        axisTo.relative = ::getTblValue("def_relative", item, axisFrom.relative)

        curJoyParams.bindAxis(item.axisIndex, axisFrom.axisId)
        haveChanges = true
      }
    }

    local autobindRaw = get_autobind_raw(item)
    local axisTo = curJoyParams.getAxis(item.axisIndex)
    if (::u.isTable(autobindRaw) && axisTo.axisId == -1)
    {
      local preset = ::g_controls_manager.getCurPreset()
      local keysRaw = ::getTblValue("keys", autobindRaw)
      if (::u.isTable(keysRaw))
      {
        foreach (keyId, keyData in keysRaw)
        {
          if (!::u.isArray(keyData))
            continue

          ::set_shortcuts([keyData], [AUTOBIND_TEST_SHORTCUT])
          local sourceHotkey = preset.getHotkey(AUTOBIND_TEST_SHORTCUT)

          local targetHotkey = preset.getHotkey(keyId)
          if (!sourceHotkey.len() || (targetHotkey.len() && targetHotkey[0].len()))
            continue

          preset.setHotkey(keyId, sourceHotkey)
          haveChanges = true
        }
      }
      local axisRaw = ::getTblValue("axis", autobindRaw)
      if (::u.isTable(axisRaw))
      {
        preset.setAxis(item.id, axisRaw)
        haveChanges = true
      }
    }
  }
  if (haveChanges)
  {
    local device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    ::joystick_set_cur_settings(curJoyParams)
  }
  return haveChanges;
}

function autobind_hidden_axises()
{
  if (::is_platform_pc)
    return false

  local haveChanges = false
  local curJoyParams = ::JoystickParams()
  curJoyParams.setFrom(::joystick_get_cur_settings())
  local device = ::joystick_get_default()
  foreach(axisType, axisData in ::autorestore_axis_table)
  {
    local curAxis = curJoyParams.getAxis(axisData.type)
    if (curAxis.axisId >= 0)
      continue

    ::dagor.debug("AUTOBIND AXISES: " + axisType + " for " + axisData.type + ", assigned axisId = " + curAxis.axisId)
    curJoyParams.bindAxis(axisData.type, axisData.id)
    curJoyParams.applyParams(device)
    haveChanges = true
  }

  if (haveChanges)
    ::joystick_set_cur_settings(curJoyParams)
  return haveChanges
}

function debug_all_presets_for_autobind() //!!this will reset your current shortcuts, debug presets only!!
{
  dagor.debug("PRESETS: debug_all_presets_for_autobind")
  local curPreset = ::get_controls_preset()

  local pList = ::g_controls_presets.getControlsPresetsList()
  local goodPresets = 0
  foreach(preset in pList)
  {
    dagor.debug("PRESETS: check preset " + preset)
    local blk = ::DataBlock()
    local presetFile = ::g_controls_presets.getControlsPresetFilename(preset)
    blk.load(presetFile)
    if (!blk)
    {
      dagor.debug("PRESETS: preset blk not found " + preset + ", " + presetFile)
      continue
    }

    if (!blk.hotkeys || !blk.joysticks)
    {
      dagor.debug("PRESETS: no block hotkeys or joystics in preset " + preset)
      continue
    }

    ::apply_joy_preset_xchange(presetFile, false)
    ::set_controls_preset("")
    ::autobind_shortcuts(false)
    local scNames = ::get_full_shortcuts_list()
    local curSc = ::get_shortcuts(scNames)

    if (!::compare_shortcuts_with_blk(scNames, curSc, blk.hotkeys, true))
      continue

    goodPresets++
    dagor.debug("PRESETS: OK!")
  }

  if (curPreset != "")
    ::apply_joy_preset_xchange(curPreset, false)
}
