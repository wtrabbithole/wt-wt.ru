local stdMath = require("std/math.nut")

::g_language <- {
  currentLanguage = null
  currentSteamLanguage = ""
  shortLangName = ""
  replaceFunctionsTable = {}

  langsList = []
  langsById = {}
  langsByChatId = {}
  isListInited = false
  langsListForInventory = {}

  needCheckLangPack = false

  steamLanguages = {
    English = "english"
    French = "french"
    Italian = "italian"
    German = "german"
    Spanish = "spanish"
    Russian = "russian"
    Polish = "polish"
    Czech = "czech"
    Turkish = "turkish"
    Chinese = "schinese"
    Japanese = "japanese"
    Portuguese = "portuguese"
    Ukrainian = "ukrainian"
    Hungarian = "hungarian"
    Korean = "koreana"
    TChinese = "tchinese"
    HChinese = "schinese"
  }
}

function g_language::standartStyleNumberCut(num)
{
  local needSymbol = num >= 9999.5
  local roundNum = stdMath.roundToDigits(num, needSymbol ? 3 : 4)
  if (!needSymbol)
    return roundNum.tostring()

  if (roundNum >= 1000000000)
    return (0.000000001 * roundNum) + "G"
  else if (roundNum >= 1000000)
    return (0.000001 * roundNum) + "M"
  return (0.001 * roundNum) + "K"
}

function g_language::chineseStyleNumberCut(num)
{
  local needSymbol = num >= 99999.5
  local roundNum = stdMath.roundToDigits(num, needSymbol ? 4 : 5)
  if (!needSymbol)
    return roundNum.tostring()

  if (roundNum >= 100000000)
    return (0.00000001 * roundNum) + ::loc("100m_shortSymbol")
  return (0.0001 * roundNum) + ::loc("10k_shortSymbol")
}

function g_language::tencentAddLineBreaks(text)
{
  local res = ""
  local total = ::utf8(text).charCount()
  for(local i = 0; i < total; i++)
  {
    local nextChar = ::utf8(text).slice(i, i + 1)
    if (nextChar == "\t")
      continue
    res += nextChar + (i < total - 1 ? "\t" : "")
  }
  return res
}

function g_language::initFunctionsTable()
{
  local table = {
    getShortTextFromNum = {
      defaultAction = ::g_language.standartStyleNumberCut
      replaceFunctions = [{
        language = ["Chinese", "TChinese", "HChinese", "Japanese"],
        action = ::g_language.chineseStyleNumberCut
      }]
    }

    addLineBreaks = {
      defaultAction = function(text) { return text }
      replaceFunctions = [{
        language = ["HChinese"],
        action = ::g_language.tencentAddLineBreaks
      }]
    }

    decimalFormat = {
      defaultAction = @(value) ::g_string.intToStrWithDelimiter(value, " ")
      replaceFunctions = [{
        language = ["German", "Italian", "Spanish", "Turkish"]
        action = @(value) ::g_string.intToStrWithDelimiter(value, ".")
      }, {
        language = ["English", "Japanese", "Korean"]
        action = @(value) ::g_string.intToStrWithDelimiter(value, ",")
      }, {
        language = ["Chinese", "TChinese", "HChinese"]
        action = @(value) ::g_string.intToStrWithDelimiter(value, ",", 4)
      }]
    }
  }

  replaceFunctionsTable = table
}
::g_language.initFunctionsTable()

function g_language::updateFunctions()
{
  foreach (funcName, block in replaceFunctionsTable)
  {
    local replaced = false
    foreach(table in block.replaceFunctions)
    {
      local langsArray = ::getTblValue("language", table, [])
      if (!::isInArray(getLanguageName(), langsArray))
        continue

      this[funcName] <- table.action
      replaced = true
      break
    }

    if (!replaced)
      this[funcName] <- block.defaultAction
  }
}

function g_language::getLanguageName()
{
  return currentLanguage
}

function g_language::getShortName()
{
  return shortLangName
}

function g_language::getCurLangInfo()
{
  return getLangInfoById(currentLanguage)
}

function g_language::onChangeLanguage()
{
  ::g_language.currentSteamLanguage = ::getTblValue(currentLanguage, steamLanguages, "english");
  ::g_language.updateFunctions()
}

function g_language::saveLanguage(langName)
{
  if (currentLanguage == langName)
    return
  currentLanguage = langName
  shortLangName = ::loc("current_lang")
  ::g_language.onChangeLanguage()
}
::g_language.saveLanguage(get_settings_blk()?.language ?? get_settings_blk()?.game_start?.language ?? "English")

function g_language::setGameLocalization(langId, reloadScene = false, suggestPkgDownload = false, isForced = false)
{
  if (langId == currentLanguage && !isForced)
    return

  ::handlersManager.shouldResetFontsCache = true
  ::setSystemConfigOption("language", langId)
  ::set_language(langId)
  ::g_language.saveLanguage(langId)

  if (suggestPkgDownload)
    needCheckLangPack = true

  local handler = ::handlersManager.getActiveBaseHandler()
  if (reloadScene && handler)
    handler.fullReloadScene()
  else
    ::handlersManager.markfullReloadOnSwitchScene()

  ::broadcastEvent("GameLocalizationChanged")
}

function g_language::reload()
{
  setGameLocalization(currentLanguage, true, false, true)
}

function g_language::onEventNewSceneLoaded(p)
{
  if (!needCheckLangPack)
    return

  ::check_localization_package_and_ask_download()
  needCheckLangPack = false
}

