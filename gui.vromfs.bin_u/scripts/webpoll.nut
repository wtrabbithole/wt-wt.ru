const WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS = 3600000
const VOTED_POLLS_SAVE_ID = "voted_polls"

::g_webpoll <- {
  cachedToken = ""
  tokenInvalidationTime = -1
  votedPolls = null
  pollBaseUrlById = {}
}

function g_webpoll::loadVotedPolls()
{
  votedPolls = ::load_local_account_settings(VOTED_POLLS_SAVE_ID, ::DataBlock())
}

function g_webpoll::saveVotedPolls()
{
  ::save_local_account_settings(VOTED_POLLS_SAVE_ID, votedPolls)
}

function g_webpoll::getVotedPolls()
{
  if(votedPolls == null)
    loadVotedPolls()
  return votedPolls
}

function g_webpoll::webpollEvent(id, token, voted)
{
  if( ! ::u.isEmpty(id) && token != null)
  {
    cachedToken = token
    if(tokenInvalidationTime == -1)
      tokenInvalidationTime = ::dagor.getCurTime() + WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS

    if(voted)
    {
      ::set_blk_value_by_path(getVotedPolls(), id, true)
      saveVotedPolls()
    }
  }
  ::broadcastEvent("WebPollAuthResult", id)
}

function g_webpoll::onSurveyVoteResult(params)
{
  webpollEvent(params.survey_id, "", params.has_vote)
}

function g_webpoll::checkTokensCacheTimeout()
{
  if(tokenInvalidationTime < ::dagor.getCurTime())
    invalidateTokensCache()
}

function g_webpoll::invalidateTokensCache()
{
  tokenInvalidationTime = -1
  if(::u.isEmpty(cachedToken))
    return
  cachedToken = ""
  ::get_cur_gui_scene().performDelayed(this,
    function(){ ::broadcastEvent("WebPollTokenInvalidated") })
}

function g_webpoll::getPollToken(pollId)
{
  checkTokensCacheTimeout()
  local baseUrl = getPollBaseUrl(pollId)
  if(cachedToken.len() == 0 && baseUrl != null)
    ::webpoll_authorize_with_url(baseUrl, pollId.tointeger())
  return cachedToken
}

function g_webpoll::generatePollUrl(pollId, token)
{
  local pollBaseUrl = getPollBaseUrl(pollId)
  if(pollBaseUrl == null)
    return ""
  return ::loc("url/webpoll_url",
    { base_url = pollBaseUrl, survey_id = pollId, disposable_token = token })
}

function g_webpoll::isPollVoted(pollId)
{
  return pollId in getVotedPolls()
}

function g_webpoll::clearOldVotedPolls(pollsTable)
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

function g_webpoll::onEventSignOut(p)
{
  votedPolls = null
  invalidateTokensCache()
}

function webpoll_event(id, token, voted)
{
  ::g_webpoll.webpollEvent(id.tostring(), token, voted)
}

function g_webpoll::setPollBaseUrl(pollId, pollUrl)
{
  pollBaseUrlById[pollId] <- pollUrl
}

function g_webpoll::getPollBaseUrl(pollId)
{
  return ::getTblValue(pollId, pollBaseUrlById)
}

web_rpc.register_handler("survey_vote_result", ::g_webpoll.onSurveyVoteResult.bindenv(::g_webpoll))
::subscribe_handler(::g_webpoll, ::g_listener_priority.CONFIG_VALIDATION)
