::g_ww_army_move_state <- {
  types = []
  cache = {
    byName = {}
  }
}

::g_ww_army_move_state.template <- {
  isMove = false
  name = ""
}

::g_enum_utils.addTypesByGlobalName("g_ww_army_move_state", {
  ES_UNKNOWN = {
    isMove = false
  }
  ES_WAIT_FOR_PATH = {
    isMove = false
  }
  ES_WRONG_PATH = {
    isMove = false
  }
  ES_PATH_PASSED = {
    isMove = false
  }
  ES_MOVING_BY_PATH = {
    isMove = true
  }
  ES_STOPED = {
    isMove = false
  }
}, null, "name")

function g_ww_army_move_state::getMoveParamsByName(name)
{
  return ::g_enum_utils.getCachedType("name", name, ::g_ww_army_move_state.cache.byName, this, ES_UNKNOWN)
}
