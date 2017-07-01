class ::gui_handlers.RemoteMissionModalHandler extends ::gui_handlers.CampaignChapter
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/empty.blk"

  mission = null

  function initScreen()
  {
    if (mission == null)
      return goBack()

    curMission = mission
    setMission()
  }

  function getModalOptionsParam(optionItems, applyFunc)
  {
    return {
      options = optionItems
      applyAtClose = false
      wndOptionsMode = ::get_options_mode(::get_game_mode())
      owner = this
      applyFunc = applyFunc
      cancelFunc = ::Callback(function() {
                                ::g_missions_manager.isRemoteMission = false
                                goBack()
                              }, this)
    }
  }
}