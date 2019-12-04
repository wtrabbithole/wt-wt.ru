const WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS = 3000000
const VOTED_POLLS_SAVE_ID = "voted_polls"

::g_webpoll <- {
  cachedToken = ""
  tokenInvalidationTime = -1
  votedPolls = null
  pollBaseUrlById = {}
  pollIdByFullUrl = {}
  authorizedPolls = []
}

g_webpoll.loadVotedPolls <- function loadVotedPolls()
{
  if (!::g_login.isProfileReceived())
    return
  votedPolls = ::load_local_account_settings(VOTED_POLLS_SAVE_ID, ::DataBlock())
}

g_webpoll.saveVotedPolls <- function saveVotedPolls()
{
  if (!::g_login.isProfileReceived())
    return
  ::save_local_account_settings(VOTED_POLLS_SAVE_ID, votedPolls)
}

g_webpoll.getVotedPolls <- function getVotedPolls()
{
  if (!::g_login.isProfileReceived())
    return ::DataBlock()
  if (votedPolls == null)
    loadVotedPolls()
  return votedPolls
}

g_webpoll.webpollEvent <- function webpollEvent(id, token, voted)
{
  id = ::to_integer_safe(id)
  if( ! id || token == null)
    return

  id = id.tostring()
  cachedToken = token
  if(tokenInvalidationTime == -1)
    tokenInvalidationTime = ::dagor.getCurTime() + WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS

  if(voted)
  {
    ::set_blk_value_by_path(getVotedPolls(), id, true)
    saveVotedPolls()
  }
  if (authorizedPolls.indexof(id) == null)
    authorizedPolls.append(id)
  ::broadcastEvent("WebPollAuthResult", {pollId = id})
}

g_webpoll.onSurveyVoteResult <- function onSurveyVoteResult(params)
{
  webpollEvent(params.survey_id, "", params.has_vote)
}

g_webpoll.checkTokensCacheTimeout <- function checkTokensCacheTimeout()
{
  if(tokenInvalidationTime < ::dagor.getCurTime())
    invalidateTokensCache()
}

g_webpoll.updateTokensCache <- function updateTokensCache(params)
{
  cachedToken = params?.new_dtoken ?? ""
  if (cachedToken != "")
    tokenInvalidationTime = ::dagor.getCurTime() + WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS
  else
    tokenInvalidationTime = -1

  ::get_cur_gui_scene().performDelayed(this,
    function(){ ::broadcastEvent("WebPollTokenInvalidated") })
}

g_webpoll.invalidateTokensCache <- function invalidateTokensCache()
{
  if (cachedToken != "" || tokenInvalidationTime != -1)
    updateTokensCache({})
}

g_webpoll.getPollIdByFullUrl <- function getPollIdByFullUrl(url)
{
  return ::getTblValue(url, pollIdByFullUrl)
}

g_webpoll.getPollToken <- function getPollToken(pollId)
{
  checkTokensCacheTimeout()
  return cachedToken
}

g_webpoll.generatePollUrl <- function generatePollUrl(pollId, needAuthorization = true)
{
  local pollBaseUrl = getPollBaseUrl(pollId)
  if (pollBaseUrl == null)
    return ""
  if (cachedToken == "")
  {
    if(needAuthorization)
      ::webpoll_authorize_with_url(pollBaseUrl, pollId.tointeger())
    return ""
  }

  if (authorizedPolls.indexof(pollId.tostring()) != null)
  {
    local url = ::loc("url/webpoll_url",
      { base_url = pollBaseUrl, survey_id = pollId, disposable_token = cachedToken })
    if( ! (url in pollIdByFullUrl))
      pollIdByFullUrl[url] <- pollId
    return url
  }

  return ""
}

g_webpoll.isPollVoted <- function isPollVoted(pollId)
{
  return pollId in getVotedPolls()
}

g_webpoll.clearOldVotedPolls <- function clearOldVotedPolls(pollsTable)
{
  local votedCount = getVotedPolls().paramCount() - 1
  for (local i = votedCount; i >= 0; i--)
  {
    local savedId = getVotedPolls().getParamName(i)
    if( ! (savedId in pollsTable))
      ::set_blk_value_by_path(getVotedPolls(), savedId, null)
  }
  saveVotedPolls()
}

g_webpoll.invalidateData <- function invalidateData()
{
  votedPolls = null
  authorizedPolls.clear()
  invalidateTokensCache()
  pollIdByFullUrl.clear()
}

g_webpoll.onEventLoginComplete <- function onEventLoginComplete(p)
{
  invalidateData()
}

g_webpoll.onEventSignOut <- function onEventSignOut(p)
{
  invalidateData()
}

g_webpoll.setPollBaseUrl <- function setPollBaseUrl(pollId, pollUrl)
{
  if( ! (pollId in pollBaseUrlById))
    pollBaseUrlById[pollId] <- pollUrl
}

g_webpoll.getPollBaseUrl <- function getPollBaseUrl(pollId)
{
  return ::getTblValue(pollId, pollBaseUrlById)
}

web_rpc.register_handler("survey_vote_result", ::g_webpoll.onSurveyVoteResult.bindenv(::g_webpoll))
web_rpc.register_handler("webpoll_dtoken_invalidate", ::g_webpoll.updateTokensCache.bindenv(::g_webpoll))
::subscribe_handler(::g_webpoll, ::g_listener_priority.CONFIG_VALIDATION)

::webpoll_event <- function webpoll_event(id, token, voted)
{
  ::g_webpoll.webpollEvent(id, token, voted)
}
