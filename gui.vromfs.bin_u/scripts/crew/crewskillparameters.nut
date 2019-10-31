::g_crew_skill_parameters <- {
  _parametersByCrewId = {}
  _baseParameters = null

  skillGroups = { //skills which have completely the same parameters for different members
    eyesight = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
    field_repair = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
    machine_gunner = ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]
  }
}

g_crew_skill_parameters.init <- function init()
{
  ::add_event_listener("CrewSkillsChanged", onEventCrewSkillsChanged, this)
  ::add_event_listener("SignOut", onEventSignOut, this)
  ::add_event_listener("CrewTakeUnit", onEventCrewTakeUnit, this)
  ::add_event_listener("CrewChanged", onEventCrewChanged, this)
}

g_crew_skill_parameters.getParametersByCrewId <- function getParametersByCrewId(crewId)
{
  local parameters = ::getTblValue(crewId, _parametersByCrewId, null)
  if (parameters == null)
  {
    /*local values =
    {
      pilot = {
        gForceTolerance = 10,
        hearing = 10,
        vitality = 10,
        endurance = 10,
        eyesight = 10,
      },
      gunner = {
        accuracy = 10,
        eyesight = 10,
        hearing = 10,
        vitality = 10,
        gForceTolerance = 10,
        endurance = 10,
        density = 10,
      },
      specialization = 1,
    };*/
    parameters = ::calc_crew_parameters(crewId, /*values*/null)
    _parametersByCrewId[crewId] <- parameters
  }
  return parameters
}

::getBaseParameters <- function getBaseParameters(crewId)
{
  if (_baseParameters == null)
  {
    local skillsBlk = ::get_skills_blk()
    local calcBlk = skillsBlk?.crew_skills_calc
    if (calcBlk == null)
      return null

    local values = {}
    foreach (memberName, memberBlk in calcBlk)
    {
      values[memberName] <- {}
      foreach (skillName, skillBlk in memberBlk)
        values[memberName][skillName] <- 0
    }
    values.specialization <- ::g_crew_spec_type.BASIC.code
    _baseParameters = ::calc_crew_parameters(crewId, values)
  }
  return _baseParameters
}

g_crew_skill_parameters.onEventCrewSkillsChanged <- function onEventCrewSkillsChanged(params)
{
  local crewId = params.crew.id
  _parametersByCrewId[crewId] <- null
}

g_crew_skill_parameters.onEventSignOut <- function onEventSignOut(params)
{
  _parametersByCrewId.clear()
  _baseParameters = null
}

g_crew_skill_parameters.onEventCrewTakeUnit <- function onEventCrewTakeUnit(params)
{
  _baseParameters = null
}

g_crew_skill_parameters.onEventCrewChanged <- function onEventCrewChanged(params)
{
  _baseParameters = null
}

g_crew_skill_parameters.getBaseDescriptionText <- function getBaseDescriptionText(memberName, skillName, crew)
{
  local locId = ::format("crew/%s/%s/tooltip", memberName, skillName)
  local locParams = null

  if (skillName == "eyesight" && ::isInArray(memberName, ["driver", "tank_gunner", "commander", "loader", "radio_gunner"]))
  {
    locId = "crew/eyesight/tank/tooltip"

    local blk = ::dgs_get_game_params()
    local detectDefaults = blk?.detectDefaults
    locParams = {
      targetingMul = ::getTblValue("distanceMultForTargetingView", detectDefaults, 1.0)
      binocularMul = ::getTblValue("distanceMultForBinocularView", detectDefaults, 1.0)
    }
  }

  return ::loc(locId, locParams)
}

