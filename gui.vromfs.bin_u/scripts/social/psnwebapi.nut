local webApi = require("ps4/webApi.nut")
local json = require_optional("json")
local parseJson = json?.parse ?? ::parse_json

webApi = webApi.__merge({
  send = function(action, onResponse=webApi.noOpCb, handler=null) {
    local cb = (handler!=null) ? ::Callback(onResponse, handler) : onResponse
    ::ps4_send_web_api_request(action, @(r) cb(r?.response ? parseJson(r.response) : null, r?.error))
  }
})

return webApi
