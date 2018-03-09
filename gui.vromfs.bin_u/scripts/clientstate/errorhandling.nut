local callback = ::require("sqStdLibs/helpers/callback.nut")
local enums = ::require("std/enums.nut")
local u = ::require("std/u.nut")

local netAssertsList = []
function script_net_assert_once(id, msg)
{
  if (::isInArray(id, netAssertsList))
    return dagor.debug(msg)

  netAssertsList.append(id)
  return script_net_assert(msg)
}

function assertf_once(id, msg)
{
  if (::isInArray(id, netAssertsList))
    return dagor.debug(msg)
  netAssertsList.append(id)
  return ::dagor.assertf(false, msg)
}

callback.setContextDbgNameFunction(function(context)
{
  if (!u.isTable(context))
    return ::toString(context, 0)

  foreach(key, value in ::getroottable())
    if (value == context)
      return key
  return "unknown table"
})

callback.setAssertFunction(function(callback, assertText)
{
  local eventText = ""
  if (::current_broadcasting_events.len())
    eventText += ::format("event = %s, ", ::current_broadcasting_events.top().eventName)
  local hudEventName = ("g_hud_event_manager" in getroottable()) ? ::g_hud_event_manager.getCurHudEventName() : null
  if (hudEventName)
    eventText += ::format("hudEvent = %s, ", hudEventName)

  ::script_net_assert_once("cb error " + eventText,
    format("Callback error ( %scontext = %s):\n%s",
      eventText, callback.getContextDbgName(), assertText
    )
  )
})

enums.setAssertFunction(::script_net_assert_once)