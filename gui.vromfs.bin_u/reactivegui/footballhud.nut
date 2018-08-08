local missionState = require("missionState.nut")
local teamColors = require("style/teamColors.nut")
local time = require("std/time.nut")
local frp = require("daRg/frp.nut")

local style = {}

style.scoreText <- {
  font = Fonts.big_text_hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = 50
  fontFx = FFT_GLOW
}

local scoreState = {
  localTeam = Watched(0)
  enemyTeam = Watched(0)
}

frp.subCombine(scoreState.localTeam,
  [missionState.localTeam, missionState.scoreTeamA, missionState.scoreTeamB],
  @(list) list[0] == 2 ? list[2] : list[1])

frp.subCombine(scoreState.enemyTeam,
  [missionState.localTeam, missionState.scoreTeamA, missionState.scoreTeamB],
  @(list) list[0] == 2 ? list[1] : list[2])


return @() {
  flow = FLOW_HORIZONTAL
  watch = missionState.gameType
  isHidden = (missionState.gameType.value & GT_FOOTBALL) == 0

  children = [
    @() {
      rendObj = ROBJ_BOX
      size = [sh(5), sh(6)]
      valign = VALIGN_MIDDLE
      halign = HALIGN_CENTER
      fillColor = teamColors.teamBlueColor
      borderColor = teamColors.teamBlueLightColor
      borderWidth = [hdpx(1)]

      children = @() style.scoreText.__merge({
        watch = scoreState.localTeam
        rendObj = ROBJ_DTEXT
        text = scoreState.localTeam.value
      })
    }
    @() {
      rendObj = ROBJ_SOLID
      size = [sh(12), sh(4.5)]
      valign = VALIGN_MIDDLE
      halign = HALIGN_CENTER
      color = Color(0, 0, 0, 102)
      children = @(){
        watch = missionState.timeLeft
        rendObj = ROBJ_DTEXT
        font = Fonts.medium_text_hud
        color = Color(249, 219, 120)
        text = time.secondsToString(missionState.timeLeft.value, false)
      }
    }
    @() {
      rendObj = ROBJ_BOX
      size = [sh(5), sh(6)]
      valign = VALIGN_MIDDLE
      halign = HALIGN_CENTER
      fillColor = teamColors.teamRedColor
      borderColor = teamColors.teamRedLightColor
      borderWidth = [hdpx(1)]

      children = @() style.scoreText.__merge({
        watch = scoreState.enemyTeam
        rendObj = ROBJ_DTEXT
        text = scoreState.enemyTeam.value
      })
    }
  ]
}
