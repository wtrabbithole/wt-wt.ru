::g_chat_latest_threads <- {
  autoUpdatePeriodMsec = 60000
  playerUpdateTimeoutMsec = 15000

  requestTimeoutMsec = 15000

  lastUpdatetTime = -1
  lastRequestTime = -1

  curListUid = 0 //for fast compare is threadsList new
  threadsList = [] //first in array is a newest thread

  _requestedList = [] //uncomplete thread list received on refresh

  langsInited = false
  isCustomLangsList = false
  langsList = []
}

//refresh for usual players
function g_chat_latest_threads::refresh()
{
  local langTags = ::u.map(getSearchLangsList(),
                           function(l) { return ::g_chat_thread_tag.LANG.prefix + l.chatId })

  local categoryTagsText = ""
  if (!::g_chat_categories.isSearchAnyCategory())
  {
    local categoryTags = ::u.map(::g_chat_categories.getSearchCategoriesLList(),
                                function(cName) { return ::g_chat_thread_tag.CATEGORY.prefix + cName })
    categoryTagsText = ::g_string.implode(categoryTags, ",")
  }
  refreshAdvanced("hidden", ::g_string.implode(langTags, ","), categoryTagsText)
}

//refresh latest threads. options full work only for moderators.
//!(any of @excludeTags) && (any from includeTags1) && (any from includeTags2)
//for not moderators available only "lang_*" include and forced "hidden" exclude
function g_chat_latest_threads::refreshAdvanced(excludeTags = "hidden", includeTags1 = "", includeTags2 = "")
{
  if (!canRefresh())
    return

  local cmdArr = ["xtlist"]
  if (!excludeTags.len() && (includeTags1.len() || includeTags2.len()) )
    excludeTags = ","

  cmdArr.extend([excludeTags, includeTags1, includeTags2])

  _requestedList.clear()
  lastRequestTime = ::dagor.getCurTime()
  ::gchat_raw_command(::g_string.implode(cmdArr, " "))
}

function g_chat_latest_threads::onNewThreadInfoToList(threadInfo)
{
  ::u.appendOnce(threadInfo, _requestedList)
}

function g_chat_latest_threads::onThreadsListEnd()
{
  threadsList.clear()
  threadsList.extend(_requestedList)
  _requestedList.clear()
  curListUid++
  lastUpdatetTime = ::dagor.getCurTime()
  ::broadcastEvent("ChatLatestThreadsUpdate")
}

function g_chat_latest_threads::checkAutoRefresh()
{
  if (getUpdateState() == chatUpdateState.OUTDATED)
    refresh()
}

function g_chat_latest_threads::getUpdateState()
{
  if (lastRequestTime > lastUpdatetTime && lastRequestTime + requestTimeoutMsec > ::dagor.getCurTime())
    return chatUpdateState.IN_PROGRESS
  if (lastUpdatetTime > 0 && lastUpdatetTime + autoUpdatePeriodMsec > ::dagor.getCurTime())
    return chatUpdateState.UPDATED
  return chatUpdateState.OUTDATED
}

function g_chat_latest_threads::getTimeToRefresh()
{
  return ::max(0, lastUpdatetTime + playerUpdateTimeoutMsec - ::dagor.getCurTime())
}

function g_chat_latest_threads::canRefresh()
{
  return ::g_chat.checkChatConnected()
         && getUpdateState() != chatUpdateState.IN_PROGRESS
         && getTimeToRefresh() <= 0
}

function g_chat_latest_threads::forceAutoRefreshInSecond()
{
  local state = getUpdateState()
  if (state == chatUpdateState.IN_PROGRESS)
    return

  local diffSec = 1000
  lastUpdatetTime = ::dagor.getCurTime() - autoUpdatePeriodMsec + diffSec
  //set status chatUpdateState.IN_PROGRESS
  lastRequestTime = ::dagor.getCurTime() - requestTimeoutMsec + diffSec
}

function g_chat_latest_threads::checkInitLangs()
{
  if (langsInited)
    return
  langsInited = true

  local canChooseLang =  ::g_chat.canChooseThreadsLang()
  if (!canChooseLang)
  {
    isCustomLangsList = false
    return
  }

  local langsStr = ::loadLocalByAccount("chat/latestThreadsLangs", "")
  local savedLangs = ::split(langsStr, ",")

  langsList.clear()
  local langsConfig = ::g_language.getGameLocalizationInfo()
  foreach(lang in langsConfig)
  {
    if (!lang.isMainChatId)
      continue
    if (::isInArray(lang.chatId, savedLangs))
      langsList.append(lang)
  }

  isCustomLangsList = langsList.len() > 0
}

function g_chat_latest_threads::saveCurLangs()
{
  if (!langsInited || !isCustomLangsList)
    return
  local chatIds = ::u.map(langsList, function (l) { return l.chatId })
  ::saveLocalByAccount("chat/latestThreadsLangs", ::g_string.implode(chatIds, ","))
}

function g_chat_latest_threads::_setSearchLangs(values)
{
  langsList = values
  saveCurLangs()
  isCustomLangsList = langsList.len() > 0
  ::broadcastEvent("ChatThreadSearchLangChanged")
}

function g_chat_latest_threads::getSearchLangsList()
{
  checkInitLangs()
  return isCustomLangsList ? langsList : [::g_language.getCurLangInfo()]
}

function g_chat_latest_threads::openChooseLangsMenu(align = "top", alignObj = null)
{
  if (!::g_chat.canChooseThreadsLang())
    return

  local optionsList = []
  local curLangs = getSearchLangsList()
  local langsConfig = ::g_language.getGameLocalizationInfo()
  foreach(lang in langsConfig)
    if (lang.isMainChatId)
      optionsList.append({
        text = lang.title
        icon = lang.icon
        value = lang
        selected = ::isInArray(lang, curLangs)
      })

  ::gui_start_multi_select_menu({
    list = optionsList
    onFinalApplyCb = function(values) { ::g_chat_latest_threads._setSearchLangs(values) }
    align = align
    alignObj = alignObj
  })
}

function g_chat_latest_threads::isListNewest(checkListUid)
{
  checkAutoRefresh()
  return checkListUid == curListUid
}

function g_chat_latest_threads::getList()
{
  checkAutoRefresh()
  return threadsList
}

function g_chat_latest_threads::onEventInitConfigs(p)
{
  langsInited = false

  local blk = get_game_settings_blk()
  if (::u.isDataBlock(blk.chat))
  {
    autoUpdatePeriodMsec = blk.chat.threadsListAutoUpdatePeriodMsec || autoUpdatePeriodMsec
    playerUpdateTimeoutMsec = blk.chat.threadsListPlayerUpdateTimeoutMsec || playerUpdateTimeoutMsec
  }
}

function g_chat_latest_threads::onEventChatThreadInfoModifiedByPlayer(p)
{
  if (::isInArray(::getTblValue("threadInfo", p), getList()))
    ::g_chat_latest_threads.forceAutoRefreshInSecond() //wait for all changes applied
}

function g_chat_latest_threads::onEventChatThreadCreateRequested(p)
{
  ::g_chat_latest_threads.forceAutoRefreshInSecond()
}

function g_chat_latest_threads::onEventChatSearchCategoriesChanged(p)
{
  refresh()
}

function g_chat_latest_threads::onEventGameLocalizationChanged(p)
{
  if (!isCustomLangsList)
    ::g_chat_latest_threads.forceAutoRefreshInSecond()
}

::subscribe_handler(::g_chat_latest_threads, ::g_listener_priority.DEFAULT_HANDLER)
