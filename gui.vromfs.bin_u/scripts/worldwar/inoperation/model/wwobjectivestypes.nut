local enums = ::require("sqStdlibs/helpers/enums.nut")
local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")


::g_ww_objective_type <- {
  types = []
  cache = {
    byTypeName = {}
  }
}

::g_ww_objective_type.template <- {
  defenderString = "Defender"
  attackerString = "Attacker"
  prefixNameLocId = "wwar_obj/types/"
  prefixParamLocId = "wwar_obj/params/"

  invertUpdateValue = false

  titleParams = []
  defaultValuesTable = {}
  paramsArray = []
  updateArray = []
  currentStateParam = ""

  needStopTimer = function(dataBlk, statusBlk, time, side) { return true }
  isDefender = function(blk, side)
  {
    if (blk.defenderSide && typeof side != typeof blk.defenderSide)
      ::script_net_assert_once("invalid operation objective data", "Func isDefender: " + blk.defenderSide + " never be equal " + side)

    return blk.defenderSide == side
  }
  getActionString = function(blk, side) { return isDefender(blk, side)
                                    ? defenderString
                                    : attackerString }

  getNameId = function(dataBlk, side) { return getParamId(dataBlk, "title") }

  getName = function(dataBlk, statusBlk, side)
  {
    return getLocText(dataBlk, side, prefixNameLocId, "/name",
      getNameSpecification(dataBlk, statusBlk),
      getTitleLocId(dataBlk, statusBlk),
      getTitleLocParams(dataBlk, statusBlk, side))
  }
  getNameSpecification = @(dataBlk, statusBlk) ""

  getDesc = function(dataBlk, statusBlk, side)
  {
    local additionalTextLocId = dataBlk?.additionalDescriptionTextLocId
    local descList = [
      additionalTextLocId ? ::loc(additionalTextLocId, "") : "",
      getLocText(dataBlk, side, prefixNameLocId, "/desc", "", getTitleLocId(dataBlk, statusBlk))
    ]

    return ::g_string.implode(descList, "\n")
  }

  getParamName = function(blk, side, paramName)
  {
    return getLocText(blk, side, prefixParamLocId, "/name", "", paramName)
  }

  getLocText = function(blk, side, prefix = "", postfix = "", spec = "", name = "", params = null)
  {
    if (name != "" && name == currentStateParam)
      return ::loc("wwar_obj/params/currentState/name")
    local locText = ::loc(prefix + name + postfix, "", params)
    if (locText == "")
      locText = ::loc(prefix + blk.type + "/" + name + postfix, "", params)
    if (locText == "")
      locText = ::loc(prefix + blk.type + "/" + getActionString(blk, side) + postfix, "", params)
    if (locText == "")
      locText = ::loc(prefix + blk.type + "/" + getActionString(blk, side) + "/" + name + postfix + spec, "", params)
    if (locText == "")
      locText = ::loc(prefix + blk.type + postfix, "", params)
    return locText
  }
  getTitleLocId = function(dataBlk, statusBlk) { return dataBlk.id }
  getTitleLocParams = function(dataBlk, statusBlk, side)
  {
    local res = {}
    foreach (paramName in titleParams)
      res[paramName] <- (paramName in dataBlk)   ? getValueByParam(paramName, dataBlk, side)
                      : (paramName in statusBlk) ? getValueByParam(paramName, statusBlk, side)
                      : getTitleLocParamsDefaultValue(dataBlk, paramName)
    return res
  }

  getTitleLocParamsDefaultValue = function(dataBlk, pName)
  {
    if (pName in defaultValuesTable)
    {
      local value = defaultValuesTable[pName]
      return ::u.isFunction(value) ? value(dataBlk) : value
    }
    return ""
  }

  specificClassParamConvertion = {}
  convertParamValue = {
    timeSecScaled = function(value, blk) { return time.hoursToString(time.secondsToHours(value - ::g_world_war.getOperationTimeSec()), false, true)}
    holdTimeSec   = function(value, blk) { return time.hoursToString(time.secondsToHours(value), false, true)}
    zonePercent_ = function(value, blk) { return ::g_measure_type.getTypeByName("percent", true).getMeasureUnitsText(value)}
    zonesPercent = function(value, blk) { return ::g_measure_type.getTypeByName("percent", true).getMeasureUnitsText(value)}
    unitCount = function(value, blk) { return value + ::g_ww_unit_type.getUnitTypeByTextCode(blk.unitType).fontIcon }
    advantage = @(value, blk)
      ::loc("wwar_obj/params/advantage/value", {advantageFactor = ::round(value, 2)})
  }

  colorize = {
    holdTimeSec = "warning"
  }
  getColorizeByParam = function(param) { return ::getTblValue(param, colorize) }

  getValueByParam = function(param, blk, side = null, useConverter = true) {
    local value = blk[param]
    if (param in specificClassParamConvertion)
      value = specificClassParamConvertion[param](value, blk, side, this)
    if (useConverter && param in convertParamValue)
      value = convertParamValue[param](value, blk)
    return value
  }

  getParamId = function(blk, paramName) { return blk.getBlockName() + "_" + typeName + "_" + paramName }
  getParamsArray = function(blk, side)
  {
    local array = []
    foreach (paramName in paramsArray)
      if (paramName in blk)
      {
        array.append({
          id = getParamId(blk, paramName)
          pName = getParamName(blk, side, paramName)
          pValue = getValueByParam(paramName, blk, side)
        })
      }
    return array
  }

  getObjectiveStatus = function(sideValue, side)
  {
    local statusCode = -1
    if (sideValue)
      statusCode = sideValue == side? ::MISSION_OBJECTIVE_STATUS_COMPLETED : ::MISSION_OBJECTIVE_STATUS_FAILED
    return ::g_objective_status.getObjectiveStatusByCode(statusCode)
  }

  getUpdatableZonesParams = function(dataBlk, statusBlk, side)
  {
    return []
  }

  getUpdatableParamsArray = function(dataBlk, statusBlk, side)
  {
    if (!statusBlk)
      return []

    side = invertUpdateValue ?
      ::ww_side_val_to_name(::g_world_war.getOppositeSide(ww_side_name_to_val(side))) :
      side

    local array = []
    foreach (paramName in updateArray)
    {
      local checkName = paramName in statusBlk? paramName : paramName + side
      if (checkName in statusBlk)
      {
        local val = statusBlk[checkName]

        local block = statusBlk[checkName]
        local isDataBlock = ::u.isDataBlock(val)
        if (!isDataBlock)
        {
          block = ::DataBlock()
          block[checkName] = val
        }

        foreach (name, value in block)
        {
          local pValueParam = isDataBlock? name : paramName
          array.append({
            id = checkName
            pName = getParamName(dataBlk, side, pValueParam)
            pValue = paramName in convertParamValue? convertParamValue[pValueParam](value, dataBlk) : value
            colorize = getColorizeByParam(pValueParam)
          })
        }
      }
    }
    return array
  }

  getUpdatableParamsDescriptionText = @(dataBlk, statusBlk, side) ""
  getUpdatableParamsDescriptionTooltip = @(dataBlk, statusBlk, side) ""
  getReinforcementSpeedupPercent = @(dataBlk, statusBlk, side) 0

  timersArrayByParamName = {}
  timerSetVisibleFunctionTable = {}
  timerUpdateFunctionTables = {
    timeSecScaled = function(nestObj, dataBlk, statusBlk, type, updateParam, side)
    {
      if (!::checkObj(nestObj))
        return true

      local sideName = ::ww_side_val_to_name(side)
      local operationTime = (statusBlk.timeSecScaled || 0) - ::g_world_war.getOperationTimeSec()
      nestObj.setValue(type.getName(dataBlk, statusBlk, sideName))
      local needStopTimer = type.needStopTimer(dataBlk, statusBlk, operationTime, sideName)
      return needStopTimer
    }
    zones = function(nestObj, dataBlk, statusBlk, type, zoneName)
    {
      local valueObj = nestObj.findObject("pValue")
      if (!::checkObj(valueObj))
        return true

      local captureTimeSec = ::ww_get_zone_capture_time_sec(zoneName)
      local captureTimeEnd = dataBlk.holdTimeSec

      valueObj.setValue(time.hoursToString(time.secondsToHours(captureTimeSec), false, true))

      return captureTimeSec > captureTimeEnd
    }
  }

  timerFunc = function(handler, scene, objId, updateParam, timerParam, dataBlk, statusBlk, side)
  {
    local type = this
    local obj = scene.findObject(objId)
    if (!::check_obj(obj))
      return []

    local setVisibleFunc = ::g_ww_objective_type.getTimerSetVisibleFunctionTableByParam(type, timerParam)
    local isVisible = setVisibleFunc(obj, dataBlk, statusBlk, type, side)
    if (!isVisible)
      return []

    local updateFunc = ::g_ww_objective_type.getTimerUpdateFuncByParam(type, timerParam)
    local update = ::Callback((@(updateFunc, statusBlk, type, updateParam, timerParam, side) function(nestObj, dataBlk) {
      return updateFunc(nestObj, dataBlk, statusBlk, type, updateParam, side)
    })(updateFunc, statusBlk, type, updateParam, timerParam, side), handler)

    return [SecondsUpdater(obj, update, false, dataBlk)]
  }
}

