local { animBgLoad } = require("scripts/loading/animBg.nut")

::gui_start_loading <- function gui_start_loading(isMissionLoading = false)
{
  if (::u.isString(isMissionLoading))
    isMissionLoading = isMissionLoading != "gui/loading.blk" //compatibility with 1.67.2.X

  local briefing = ::DataBlock()
  if (::g_login.isLoggedIn() && isMissionLoading
      && ::loading_get_briefing(briefing) && (briefing.blockCount() > 0))
  {
    ::dagor.debug("briefing loaded, place = "+briefing.getStr("place_loc", ""))
    ::handlersManager.loadHandler(::gui_handlers.LoadingBrief, { briefing = briefing })
  }
  else if (::g_login.isLoggedIn())
    ::handlersManager.loadHandler(::gui_handlers.LoadingHangarHandler, { isEnteringMission = isMissionLoading })
  else
    ::handlersManager.loadHandler(::gui_handlers.LoadingHandler)

  ::show_title_logo(true)
}

class ::gui_handlers.LoadingHandler extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loading.blk"
  sceneNavBlkName = "gui/loadingNav.blk"

  function initScreen()
  {
    animBgLoad()
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