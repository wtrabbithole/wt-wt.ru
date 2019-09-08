local function showMsgboxIfEacInactive()
{
  if (::is_eac_inited())
    return true

  ::showInfoMsgBox(::loc("eac/eac_not_inited"), "eac_violation", true)
  return false
}


return {
  showMsgboxIfEacInactive = showMsgboxIfEacInactive
}