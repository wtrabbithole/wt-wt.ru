::g_tutorials_manager <- {
  actions = []

  function canAct()
  {
    if (!::isInMenu())
      return false
    if (::isHandlerInScene(::gui_handlers.ShopCheckResearch))
      return false
    return true
  }

  function processActions()
  {
    if (!actions.len() || !canAct())
      return

    foreach (action in actions)
      if (action())
        return
  }

  function onEventModalWndDestroy(params)
  {
    processActions()
  }

  function onEventCrewTakeUnit(params)
  {
    local unit = ::getTblValue("unit", params)
    actions.append((@(unit) function() { return checkTutorialOnSetUnit(unit) })(unit).bindenv(this))
    processActions()
  }

  function checkTutorialOnSetUnit(unit)
  {
    if (!unit)
      return false

    if (::isTank(unit))
      return ::gui_start_checkTutorial("lightTank")
    else if (::gui_start_checkTutorial("fighter"))
      return true

    if (::check_aircraft_tags(unit.tags, ["bomberview"]))
      return ::gui_start_checkTutorial("bomber")
    else if (::isAirHaveAnyWeaponsTags(unit, ["bomb", "rocket"]))
      return ::gui_start_checkTutorial("assaulter")

    return false
  }
}

::subscribe_handler(::g_tutorials_manager, ::g_listener_priority.DEFAULT_HANDLER)
