::g_language <- {
  currentLanguage = null
  shortLangName = ""
  replaceFunctionsTable = {}

  langsList = []
  langsById = {}
  langsByChatId = {}
  isListInited = false

  needCheckLangPack = false
}

function g_language::standartStyleNumberCut(num)
{
  local needSymbol = num >= 9999.5
  local roundNum = ::roundToDigits(num, needSymbol ? 3 : 4)
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
  local roundNum = ::roundToDigits(num, needSymbol ? 4 : 5)
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

    // Source http://docs.translatehouse.org/projects/localization-guide/en/latest/l10n/pluralforms.html
    getPluralNounFormIdx = {
      // "Chinese", "TChinese", "HChinese", "Japanese", "Vietnamese", "Korean"
      // return -1 here is to ensure that when several words listed, the last one will be selected.
      // To make unlocalized (english) strings look better in asian localizations.
      // Also to always select the last word in unsupported user localizations.
      defaultAction = function(n) { return -1 } // nplurals=1
      replaceFunctions = [{
        language = ["English", "French", "Italian", "German", "Spanish", "Turkish", "Portuguese",
          "Hungarian", "Georgian", "Greek"]
        action = function(n) { return (n==1 ? 0 : 1) } // nplurals=2
      }, {
        language = ["Russian", "Serbian", "Ukrainian", "Belarusian", "Croatian"]
        action = function(n) { return (n%10==1 && n%100!=11 ? 0
                                     : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1
                                     : 2) } // nplurals=3
      }, {
        language = ["Polish"]
        action = function(n) { return (n==1 ? 0
                                     : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1
                                     : 2) } // nplurals=3
      }, {
        language = ["Czech"]
        action = function(n) { return (n==1 ? 0
                                     : n>=2 && n<=4 ? 1
                                     : 2) } // nplurals=3
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
  ::g_language.updateFunctions()
}

function g_language::saveLanguage(langName)
{
  currentLanguage = langName
  shortLangName = ::loc("current_lang")
  ::g_language.onChangeLanguage()
}
::g_language.saveLanguage(::get_blk_value_by_path(get_settings_blk(), "game_start/language", "English"))

function g_language::setGameLocalization(langId, reloadScene = false, suggestPkgDownload = false, isForced = false)
{
  if (langId == currentLanguage && !isForced)
    return

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
  return !::is_platform_ps4 && !::is_vendor_tencent() && !::is_vietnamese_version()
}

function g_language::_addLangOnce(id, icon = null, chatId = null, hasUnitSpeech = null)
{
  if (id in langsById)
    return

  local langInfo = {
    id = id
    title = ::loc("language/" + id)
    icon = icon || ""
    chatId = chatId || "en"
    isMainChatId = true
    hasUnitSpeech = !!hasUnitSpeech
  }
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

  local locBlk = ::DataBlock()
  ::get_localization_blk_copy(locBlk)
  local ttBlk = locBlk.text_translation || ::DataBlock()
  local existingLangs = ttBlk % "lang"

  local info = []
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
      local preset = blk.getBlock(p)
      for (local l = 0; l < preset.blockCount(); l++)
      {
        local lang = preset.getBlock(l)
        _addLangOnce(lang.id, lang.icon, lang.chatId, lang.hasUnitSpeech)
      }
    }

    foreach (langId in existingLangs)
      _addLangOnce(langId)
  }

  local curLangId = ::g_language.getLanguageName()
  _addLangOnce(curLangId)
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

::subscribe_handler(::g_language, ::g_listener_priority.DEFAULT_HANDLER)
