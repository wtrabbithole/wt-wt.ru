::g_user_presence <- {
  inited = false
  currentPresence = {}
  helperObj = {}
}

function g_user_presence::init()
{
  updateBattlePresence()

  // Call updateClanTagPresence()
  // is not needed as this info comes
  // to client from char-server on login.

  if (!inited)
  {
    inited = true
    ::subscribe_handler(this, ::g_listener_priority.USER_PRESENCE_UPDATE)
  }
}

function g_user_presence::updateBattlePresence()
{
  if (::is_in_flight() || ::SessionLobby.isInRoom())
    setBattlePresence("in_game", ::SessionLobby.getRoomEvent())
  else if (::queues.isAnyQueuesActive())
  {
    local queue = ::queues.findQueue({})
    local event = ::events.getEvent(::getTblValue("name", queue, null))
    setBattlePresence("in_queue", event)
  }
  else
    setBattlePresence(null)
}

function g_user_presence::setBattlePresence(presenceName = null, event = null)
{
  if (presenceName == null || event == null)
    setPresence({status = null}) // Sets presence to "Online".
  else
  {
    setPresence({status = {
      [presenceName] = {
        country = ::get_profile_country_sq()
        diff = ::events.getEventDiffCode(event)
        eventId = event.name
      }
    }})
  }
}

function g_user_presence::updateClanTagPresence()
{
  local clanTag = ::getTblValue("tag", ::my_clan_info, null) || ""
  setPresence({ clanTag = clanTag })
}

function g_user_presence::onEventLobbyStatusChange(params)
{
  updateBattlePresence()
}

function g_user_presence::onEventQueueChangeState(params)
{
  updateBattlePresence()
}

function g_user_presence::onEventClanInfoUpdate(params)
{
  updateClanTagPresence()
}

function g_user_presence::setPresence(presence)
{
  if (!::g_login.isLoggedIn() || !checkPresence(presence))
    return

  // Copy new values to current presence object.
  foreach (key, value in presence)
    currentPresence[key] <- value
  ::set_presence(presence)
  ::broadcastEvent("MyPresenceChanged", presence)
}

/**
 * Checks if presence has something new
 * comparing to current presence. Used
 * to skip 'set_presence' call if nothing
 * changed.
 */
function g_user_presence::checkPresence(presence)
{
  if (presence == null)
    return false
  helperObj.clear()

  // Selecting only properties that can
  // be inequal with current presence.
  foreach (key, value in presence)
    helperObj[key] <- ::getTblValue(key, currentPresence)

  return !::u.isEqual(helperObj, presence)
}
