function replay_status(params)
{
  return {
    status = ::get_replay_status(),
    version = ::get_replay_version()
  }
}

function replay_start(params)
{
  local status = ::get_replay_status()
  if (status != "ok")
    return replay_status(null)

  local startPosition = params.position
  local url = params.url
  local timeline = ::getTblValue("timeline", false)

  ::start_replay(startPosition, url, timeline)
  return {status = "processed", version = ::get_replay_version()}
}

web_rpc.register_handler("replay_status", replay_status)
web_rpc.register_handler("replay_start", replay_start)
