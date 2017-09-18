class ::gui_handlers.AxisControls extends ::gui_handlers.Hotkeys
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/joystickAxisInput.blk"
  sceneNavBlkName = null
  owner = null

  axisItem = null
  curJoyParams = null
  shortcuts = null
  shortcutItems = null

  setupAxisMode = null
  autodetectAxis = false
  axisRawValues = null
  axisShortcuts = null
  dontCheckControlsDupes = null
  numAxisInList = 0
  curDevice = null
  bindAxisNum = -1

  function getMainFocusObj()
  {
    return getObj("axis_setup_table")
  }

  function initScreen()
  {
    axisRawValues = []
    axisShortcuts = []
    dontCheckControlsDupes = []

    curDevice = ::joystick_get_default()
    setupAxisMode = axisItem.axisIndex

    local axis = curJoyParams.getAxis(setupAxisMode)
    bindAxisNum = axis.axisId

    local titleObj = scene.findObject("axis_title")
    if (::checkObj(titleObj))
      titleObj.setValue(::loc("controls/" + axisItem.id))

    reinitAutodetectAxis()

    if ("modifiersId" in axisItem)
      foreach(name, shortcutId in axisItem.modifiersId)
        foreach(idx, block in ::shortcutsAxisList)
          if (name == block.id)
          {
            block.shortcutId = shortcutId
            break
          }

    fillAxisDropright()
    fillAxisTable(axis)
    updateAxisRelativeOptions(axis.relative)
    dontCheckControlsDupes = ::refillControlsDupes()

    local timerObj = scene.findObject("axis_test_box")
    if (::checkObj(timerObj))
      timerObj.setUserData(this)

    ::update_gamercards()
    initFocusArray()
    restoreFocus()
  }

  function reinitAutodetectAxis()
  {
    local autodetectChBxObj = scene.findObject("autodetect_checkbox")
    if (::checkObj(autodetectChBxObj))
    {
      autodetectChBxObj.setValue(autodetectAxis)
      onChangeAutodetect(autodetectChBxObj)

      if (!autodetectAxis)
        updateAxisItemsPos([0, 0])
    }
  }

  function getAxisRawValues(curDevice, idx)
  {
    local res = ::getTblValue(idx, axisRawValues)
    if (!res)
    {
      if (axisRawValues.len() <= idx)
        axisRawValues.resize(idx + 1, null)

      local rawPos = curDevice.getAxisPosRaw(idx)
      res = {
              def = rawPos,
              last = rawPos,
              stuckTime = 0.0,
              inited = ::is_axis_digital(idx) || rawPos!=0
            }
      axisRawValues[idx] = res
    }
    return res
  }

  function fillAxisTable(axis)
  {
    local axisControlsTbl = scene.findObject("axis_setup_table")
    if (!::checkObj(axisControlsTbl))
      return

    local hideAxisOptionsArray = []
    if (axisItem && ("hideAxisOptions" in axisItem))
      hideAxisOptionsArray = axisItem.hideAxisOptions

    local data = ""
    for(local i=0; i < ::shortcutsAxisList.len(); i++)
    {
      local addTrParams = ""
      if (isInArray(::shortcutsAxisList[i].id, hideAxisOptionsArray))
        addTrParams = "hiddenTr:t='yes'; inactive:t='yes';"

      data += ::buildHotkeyItem(i, shortcuts, ::shortcutsAxisList[i], axis, i%2 == 0, addTrParams)
    }

    guiScene.replaceContentFromText(axisControlsTbl, data, data.len(), this)

    local invObj = scene.findObject("invertAxis")
    if (::checkObj(invObj))
      invObj.setValue(axis.inverse ? 1 : 0)

    local relObj = scene.findObject("relativeAxis")
    if (::checkObj(relObj))
      relObj.setValue(axis.relative ? 1 : 0)

    updateAxisItemsPos([0,0])
    updateButtons()

    foreach(item in ::shortcutsAxisList)
      if (item.type == CONTROL_TYPE.SLIDER)
      {
        local slideObj = scene.findObject(item.id)
        if (::checkObj(slideObj))
          onSliderChange(slideObj)
      }
  }

  function onChangeAxisRelative(obj)
  {
    if (!::checkObj(obj))
      return

    updateAxisRelativeOptions(obj.getValue())
  }

  function updateAxisRelativeOptions(isRelative)
  {
    local txtObj = null
    txtObj = scene.findObject("txt_rangeMax")
    if (::checkObj(txtObj))
      txtObj.setValue(::loc(isRelative? "hotkeys/rangeInc" : "hotkeys/rangeMax"))

    txtObj = scene.findObject("txt_rangeMin")
    if (::checkObj(txtObj))
      txtObj.setValue(::loc(isRelative? "hotkeys/rangeDec" : "hotkeys/rangeMin"))

    for(local i=0; i < ::shortcutsAxisList.len(); i++)
    {
      local item = ::shortcutsAxisList[i]
      if (item.id == "kRelSpd" || item.id == "kRelStep")
      {
        local obj = scene.findObject("table_row_" + i)
        if (!::checkObj(obj))
          continue

        obj.inactive = isRelative? "no" : "yes"
        obj.enable = isRelative? "yes" : "no"
      }
    }
    restoreFocus()
  }

  function onSliderChange(obj)
  {
    local textObj = obj.getParent().findObject(obj.id + "_value")
    if (!::checkObj(textObj))
      return

    local reqItem = null
    foreach(item in ::shortcutsAxisList)
      if (item.type == CONTROL_TYPE.SLIDER && item.id == obj.id)
      {
        reqItem = item
        break
      }

    if (reqItem == null)
      return

    local value = obj.getValue()
    local valueText = ""
    if ("showValueMul" in reqItem)
      valueText = (reqItem.showValueMul * value).tostring()
    else
      valueText = value * (("showValuePercMul" in reqItem)? reqItem.showValuePercMul : 1) + "%"

    textObj.setValue(valueText)
  }

  function fillAxisDropright()
  {
    local listObj = scene.findObject("axis_list")
    if (!::checkObj(listObj))
      return

    curDevice = ::joystick_get_default()
    local curPreset = ::g_controls_manager.getCurPreset()
    numAxisInList = curDevice ? curPreset.getNumAxes() : 0

    local data = "option { id:t='axisopt_'; text:t='#joystick/axis_not_assigned' }\n"
    for(local i=0; i<numAxisInList; i++)
      data += format("option { id:t='axisopt_%d'; text:t='%s' }\n",
              i, ::g_string.stripTags(::remapAxisName(curPreset.getAxisName(i))))

    guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.setValue(curDevice? (bindAxisNum+1) : 0)

    updateAxisListValue()
  }

  function updateAxisListValue()
  {
    if (bindAxisNum > numAxisInList)
      return

    local listObj = scene.findObject("axis_list")
    if (!::checkObj(listObj))
      return

    //"-1", "+1" cos value is what we get from dropright, 0 is not recognized axis there,
    // but we have 0 axis

    if (listObj.getValue() - 1 == bindAxisNum)
      return

    listObj.setValue(bindAxisNum + 1)
  }

  function onButtonAutodetectAxis()
  {
    autodetectAxis =! autodetectAxis

    local obj = scene.findObject("autodetect_checkbox")
    if (::checkObj(obj))
      obj.setValue(autodetectAxis)

    updateAutodetectButtonStyle()
  }

  function onChangeAutodetect(obj)
  {
    autodetectAxis = obj.getValue()
    updateAutodetectButtonStyle()
  }

  function updateAutodetectButtonStyle()
  {
    local obj = scene.findObject("btn_axis_autodetect")
    if (::checkObj(obj))
    {
      local text = ::loc("mainmenu/btn" + (autodetectAxis? "StopAutodetect":"AutodetectAxis"))
      obj.tooltip = text
      obj.text = text

      local imgObj = obj.findObject("autodetect_img")
      if (::checkObj(imgObj))
        imgObj["background-image"] = "#ui/gameuiskin#btn_autodetect_" + (autodetectAxis? "off" : "on")
    }
  }

  function onAxisReset()
  {
    bindAxisNum = -1

    ::set_controls_preset("")
    local axis = curJoyParams.getAxis(setupAxisMode)
    axis.inverse = false
    axis.innerDeadzone = 0
    axis.nonlinearity = 0
    axis.kAdd = 0
    axis.kMul = 0
    axis.relSens = 0
    axis.relStep = 0
    axis.relative = false
    axis.keepDisabledValue = false

    foreach(item in ::shortcutsAxisList)
    {
      if (item.type == CONTROL_TYPE.SLIDER || item.type == CONTROL_TYPE.SPINNER || item.type == CONTROL_TYPE.SWITCH_BOX)
      {
        local slideObj = scene.findObject(item.id)
        if (::checkObj(slideObj))
          slideObj.setValue(item.value.call(this, axis))
      }
      else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
        clearBinds(item)
    }
  }

  function clearBinds(item)
  {
    local event = shortcuts[item.shortcutId]
    event.clear()
    updateShortcutText(item.shortcutId)
  }

  function onAxisBindChange(obj)
  {
    bindAxisNum = obj.getValue() - 1
  }

  function onAxisRestore()
  {
    local axis = curJoyParams.getAxis(setupAxisMode)
    bindAxisNum = axis.axisId
    updateAxisListValue()
  }

  function getCurItem()
  {
    local objTbl = scene.findObject("axis_setup_table")
    if (!::checkObj(objTbl))
      return null

    local idx = objTbl.cur_row.tointeger()
    if (idx < 0 || idx >= ::shortcutsAxisList.len())
      return null

    return ::shortcutsAxisList[idx]
  }

  function onAxisInputTimer(obj, dt)
  {
    if (scene.getModalCounter() > 0)
      return

    curDevice = ::joystick_get_default()

    if (!curDevice)
      return

    local foundAxis = -1
    local deviation = 12000 //foundedAxis deviation, cant be lower than a initial value
    local totalAxes = curDevice.getNumAxes()

    for (local i = 0; i < totalAxes; i++)
    {
      local rawValues = getAxisRawValues(curDevice, i)
      local rawPos = curDevice.getAxisPosRaw(i)
      if (!rawValues.inited && rawPos!=0)
      {
        rawValues.def = rawPos //reinit
        rawValues.inited = true
      }
      local dPos = rawPos - rawValues.def

      if (abs(dPos) > deviation)
      {
        foundAxis = i
        deviation = abs(dPos)

        if (fabs(rawPos-rawValues.last) < 1000)  //check stucked axes
        {
          rawValues.stuckTime += dt
          if (rawValues.stuckTime > 3.0)
            rawValues.def = rawPos //change cur value to def becoase of stucked
        } else
        {
          rawValues.last = rawPos
          rawValues.stuckTime = 0.0
        }
      }
    }

    if (autodetectAxis && foundAxis >= 0 && foundAxis != bindAxisNum)
      bindAxisNum = foundAxis

    updateAxisListValue()

    if (bindAxisNum < 0)
      return

    //!!FIX ME: Have to adjust the code below taking values from the table and only when they change
    local val = curDevice.getAxisPosRaw(bindAxisNum) / 32000.0
    if (setupAxisMode == ::AXIS_RUDDER_LEFT && val > 0)
      val = -val
    else if (setupAxisMode == ::AXIS_RUDDER_RIGHT && val < 0)
      val = -val

    local isInv = scene.findObject("invertAxis").getValue()

    local objDz = scene.findObject("deadzone")
    local deadzone = max_deadzone * objDz.getValue() / objDz.max.tofloat()
    local objNl = scene.findObject("nonlinearity")
    local nonlin = objNl.getValue().tofloat() / 10 - 1

    local objMul = scene.findObject("kMul")
    local kMul = objMul.getValue().tofloat() / 100.0
    local objAdd = scene.findObject("kAdd")
    local kAdd = objAdd.getValue().tofloat() / 50.0

    local devVal = val
    if (isInv)
      val = -1*val

    val = val*kMul+kAdd

    local valSign = val < 0? -1 : 1

    if (val > 1.0)
      val = 1.0
    else if (val < -1.0)
      val = -1.0

    val = fabs(val) < deadzone? 0 : valSign * ((fabs(val) - deadzone) / (1.0 - deadzone))

    val = valSign * (pow(fabs(val), (1 + nonlin)))

    updateAxisItemsPos([val, devVal])
  }

  function updateAxisItemsPos(valsArray)
  {
    if (typeof(valsArray) != "array")
      return

    local objectsArray = ["test-game-box", "test-real-box"]
    foreach(idx, id in objectsArray)
    {
      local obj = scene.findObject(id)
      if (!::checkObj(obj))
        continue

      local leftPos = (valsArray[idx] + 1.0) * 0.5
      obj.left = ::format("%.3f(pw - w)", leftPos)
    }
  }

  function checkZoomOnMWheel()
  {
    if (bindAxisNum < 0 || !axisItem || axisItem.id!="zoom")
      return false

    local mWheelId = "mouse_z"
    local wheelObj = scene.findObject(mWheelId)
    if (!wheelObj) return false

    foreach(item in ::shortcutsList)
      if (item.id == mWheelId)
      {
        local value = wheelObj.getValue()
        if (("values" in item) && (value in item.values) && (item.values[value]=="zoom"))
        {
          local msg = format(::loc("msg/zoomAssignmentsConflict"), ::loc("controls/mouse_z"))
          msgBox("zoom_axis_assigned", msg,
          [
            ["replace", (@(wheelObj) function() {
              if (wheelObj && wheelObj.isValid())
                wheelObj.setValue(0)
              doAxisApply()
            })(wheelObj)],
            ["cancel", function()
            {
              bindAxisNum = -1
              doAxisApply()
            }]
          ], "replace")
          return true
        }
        return false
      }
    return false
  }

  function doAxisApply()
  {
    local alreadyBindedAxeses = findBindedAxises(bindAxisNum)
    if (alreadyBindedAxeses.len() == 0)
    {
      doBindAxis()
      return
    }

    local actionText = ""
    foreach(item in alreadyBindedAxeses)
      actionText += ((actionText=="")? "":", ") + ::loc("controls/" + item.id)
    local msg = ::loc("hotkeys/msg/unbind_axis_question", {
      action=actionText
    })
    msgBox("controls_unbind_question", msg, [
      ["add", function() { doBindAxis() }],
      ["replace", (@(alreadyBindedAxeses) function() {
        foreach(item in alreadyBindedAxeses)
          curJoyParams.bindAxis(item.axisIndex, -1)
        doBindAxis()
      })(alreadyBindedAxeses)],
      ["cancel", function() {}],
    ], "add")
  }

  function findBindedAxises(curAxisId)
  {
    if (curAxisId < 0 || !axisItem.checkAssign)
      return []

    local res = []
    foreach(item in ::shortcutsList)
      if (item.type == CONTROL_TYPE.AXIS && item != axisItem)
      {
        local axis = curJoyParams.getAxis(item.axisIndex)
        if (curAxisId == axis.axisId)
          res.append(item)
      }
    return res
  }

  function doBindAxis()
  {
    curDevice = ::joystick_get_default()
    ::set_controls_preset(""); //custom mode
    curJoyParams.bindAxis(setupAxisMode, bindAxisNum)
    doApplyJoystick()
    curJoyParams.applyParams(curDevice)
    goBack()
  }

  function updateButtons()
  {
    local item = getCurItem()
    if (!item)
      return

    local showScReset = item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT
    showSceneBtn("btn_axis_reset_shortcut", showScReset)
    showSceneBtn("btn_axis_assign", showScReset)
  }

  function onTblSelect()
  {
    updateButtons()
  }

  function onTblDblClick()
  {
    local item = getCurItem()
    if (!item)
      return

    if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      callAssignButton()
  }

  function callAssignButton()
  {
    ::assignButtonWindow(this, onAssignButton)
  }

  function onAssignButton(dev, btn)
  {
    if (dev.len() > 0 && dev.len() == btn.len())
    {
      local item = getCurItem()
      if (item)
        bindShortcut(dev, btn, item)
    }
  }

  function findButtons(devs, btns, curItem)
  {
    local res = []

    if (::find_in_array(dontCheckControlsDupes, curItem.shortcutId) < 0)
      foreach (idx, event in shortcuts)
        if (curItem.checkGroup & shortcutItems[idx].checkGroup)
          foreach (button_index, button in event)
          {
            if (!button || button.dev.len() != devs.len())
              continue
            local numEqual = 0
            for (local i = 0; i < button.dev.len(); i++)
              for (local j = 0; j < devs.len(); j++)
                if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]))
                  numEqual++

            if (numEqual == btns.len() && ::find_in_array(dontCheckControlsDupes, shortcutItems[idx].id) < 0)
              res.append([idx, button_index])
          }

    return res
  }

  function getShortcutLocId(reqNameId, fullName = true)
  {
    if (!(reqNameId in shortcutItems))
      return ""

    local reqItem = shortcutItems[reqNameId]
    local reqName = reqItem.id

    if ("modifiersId" in reqItem)
      foreach(name, shortcutId in reqItem.modifiersId)
        if (shortcutId == reqNameId)
        {
          reqName = (fullName? reqItem.id + (name == ""? "" : "_"): "") + name
          break
        }

     return reqName
  }

  function bindShortcut(devs, btns, item)
  {
    if (!(item.shortcutId in shortcuts))
      return

    local curBinding = findButtons(devs, btns, item)
    if (curBinding.len() == 0)
    {
      doBind(devs, btns, item)
      return
    }

    for(local i = 0; i < curBinding.len(); i++)
      if (curBinding[i][0] == item.shortcutId)
        return

    local actions = ""
    foreach(idx, shortcut in curBinding)
      actions += (actions == ""? "" : ", ") + ::loc("hotkeys/" + getShortcutLocId(shortcut[0]))

    local msg = ::loc("hotkeys/msg/unbind_question", {action = actions})

    msgBox("controls_unbind_question", msg, [
      ["add", (@(devs, btns, item) function() {
        doBind(devs, btns, item)
      })(devs, btns, item)],
      ["replace", (@(curBinding, devs, btns, item) function() {
        foreach(binding in curBinding)
        {
          shortcuts[binding[0]].remove(binding[1])
          updateShortcutText(binding[0])
        }
        doBind(devs, btns, item)
      })(curBinding, devs, btns, item)],
      ["cancel", function() { }],
    ], "cancel")
    return
  }

  function doBind(devs, btns, item)
  {
    local event = shortcuts[item.shortcutId]
    event.append({
                   dev = devs,
                   btn = btns
                })

    if (event.len() > ::MAX_SHORTCUTS)
      event.remove(0)

    ::set_controls_preset("") //custom mode
    updateShortcutText(item.shortcutId)
  }

  function updateShortcutText(shortcutId)
  {
    if (!(shortcutId in shortcuts) ||
      !::isInArray(shortcutId, ::u.values(axisItem.modifiersId)))
      return

    local itemId = getShortcutLocId(shortcutId, false)
    local obj = scene.findObject("txt_sc_"+ itemId)

    if (::checkObj(obj))
      obj.setValue(::get_shortcut_text(shortcuts, shortcutId))
  }

  function onButtonReset()
  {
    local item = getCurItem()
    if (!item)
      return

    shortcuts[item.shortcutId].clear()
    updateShortcutText(item.shortcutId)
  }

  function onApply()
  {
    if (!checkZoomOnMWheel())
      doAxisApply()
  }

  function onEventControlsMappingChanged(realMapping)
  {
    doAxisApply()
  }

  function afterModalDestroy()
  {
    if (::handlersManager.isHandlerValid(owner) && ("updateSceneOptions" in owner))
      owner.updateSceneOptions()
  }

  function goBack()
  {
    ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }
}