enums.addTypesByGlobalName("g_ww_objective_type", {
  UNKNOWN = {}

  OT_CAPTURE_ZONE = {
    titleParams = ["num", "timeSecScaled"]
    updateArray = ["holdTimeSec"]

    getNameId = function(dataBlk, side) { return getParamId(dataBlk, "timeSecScaled") }
    getTitleLocId = function(dataBlk, statusBlk)
    {
      local hasAmount = dataBlk.num != null
      local hasTime = (statusBlk.timeSecScaled || 0 ) - ::g_world_war.getOperationTimeSec() > 0
      return (hasAmount ? "Amount" : "Specified") + (hasTime ? "" : "Timeless")
    }

    timersArrayByParamName = {
      timeSecScaled = function (handler, scene, param, dataBlk, statusBlk, type, side)
      {
        local paramId = type.getParamId(dataBlk, param)
        return [type.timerFunc(handler, scene, paramId, param, param, dataBlk, statusBlk, side)]
      }
      holdTimeSec = function (handler, scene, param, dataBlk, statusBlk, type, side)
      {
        local paramId = type.getParamId(dataBlk, param)
        return [type.timerFunc(handler, scene, paramId, param, param, dataBlk, statusBlk, side)]
      }
    }

    timerUpdateFunctionTables = {
      timeSecScaled = function(nestObj, dataBlk, statusBlk, type, updateParam, side)
      {
        local sideName = ::ww_side_val_to_name(side)
        local minCapturedTimeSec = -1
        local block = statusBlk.getBlockByName("zones")
        foreach (zoneName, holderSide in block)
        {
          local zoneCapturedTimeSec = ::ww_get_zone_capture_time_sec(zoneName)
          minCapturedTimeSec = minCapturedTimeSec < 0 ? zoneCapturedTimeSec : ::min(minCapturedTimeSec, zoneCapturedTimeSec)
        }

        local timeSec = (statusBlk.timeSecScaled || 0) - ::g_world_war.getOperationTimeSec()
        nestObj.setValue(type.getName(dataBlk, statusBlk, sideName))

        local stopTimer = type.needStopTimer(dataBlk, statusBlk, timeSec, sideName)
        return stopTimer
      }
      holdTimeSec = function(nestObj, dataBlk, statusBlk, type, updateParam, side)
      {
        local pValueObj = nestObj.findObject("pValue")
        if (!::checkObj(pValueObj))
          return

        local zonesArray = ::split(dataBlk.zone, ";")
        local minCapturedTimeSec = -1
        for (local i = 0; i < zonesArray.len(); i++)
        {
          if (minCapturedTimeSec < 0)
            minCapturedTimeSec = ::ww_get_zone_capture_time_sec(zonesArray[i])
          else
            minCapturedTimeSec = ::min(minCapturedTimeSec, ::ww_get_zone_capture_time_sec(zonesArray[i]))
        }

        local leftTime = (dataBlk[updateParam] - minCapturedTimeSec) / ::ww_get_speedup_factor()
        local pValueText = type.convertParamValue[updateParam](leftTime, dataBlk)
        pValueObj.setValue(pValueText)
        nestObj.show(!::u.isEmpty(pValueText))

        return type.needStopTimer(dataBlk, statusBlk, leftTime, ::ww_side_val_to_name(side))
      }
    }

    timerSetVisibleFunctionTable = {
      holdTimeSec = function(nestObj, dataBlk, statusBlk, type, side)
      {
        if (!::checkObj(nestObj))
          return false

        local show = false
        if (statusBlk.winner == null)
        {
          local sideName = ::ww_side_val_to_name(side)
          local block = statusBlk.getBlockByName("zones")
          local num = type.getValueByParam("num", dataBlk, sideName, false)
          foreach (zoneName, holderSide in block)
            if (holderSide == sideName)
              num--

          show = type.isDefender(dataBlk, sideName)? num > 0 : num <= 0
        }

        nestObj.show(show)
        return show
      }
    }

    specificClassParamConvertion = {
      num = function(value, blk, side, type) {
        local zones = ::split(blk.zone, ";")
        return type.isDefender(blk, side) ? zones.len() - value + 1 : value
      }
    }

    needStopTimer = function(dataBlk, statusBlk, time, side)
    {
      return time < 0 || statusBlk.winner
    }

    getUpdatableZonesParams = function(dataBlk, statusBlk, side)
    {
      if (!statusBlk)
        return []

      local zonesArray = []
      local data = statusBlk.zones || dataBlk.zones
      if (::u.isDataBlock(data))
      {
        local num = data.paramCount()
        local lastZoneName = data.getParamName(num - 1)
        foreach (zoneName, holderSide in data)
        {
          local teamName = "none"
          local mapLayer = WW_MAP_HIGHLIGHT.LAYER_0
          if (holderSide != ::ww_side_val_to_name(::SIDE_NONE))
          {
            teamName = side == holderSide ? "blue" : "red"
            mapLayer = side == holderSide ? WW_MAP_HIGHLIGHT.LAYER_1 : WW_MAP_HIGHLIGHT.LAYER_2
          }

          zonesArray.append({
            id = zoneName
            text = zoneName + (zoneName != lastZoneName ? ", " : "")
            team = teamName
            mapLayer = mapLayer
          })
        }
      }

      return zonesArray
    }

    getUpdatableParamsArray = function(dataBlk, statusBlk, side)
    {
      return [{
        id = getParamId(dataBlk, "holdTimeSec")
        pName = getParamName(dataBlk, side, "holdTimeSec")
        pValue = getValueByParam("holdTimeSec", dataBlk, side)
        colorize = getColorizeByParam("holdTimeSec")
      }]
    }

    getUpdatableParamsDescriptionText = function(dataBlk, statusBlk, side)
    {
      local speedupPerc = getReinforcementSpeedupPercent(dataBlk, statusBlk, side)
      if (speedupPerc <= 0)
        return ""

      local speedupText = ::loc("worldwar/valueWithPercent", {percent = speedupPerc})
      speedupText = ::colorize("goodTextColor", ::loc("keysPlus") + speedupText)
      speedupText = ::loc("worldWar/iconReinforcement") + speedupText
      return ::loc("ui/parentheses", {text = speedupText})
    }

    getReinforcementSpeedupPercent = function(dataBlk, statusBlk, side)
    {
      local sideIdx = ::ww_side_name_to_val(side)
      local paramName = "rSpeedMulStatus" + sideIdx + "New"
      local speedupFactor = statusBlk?[paramName] ?? 1
      return ::round(::max(speedupFactor - 1, 0) * 100)
    }

    getNameSpecification = function(dataBlk, statusBlk)
    {
      local zonesNeeded = dataBlk?.num
      if (!zonesNeeded)
        return ""

      local zonesData = dataBlk.zones || statusBlk.zones
      local zonesCount = ::u.isDataBlock(zonesData) ? zonesData.paramCount() : 0
      return zonesNeeded < zonesCount ? "/approximate" : "/accurate"
    }

    getUpdatableParamsDescriptionTooltip = @(...) ::loc("worldwar/state/reinforcement_arrival_speedup")
  }

  OT_DOMINATION_ZONE = {
    titleParams = ["zonesPercent", "timeSecScaled"]
    updateArray = ["zonePercent_"]
    currentStateParam = "zonePercent_"

    getNameId = function(dataBlk, side) { return getParamId(dataBlk, "timeSecScaled") }
    getTitleLocId = function(dataBlk, statusBlk)
    {
      local hasTime = (statusBlk.timeSecScaled || 0 ) - ::g_world_war.getOperationTimeSec() > 0
      return "Percentage" + (hasTime ? "" : "Timeless")
    }

    timersArrayByParamName = {
      timeSecScaled = function (handler, scene, timerParam, dataBlk, statusBlk, type, side)
      {
        local objId = type.getParamId(dataBlk, timerParam)
        return [type.timerFunc(handler, scene, objId, timerParam, timerParam, dataBlk, statusBlk, side)]
      }
    }

    needStopTimer = function(dataBlk, statusBlk, time, side)
    {
      return time < 0 || statusBlk.winner
    }

    specificClassParamConvertion = {
      zonesPercent = function(value, blk, side, type) {
        return type.isDefender(blk, side) ? 100 - value + 1 : value
      }
    }

    timerSetVisibleFunctionTable = {
      timeSec = function(nestObj, dataBlk, statusBlk, type, side)
      {
        if (!::checkObj(nestObj))
          return

        local attackerSide = ::g_world_war.getOppositeSide(::ww_side_name_to_val(dataBlk.defenderSide || ""))
        local zonesPercent = dataBlk.zonesPercent
        local capturedPercent = statusBlk["zonePercent_" + attackerSide]

        local isVisible = zonesPercent <= capturedPercent
        nestObj.show(isVisible)

        return isVisible
      }
    }
  }

  OT_COUNT_UNIT_LESS = {
    titleParams = ["num"]
    updateArray = ["unitCount"]
    currentStateParam = "unitCount"
    invertUpdateValue = true

    specificClassParamConvertion = {
      num = function(value, blk, side, type) { return value + ::g_ww_unit_type.getUnitTypeByTextCode(blk.unitType).fontIcon }
    }
  }

  OT_DOMINATION_UNIT = {
    titleParams = ["fontIcon", "advantageFactor"]
    defaultValuesTable = {
      fontIcon = @(dataBlk) ::g_ww_unit_type.getUnitTypeByTextCode(dataBlk.unitType).fontIcon
    }
    updateArray = ["advantage"]
  }

}, null, "typeName")

function g_ww_objective_type::getTypeByTypeName(typeName)
{
  return enums.getCachedType("typeName", typeName, ::g_ww_objective_type.cache.byTypeName, ::g_ww_objective_type, ::g_ww_objective_type.UNKNOWN)
}

function g_ww_objective_type::getTimerUpdateFuncByParam(type, param)
{
  if (param in type.timerUpdateFunctionTables)
    return type.timerUpdateFunctionTables[param]

  return function(...){}
}

function g_ww_objective_type::getTimerSetVisibleFunctionTableByParam(type, param)
{
  if (param in type.timerSetVisibleFunctionTable)
    return type.timerSetVisibleFunctionTable[param]

  return function(...){ return true }
}
