function notify_keyboard_layout_changed(layout)
{
  ::broadcastEvent("KeyboardLayoutChanged", {layout = layout})
}

function notify_keyboard_locks_changed(locks)
{
  ::broadcastEvent("KeyboardLocksChanged", {locks = locks})
}
