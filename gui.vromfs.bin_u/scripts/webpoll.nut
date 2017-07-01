const WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS = 3600000

::g_webpoll <- {
  token = ""
  tokenInvalidationTime = -1
}

function g_webpoll::webpollEvent(id, token, voted)
{
  if(id != null && token != null)
  {
    ::g_webpoll.token = token
    if(tokenInvalidationTime == -1)
      tokenInvalidationTime = ::dagor.getCurTime() + WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS
  }
  ::broadcastEvent("WebPollAuthResult", { id = id, token = token, voted = voted })
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
  token = ""
  tokenInvalidationTime = -1
}

function g_webpoll::getPollToken(pollId)
{
  checkTokensCacheTimeout()
  if(token.len() == 0)
    ::webpoll_authorize(pollId.tointeger())
  return token
}

function g_webpoll::generatePollUrl(pollId, token)
{
  return ::loc("url/webpoll_url", { survey_id = pollId, disposable_token = token })
}

function webpoll_event(id, token, voted)
{
  ::g_webpoll.webpollEvent(id, token, voted)
}

web_rpc.register_handler("survey_vote_result", ::g_webpoll.onSurveyVoteResult)
