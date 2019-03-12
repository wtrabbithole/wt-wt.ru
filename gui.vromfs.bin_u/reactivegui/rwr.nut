local screenState = require("style/screenState.nut")

local rwrState = {
  arrowState = [
    Watched(false),
    Watched(false),
    Watched(false),
    Watched(false),
    Watched(false),
    Watched(false),
    Watched(false),
    Watched(false)
  ]
}


::interop.updateArrowState <- function(index, isActive)
{
  rwrState.arrowState[index].update(isActive)
}


local rwrIndicatorWidth = hdpx(66)

local createArrow = function(line_style, width) {
  local arrBaseWidthHalf = 15
  local arrWidthHalf = 30
  local arrHeight = 40

  return line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    commands = [
      [VECTOR_LINE, 50, 0, 50 - arrWidthHalf, arrHeight],
      [VECTOR_LINE, 50 - arrWidthHalf, arrHeight, 50 - arrBaseWidthHalf, arrHeight],
      [VECTOR_LINE, 50 - arrBaseWidthHalf, arrHeight, 50 - arrBaseWidthHalf, 100],
      [VECTOR_LINE, 50 - arrBaseWidthHalf, 100, 50 + arrBaseWidthHalf, 100],
      [VECTOR_LINE, 50 + arrBaseWidthHalf, 100, 50 + arrBaseWidthHalf, arrHeight],
      [VECTOR_LINE, 50 + arrBaseWidthHalf, arrHeight, 50 + arrWidthHalf, arrHeight],
      [VECTOR_LINE, 50 + arrWidthHalf, arrHeight, 50, 0]
    ]
  })
}


local createLabel = function(line_style) {
  return line_style.__merge({
    rendObj = ROBJ_STEXT
    size = SIZE_TO_CONTENT
    text = ::loc("radar")
  })
}

local defArrowsParams = {
  arrowPlaceOveride = {}
  arrowRotation = 180.0
  labelOveride = {}
  arrowOveride = {}
  isLabelFirst = false
}

local createIndicator = function(line_style, stateWatched, arrowsParams = defArrowsParams) {
  arrowsParams = defArrowsParams.__merge(arrowsParams)
  local arrowChildren = [{
      transform = {
        pivot = [0.5, 0.5]
        rotate = arrowsParams.arrowRotation
      }
      children = createArrow(line_style, rwrIndicatorWidth)
    },
    {
      children = createLabel(line_style)
    }.__update(arrowsParams.labelOveride)
  ]

  if (arrowsParams.isLabelFirst)
    arrowChildren.reverse()

  return @() {
    size = flex()
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    watch = stateWatched
    opacity = stateWatched.value ? 100 : 0
    children = [
      {
        size = [rwrIndicatorWidth, rwrIndicatorWidth]
        halign = HALIGN_LEFT
        valign = VALIGN_BOTTOM
        flow = FLOW_VERTICAL
        children = arrowChildren
      }.__update(arrowsParams.arrowOveride)
    ]
  }.__update(arrowsParams.arrowPlaceOveride)
}


local rwrComponent = function(line_style) {
  local gap = hdpx(5)

  return {
    size = [sw(100), sh(100)]
    padding = screenState.safeAreaSizeHud.value.borders
    children = [
      createIndicator(line_style, rwrState.arrowState[0],
        {
          arrowPlaceOveride = { halign = HALIGN_CENTER, valign = VALIGN_TOP }
          arrowRotation = 180.0,
          labelOveride = { margin = [0.2 * rwrIndicatorWidth, 0] }
          arrowOveride = {
            flow = FLOW_HORIZONTAL
            valign = VALIGN_TOP
            margin = [::dp(36) + ::scrn_tgt(0.2), 0]
          }
        }
      ),
      createIndicator(line_style, rwrState.arrowState[1],
        {
          arrowPlaceOveride = { halign = HALIGN_RIGHT, valign = VALIGN_TOP }
          arrowRotation = 180.0 + 45.0
          arrowOveride = { valign = VALIGN_TOP }
        }
      ),
      createIndicator(line_style, rwrState.arrowState[2],
        {
          arrowPlaceOveride = { halign = HALIGN_RIGHT, valign = VALIGN_MIDDLE }
          arrowRotation = 270.0
        }
      ),
      createIndicator(line_style, rwrState.arrowState[3],
        {
          arrowPlaceOveride = { halign = HALIGN_RIGHT, valign = VALIGN_BOTTOM }
          arrowRotation = 360.0 - 45.0,
          arrowOveride = { valign = VALIGN_BOTTOM }
          isLabelFirst = true
        }
      ),
      createIndicator(line_style, rwrState.arrowState[4],
        {
          arrowPlaceOveride = { halign = HALIGN_CENTER, valign = VALIGN_BOTTOM }
          arrowRotation = 0.0
          arrowOveride = { flow = FLOW_HORIZONTAL }
          labelOveride = { margin = [0.2 * rwrIndicatorWidth, 0] }
        }
      ),
      createIndicator(line_style, rwrState.arrowState[5],
        {
          arrowPlaceOveride = { halign = HALIGN_LEFT, valign = VALIGN_BOTTOM }
          arrowRotation = 45.0,
          arrowOveride = { halign = HALIGN_RIGHT, valign = VALIGN_BOTTOM }
          isLabelFirst = true
        }
      ),
      createIndicator(line_style, rwrState.arrowState[6],
        {
          arrowPlaceOveride = { halign = HALIGN_LEFT, valign = VALIGN_MIDDLE }
          arrowRotation = 90.0
          arrowOveride = { halign = HALIGN_RIGHT }
        }
      ),
      createIndicator(line_style, rwrState.arrowState[7],
        {
          arrowPlaceOveride = { halign = HALIGN_LEFT, valign = VALIGN_TOP }
          arrowRotation = 90.0 + 45.0,
          arrowOveride = { halign = HALIGN_RIGHT, valign = VALIGN_TOP }
        }
      )
    ]
  }
}


return rwrComponent
