/*
   g_system_msg allow to send messages via config to localize and color on receiver side.
   It has short keys to be compact in json format allowed to use in irc chat etc.
   Also it save enough to be user generated.

  langConfig (table or array of tables):
  {
    [::g_system_msg.LOC_ID] - locId used to localize this config
                              when it set, all other keys in config are used as params for localizaation
                              but any param also can be langConfig
    [::g_system_msg.VALUE_ID] - exact value to show. used only when ::g_system_msg.LOC_ID not set
    [::g_system_msg.COLOR_ID] - colorTag to colorize result of localize this config
                                can be used only colors from COLOR_TAG enum
                                to avoid broken markup by mistake or by users
  }
    also langConfig can be a simple string.
    it will be equal to { [::g_system_msg.LOC_ID] = "string" }

  example:
****  [
****    {
****      [::g_system_msg.LOC_ID] = "multiplayer/enemyTeamTooLowMembers",
****      [::g_system_msg.COLOR_ID] = COLOR_TAG.ACTIVE,
****      chosenTeam =  {
****        [::g_system_msg.VALUE_ID] = "A",
****        [::g_system_msg.COLOR_ID] = COLOR_TAG.TEAM_BLUE,
****      }
****      otherTeam = {
****        [::g_system_msg.LOC_ID] = ::g_team.B.shortNameLocId,
****        [::g_system_msg.COLOR_ID] = COLOR_TAG.TEAM_RED,
****      }
****      chosenTeamCount = 5
****      otherTeamCount =  3
****      reqOtherteamCount = 4
****    }
****    "simpleLocIdNotColored"
****    {
****      [::g_system_msg.VALUE_ID] = "\nsome unlocalized text"
****    }
****  ]

also you can find example function below - g_system_msg::dbgExample


  API:
  function configToLang(langConfig, paramValidateFunction = null)
    creates localized string by given <langConfig>
    but validate each text param by <paramValidateFunction>
    return null if failed to convert

  function configToJsonString(langConfig, paramValidateFunction = null)
    convert <langConfig> to json string,
    with prevalidation each config param by <paramValidateFunction>

  function jsonStringToLang(jsonString, paramValidateFunction = null)
    convert jsonString to langConfig and return localized string maked from it
    return null if failed to convert

  function makeColoredValue(colorTag, value)
    return simple langConfig with colored value
      { [COLOR_ID] = colorTag, [VALUE_ID] = value }

  function makeColoredLocId(colorTag, locId)
    return simple langConfig with colored localizationId (locId)
      { [COLOR_ID] = colorTag, [LOC_ID] = locId }
*/

enum COLOR_TAG {
  ACTIVE = "av"
  USERLOG = "ul"
  TEAM_BLUE = "tb"
  TEAM_RED = "tr"
}

::g_system_msg <- {
  LOC_ID = "l"
  VALUE_ID = "t"
  COLOR_ID = "c"

  colors = {
    [COLOR_TAG.ACTIVE] = "activeTextColor",
    [COLOR_TAG.USERLOG] = "userlogColoredText",
    [COLOR_TAG.TEAM_BLUE] = "teamBlueColor",
    [COLOR_TAG.TEAM_RED] = "teamRedColor",
  }
}

function g_system_msg::configToJsonString(langConfig, textValidateFunction = null)
{
  if (textValidateFunction)
    langConfig = validateLangConfig(langConfig, textValidateFunction)

  local jsonString = ::save_to_json(langConfig)
  return jsonString
}

function g_system_msg::validateLangConfig(langConfig, valueValidateFunction)
{
  return ::u.map(
    langConfig,
    function(value) {
      if (::u.isString(value))
        return valueValidateFunction(value)
      else if (::u.isTable(value) || ::u.isArray(value))
        return validateLangConfig(value, valueValidateFunction)
      return value
    }.bindenv(this)
  )
}