g_crew_skill_parameters.getTooltipText <- function getTooltipText(memberName, skillName, crewUnitType, crew, difficulty)
{
  local resArray = [getBaseDescriptionText(memberName, skillName, crew)]

  local unit = ::g_crew.getCrewUnit(crew)

  if (unit && unit.unitType.crewUnitType != crewUnitType)
  {
    local text = ::loc("crew/skillsWorkWithUnitsSameType")
    resArray.append(::colorize("warningTextColor", text))
  }
  else if (crew && memberName == "groundService" && skillName == "repair")
  {
    local fullParamsList = ::g_skill_parameters_request_type.CURRENT_VALUES.getParameters(crew.id)
    local repairRank = fullParamsList?[difficulty.crewSkillName][memberName].repairRank.groundServiceRepairRank ?? 0
    if (repairRank!=0 && unit && unit.rank > repairRank)
    {
      local text = ::loc("crew/notEnoughRepairRank", {
                          rank = ::colorize("activeTextColor", ::get_roman_numeral(unit.rank))
                          level = ::colorize("activeTextColor",
                                             ::g_crew_skills.getMinSkillsUnitRepairRank(unit.rank))
                         })
      resArray.append(::colorize("warningTextColor", text))
    }
  }
  else if (memberName == "loader" && skillName == "loading_time_mult")
  {
    local wBlk = ::get_wpcost_blk()
    if (unit && wBlk?[unit.name].primaryWeaponAutoLoader)
    {
      local text = ::loc("crew/loader/loading_time_mult/tooltipauto")
      resArray.append(::colorize("warningTextColor", text))
    }
  }

  return ::g_string.implode(resArray, "\n")
}

//skillsList = [{ memberName = "", skillName = "" }]
g_crew_skill_parameters.getColumnsTypesList <- function getColumnsTypesList(skillsList, crewUnitType)
{
  local columnTypes = []
  foreach (columnType in ::g_skill_parameters_column_type.types)
  {
    if (!columnType.checkCrewUnitType(crewUnitType))
      continue

    foreach(skill in skillsList)
      if (columnType.checkSkill(skill.memberName, skill.skillName))
      {
        columnTypes.push(columnType)
        break
      }
  }
  return columnTypes
}

g_crew_skill_parameters.getSkillListHeaderRow <- function getSkillListHeaderRow(crew, columnTypes)
{
  local res = {
    descriptionLabel = ::loc("crewSkillParameterTable/descriptionLabel")
    valueItems = []
  }

  local headerImageParams = {
    crew = crew
    unit = ::g_crew.getCrewUnit(crew)
  }
  foreach (columnType in columnTypes)
    res.valueItems.push({
      itemText = columnType.getHeaderText()
      itemImage = columnType.getHeaderImage(headerImageParams)
      imageSize = columnType.imageSize.tostring()
      imageLegendText = columnType.getHeaderImageLegendText()
    })
  res.valueItems.push({
    itemDummy = true
  })

  return res
}

//skillsList = [{ memberName = "", skillName = "" }]
g_crew_skill_parameters.getParametersByRequestType <- function getParametersByRequestType(crewId, skillsList, difficulty, requestType, useSelectedParameters)
{
  local res = {}
  local fullParamsList = useSelectedParameters
                         ? requestType.getSelectedParameters(crewId)
                         : requestType.getParameters(crewId)

  foreach(skill in skillsList)
  {
    // Leaving data only related to selected difficulty, member and skill.
    local skillParams = fullParamsList?[difficulty.crewSkillName][skill.memberName][skill.skillName]
    if (!skillParams)
      continue
    foreach(key, value in skillParams)
    {
      if (!(key in res))
        res[key] <- []
      res[key].append({
        memberName = skill.memberName
        skillName = skill.skillName
        value = value
      })
    }
  }
  return res
}

g_crew_skill_parameters.getSortedArrayByParamsTable <- function getSortedArrayByParamsTable(parameters, crewUnitType)
{
  local res = []
  foreach(name, valuesArr in parameters)
  {
    if (crewUnitType != ::CUT_AIRCRAFT
      && name == "airfieldMinRepairTime")
      continue
    res.append({
      name = name
      valuesArr = valuesArr
      sortOrder = ::g_crew_skills.getSortOrderBySkillParameterName(name)
    })
  }

  res.sort(function(a, b) {
    if (a.sortOrder != b.sortOrder)
      return a.sortOrder > b.sortOrder ? 1 : -1
    return 0
  })
  return res
}

