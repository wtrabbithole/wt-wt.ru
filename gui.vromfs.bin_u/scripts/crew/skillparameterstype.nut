local enums = ::require("std/enums.nut")
::g_skill_parameters_type <- {
  types = []
}

function g_skill_parameters_type::_parseColumns(paramData, parameterValue, columnTypes,
           parametersByRequestType, selectedParametersByRequestType, resArray)
{
  // Do nothing.
  return true
}

function g_skill_parameters_type::_getValue(requestType, parametersByRequestType, params = null)
{
  // Do nothing.
  return 0
}

function g_skill_parameters_type::_parseColumnTypes(
  columnTypes, parametersByRequestType, selectedParametersByRequestType,
  measureType, parameterView, params = null)
{
  foreach (columnType in columnTypes)
  {
    local prevValue = getValue(
      columnType.previousParametersRequestType, parametersByRequestType, params)

    local curValue = getValue(
      columnType.currentParametersRequestType, parametersByRequestType, params)

    local prevSelectedValue = getValue(
      columnType.previousParametersRequestType, selectedParametersByRequestType, params)

    local curSelectedValue = getValue(
      columnType.currentParametersRequestType, selectedParametersByRequestType, params)

    local valueItem = columnType.createValueItem(
      prevValue, curValue, prevSelectedValue, curSelectedValue, measureType)

    parameterView.valueItems.push(valueItem)
  }
}

function g_skill_parameters_type::_getProgressBarValue(parametersByRequestType, params = null)
{
  local currentParameterValue = getValue(
    ::g_skill_parameters_request_type.CURRENT_VALUES, parametersByRequestType, params)
  local maxParameterValue = getValue(
    ::g_skill_parameters_request_type.MAX_VALUES, parametersByRequestType, params)
  local baseParameterValue = getValue(
    ::g_skill_parameters_request_type.BASE_VALUES, parametersByRequestType, params)
  local curDiff = ::fabs(currentParameterValue - baseParameterValue)
  local maxDiff = ::fabs(maxParameterValue - baseParameterValue)
  if (maxDiff > 0.0)
    return (1000 * (curDiff / maxDiff)).tointeger()
  return 0
}

::g_skill_parameters_type.template <- {
  paramNames = []
  parseColumns = ::g_skill_parameters_type._parseColumns
  getValue = ::g_skill_parameters_type._getValue
  parseColumnTypes = ::g_skill_parameters_type._parseColumnTypes
  getProgressBarValue = ::g_skill_parameters_type._getProgressBarValue
}

enums.addTypesByGlobalName("g_skill_parameters_type", {
  DEFAULT = {
    parseColumns = function(paramData, columnTypes,
                            parametersByRequestType, selectedParametersByRequestType, resArray)
    {
      local parameterName = paramData.name
      local measureType = ::g_crew_skills.getMeasureTypeBySkillParameterName(parameterName)
      local needMemberName = paramData.valuesArr.len() > 1
      local parsedMembers = []
      foreach(idx, value in paramData.valuesArr)
      {
        if(::isInArray(value.memberName, parsedMembers))
          continue
        local parameterView = {
          descriptionLabel = parameterName.find("weapons/") == 0 ? ::loc(parameterName) : ::loc(::format("crewSkillParameter/%s", parameterName))
          valueItems = []
        }

        if (needMemberName)
          parameterView.descriptionLabel += ::format(" (%s)", ::loc("crew/" + value.memberName))

        local params = {
          idx = idx
          parameterName = parameterName
        }
        parseColumnTypes(columnTypes, parametersByRequestType, selectedParametersByRequestType,
          measureType, parameterView, params)

        parameterView.progressBarValue <- getProgressBarValue(parametersByRequestType, params)
        parameterView.progressBarSelectedValue <- getProgressBarValue(selectedParametersByRequestType, params)
        resArray.push(parameterView)
        parsedMembers.push(value.memberName)
      }
    }

    getValue = function (requestType, parametersByRequestType, params = null)
    {
      local path = [requestType, params.parameterName, params.idx, "value"]
      return ::get_tbl_value_by_path_array(path, parametersByRequestType, 0)
    }
  }

  DISTANCE_ERROR = {
    paramNames = [
      "tankGunnerDistanceError",
      "shipGunnerFuseDistanceError"
    ]

    parseColumns = function(paramData, columnTypes,
                            parametersByRequestType, selectedParametersByRequestType, resArray)
    {
      local currentDistanceErrorData = paramData.valuesArr
      if (!currentDistanceErrorData.len())
        return

      foreach (i, parameterTable in currentDistanceErrorData[0].value)
      {
        local descriptionLocParams = {
          errorText = ::g_measure_type.ALTITUDE.getMeasureUnitsText(parameterTable.error, true, true)
        }
        local parameterView = {
          descriptionLabel = ::loc("crewSkillParameter/" + paramData.name, descriptionLocParams)
          valueItems = []
        }
        local params = {
          columnIndex = i
          parameterName = paramData.name
        }
        parseColumnTypes(columnTypes, parametersByRequestType, selectedParametersByRequestType,
          ::g_measure_type.DISTANCE, parameterView, params)
        parameterView.progressBarValue <- getProgressBarValue(parametersByRequestType, params)
        resArray.push(parameterView)
      }
    }

    getValue = function (requestType, parametersByRequestType, params = null)
    {
      local path = [requestType, params.parameterName, 0, "value", params.columnIndex, "distance"]
      return ::get_tbl_value_by_path_array(path, parametersByRequestType, 0)
    }
  }
})

function g_skill_parameters_type::getTypeByParamName(paramName)
{
  return enums.getCachedType(
    "paramNames", paramName, ::g_skill_parameters_type_cache.byParamName,
    ::g_skill_parameters_type, ::g_skill_parameters_type.DEFAULT)
}

::g_skill_parameters_type_cache <- {
  byParamName = {}
}
