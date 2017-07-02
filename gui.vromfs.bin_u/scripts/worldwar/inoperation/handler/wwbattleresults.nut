class ::gui_handlers.WwBattleResults extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/battleResultsWindow"

  battleRes = null

  static function open(battleRes)
  {
    if (!battleRes || !battleRes.isValid())
      return ::g_popups.add("", ::loc("worldwar/battle_not_found"))

    ::handlersManager.loadHandler(::gui_handlers.WwBattleResults, { battleRes = battleRes })
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function getSceneTplView()
  {
    return battleRes.getView()
  }

  function getCurrentEdiff()
  {
    return ::g_world_war.defaultDiffCode
  }
}