function canSwitchGameLocalization()
{
  return !::is_ps4_or_xbox && !::is_vendor_tencent() && !::is_vietnamese_version()
}

function g_language::getEmptyLangInfo()
{
  local langInfo = {
    id = "empty"
    title = "empty"
    icon = ""
    chatId = ""
    isMainChatId = true
    hasUnitSpeech = false
  }
  return langInfo
}

function g_language::_addLangOnce(id, icon = null, chatId = null, hasUnitSpeech = null)
{
  if (id in langsById)
    return

  local langInfo = getEmptyLangInfo()
  langInfo.id = id
  langInfo.title = ::loc("language/" + id)
  langInfo.icon = icon || ""
  langInfo.chatId = chatId || "en"
  langInfo.isMainChatId = true
  langInfo.hasUnitSpeech = !!hasUnitSpeech

  langsList.append(langInfo)
  langsById[id] <- langInfo

  if (chatId && !(chatId in langsByChatId))
    langsByChatId[chatId] <- langInfo
  else
    langInfo.isMainChatId = false
}

function g_language::checkInitList()
{
  if (isListInited)
    return
  isListInited = true

  langsList.clear()
  langsById.clear()
  langsByChatId.clear()
  langsListForInventory.clear()

  local locBlk = ::DataBlock()
  ::get_localization_blk_copy(locBlk)
  local ttBlk = locBlk.text_translation || ::DataBlock()
  local existingLangs = ttBlk % "lang"

  local guiBlk = ::configs.GUI.get()
  local blockName = ::is_vendor_tencent() ? "tencent" : ::is_vietnamese_version() ? "vietnam" : "default"
  local preset = guiBlk.game_localization ? guiBlk.game_localization[blockName] : ::DataBlock()
  for (local l = 0; l < preset.blockCount(); l++)
  {
    local lang = preset.getBlock(l)
    if (::isInArray(lang.id, existingLangs))
      _addLangOnce(lang.id, lang.icon, lang.chatId, lang.hasUnitSpeech)
  }

  if (::is_dev_version)
  {
    local blk = guiBlk.game_localization || ::DataBlock()
    for (local p = 0; p < blk.blockCount(); p++)
    {
      local devPreset = blk.getBlock(p)
      for (local l = 0; l < devPreset.blockCount(); l++)
      {
        local lang = devPreset.getBlock(l)
        _addLangOnce(lang.id, lang.icon, lang.chatId, lang.hasUnitSpeech)
      }
    }

    foreach (langId in existingLangs)
      _addLangOnce(langId)
  }

  local curLangId = ::g_language.getLanguageName()
  _addLangOnce(curLangId)

  local inventoryBlk = locBlk.inventory_abbreviated_languages_table || ::DataBlock()
  for (local l = 0; l < inventoryBlk.paramCount(); ++l)
  {
    local param = inventoryBlk.getParamValue(l)
    if (typeof(param) != "string")
      continue

    local abbrevName = inventoryBlk.getParamName(l)
    langsListForInventory[param] <- abbrevName
  }
}

function g_language::getGameLocalizationInfo()
{
  checkInitList()
  return langsList
}

function g_language::getLangInfoById(id)
{
  checkInitList()
  return ::getTblValue(id, langsById)
}

function g_language::getLangInfoByChatId(chatId)
{
  checkInitList()
  return ::getTblValue(chatId, langsByChatId)
}

/*
  return localized text from @config (table or datablock) by id
  if text value require to be localized need to start it with #

  defaultValue returned when not fount id in config.
  if defaultValue == null  - it will return id instead

  example config:
  {
    text = "..."   //default text. returned when not found lang specific.
    text_ru = "#locId"  //russian text, taken from localization  ::loc("locId")
    text_en = "localized text"  //english text. already localized.
  }
*/
function g_language::getLocTextFromConfig(config, id = "text", defaultValue = null)
{
  local res = null
  local key = id + "_" + shortLangName
  if (key in config)
    res = config[key]
  else
    res = ::getTblValue(id, config, res)

  if (typeof(res) != "string")
    return defaultValue || id

  if (res.len() > 1 && res.slice(0, 1) == "#")
    return ::loc(res.slice(1))
  return res
}

function g_language::isAvailableForCurLang(block)
{
  if (!::getTblValue("showForLangs", block))
    return true

  local availableForLangs = ::split(block.showForLangs, ";")
  return ::isInArray(getLanguageName(), availableForLangs)
}

function g_language::onEventInitConfigs(p)
{
  isListInited = false
}

function get_current_language()
{
  return ::g_language.getLanguageName()
}

function getShortTextFromNum(num)
{
  return ::g_language.getShortTextFromNum(num)
}

// using from C++ to convert current language to inventory's abbreviation language
// to properly load localization for its goods
function get_abbreviated_language_for_inventory(fullLang)
{
  local abbrevLang = "en"
  if (fullLang in ::g_language.langsListForInventory)
    abbrevLang = ::g_language.langsListForInventory[fullLang]

  return abbrevLang
}

// called from native playerProfile on language change, so at this point we can use get_language
function on_language_changed()
{
  ::g_language.saveLanguage(::get_language())
}

function g_language::getCurrentSteamLanguage()
{
  return currentSteamLanguage
}

// used in native code
function get_current_steam_language()
{
  return g_language.getCurrentSteamLanguage()
}

::subscribe_handler(::g_language, ::g_listener_priority.DEFAULT_HANDLER)
