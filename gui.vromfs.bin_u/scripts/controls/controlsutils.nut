function on_connected_controller()
{
  //calls from c++ code, no event on PS4
  if (!::isInMenu())
    return
  local action = function() { ::gui_start_controls_type_choice() }
  local buttons = [{
      id = "change_preset",
      text = ::loc("msgbox/btn_yes"),
      func = action
    },
    { id = "cancel",
      text = ::loc("msgbox/btn_no"),
      func = null
    }]

  ::g_popups.add(::loc("popup/newcontroller"),
          ::loc("popup/newcontroller/message"),
          action,
          buttons,
          null,
          null,
          10*TIME_MINUTE_IN_SECONDS*TIME_SECOND_IN_MSEC)
}