 /*
 module with low-level matching server interface

 matching_rpc_subscribe - set handler for server-side rpc or notification
 matching_api_func - call remote function by name and set callback for answer
 matching_api_notify - call remote function without callback
*/

_matching <- {
  matching_rpc_handlers = {}

  function translate_matching_params(params)
  {
    foreach(key, value in params)
    {
      if (typeof value == "string")
      {
        switch (key)
        {
          case "userId":
          case "roomId":
            params[key] = value.tointeger()
        }
      }
    }
    return params
  }

  function stringify_userid(data)
  {
    if (data == null)
      return null
    if (typeof data == "array")
    {
      for (local i = 0; i < data.len(); ++i)
        data[i] = stringify_userid(data[i])
    }
    else if (typeof data == "table")
    {
      if ("userId" in data)
        data.userId = data.userId.tostring()
      foreach (k, v in data)
        data[k] = stringify_userid(v)
    }
    return data
  }

  function find_rpc_handler(rpc_name)
  {
    local handler = ::getTblValue(rpc_name, matching_rpc_handlers)
    if (handler)
      return handler

    local dotPos = rpc_name.find(".")
    if (dotPos == null || dotPos == (rpc_name.len()-1))
      return null

    local globName = "*." + g_string.slice(rpc_name, dotPos+1)
    return ::getTblValue(globName, matching_rpc_handlers)
  }

  dbg_silent_messages = {
    ["mlogin.update_online_info"] = 1
  }
}

function matching_rpc_subscribe(rpc_name, callback)
{
  _matching.matching_rpc_handlers[rpc_name] <- callback
}

function matching_api_func(name, cb, params = null)
{
  local reqParams = { name = name }
  if (params != null)
    reqParams.data <- _matching.translate_matching_params(params)
  local realCb = (@(cb) function (response) {
    local unifyResp = {}
    if ("data" in response && typeof response.data == "table")
      unifyResp = _matching.stringify_userid(response.data)
    unifyResp.error <- response.error
    cb(unifyResp)
  })(cb)

  dagor.debug("send matching request: " + name)
  send_matching_rpc_request(reqParams, realCb)
}

function matching_api_notify(name, params = null)
{
  local reqParams = { name = name }
  if (params != null)
    reqParams.data <- _matching.translate_matching_params(params)
  dagor.debug("send matching notify: " + name)
  send_matching_generic_message(reqParams)
}

function debug_matching_api(api_call, params=null)
{
  api_call(params,
    function(response) {
      debugTableData(response)
    })
}

/*
  Notifications from C++ code
*/
function on_matching_generic_message(params)
{
  local name = ::getTblValue("name", params)
  if (!name)
  {
    dagor.debug("matching protocol error: bad message packet")
    debugTableData(params)
    return
  }
  params = _matching.stringify_userid(params)

  if (!(name in _matching.dbg_silent_messages))
  {
    dagor.debug("on_matching_generic_message: " + name)
    if (name.find("mrooms.on_") != -1 || ::is_dev_version)
      debugTableData(::getTblValue("data", params))
  }

  local handler = _matching.find_rpc_handler(name)
  if (!handler)
  {
    dagor.debug("matching rpc handler '" + name + "' not supported")
    return
  }

  handler(::getTblValue("data", params))
}

function on_matching_generic_rpc(params, rid)
{
  local name = ::getTblValue("name", params)
  if (!name)
  {
    dagor.debug("matching protocol error: bad RPC packet")
    debugTableData(params)
    return
  }
  params = _matching.stringify_userid(params)

  if (!(name in _matching.dbg_silent_messages))
  {
    dagor.debug("on_matching_generic_rpc: " + name)
    if (::is_dev_version)
      debugTableData(params.data)
  }

  local callback = (@(rid, name) function(message) {
    ::send_matching_rpc_response(rid, {name = name, data = message})
  })(rid, name)

  local handler = _matching.find_rpc_handler(name)
  if (!handler)
  {
    dagor.debug("matching rpc handler '" + name + "' not supported")
    callback({error = "not supported"})
    return
  }

  handler(::getTblValue("data", params), callback)
}

