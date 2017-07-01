/*
  ::UnlockConditions API:

  loadConditionsFromBlk(blk)              - return array of conditions
  getConditionsText(conditions, curValue, maxValue, params = null)
                                          - return descripton by array of conditions
                                          - curValue - current value to show in text (if null, not show)
                                          - maxvalue - overrride progress value from mode if maxValue != null
                                          - params:
                                            * if inlineText==true then condition will be generated in following way:
                                              "<main condition> (<other conditions>) <multipliers>"
                                            * locEnding - try to use it as ending for main condition localization key
                                              if not found, use usual locId
  getMainConditionText(conditions, curValue, maxValue)
                                          - get text only of the main condition
  addToText(text, name, valueText = "", separator = "\n")
                                          - add colorized "<text>: <valueText>" to text
                                          - used for generation conditions texts
                                          - custom separator can be specified
  isBitModeType(modeType)                 - (bool) is mode count by complete all values
  getMainProgressCondition(conditions)    - get main condition from list to show progress.
*/


::UnlockConditions <- {
  conditionsOrder = [
    "beginDate", "endDate",
    "missionsWon", "mission", "char_mission_completed",
    "missionPostfixAllowed", "missionPostfixProhibited", "missionType",
    "atLeastOneUnitsRankOnStartMission", "maxUnitsRankOnStartMission",
    "unitExists", "additional", "unitClass",
    "gameModeInfoString", "modes", "events", "tournamentMode",
    "location", "weaponType", "difficulty",
    "playerUnit", "playerType", "playerExpClass" "playerUnitRank", "playerTag",
    "targetUnit", "targetType", "targetExpClass", "targetTag",
    "crewsUnit", "crewsUnitRank", "crewsTag", "activity",
    "minStat", "statPlace", "statScore", "statPlaceInSession", "statScoreInSession",
    "targetIsPlayer", "eliteUnitsOnly", "noPremiumVehicles", "era", "country"
  ]

  condWithValuesInside = [
    "atLeastOneUnitsRankOnStartMission"
  ]

  additionalTypes = ["critical", "lesserTeam", "teamLeader", "inTurret"]

  locGroupByType = {
    playerType       = "playerUnit"
    playerTag        = "playerUnit"
    playerUnitRank   = "playerUnit"
    targetType       = "targetUnit"
    targetTag        = "targetUnit"
    crewsUnitRank    = "crewsUnit"
    crewsTag         = "crewsUnit"
  }

  mapConditionUnitType = {
    aircraft          = "unit_aircraft"
    tank              = "unit_tank"
    typeLightTank     = "type_light_tank"
    typeMediumTank    = "type_medium_tank"
    typeHeavyTank     = "type_heavy_tank"
    typeSPG           = "type_tank_destroyer"
    typeSPAA          = "type_spaa"
    typeTankDestroyer = "type_tank_destroyer"
    typeFighter       = "type_fighter"
    typeDiveBomber    = "type_dive_bomber"
    typeBomber        = "type_bomber"
    typeAssault       = "type_assault"
    typeStormovik     = "type_assault"
    typeTransport     = "type_transport"
    typeStrikeFighter = "type_strike_fighter"
  }

  minStatGroups = {
    place         = "statPlace"
    score         = "statScore"
    playerkills   = "statKillsPlayer"
    kills         = "statKillsAir"
    aikills       = "statKillsAirAi"
    groundkills   = "statKillsGround"
    aigroundkills = "statKillsGroundAi"
  }

  bitModesList = {
    char_unlocks               = "unlock"
    unlocks                    = "unlock"
    char_mission_list          = "name"
    char_mission_completed     = "name"
    char_buy_modification_list = "name"
    missionCompleted           = "mission"
    char_unit_exist            = "unit" //must be here but in old format was skipped
  }

  modeTypesWithoutProgress = [
    ""
    "char_always_progress" //char_always_progress do not have progress, only check conditions

    "char_crew_skill"
  ]

  singleAttachmentList = {
    unlockOpenCount = "unlock"
    unlockStageCount = "unlock"
  }

  customLocTypes = ["gameModeInfoString"]

  regExpNumericEnding = ::regexp2("\\d+$")
}


