local tabsBase = require("daRg/components/tabs.nut")
local colors = require("reactiveGui/style/colors.nut")


local tab = function(tab, is_current, handler) {
  local grp = ::ElemGroup()
  local stateFlags = ::Watched(0)

  return function() {
    local isHover = (stateFlags.value & S_HOVER)
    local isActive = (stateFlags.value & S_ACTIVE)
    local fillColor, textColor, borderColor
    if (is_current) {
      textColor = colors.menu.activeTextColor
      fillColor = colors.menu.listboxSelOptionColor
      borderColor = colors.menu.headerOptionSelectedColor
    } else {
      textColor = isHover ? colors.menu.headerOptionSelectedTextColor : colors.menu.headerOptionTextColor
      fillColor = colors.transparent
      borderColor = isActive && isHover ? colors.menu.headerOptionSelectedColor :
        isHover ? colors.menu.headerOptionHoverColor :
        colors.transparent
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
      borderWidth = [0, 0, hdpx(1), 0]

      onClick = handler
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_STEXT
        font = Fonts.tiny_text_hud
        margin = [sh(1), sh(1)]
        color = textColor

        text = tab.text
        group = grp
      }
    }
  }
}


local tabsHolder = @(params){
  rendObj = ROBJ_SOLID
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  padding = [hdpx(1)]
  gap = hdpx(1)

  color = colors.menu.tabBackgroundColor
}


return tabsBase(tabsHolder, tab)
