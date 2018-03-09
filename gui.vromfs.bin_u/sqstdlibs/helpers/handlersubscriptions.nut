local u = require("std/u.nut")
local callback = ::require("sqStdLibs/helpers/callback.nut")

const SUBSCRIPTIONS_AMOUNT_TO_CLEAR = 50

//
// Event dispatching
//

::g_listener_priority <- {
  DEFAULT = 0
  DEFAULT_HANDLER = 1
  UNIT_CREW_CACHE_UPDATE = 2
  USER_PRESENCE_UPDATE = 2
  CONFIG_VALIDATION = 2
  LOGIN_PROCESS = 3
}

::current_broadcasting_events <- []
::current_event_id <- 0

/**
 * Data model:
 * {
 *   "CrewChanged" = [{ // Event name.
 *     listenerEnvWeakref = some_object_1.weakref() // Weak reference to environment object.
 *     listenerFunc = listener_func_1 // Function to call on event broadcast.
 *   }, {
 *     listenerEnvWeakref = some_object_2.weakref()
 *     listenerFunc = listener_func_2
 *   },
 *   ...
 *   ]
 *
 *   "WndModalDestroy" = ...
 * }
 */
::subscriptions_data_by_event_name <- {}

class Subscription
{
  listenerPriority = 0
  listenerCallback = null

  constructor(func, env, priority)
  {
    listenerCallback = callback.make(func, env)
    listenerPriority = priority
  }
}

function broadcastEvent(event_name, params = {})
{
  ::current_broadcasting_events.push({
    eventName = event_name
    eventId = (::current_event_id++)
  })

  // Remove invalid callbacks.
  local subscriptions = ::get_subscriptions_by_event_name(event_name)
  for (local i = subscriptions.len() - 1; i >= 0; --i)
    if (!subscriptions[i].listenerCallback.isValid())
      subscriptions.remove(i)

  // Using cloned queue to handle properly nested broadcasts.
  local subscriptionQueue = clone subscriptions
  local queueLen = subscriptionQueue.len()
  for (local i = 0; i < queueLen; ++i)
    subscriptionQueue[i].listenerCallback(params)

  ::current_broadcasting_events.pop()
}

function get_current_broadcasting_event_by_name(event_name)
{
  for (local i = ::current_broadcasting_events.len() - 1; i >= 0; --i)
  {
    local event_data = ::current_broadcasting_events[i]
    if (event_data.eventName == event_name)
      return event_data
  }
  return null
}

/**
 * @param {function} listener_env  Optional parameter which enforces call-environment for
 *                                 specified listener function. This parameter is also used
 *                                 for removing existing listeners.
 */
function add_event_listener(event_name, listener_func, listener_env = null, listener_priority = -1)
{
  if (listener_priority < 0)
    listener_priority = ::g_listener_priority.DEFAULT

  local subscriptions = ::get_subscriptions_by_event_name(event_name)
  if (subscriptions.len() % SUBSCRIPTIONS_AMOUNT_TO_CLEAR == 0) //if valid subscriptions more than amount to clear,
                                                                //do not need to check on each new
    for (local i = subscriptions.len() - 1; i >= 0; i--)
      if (!subscriptions[i].listenerCallback.isValid())
        subscriptions.remove(i)

  // Subscription object must be added according to specified priority.
  local indexToInsert
  for (indexToInsert = 0; indexToInsert < subscriptions.len(); ++indexToInsert)
    if (subscriptions[indexToInsert].listenerPriority <= listener_priority)
      break

  subscriptions.insert(indexToInsert, ::Subscription(listener_func, listener_env, listener_priority))
}

function get_subscriptions_by_event_name(event_name)
{
  if (!(event_name in ::subscriptions_data_by_event_name))
    ::subscriptions_data_by_event_name[event_name] <- []
  return ::subscriptions_data_by_event_name[event_name]
}

/**
 * Removes all event listeners with specified event name and environment.
 */
function remove_event_listeners_by_env(event_name, listener_env)
{
  local subscriptions = ::get_subscriptions_by_event_name(event_name)
  for (local i = subscriptions.len() - 1; i >= 0; --i)
    if (!subscriptions[i].listenerCallback.isValid()
      || subscriptions[i].listenerCallback.refToContext == listener_env)
    {
      subscriptions.remove(i)
    }
}

/**
 * Removes all listeners with specified environment regardless to event name.
 */
function remove_all_listeners_by_env(listener_env)
{
  foreach (event_name, subscriptions in ::subscriptions_data_by_event_name)
    ::remove_event_listeners_by_env(event_name, listener_env)
}

function subscribe_events_from_handler(handler, eventNamesList)
{
  if (handler == null)
    return
  foreach (eventName in eventNamesList)
  {
    local funcName = "onEvent" + eventName
    local listenerFunc = handler?[funcName]
    if (listenerFunc != null)
      ::add_event_listener(eventName, listenerFunc, handler)
  }
}

function subscribe_handler(handler, listener_priority = -1)
{
  if (handler == null)
    return
  foreach (property_name, property in handler)
  {
    if (!u.isFunction(property))
      continue
    local index = property_name.find("onEvent")
    if (index != 0)
      continue
    local event_name = property_name.slice("onEvent".len())
    ::add_event_listener(event_name, property, handler, listener_priority)
  }
}