//condition format:
//{
//  type = string
//  values = null || array of values
//  locGroup  - group values in one loc string instead of different string for each value.
//
//  specific params for main progresscondition (type == "mode")
//  modeType - mode type of conditions with progress
//             such condition can be only one in list, and always first.
//  modeTypeLocID  - locId for mode type
//}
function UnlockConditions::loadConditionsFromBlk(blk)
{
  local res = []
  local mainCond = loadMainProgressCondition(blk) //main condition by modeType
  if (mainCond)
    res.append(mainCond)

  res.extend(loadParamsConditions(blk)) //conditions by mode params - elite, country etc

  foreach(condBlk in blk % "condition") //conditions determined by blocks "condition"
  {
    local condition = loadCondition(condBlk)
    if (condition)
      _mergeConditionToList(condition, res)
  }
  return res
}

function UnlockConditions::_createCondition(condType, values = null)
{
  return {
    type = condType
    values = values
  }
}

function UnlockConditions::_mergeConditionToList(newCond, list)
{
  local cType = newCond.type
  local cond = _findCondition(list, cType, ::getTblValue("locGroup", newCond, null))
  if (!cond)
    return list.append(newCond)

  if (!newCond.values)
    return

  if (!cond.values)
    cond.values = newCond.values
  else
  {
    if (typeof(cond.values) != "array")
      cond.values = [cond.values]
    cond.values.extend(newCond.values)
  }

  //merge specific by type
  if (cType == "modes")
  {
    local idx = ::find_in_array(cond.values, "online") //remove mode online if there is ther modes (clan, event, etc)
    if (idx >= 0 && cond.values.len() > 1)
      cond.values.remove(idx)
  }
}

function UnlockConditions::_findCondition(list, cType, locGroup)
{
  local cLocGroup = null
  foreach(cond in list)
  {
    cLocGroup = ::getTblValue("locGroup", cond, null)
    if (cond.type == cType && locGroup == cLocGroup)
      return cond
  }
  return null
}

function UnlockConditions::isBitModeType(modeType)
{
  return modeType in bitModesList
}

function UnlockConditions::isMainConditionBitType(mainCond)
{
  return mainCond != null && isBitModeType(mainCond.modeType)
}

function UnlockConditions::isCheckedBySingleAttachment(modeType)
{
  return modeType in singleAttachmentList || isBitModeType(modeType)
}

function UnlockConditions::loadMainProgressCondition(blk)
{
  local modeType = blk.type
  if (!modeType || ::isInArray(modeType, modeTypesWithoutProgress)
      || blk.dontShowProgress || modeType == "maxUnitsRankOnStartMission")
    return null

  local res = _createCondition("mode")
  res.modeType <- modeType
  res.num <- blk.rewardNum || blk.num

  if ("customUnlockableList" in blk)
    res.values = blk.customUnlockableList % "unlock"

  res.hasCustomUnlockableList <- (res.values != null && res.values.len() > 0)

  if (blk.typeLocID)
    res.modeTypeLocID <- blk.typeLocID
  if (isBitModeType(modeType))
  {
    if (!res.hasCustomUnlockableList)
      res.values = blk % bitModesList[modeType]
    res.compareOR <- blk.compareOR || false
    if (!blk.num)
      res.num = res.values.len()
  }

  foreach(p in ["country", "reason", "isShip", "typeLocIDWithoutValue"])
    if (blk[p])
      res[p] <- blk[p]

  //uniq modeType params
  if (modeType == "unlockCount")
    res.unlockType <- blk.unlockType || ""
  else if (modeType == "unlockOpenCount" || modeType == "unlockStageCount")
  {
    local unlock = ::g_unlocks.getUnlockById(blk.unlock)
    if (unlock == null)
    {
      res.values = []
      ::dagor.assertf(false, "ERROR: Unlock "+blk.unlock+" does not exist")
    }
    else if (!res.hasCustomUnlockableList)
    {
      res.values = unlock.mode % "unlock"
      if( ! res.values.len())
        res.values.push(unlock.id)
    }
  }
  else if (modeType == "landings")
    res.carrierOnly <- blk.carrierOnly || false
  else if (modeType == "char_static_progress")
    res.level <- blk.level || 0
  else if (modeType == "char_resources_count")
    res.resourceType <- blk.resourceType

  res.multiplier <- getMultipliersTable(blk)
  return res
}

