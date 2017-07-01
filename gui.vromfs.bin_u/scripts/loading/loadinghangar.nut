class ::gui_handlers.LoadingHangarHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/loading/loadingHangar.blk"
  sceneNavBlkName = "gui/loadingNav.blk"

  function initScreen()
  {
    ::g_anim_bg.load()
    ::setVersionText()
    ::set_help_text_on_loading(scene.findObject("help_text"))

    initFocusArray()

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