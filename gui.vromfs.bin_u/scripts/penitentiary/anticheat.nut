local function showMsgboxIfEacInactive(diffCode)
{
  if (::is_eac_inited() || !::should_use_eac(diffCode))
    return true

  ::scene_msg_box("eac_required", null, ::loc("eac/eac_not_inited_restart"),
       [
         ["restart",  function() {::restart_game(true)}],
         ["cancel", function() {}]
       ], null)
  return false
}


return {
  showMsgboxIfEacInactive = showMsgboxIfEacInactive
}