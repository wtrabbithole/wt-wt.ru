function on_hit_camera_event(mode, result = ::DM_HIT_RESULT_NONE, info = null) // called from client
{
  ::g_hud_hitcamera.onHitCameraEvent(mode, result)

  if (result >= ::DM_HIT_RESULT_KILL)
    ::broadcastEvent("CurrentTargetKilled")
}

function get_hit_camera_aabb() // called from client
{
  return ::g_hud_hitcamera.getAABB()
}

::g_hud_hitcamera <- {
  scene     = null
  titleObj  = null

  enabled = true
  needShow = false //need to show, but show only when enabled
  hitResult = ::DM_HIT_RESULT_NONE

  styles = {
    [::DM_HIT_RESULT_NONE]      = "none",
    [::DM_HIT_RESULT_RICOSHET]  = "ricochet",
    [::DM_HIT_RESULT_BOUNCE]    = "bounce",
    [::DM_HIT_RESULT_HIT]       = "hit",
    [::DM_HIT_RESULT_BURN]      = "burn",
    [::DM_HIT_RESULT_CRITICAL]  = "critical",
    [::DM_HIT_RESULT_KILL]      = "kill",
    [::DM_HIT_RESULT_METAPART]  = "hull",
    [::DM_HIT_RESULT_AMMO]      = "ammo",
    [::DM_HIT_RESULT_FUEL]      = "fuel",
    [::DM_HIT_RESULT_CREW]      = "crew",
    [::DM_HIT_RESULT_TORPEDO]   = "torpedo",
  }
}

function g_hud_hitcamera::init(_nest)
{
  if (!::checkObj(_nest))
    return

  if (::checkObj(scene) && scene.isEqual(_nest))
    return

  scene = _nest
  titleObj = scene.findObject("title")

  reinit()
}

function g_hud_hitcamera::reinit()
{
  enabled = ::get_option_xray_kill()
  update()
}

function g_hud_hitcamera::reset()
{
  needShow = false
  hitResult = ::DM_HIT_RESULT_NONE
}

function g_hud_hitcamera::update()
{
  if (!::checkObj(scene))
    return

  local isVisible = enabled && needShow
  scene.show(isVisible)

  if (!isVisible || !::checkObj(titleObj))
    return

  local style = ::getTblValue(hitResult, styles, "none")
  titleObj.show(hitResult != ::DM_HIT_RESULT_NONE)
  titleObj.setValue(::loc("hitcamera/result/" + style))
  scene.result = style
}

function g_hud_hitcamera::getAABB()
{
  return ::get_dagui_obj_aabb(scene)
}

function g_hud_hitcamera::onHitCameraEvent(mode, result = ::DM_HIT_RESULT_NONE)
{
  hitResult = result
  needShow = mode == ::HIT_CAMERA_START
  update()
}

function g_hud_hitcamera::onEventLoadingStateChange(params)
{
  if (!::is_in_flight())
    reset()
}

::subscribe_handler(::g_hud_hitcamera, ::g_listener_priority.DEFAULT_HANDLER)