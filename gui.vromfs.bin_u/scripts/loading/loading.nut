function gui_start_loading(blkpath = "gui/loading.blk")
{
  local handler = null
  local briefing = ::DataBlock()
  if (::g_login.isLoggedIn() && (blkpath != "gui/loading.blk")
      && ::loading_get_briefing(briefing) && (briefing.blockCount() > 0))
  {
    dagor.debug("briefing loaded, place = "+briefing.getStr("place_loc", ""))
    handler = ::handlersManager.loadHandler(::gui_handlers.LoadingBrief, { briefing = briefing })
  }
  else
    handler = ::handlersManager.loadHandler(::gui_handlers.LoadingHandler)
  ::show_title_logo(true)
  ::last_ca_base <- null //!!FIX ME: it not about loading - it about respawn screen
}

class ::gui_handlers.LoadingHandler extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loading.blk"
  sceneNavBlkName = "gui/loadingNav.blk"

  function initScreen()
  {
    ::g_anim_bg.load()
    ::setVersionText()
    ::set_help_text_on_loading(scene.findObject("help_text"))

    local updObj = scene.findObject("cutscene_update")
    if (::checkObj(updObj))
      updObj.setUserData(this)
  }

  function onUpdate(obj, dt)
  {
    if (::loading_is_finished())
      ::loading_press_apply()
  }
}