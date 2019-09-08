local shortcutsEnumData = require("scripts/controls/shortcutsList/shortcutsEnumData.nut")

local shHelpersMode = require("scripts/controls/shortcutsList/shortcutsListHelpersMode.nut")
local shGroupAircraft = require("scripts/controls/shortcutsList/shortcutsGroupAircraft.nut")
local shGroupArtillery = require("scripts/controls/shortcutsList/shortcutsGroupArtillery.nut")
local shGroupGamepad = require("scripts/controls/shortcutsList/shortcutsGroupGamepad.nut")
local shGroupHelicopter = require("scripts/controls/shortcutsList/shortcutsGroupHelicopter.nut")
local shGroupIngame = require("scripts/controls/shortcutsList/shortcutsGroupIngame.nut")
local shGroupInterface = require("scripts/controls/shortcutsList/shortcutsGroupInterface.nut")
local shGroupReplay = require("scripts/controls/shortcutsList/shortcutsGroupReplay.nut")
local shGroupShip = require("scripts/controls/shortcutsList/shortcutsGroupShip.nut")
local shGroupSubmarine = require("scripts/controls/shortcutsList/shortcutsGroupSubmarine.nut")
local shGroupTank = require("scripts/controls/shortcutsList/shortcutsGroupTank.nut")
local shGroupTrackIR = require("scripts/controls/shortcutsList/shortcutsGroupTrackIR.nut")
local shGroupView = require("scripts/controls/shortcutsList/shortcutsGroupView.nut")
local shGroupVoice = require("scripts/controls/shortcutsList/shortcutsGroupVoice.nut")
local shGroupWalker = require("scripts/controls/shortcutsList/shortcutsGroupWalker.nut")

local shortcutsList = {
  types = []
  template = shortcutsEnumData.template
  addShortcuts = shortcutsEnumData.definitionFunc
}

foreach (list in [
  shHelpersMode
  shGroupAircraft
  shGroupHelicopter
  shGroupTank
  shGroupShip
  shGroupSubmarine
  shGroupWalker
  shGroupGamepad
  shGroupIngame
  shGroupArtillery
  shGroupInterface
  shGroupView
  shGroupVoice
  shGroupTrackIR
  shGroupReplay
])
  shortcutsList.addShortcuts(list, shortcutsList)

return shortcutsList