function UnlockConditions::loadParamsConditions(blk)
{
  local res = []
  if (blk.elite && (typeof(blk.elite) != "integer" || blk.elite > 1))
    res.append(_createCondition("eliteUnitsOnly"))

  if (blk.premium == false)
    res.append(_createCondition("noPremiumVehicles"))

  if (blk.era)
    res.append(_createCondition("era", blk.era))

  if (blk.country && blk.country != "")
    res.append(_createCondition("country", blk.country))

  if (blk.unitClass)
    res.append(_createCondition("unitClass", blk.unitClass))

  if (blk.type == "maxUnitsRankOnStartMission") //2 params conditions instead of 1 base
  {
    local minRank = blk.minRank || 0
    local maxRank = blk.maxRank || minRank
    if (minRank)
    {
      local values = [minRank]
      if (maxRank > minRank)
        values.append(maxRank)
      res.append(_createCondition("atLeastOneUnitsRankOnStartMission", values))
    }

    if (blk.maxRank)
      res.append(_createCondition("maxUnitsRankOnStartMission", maxRank))
  }

  return res
}

function UnlockConditions::loadCondition(blk)
{
  local t = blk.type
  local res = _createCondition(t)

  if (t == "weaponType")
    res.values = (blk % "weapon")
  else if (t == "location")
    res.values = (blk % "location")
  else if (t == "activity")
    res.values = getDiffTextArrayByPoint3(blk.percent, "%s%%")
  else if (t == "online")
  {
    res.type = "modes"
    res.values = t
  }
  else if (t == "gameModeInfoString")
  {
    res.values = [blk.value]
    res.name <- blk.name
    if ("locParamName" in blk)
    {
      res.locParamName <- blk.locParamName
    }
    if ("locParamValue" in blk)
    {
      res.locParamValue <- blk.locParamValue
    }
  }
  else if (t == "eventMode")
  {
    res.values = (blk % "event_name")
    if (res.values.len())
      res.type = "events"
    else
    {
      res.type = "modes"
      local group = "events_only"
      if (blk.for_clans_only)
        group = "clans_only"
      else if (blk.is_event == false) //true by default
        group = "random_battles"
      res.values.append(group)
    }
  }
  else if (t == "playerUnit" || t == "targetUnit")
    res.values = (blk % "class")
  else if (t == "playerType" || t == "targetType")
  {
    res.values = (blk % "unitType")
    res.values.extend(blk % "unitClass")
  }
  else if (t == "playerExpClass" || t == "targetExpClass")
    res.values = (blk % "class")
  else if (t == "playerTag" || t == "targetTag")
    res.values = (blk % "tag")
  else if (t == "playerUnitRank")
  {
    if (blk.inSessionAnd)
      res.type = "crewsUnitRank"

    local range = (blk.minRank && blk.maxRank) ? ::Point2(blk.minRank, blk.maxRank) : blk.range
    res.values = ::getRangeTextByPoint2(range, "%s", ::loc("conditions/unitRank/format", "%s"), true)
  }
  else if (t == "playerUnitClass")
  {
    local unitClassList = (blk % "unitClass")
    foreach (i, v in unitClassList)
      if (v.len() > 4 && v.slice(0,4) == "exp_")
        unitClassList[i] = "type_" + v.slice(4)

    res.type = blk.inSessionAnd ? "crewsTag" : "playerTag"
    res.values = unitClassList
  }
  else if (t == "playerUnitFilter")
  {
    switch (blk.paramName)
    {
      case "country":
        res.type = blk.inSessionAnd ? "crewsTag" : "playerTag"
        res.values = blk % "value"
        break
      default:
        return null
    }
  }
  else if (t == "char_mission_completed")
    res.values = blk.name || ""
  else if (t == "difficulty")
  {
    res.values = blk % "difficulty"
    res.exact <- blk.exact || false
  }
  else if (t == "minStat")
  {
    local lessIsBetter = blk.stat == "place"
    res.values = getDiffTextArrayByPoint3(blk.value, "%s", lessIsBetter)
    if (!res.values.len())
      return null

    local stat = blk.stat || ""
    res.locGroup <- ::getTblValue(stat, minStatGroups, stat)

    if ("inSession" in blk && blk.inSession == true)
      res.locGroup +=  "InSession"
  }
  else if (::isInArray(t, unlock_time_range_conditions))
  {
    foreach(key in ["beginDate", "endDate"])
    {
      local time = blk[key] && ::convert_utc_to_local_time(::get_time_from_string_utc(blk[key]))
      if (time)
        res[key] <- ::build_date_time_str(time)
    }
  }
  else if (t == "missionPostfix")
  {
    res.values = []
    local values = blk % "postfix"
    foreach(val in values)
      ::append_once(regExpNumericEnding.replace("", val), res.values)
    res.locGroup <- ::getTblValue("allowed", blk, true) ? "missionPostfixAllowed" : "missionPostfixProhibited"
  }
  else if (t == "mission")
    res.values = (blk % "mission")
  else if (t == "tournamentMode")
    res.values = (blk % "mode")
  else if (t == "missionType")
  {
    res.values = []
    local values = blk % "missionType"
    foreach(modeInt in values)
      res.values.append(::get_mode_localization_text(modeInt))
  }
  else if (t == "char_personal_unlock")
    res.values = blk % "personalUnlocksType"
  else if (::isInArray(t, additionalTypes))
  {
    res.type = "additional"
    res.values = t
  }

  if (res.type in locGroupByType)
    res.locGroup <- locGroupByType[res.type]
  return res
}