g_crew_skill_parameters.parseParameters <- function parseParameters(columnTypes,
  currentParametersByRequestType, selectedParametersByRequestType, crewUnitType)
{
  local res = []
  local currentParameters = currentParametersByRequestType[::g_skill_parameters_request_type.CURRENT_VALUES]
  if (!::u.isTable(currentParameters))
    return res

  local paramsArray = getSortedArrayByParamsTable(currentParameters, crewUnitType)
  foreach (idx, paramData in paramsArray)
  {
    local parametersType = ::g_skill_parameters_type.getTypeByParamName(paramData.name)
    parametersType.parseColumns(paramData, columnTypes,
      currentParametersByRequestType, selectedParametersByRequestType, res)
  }
  return res
}

g_crew_skill_parameters.filterSkillsList <- function filterSkillsList(skillsList)
{
  local res = []
  foreach(skill in skillsList)
  {
    local group = ::getTblValue(skill.skillName, skillGroups)
    if (group)
    {
      local resSkill = ::u.search(res, (@(skill, group) function(resSkill) {
                         return skill.skillName == resSkill.skillName && ::isInArray(resSkill.memberName, group)
                       })(skill, group))
      if (resSkill)
        continue
    }

    res.append(skill)
  }
  return res
}

//skillsList = [{ memberName = "", skillName = "" }]
g_crew_skill_parameters.getSkillListParameterRowsView <- function getSkillListParameterRowsView(crew, difficulty, notFilteredSkillsList, crewUnitType)
{
  local skillsList = filterSkillsList(notFilteredSkillsList)

  local columnTypes = getColumnsTypesList(skillsList, crewUnitType)

  //preparing full requestsList
  local fullRequestsList = [::g_skill_parameters_request_type.CURRENT_VALUES] //required for getting params list
  foreach(columnType in columnTypes)
  {
    ::u.appendOnce(columnType.previousParametersRequestType, fullRequestsList, true)
    ::u.appendOnce(columnType.currentParametersRequestType, fullRequestsList, true)
  }

  //collect parameters by request types
  local currentParametersByRequestType = {}
  local selectedParametersByRequestType = {}
  foreach (requestType in fullRequestsList)
  {
    currentParametersByRequestType[requestType] <-
      getParametersByRequestType(crew.id, skillsList,  difficulty, requestType, false)
    selectedParametersByRequestType[requestType] <-
      getParametersByRequestType(crew.id, skillsList,  difficulty, requestType, true)
  }

  // Here goes generation of skill parameters cell values.
  local res = parseParameters(columnTypes,
    currentParametersByRequestType, selectedParametersByRequestType, crewUnitType)
  // If no parameters added then hide table's header.
  if (res.len()) // Nothing but header row.
    res.insert(0, getSkillListHeaderRow(crew, columnTypes))

  return res
}

g_crew_skill_parameters.getSkillDescriptionView <- function getSkillDescriptionView(crew, difficulty, memberName, skillName, crewUnitType)
{
  local skillsList = [{
    memberName = memberName
    skillName = skillName
  }]

  local view = {
    skillName = ::loc("crew/" + skillName)
    tooltipText = getTooltipText(memberName, skillName, crewUnitType, crew, difficulty)

    // First item in this array is table's header.
    parameterRows = getSkillListParameterRowsView(crew, difficulty, skillsList, crewUnitType)
    footnoteText = ::loc("shop/all_info_relevant_to_current_game_mode")
      + ::loc("ui/colon") + difficulty.getLocName()
  }

  if (!view.parameterRows.len())
    return view

  //use header items for legend
  view.headerItems <- view.parameterRows[0].valueItems

  //getprogressbarFrom a first row (it the same for all rows, so we showing it in a top of tooltip
  local firstRow = ::getTblValue(1, view.parameterRows)
  view.progressBarValue <- ::getTblValue("progressBarValue", firstRow)
  view.progressBarSelectedValue <- ::getTblValue("progressBarSelectedValue", firstRow)

  return view
}

::g_crew_skill_parameters.init()