function g_system_msg::jsonStringToLang(jsonString, paramValidateFunction = null, separator = "")
{
  local langConfig = ::parse_json(jsonString)
  return configToLang(langConfig, paramValidateFunction, separator)
}

function g_system_msg::configToLang(langConfig, paramValidateFunction = null, separator = "", defaultLocValue = null)
{
  if (::u.isTable(langConfig))
    return configTblToLang(langConfig, paramValidateFunction)
  if (::u.isArray(langConfig))
  {
    local resArray = ::u.map(langConfig,
      (@(cfg) configToLang(cfg, paramValidateFunction) || "").bindenv(this))
    return ::implode(resArray, separator)
  }
  if (::u.isString(langConfig))
    return ::loc(langConfig, defaultLocValue)
  return null
}

function g_system_msg::configTblToLang(configTbl, paramValidateFunction = null)
{
  local res = ""
  local locId = ::getTblValue(LOC_ID, configTbl, null)
  if (!::u.isString(locId)) //res by value
  {
    local value = ::getTblValue(VALUE_ID, configTbl, null)
    if (value == null)
      return res

    res = value.tostring()
    if (paramValidateFunction)
      res = paramValidateFunction(res)
  }
  else //res by locId with params
  {
    local params = {}
    foreach(key, param in configTbl)
    {
      local text = configToLang(param, paramValidateFunction, "", "")
      if (!::u.isEmpty(text))
      {
        params[key] <- text
        continue
      }

      if (paramValidateFunction && ::u.isString(param))
        param = paramValidateFunction(param)
      params[key] <- param
    }
    res = ::loc(locId, params)
  }

  local colorName = getColorByTag(::getTblValue(COLOR_ID, configTbl))
  res = ::colorize(colorName, res)
  return res
}

function g_system_msg::getColorByTag(tag)
{
  return ::getTblValue(tag, colors, "")
}

//return config of value which will be colored in result
function g_system_msg::makeColoredValue(colorTag, value)
{
  return { [COLOR_ID] = colorTag, [VALUE_ID] = value }
}

//return config of localizationId which will be colored in result
function g_system_msg::makeColoredLocId(colorTag, locId)
{
  return { [COLOR_ID] = colorTag, [LOC_ID] = locId }
}

/*
function g_system_msg::dbgExample(textObjId = "menu_chat_text")
{
  local json = ::g_system_msg.configToJsonString([
    {
      [::g_system_msg.LOC_ID] = "multiplayer/enemyTeamTooLowMembers",
      [::g_system_msg.COLOR_ID] = COLOR_TAG.ACTIVE,
      chosenTeam = ::g_system_msg.makeColoredValue(COLOR_TAG.TEAM_BLUE, ::g_team.A.getShortName())
      otherTeam = ::g_system_msg.makeColoredValue(COLOR_TAG.TEAM_RED, ::g_team.B.getShortName())
      chosenTeamCount = 5
      otherTeamCount =  3
      reqOtherteamCount = 4
    }
    {
      [::g_system_msg.VALUE_ID] = "\n-------------------------------------\n"
    }
    {
      [::g_system_msg.LOC_ID] = "multiplayer/enemyTeamTooLowMembers",
      [::g_system_msg.COLOR_ID] = COLOR_TAG.ACTIVE,
      chosenTeam = {
        [::g_system_msg.LOC_ID] = ::g_team.A.shortNameLocId,
        [::g_system_msg.COLOR_ID] = COLOR_TAG.TEAM_BLUE,
      }
      otherTeam = {
        [::g_system_msg.LOC_ID] = ::g_team.B.shortNameLocId,
        [::g_system_msg.COLOR_ID] = COLOR_TAG.TEAM_RED,
      }
      chosenTeamCount = 5
      otherTeamCount =  3
      reqOtherteamCount = 4
    }
  ])

  local res = ::g_system_msg.jsonStringToLang(json)
  local testObj = get_gui_scene()[textObjId]
  if (::check_obj(testObj))
    testObj.setValue(res)
  return json
}
*/