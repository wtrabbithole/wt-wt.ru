::g_crews_list <- {
  crewsList = !::g_login.isLoggedIn() ? [] : ::get_crew_info()

  isNeedToSkipNextProfileUpdate = false
  ignoreTransactions = [
    ::EATT_SAVING
    ::EATT_CLANSYNCPROFILE
    ::EATT_CLAN_TRANSACTION
    ::EATT_SET_EXTERNAL_ID
    ::EATT_BUYING_UNLOCK
    ::EATT_COMPLAINT
  ]
  isSlotbarUpdateSuspended = false
  isSlotbarUpdateRequired = false
}

function g_crews_list::get()
{
  if (!crewsList.len() && ::g_login.isProfileReceived())
    refresh()
  return crewsList
}

function g_crews_list::refresh()
{
  //we don't know about slotbar refresh in flight,
  //but we know than out of flight it refresh only with profile, 
  //so can optimize it updates, and remove some direct refresh calls from outside
  crewsList = ::get_crew_info()
}

g_crews_list._isReinitSlotbarsInProgress <- false
function g_crews_list::reinitSlotbars()
{
  if (isSlotbarUpdateSuspended)
  {
    isSlotbarUpdateRequired = true
    dagor.debug("ignore reinitSlotbars: updates suspended")
    return
  }

  isSlotbarUpdateRequired = false
  if (_isReinitSlotbarsInProgress)
  {
    ::script_net_assert_once("reinitAllSlotbars recursion", "reinitAllSlotbars: recursive call found")
    return
  }

  _isReinitSlotbarsInProgress = true
  ::init_selected_crews(true)
  ::handlersManager.sendEventToHandlers("reinitSlotbar")
  _isReinitSlotbarsInProgress = false
}

function g_crews_list::suspendSlotbarUpdates()
{
  isSlotbarUpdateSuspended = true
}

function g_crews_list::flushSlotbarUpdate()
{
  isSlotbarUpdateSuspended = false
  if (isSlotbarUpdateRequired)
    reinitSlotbars()
}

function g_crews_list::onEventProfileUpdated(p)
{
  if (p.transactionType == ::EATT_UPDATE_ENTITLEMENTS)
    ::update_shop_countries_list()

  if (::g_login.isLoggedIn() && !::isInArray(p.transactionType, ignoreTransactions))
    reinitSlotbars()
}

function g_crews_list::onEventUnlockedCountriesUpdate(p)
{
  ::update_shop_countries_list()
  if (::g_login.isLoggedIn())
    reinitSlotbars()
}


function g_crews_list::onEventSignOut(p)
{
  isSlotbarUpdateSuspended = false
}

function g_crews_list::onEventLoadingStateChange(p)
{
  isSlotbarUpdateSuspended = false
}

function reinitAllSlotbars()
{
  ::g_crews_list.reinitSlotbars()
}

::subscribe_handler(::g_crews_list, ::g_listener_priority.DEFAULT_HANDLER)