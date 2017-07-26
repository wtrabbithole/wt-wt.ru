g_personal_unlocks <- {
  [PERSISTENT_DATA_PARAMS] = ["unlocksArray"]

  unlocksArray = []
  newIconWidgetById = {}

  showAllUnlocksValue = false
}

function g_personal_unlocks::reset()
{
  unlocksArray.clear()
  newIconWidgetById.clear()
}

function g_personal_unlocks::update()
{
  if (!::g_login.isLoggedIn())
    return

  reset()

  foreach(unlockBlk in ::g_unlocks.getAllUnlocksWithBlkOrder())
    if (unlockBlk.showAsBattleTask && (showAllUnlocksValue || ::is_unlock_visible(unlockBlk)))
    {
      unlocksArray.append(unlockBlk)
      newIconWidgetById[unlockBlk.id] <- null
    }
}

function g_personal_unlocks::getUnlocksArray() { return unlocksArray }

function g_personal_unlocks::onEventBattleTasksShowAll(params)
{
  showAllUnlocksValue = ::getTblValue("showAllTasksValue", params, false)
  update()
}

function g_personal_unlocks::onEventSignOut(p)
{
  reset()
}

function g_personal_unlocks::onEventLoginComplete(p)
{
  update()
}

function g_personal_unlocks::isAvailableForUser()
{
  return ::has_feature("PersonalUnlocks") && !::u.isEmpty(getUnlocksArray())
}

::g_script_reloader.registerPersistentDataFromRoot("g_personal_unlocks")
::subscribe_handler(::g_personal_unlocks, ::g_listener_priority.CONFIG_VALIDATION)
