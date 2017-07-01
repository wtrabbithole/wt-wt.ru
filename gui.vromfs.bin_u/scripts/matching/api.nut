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

  dbg_silent_messages = {
    ["mlogin.update_online_info"] = 1
  }
}

function matching_rpc_subscribe(message, callback)
{
  _matching.matching_rpc_handlers[message] <- callback
}

function matching_api_func(name, cb, params = null)
{
  local reqParams = { name = name }
  if (params != null)
    reqParams.data <- _matching.translate_matching_params(params)
  local realCb = (@(cb) function (response) {
    local unifyResp = {}
    if ("data" in response && typeof response.data == "table")
      unifyResp = response.data
    unifyResp.error <- response.error
    cb(unifyResp)
  })(cb)

  send_matching_rpc_request(reqParams, realCb)
}

function matching_api_notify(name, params = null)
{
  local reqParams = { name = name }
  if (params != null)
    reqParams.data <- _matching.translate_matching_params(params)
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

  if (!(name in _matching.dbg_silent_messages))
  {
    dagor.debug("on_matching_generic_message: " + name)
    if (::is_dev_version)
      debugTableData(::getTblValue("data", params))
  }

  if (!(name in _matching.matching_rpc_handlers))
  {
    dagor.debug("matching rpc handler '" + name + "' not supported")
    return
  }

  _matching.matching_rpc_handlers[name](::getTblValue("data", params))
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

  if (!(name in _matching.dbg_silent_messages))
  {
    dagor.debug("on_matching_generic_rpc: " + name)
    if (::is_dev_version)
      debugTableData(params.data)
  }

  local callback = (@(rid, name) function(message) {
    ::send_matching_rpc_response(rid, {name = name, data = message})
  })(rid, name)

  if (!(name in _matching.matching_rpc_handlers))
  {
    dagor.debug("matching rpc handler '" + name + "' not supported")
    callback({error = "not supported"})
    return
  }

  _matching.matching_rpc_handlers[name](::getTblValue("data", params), callback)
}

