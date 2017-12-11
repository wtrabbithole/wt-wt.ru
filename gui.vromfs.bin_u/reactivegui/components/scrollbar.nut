local scrollbarBase = require("daRg/components/scrollbar.nut")
local colors = require("../style/colors.nut")


local styling = {
  Knob = class {
    rendObj = ROBJ_SOLID
    colorCalc = @(sf) (sf & S_ACTIVE) ? colors.menu.scrollbarSliderColorHover
                    : ((sf & S_HOVER) ? colors.menu.scrollbarSliderColorHover
                                      : colors.menu.scrollbarSliderColor)
  }

  Bar = function(has_scroll) {
    if (has_scroll) {
      return class {
        rendObj = ROBJ_SOLID
        color = colors.menu.scrollbarBgColor
        _width = sh(1)
        _height = sh(1)
      }
    } else {
      return class {
        rendObj = ROBJ_SOLID
        color = 0
        _width = sh(1)
        _height = sh(1)
      }
    }
  }

  ContentRoot = class {
    size = flex()
  }
}


local scrollbar = function(scroll_handler) {
  return scrollbarBase.scroll(scroll_handler, {styling=styling})
}


local makeHorizScroll = function(content, options={}) {
  if (!("styling" in options))
    options.styling <- styling
  return scrollbarBase.makeHorizScroll(content, options)
}


local makeVertScroll = function(content, options={}) {
  if (!("styling" in options))
    options.styling <- styling
  return scrollbarBase.makeVertScroll(content, options)
}


local export = class {
  scrollbar = scrollbar
  makeHorizScroll = makeHorizScroll
  makeVertScroll = makeVertScroll
  styling = styling
}()


return export