function UnlockConditions::getDiffTextArrayByPoint3(val, formatStr = "%s", lessIsBetter = false)
{
  local res = []

  if (type(val) != "instance" || !(val instanceof ::Point3))
  {
    res.append(_getDiffValueText(val, formatStr, lessIsBetter))
    return res
  }

  if (val.x == val.y && val.x == val.z)
    res.append(_getDiffValueText(val.x, formatStr, lessIsBetter))
  else
    foreach (idx, key in [ "x", "y", "z" ])
    {
      local value = val[key]
      local valueStr = _getDiffValueText(value, formatStr, lessIsBetter)
      res.append(valueStr + ::loc("ui/parentheses/space", {
                                    text = ::loc(::getTblValue("abbreviation", ::g_difficulty.getDifficultyByDiffCode(idx), ""))
                                  }))
    }

  return res
}

function UnlockConditions::_getDiffValueText(value, formatStr = "%s", lessIsBetter = false)
{
  return lessIsBetter? ::getRangeString(1, value, formatStr) : ::format(formatStr, value.tostring())
}

function UnlockConditions::getMainProgressCondition(conditions)
{
  foreach(c in conditions)
    if (::getTblValue("modeType", c))
      return c
  return null
}

function UnlockConditions::getConditionsText(conditions, curValue = null, maxValue = null, params = null)
{
  local inlineText = ::getTblValue("inlineText", params, false)
  local separator = inlineText ? ", " : "\n"

  //add main conditions
  local mainConditionText = ""
  if (::getTblValue("withMainCondition", params, true))
    mainConditionText = getMainConditionText(conditions, curValue, maxValue, params)

  //local add not main conditions
  local descByLocGroups = {}
  local customDataByLocGroups = {}
  foreach(condition in conditions)
    if (!::isInArray(condition.type, customLocTypes))
    {
      if (!_addUniqConditionsText(descByLocGroups, condition))
        _addUsualConditionsText(descByLocGroups, condition)
    }
    else
    {
      _addCustomConditionsTextData(customDataByLocGroups, condition)
    }

  local condTextsList = []
  foreach(group in conditionsOrder)
  {
    local data = null

    if (!::isInArray(group, customLocTypes))
    {
      data = ::getTblValue(group, descByLocGroups)
      if (data == null || data.len() == 0)
        continue

      addTextToCondTextList(condTextsList, group, data)
    }
    else
    {
      local customData = ::getTblValue(group, customDataByLocGroups)
      if (customData == null || customData.len() == 0)
        continue

      foreach (condCustomData in customData)
      {
        addTextToCondTextList(condTextsList, group, getTblValue("descText", condCustomData), getTblValue("groupText", condCustomData))
      }
    }
  }

  local conditionsText = ::implode(condTextsList, separator)
  if (inlineText && conditionsText != "")
    conditionsText = ::format("(%s)", conditionsText)

  //add multipliers text
  local mainCond = getMainProgressCondition(conditions)
  local mulText = ::UnlockConditions.getMultipliersText(mainCond || {})

  local pieces = [mainConditionText, conditionsText, mulText]
  return ::implode(pieces, separator)
}

