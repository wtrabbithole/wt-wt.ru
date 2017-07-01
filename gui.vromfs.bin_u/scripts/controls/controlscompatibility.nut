// DEPRECATED
// Interface of ControlsPreset and ControlsManager for controls.nut
// TODO: Rewrite controls with new ControlsPreset and ControlsManager classes


function get_shortcuts(list, preset = null)
{
  if (preset == null)
    preset = ::g_controls_manager.getCurPreset()

  local result = []
  foreach (name in list)
  {
    local eventData = []

    local hotkey = preset.getHotkey(name)
    foreach (shortcut in hotkey)
    {
      local shortcutData = {dev = [], btn = []}
      foreach (button in shortcut)
      {
        shortcutData.dev.append(button.deviceId)
        shortcutData.btn.append(button.buttonId)
      }
      eventData.append(shortcutData)
    }
    result.append(eventData)
  }
  return result
}


function set_shortcuts(shortcutList, nameList, preset = null)
{
  if (preset == null)
    preset = ::g_controls_manager.getCurPreset()

  local result = []
  foreach (i, name in nameList)
  {
    local hotkey = []
    foreach (shortcut in shortcutList[i])
    {
      local shortcutData = []

      local numButtons = ::min(shortcut.dev.len(), shortcut.btn.len())
      for (local j = 0; j < numButtons; j++)
        shortcutData.append({
          deviceId = shortcut.dev[j]
          buttonId = shortcut.btn[j]
        })

      hotkey.append(shortcutData)
    }
    preset.setHotkey(name, hotkey)
  }

  if (preset == ::g_controls_manager.getCurPreset())
    ::g_controls_manager.commitControls()
}


function fix_shortcuts_and_axes_mapping(usedMapping, realMapping,
  shortcuts, shortcutNames, axisType = -1, axisList = [])
{
  ::dagor.debug("ControlsCompatibility: RemappingWhileEditControls")

  local tempPreset = ::ControlsPreset()
  tempPreset.deviceMapping = usedMapping

  ::set_shortcuts(shortcuts, shortcutNames, tempPreset)
  for (local i = 0; i < axisList.len(); i++)
    if (axisList[i].type == axisType && axisList[i].axisIndex >= 0)
      tempPreset.setAxis(axisList[i].id, {axisId = axisList[i].axisIndex})

  tempPreset.fixDeviceMapping(realMapping)

  shortcuts = ::get_shortcuts(shortcutNames, tempPreset)
  for (local i = 0; i < axisList.len(); i++)
    if (axisList[i].type == axisType && axisList[i].axisIndex >= 0)
      axisList[i].axisIndex = tempPreset.getAxis(axisList[i].id).axisId

  return shortcuts
}


joystick_params_template <- {
  getAxis = function(idx)
  {
    local name = ::get_axis_name(idx)
    return ::g_controls_manager.getCurPreset().getAxis(name)
  }

  getMouseAxis = function(idx) {
    if (idx < 0)
      return ""

    local curPreset = ::g_controls_manager.getCurPreset()
    foreach (axisName, axis in curPreset.axes)
      if (::getTblValue("mouseAxisId", axis, -1) == idx)
        return axisName

    return ""
  }

  setMouseAxis = function(idx, name) {
    if (idx < 0)
      return

    local curPreset = ::g_controls_manager.getCurPreset()
    foreach (axisName, axis in curPreset.axes)
      if (::getTblValue("mouseAxisId", axis, -1) == idx)
        axis["mouseAxisId"] <- -1

    if (name == "")
      return

    local axis = curPreset.getAxis(name)
    axis.mouseAxisId <- idx
  }

  applyParams = function(joy) {
    ::g_controls_manager.commitControls()
  }

  bindAxis = function(idx, realAxisIdx) {
    local name = ::get_axis_name(idx)
    local axis = ::g_controls_manager.getCurPreset().getAxis(name)
    axis.axisId = realAxisIdx
    ::g_controls_manager.commitControls()
  }

  setFrom = function(params) {
    ::u.extend(this, params)
  }
}
::u.extend(joystick_params_template, ::ControlsPreset.getDefaultParams())


function JoystickParams()
{
  return ::u.copy(joystick_params_template)
}


function joystick_get_cur_settings()
{
  local result = JoystickParams()
  ::u.extend(result, ::g_controls_manager.getCurPreset().params)
  return result
}


function joystick_set_cur_settings(other)
{
  local params = ::g_controls_manager.getCurPreset().params
  foreach(name, value in other)
    if (!::u.isFunction(value))
      params[name] <- value
  ::g_controls_manager.commitControls()
}


function set_controls_preset(presetPath)
{
  if (presetPath != "")
    ::g_controls_manager.setCurPreset(::ControlsPreset(presetPath))
  else
    ::g_controls_manager.notifyPresetModified()
}


function get_controls_preset()
{
  return ""
}

function restore_default_controls(preset)
{
  // Dummy. Preset loading performed by set_controls_preset later
}

function joystick_set_cur_values(settings)
{
  // Settings already changed by JoystickParams
  ::g_controls_manager.commitControls()
}
