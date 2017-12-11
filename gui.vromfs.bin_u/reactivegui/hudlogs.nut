local transition = require("style/hudTransition.nut")
local chat = require("hudChat.nut")
local battleLog = require("hudBattleLog.nut")
local tabs = require("components/tabs.nut")
local hudState = require("hudState.nut")


local tabsList = [
  { id = "Chat", text = ::loc("mainmenu/chat"), content = chat }
  { id = "BattleLog", text = ::loc("options/_Bttl"), content = battleLog }
]


local currentTab = Watched(tabsList[0])


local logsHeader = @(){
  size = [flex(), SIZE_TO_CONTENT]
  watch = [
    currentTab
    hudState.cursorVisible
  ]
  opacity = hudState.cursorVisible.value ? 1.0 : 0.0
  children = [
    tabs({
      tabs = tabsList
      currentTab = currentTab.value
      onChange = function(tab) {
        currentTab.update(tab)
      }
    })
  ]

  transitions = [transition()]
}


return @() {
  size = [sw(30),  sw(13)]
  flow = FLOW_VERTICAL
  watch = currentTab
  children = [
    logsHeader
    currentTab.value.content
  ]
}