function UnlockConditions::addTextToCondTextList(condTextsList, group, valuesData, customLocGroupText = "")
{
  local valuesText = ""
  local text = ""

  valuesText = ::implode(valuesData, ::loc("ui/comma"))
  if (valuesText != "")
    valuesText = ::colorize("unlockActiveColor", valuesText)

  text = !::isInArray(group, customLocTypes) ? ::loc("conditions/" + group, { value = valuesText }) : customLocGroupText
  if (valuesText != "" && !::isInArray(group, condWithValuesInside))
    text += (text.len() ? ::loc("ui/colon") : "") + valuesText

  condTextsList.append(text)
}

function UnlockConditions::getMainConditionText(conditions, curValue = null, maxValue = null, params = null)
{
  local mainCond = getMainProgressCondition(conditions)
  return _genMainConditionText(mainCond, curValue, maxValue, params)
}

function UnlockConditions::_genMainConditionText(condition, curValue = null, maxValue = null, params = null)
{
  local res = ""
  local modeType = ::getTblValue("modeType", condition)
  if (!modeType)
    return res

  local typeLocIDWithoutValue = ::getTblValue("typeLocIDWithoutValue", condition)
  if (typeLocIDWithoutValue)
    return ::loc(typeLocIDWithoutValue)

  local bitMode = isBitModeType(modeType)

  if (maxValue == null)
    maxValue = ::getTblValue("rewardNum", condition) || ::getTblValue("num", condition)
  if (::is_numeric(curValue))
  {
    if (bitMode)
      curValue = ::number_of_set_bits(curValue)
    else if (::is_numeric(maxValue) && curValue > maxValue) //validate values if numeric
      curValue = maxValue
  }
  if (bitMode && ::is_numeric(maxValue))
    maxValue = ::number_of_set_bits(maxValue)

  if (isCheckedBySingleAttachment(modeType) && condition.values && condition.values.len() == 1)
    return _getSingleAttachmentConditionText(condition, curValue, maxValue)

  local textId = "conditions/" + modeType
  local textParams = {}

  local progressText = ""
  if (bitMode && ::getTblValue("bitListInValue", params))
  {
    if (curValue == null)
      progressText = ::implode(getLocForBitValues(modeType, condition.values), ", ")
    if (::is_numeric(maxValue) && maxValue != condition.values.len())
    {
      textId += "/withValue"
      textParams.value <- ::colorize("unlockActiveColor", maxValue)
    }
  } else if (modeType == "maxUnitsRankOnStartMission")
  {
    local valuesText = ::u.map(condition.values, ::get_roman_numeral)
    progressText = ::implode(valuesText, "-")
  } else //usual progress text
  {
    progressText = (curValue != null) ? curValue : ""
    if (maxValue != null && maxValue != "")
      progressText += ((progressText != "") ? "/" : "") + maxValue
  }

  if ("modeTypeLocID" in condition)
    textId = condition.modeTypeLocID
  else if (modeType == "rank" || modeType == "char_country_rank")
  {
    local country = ::getTblValue("country", condition)
    textId = country ? "mainmenu/rank/" + country : "mainmenu/rank"
  }
  else if (modeType == "unlockCount")
    textId = "conditions/" + ::getTblValue("unlockType", condition, "")
  else if (modeType == "char_static_progress")
    textParams.level <- ::loc("crew/qualification/" + ::getTblValue("level", condition, 0))
  else if (modeType == "landings" && ::getTblValue("carrierOnly", condition))
    textId = "conditions/carrierOnly"
  else if (::getTblValue("isShip", condition)) //really strange exclude, becoase of this flag used with various modeTypes.
    textId = "conditions/isShip"
  else if (modeType == "killedAirScore")
    textId = "conditions/statKillsAir"
  else if (modeType == "sessionsStarted")
    textId = "conditions/missionsPlayed"
  else if (modeType == "char_resources_count")
    textId = "conditions/char_resources_count/" + ::getTblValue("resourceType", condition, "")

  if ("locEnding" in params)
    res = ::loc(textId + params.locEnding, textParams)
  if (res == "")
    res = ::loc(textId, textParams)

  if ("reason" in condition)
    res += " " + ::loc(textId + "/" + condition.reason)

  //if condition lang is empty and max value == 1 no need to show progress text
  if (progressText != "" && (res != "" || maxValue != 1))
    res += ::loc("ui/colon") + ::colorize("unlockActiveColor", progressText)
  return res
}

