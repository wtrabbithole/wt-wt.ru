local cc = require_native("colorCorrector")
local teamColors = {
  teamBlueColor = Watched(null)
  teamBlueLightColor = Watched(null)
  teamBlueInactiveColor = Watched(null)
  teamBlueDarkColor = Watched(null)
  chatTextTeamColor = Watched(null)
  teamRedColor = Watched(null)
  teamRedLightColor = Watched(null)
  teamRedInactiveColor = Watched(null)
  teamRedDarkColor = Watched(null)
  squadColor = Watched(null)
  chatTextSquadColor = Watched(null)
  trigger = Watched(null)
}


::interop.recalculateTeamColors <- function () {
  local standardColors = !::cross_call.login.isLoggedIn() || !::cross_call.isPlayerDedicatedSpectator()
  local squadTheme = @() standardColors ? cc.TARGET_HUE_SQUAD : cc.TARGET_HUE_SPECTATOR_ALLY
  local allyTheme =  @() standardColors ? cc.TARGET_HUE_ALLY  : cc.TARGET_HUE_SPECTATOR_ALLY
  local enemyTheme = @() standardColors ? cc.TARGET_HUE_ENEMY : cc.TARGET_HUE_SPECTATOR_ENEMY

  foreach (cfg in [
    { theme = allyTheme,  baseColor = Color( 82, 122, 255), name = "teamBlueColor" }
    { theme = allyTheme,  baseColor = Color(153, 177, 255), name = "teamBlueLightColor"}
    { theme = allyTheme,  baseColor = Color( 92,  99, 122), name = "teamBlueInactiveColor" }
    { theme = allyTheme,  baseColor = Color( 16,  24,  52), name = "teamBlueDarkColor" }
    { theme = allyTheme,  baseColor = Color(189, 204, 255), name = "chatTextTeamColor" }
    { theme = enemyTheme, baseColor = Color(255,  90,  82), name = "teamRedColor" }
    { theme = enemyTheme, baseColor = Color(255, 162, 157), name = "teamRedLightColor" }
    { theme = enemyTheme, baseColor = Color(124,  95,  93), name = "teamRedInactiveColor" }
    { theme = enemyTheme, baseColor = Color( 52,  17,  16), name = "teamRedDarkColor" }
    { theme = squadTheme, baseColor = Color( 62, 158,  47), name = "squadColor" }
    { theme = squadTheme, baseColor = Color(198, 255, 189), name = "chatTextSquadColor" }
  ]) {
    teamColors[cfg.name].update(cc.correctHueTarget(cfg.baseColor, cfg.theme()))
  }

  teamColors.trigger.trigger()
}

::interop.recalculateTeamColors()


local export = class {
  watch = teamColors
  trigger = teamColors.trigger

  function _call(self) {
    local colors = {}
    foreach (colorName, colorWatch in teamColors) {
      colors[colorName] <- colorWatch.value
    }
    return colors
  }

  function _get(colorName) {
    return colorName in teamColors ? teamColors[colorName].value : null
  }
}()

return export
