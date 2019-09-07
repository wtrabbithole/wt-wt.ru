::gui_start_credits <- function gui_start_credits()
{
  ::handlersManager.loadHandler(::gui_handlers.CreditsMenu)
}

::gui_start_credits_ingame <- function gui_start_credits_ingame()
{
  ::credits_handler = ::handlersManager.loadHandler(::gui_handlers.CreditsMenu, { backSceneFunc = null })
}

class ::gui_handlers.CreditsMenu extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/credits.blk"
  rootHandlerClass = ::gui_handlers.TopMenu
  static hasTopMenuResearch = false

  function initScreen()
  {
    local textArea = (guiScene/"credits-text"/"textarea")
    ::load_text_content_to_gui_object(textArea, "lang/credits.txt")
    ::enableHangarControls(true)
  }

  function onScreenClick()
  {
    ::on_credits_finish(true)
  }
}