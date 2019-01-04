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


local function resolveBarClass(bar, has_scroll) {
  if (type(bar) == "function") {
    return bar(has_scroll)
  }
  return bar
}

local function calcBarSize(bar_class, axis) {
  return (axis==0) ? [flex(), bar_class._height] : [bar_class._width, flex()]
}


local function scrollbar(scroll_handler, options={}) {
  local stateFlags = ::Watched(0)
  local styling   = options?.styling ?? defStyling
  local barClass  = options?.barStyle ?? styling.Bar
  local knobClass = options?.knobStyle ?? styling.Knob

  local orientation = options?.orientation ?? O_VERTICAL
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

      children = ("hoverChild" in knobClass) ? knobClass.hoverChild(stateFlags.value) : null
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

local DEF_SIDE_SCROLL_OPTIONS = { //const
  styling = defStyling
  rootBase = null
  scrollAlign = HALIGN_RIGHT
  orientation = O_VERTICAL
}

local function makeSideScroll(content, options = DEF_SIDE_SCROLL_OPTIONS) {
  options = DEF_SIDE_SCROLL_OPTIONS.__merge(options)

  local styling = options.styling
  local scrollHandler = options?.scrollHandler ?? ::ScrollHandler()
  local rootBase = options.rootBase ?? styling.ContentRoot
  local scrollAlign = options.scrollAlign

  local function contentRoot() {
    local bhv = ("behavior" in rootBase) ? rootBase.behavior : []
    if (typeof(bhv)!="array")
      bhv = [bhv]
    bhv.extend([Behaviors.WheelScroll, Behaviors.ScrollEvent])

    return class extends rootBase {
      behavior = bhv
      scrollHandler = scrollHandler
      orientation = options.orientation
      joystickScroll = true

      children = content
    }
  }

  local childrenContent = []
  if (scrollAlign == HALIGN_LEFT || scrollAlign == VALIGN_TOP)
    childrenContent = [
      scrollbar(scrollHandler, options)
      contentRoot
    ]
  else
    childrenContent = [
      contentRoot
      scrollbar(scrollHandler, options)
    ]

  return {
    size = flex()
    flow = (options.orientation == O_VERTICAL) ? FLOW_HORIZONTAL : FLOW_VERTICAL
    clipChildren = true

    children = childrenContent
  }
}


local function makeHVScrolls(content, options={}) {
  local styling = options?.styling ?? defStyling
  local scrollHandler = options?.scrollHandler ?? ::ScrollHandler()
  local rootBase = options?.rootBase ?? styling.ContentRoot

  local function contentRoot() {
    local bhv = ("behavior" in rootBase) ? rootBase.behavior : []
    if (typeof(bhv)!="array")
      bhv = [bhv]
    bhv.extend([Behaviors.WheelScroll, Behaviors.ScrollEvent])

    return class extends rootBase {
      behavior = bhv
      scrollHandler = scrollHandler
      joystickScroll = true

      children = content
    }
  }

  return {
    size = flex()
    flow = FLOW_VERTICAL

    children = [
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        clipChildren = true
        children = [
          contentRoot
          scrollbar(scrollHandler, options.__merge({orientation=O_VERTICAL}))
        ]
      }
      scrollbar(scrollHandler, options.__merge({orientation=O_HORIZONTAL}))
    ]
  }
}


local function makeVertScroll(content, options={}) {
  local o = clone options
  o.orientation <- O_VERTICAL
  o.scrollAlign <- o?.scrollAlign ?? HALIGN_RIGHT
  return makeSideScroll(content, o)
}


local function makeHorizScroll(content, options={}) {
  local o = clone options
  o.orientation <- O_HORIZONTAL
  o.scrollAlign <- o?.scrollAlign ?? VALIGN_BOTTOM
  return makeSideScroll(content, o)
}


return {
  styling = defStyling
  scrollbar = scrollbar
  makeHorizScroll = makeHorizScroll
  makeVertScroll = makeVertScroll
  makeHVScrolls = makeHVScrolls
  makeSideScroll = makeSideScroll
}
