foreach (notificationName, callback in
          {
            ["mrpc.generic_notify"] = function (params)
              {
                local from = ::getTblValue("from", params)
                if (from == "web-service")
                  ::handle_web_rpc(params)
              },

            ["mrpc.generic_rpc"] = function (params, callback)
              {
                local from = ::getTblValue("from", params)
                if (from == "web-service")
                {
                  callback(::handle_web_rpc(params))
                  return
                }
                callback({error = "unknown service"})
              }
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)

