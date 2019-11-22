local sortIdxByExpClass = {
  fighter = 0
  assault = 1
  bomber  = 2
}

local wwUnitClassParams = {
  [WW_UNIT_CLASS.FIGHTER] = {
    name = "fighter"
    iconText = @() ::loc("worldWar/iconAirFighter")
    color = "medium_fighterColor"
  },
  [WW_UNIT_CLASS.ASSAULT] = {
    name = "assault"
    iconText = @() ::loc("worldWar/iconAirAssault")
    color = "common_assaultColor"
  },
  [WW_UNIT_CLASS.BOMBER] = {
    name = "bomber"
    iconText = @() ::loc("worldWar/iconAirBomber")
    color = "medium_bomberColor"
  }
}

local getSortIdx = @(expClass) sortIdxByExpClass?[expClass] ?? sortIdxByExpClass.len()
local getText = @(unitClass) wwUnitClassParams?[unitClass].name ?? "unknown"
local function getIconText(unitClass, needColorize = false) {
  local params = wwUnitClassParams?[unitClass]
  if (params == null)
    return ""

  local text = params.iconText()
  if (needColorize)
    text = ::colorize(params.color, text)

  return text
}

return {
  getSortIdx = getSortIdx
  getText = getText
  getIconText = getIconText
}