function UnlockConditions::getMainConditionListPrefix(conditions)
{
  local mainCondition = getMainProgressCondition(conditions)
  if (mainCondition == null)
    return ""
  if (!mainCondition.values)
    return ""

  local modeType = mainCondition.modeType

  if (mainCondition.hasCustomUnlockableList || (::isInArray(modeType, ["unlockOpenCount", "unlocks"]) && mainCondition.values.len() > 1))
  {
    return ::loc("ui/awards") + ::loc("ui/colon")
  }

  return ""
}

function UnlockConditions::_getSingleAttachmentConditionText(condition, curValue, maxValue)
{
  local modeType = ::getTblValue("modeType", condition)
  local locNames = getLocForBitValues(modeType, condition.values)
  local valueText = ::colorize("unlockActiveColor", "\"" +  ::implode(locNames, ::loc("ui/comma")) + "\"")
  local progress = ::colorize("unlockActiveColor", (curValue != null? (curValue + "/") : "") + maxValue)
  return ::loc("conditions/" + modeType + "/single", { value = valueText, progress = progress})
}

function UnlockConditions::_addUniqConditionsText(groupsList, condition)
{
  local cType = condition.type
  if (::isInArray(cType, unlock_time_range_conditions)) //2 loc groups by one condition
  {
    foreach(key in ["beginDate", "endDate"])
      if (key in condition)
        _addValueToGroup(groupsList, key, condition[key])
    return true
  }
  else if (cType == "atLeastOneUnitsRankOnStartMission")
  {
    local valuesTexts = ::u.map(condition.values, ::get_roman_numeral)
    _addValueToGroup(groupsList, cType, ::implode(valuesTexts, "-"))
    return true
  }
  return false //not found, do as usual conditions.
}

function UnlockConditions::_addUsualConditionsText(groupsList, condition)
{
  local cType = condition.type
  local group = ::getTblValue("locGroup", condition, cType)
  local values = condition.values
  local text = ""

  if (values == null)
    return _addValueToGroup(groupsList, group, text)

  if (typeof values != "array")
    values = [values]
  foreach (v in values)
  {
    if (cType == "playerUnit" || cType=="targetUnit" || cType == "crewsUnit" || cType=="unitExists")
      text = ::getUnitName(v)
    else if (cType == "playerType" || cType == "targetType")
      text = ::loc("unlockTag/" + ::getTblValue(v, mapConditionUnitType, v))
    else if (cType == "playerExpClass" || cType == "targetExpClass" || cType == "unitClass")
      text = ::get_role_text(::cut_prefix(v, "exp_", v))
    else if (cType == "playerTag" || cType == "crewsTag" || cType == "targetTag" || cType == "country")
      text = ::loc("unlockTag/" + v)
    else if (::isInArray(cType, [ "activity", "playerUnitRank", "crewsUnitRank", "minStat"]))
      text = v.tostring()
    else if (cType == "difficulty")
    {
      text = ::getDifficultyLocalizationText(v)
      if (!::getTblValue("exact", condition, false) && v != "hardcore")
        text += " " + ::loc("conditions/moreComplex")
    }
    else if (cType == "mission" || cType == "char_mission_completed" || cType == "missionType")
      text = ::loc("missions/" + v)
    else if (::isInArray(cType, ["era", "maxUnitsRankOnStartMission"]))
      text = ::get_roman_numeral(v)
    else if (cType == "events")
      text = ::events.getNameByEconomicName(v)
    else if (cType == "missionPostfix")
      text = ::loc("options/" + v)
    else
      text = ::loc(cType+"/" + v)

    _addValueToGroup(groupsList, group, text)
  }
}

function UnlockConditions::_addCustomConditionsTextData(groupsList, condition)
{
  local cType = condition.type
  local group = ""
  local desc = ""

  local res = {
    groupText = ""
    descText = []
  }

  local values = condition.values

  if (values == null)
    return

  if (typeof values != "array")
    values = [values]

  foreach (v in values)
  {
    if (cType == "gameModeInfoString")
    {
      if ("locParamName" in condition)
      {
        group = ::loc(condition.locParamName)
      }
      else
      {
        group = "gameModeInfoString/" + condition.name
      }

      if ("locParamValue" in condition)
      {
        desc += ::loc(condition.locParamValue)
      }
      else
      {
        desc += "gameModeInfoString/" + v
      }
    }
  }

  res.groupText <- group
  res.descText.append(desc)

  _addDataToCustomGroup(groupsList, cType, res)
}

