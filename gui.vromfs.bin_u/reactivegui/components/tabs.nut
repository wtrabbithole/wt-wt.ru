local tabsBase = require("daRg/components/tabs.nut")
local colors = require("../style/colors.nut")


local tab = function(tab, is_current, handler) {
  local grp = ::ElemGroup()
  local stateFlags = ::Watched(0)

  return function() {
    local isHover = (stateFlags.value & S_HOVER)
    local fillColor, textColor, borderColor
    if (is_current) {
      textColor = colors.menu.activeTextColor
      fillColor = colors.menu.listboxSelOptionColor
      borderColor = colors.menu.headerOptionSelectedColor
    } else {
      textColor = isHover ? colors.menu.headerOptionSelectedTextColor : colors.menu.headerOptionTextColor
      fillColor = colors.transparent
      borderColor = isHover ? colors.menu.headerOptionHoverColor : colors.transparent
    }

    return {
      key = tab
      rendObj = ROBJ_BOX
      halign = HALIGN_CENTER
      valign = VALIGN_MIDDLE
      size = SIZE_TO_CONTENT
      watch = stateFlags
      group = grp

      behavior = Behaviors.Button

      fillColor = fillColor
      borderColor = borderColor
      borderWidth = [0, 0, hdpx(2), 0]

      onClick = handler
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_STEXT
        font = Fonts.tiny_text_hud
        fontSize = hdpx(10)
        margin = [sh(1), sh(2)]
        color = textColor

        text = tab.text
        group = grp
      }
    }
  }
}


local tabsHolder = @(){
  rendObj = ROBJ_SOLID
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  padding = [0, sh(1)]
  gap = sh(1)

  color = colors.menu.tabBackgroundColor
}


return tabsBase(tabsHolder, tab)
