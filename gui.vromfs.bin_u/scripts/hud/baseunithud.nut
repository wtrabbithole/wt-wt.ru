local hudCompassState = require_native("hudCompassState")
local { stashBhvValueConfig } = require("sqDagui/guiBhv/guiBhvValueConfig.nut")

class ::gui_handlers.BaseUnitHud extends ::gui_handlers.BaseGuiHandlerWT
{
  scene = null
  wndType = handlerType.CUSTOM

  function updatePosHudMultiplayerScore() {
    local multiplayerScoreObj = scene.findObject("hud_multiplayer_score")
    if (::check_obj(multiplayerScoreObj)) {
      multiplayerScoreObj.setValue(stashBhvValueConfig([{
        watch = hudCompassState.getHasCompassObservable()
        updateFunc = @(obj, value) obj.top = value ? "0.065@scrn_tgt" : "0.015@scrn_tgt"
      }]))
    }
  }
}