function UnlockConditions::_addDataToCustomGroup(groupsList, cType, data)
{
  if (!(cType in groupsList))
    groupsList[cType] <- []

  local customData = groupsList[cType]
  foreach (conditionData in customData)
  {
    if (data.groupText == ::getTblValue("groupText", conditionData))
    {
      conditionData.descText.append(::getTblValue("descText", data)[0])
      return
    }
  }

  groupsList[cType].append(data)
}

function UnlockConditions::_addValueToGroup(groupsList, group, value)
{
  if (!(group in groupsList))
    groupsList[group] <- []
  groupsList[group].append(value)
}

function UnlockConditions::addToText(text, name, valueText = "", color = "unlockActiveColor", separator = "\n")
{
  text += (text.len() ? separator : "") + name
  if (valueText != "")
    text += (name.len() ? ::loc("ui/colon") : "") + "<color=@" + color + ">" + valueText + "</color>"
  return text
}

function UnlockConditions::getMultipliersTable(blk)
{
  local diffTable = {
    mulArcade = "ArcadeBattle"
    mulRealistic = "HistoricalBattle"
    mulHardcore = "FullRealBattles"
  }

  local mulTable = {}
  foreach(paramName, diff in diffTable)
  {
    local value = ::getTblValue(paramName, blk)
    if (value)
      mulTable[diff] <- value
  }

  return mulTable
}

function UnlockConditions::getMultipliersText(condition)
{
  local multiplierTable = ::getTblValue("multiplier", condition, {})
  if (multiplierTable.len() == 0)
    return ""

  local mulText = ""

  foreach(difficulty, num in multiplierTable)
  {
    if (num == 1)
      continue

    mulText += mulText.len() > 0? ", " : ""
    mulText += ::format("%s (x%d)", ::loc("clan/short" + difficulty), num)
  }

  if (mulText == "")
    return ""

  return ::format("<color=@fadedTextColor>%s</color>", ::loc("conditions/multiplier") + ::loc("ui/colon") + mulText)
}

function UnlockConditions::getLocForBitValues(modeType, values, hasCustomUnlockableList = false)
{
  local valuesLoc = []
  if (hasCustomUnlockableList || modeType == "unlocks" || modeType == "char_unlocks"
    || modeType == "unlockOpenCount" || modeType == "unlockStageCount")
    foreach(name in values)
      valuesLoc.append(::get_unlock_name_text(-1, name))
  else if (modeType == "char_unit_exist")
    foreach(name in values)
      valuesLoc.append(::getUnitName(name))
  else
  {
    local nameLocPrefix = ""
    if (modeType == "char_mission_list" ||
        modeType == "char_mission_completed"
       )
      nameLocPrefix = "missions/"
    else if (modeType == "char_buy_modification_list")
      nameLocPrefix = "modification/"
    foreach(name in values)
      valuesLoc.append(::loc(nameLocPrefix + name))
  }
  return valuesLoc
}

function UnlockConditions::getTooltipIdByModeType(modeType, id, hasCustomUnlockableList = false)
{
  if (hasCustomUnlockableList || modeType == "unlocks" || modeType == "char_unlocks" || modeType == "unlockOpenCount")
    return ::g_tooltip.getIdUnlock(id)

  if (modeType == "char_unit_exist")
    return ::g_tooltip.getIdUnit(id)

  return id
}

function UnlockConditions::getProgressBarData(modeType, curVal, maxVal)
{
  local res = {
    show = !::isInArray(modeType, modeTypesWithoutProgress)
    value = 0
  }

  if (::UnlockConditions.isBitModeType(modeType))
  {
    curVal = ::number_of_set_bits(curVal)
    maxVal = ::number_of_set_bits(maxVal)
  }

  res.show = res.show && maxVal > 1 && curVal < maxVal
  res.value = ::clamp(1000 * curVal / (maxVal || 1), 0, 1000)
  return res
}

function UnlockConditions::getRankValue(conditions)
{
  foreach(c in conditions)
    if (c.type == "playerUnitRank")
      return c.values
  return null
}
