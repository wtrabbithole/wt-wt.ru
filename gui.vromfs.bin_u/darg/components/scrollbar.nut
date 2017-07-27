local defStyling = {
  Bar = class {
    rendObj = ROBJ_SOLID
    color = Color(40, 40, 40, 160)
    _width = sh(1)
    _height = sh(1)
  }

  Knob = class {
    rendObj = ROBJ_SOLID
    colorCalc = @(sf) (sf & S_ACTIVE) ? Color(255,255,255)
                    : (sf & S_HOVER)  ? Color(110, 120, 140, 80)
                                      : Color(110, 120, 140, 160)
  }

  ContentRoot = class {
    size = flex()
  }
}


local resolveBarClass = function(bar, has_scroll) {
  if (type(bar) == "function") {
    return bar(has_scroll)
  }
  return bar
}

local calcBarSize = function(bar_class, axis) {
  return (axis==0) ? [flex(), bar_class._height] : [bar_class._width, flex()]
}


local scrollbar = function(scroll_handler, options={}) {
  local stateFlags = ::Watched(0)
  local styling   = options.get("styling", defStyling)
  local barClass  = options.get("barStyle", styling.Bar)
  local knobClass = options.get("knobStyle", styling.Knob)

  local orientation = options.get("orientation", O_VERTICAL)
  local axis        = (orientation==O_VERTICAL) ? 1 : 0

  return function() {
    local elem = scroll_handler.elem

    if (!elem) {
      local cls = resolveBarClass(barClass, false)
      return class extends cls {
        key = scroll_handler
        behavior = Behaviors.Slider
        watch = scroll_handler
        size = calcBarSize(cls, axis)
      }
    }

    local contentSize, elemSize, scrollPos
    if (axis == 0) {
      contentSize = elem.getContentWidth()
      elemSize = elem.getWidth()
      scrollPos = elem.getScrollOffsX()
    } else {
      contentSize = elem.getContentHeight()
      elemSize = elem.getHeight()
      scrollPos = elem.getScrollOffsY()
    }

    if (contentSize <= elemSize) {
      local cls = resolveBarClass(barClass, false)
      return class extends cls {
        key = scroll_handler
        behavior = Behaviors.Slider
        watch = scroll_handler
        size = calcBarSize(cls, axis)
      }
    }


    local min = 0
    local max = contentSize - elemSize
    local fValue = scrollPos

    local color = ("colorCalc" in knobClass) ? knobClass.colorCalc(stateFlags.value) 
                  : ("color" in knobClass) ? knobClass.color
                  : null

    local knob = class extends knobClass {
      size = [flex(elemSize), flex(elemSize)]
      color = color
      key = "knob"
    }


    local cls = resolveBarClass(barClass, true)
    return class extends cls {
      key = scroll_handler
      behavior = Behaviors.Slider

      watch = [scroll_handler, stateFlags]
      fValue = fValue

      knob = knob
      min = min
      max = max
      unit = 1

      flow = axis==0 ? FLOW_HORIZONTAL : FLOW_VERTICAL
      halign = HALIGN_CENTER
      valign = VALIGN_MIDDLE

      orientation = orientation
      size = calcBarSize(cls, axis)

      children = [
        {size=[flex(fValue), flex(fValue)]}
        knob
        {size=[flex(max-fValue), flex(max-fValue)]}
      ]

      onChange = function(val) {
        if (axis == 0) {
          scroll_handler.scrollToX(val)
        } else {
          scroll_handler.scrollToY(val)
        }
      }

      onElemState = @(sf) stateFlags.update(sf)
    }
  }
}


local makeSideScroll = function(content, options={}) {
  local styling = options.get("styling", defStyling)
  local scrollHandler = options.get("scrollHandler") || ::ScrollHandler()
  local rootBase = options.get("rootBase", styling.ContentRoot)

  local contentRoot = function() {
    local bhv = ("behavior" in rootBase) ? rootBase.behavior : []
    if (typeof(bhv)!="array")
      bhv = [bhv]
    bhv.extend([Behaviors.WheelScroll, Behaviors.ScrollEvent])

    return class extends rootBase {
      behavior = bhv
      scrollHandler = scrollHandler

      children = content
    }
  }

  return {
    size = flex()
    flow = (options.orientation==O_VERTICAL) ? FLOW_HORIZONTAL : FLOW_VERTICAL
    clipChildren = true
    children = [
      contentRoot
      scrollbar(scrollHandler, options)
    ]
  }
}


local makeVertScroll = function(content, options={}) {
  local o = clone options
  o.orientation <- O_VERTICAL
  return makeSideScroll(content, o)
}


local makeHorizScroll = function(content, options={}) {
  local o = clone options
  o.orientation <- O_HORIZONTAL
  return makeSideScroll(content, o)
}


return {
  styling = defStyling
  scrollbar = scrollbar
  makeHorizScroll = makeHorizScroll
  makeVertScroll = makeVertScroll
}
