local queuedActivate = null
local activeTooltip = Watched(null)


local onHover = @(ttobj, delay) function(elem, hover_on) {
  if (queuedActivate) {
    ::gui_scene.clearTimer(queuedActivate)
    queuedActivate = null
  }

  if (hover_on) {
    if (delay <= 0) {
      activeTooltip.update(@() ttobj)
    } else {
      queuedActivate = @() activeTooltip.update(@() ttobj)
      ::gui_scene.setTimeout(delay, queuedActivate)
    }
  } else {
    activeTooltip.update(null)
  }
}


local textTooltip = function(text, width) {
  local f = null
  f = function() {
    if (f == activeTooltip.value) {
      return {
        watch = activeTooltip
        zOrder = Layers.Tooltip
        halign = HALIGN_CENTER
        size = flex()
        flow = FLOW_VERTICAL

        children = [
          {size = [0, ph(100)]}
          {size = [0, sh(1)]}
          {
            rendObj = ROBJ_SOLID
            color = Color(20,20,50,180)
            size = SIZE_TO_CONTENT
            padding = sh(1)

            children = {
              rendObj = ROBJ_TEXTAREA
              behavior = Behaviors.TextArea
              maxContentWidth = width
              size = SIZE_TO_CONTENT
              text = text
            }
            animations = [
              { prop=AnimProp.opacity, from=0, to=1, duration=0.2, easing=InOutCubic, play=true}
              { prop=AnimProp.opacity, from=1, to=0, duration=0.2, easing=InOutCubic, playFadeOut=true}
            ]
          }
        ]
      }
    } else {
      return {
        watch = activeTooltip
      }
    }
  }

  return f
}


local addToArr = function(obj, field, value) {
  if ((field in obj) && obj[field]!=null) {
    local arr = (type(obj[field]) == "array") ? obj[field] : [obj[field]]
    arr.append(value)
    return arr
  } else {
    return [value]
  }
}


local setupTooltip = function(comp_desc, ttip, delay, mount) {
  if (!ttip)
    return comp_desc

  return function() {
    local res = comp_desc
    if (type(res) == "function")
      res = res()

    if (mount)
      res.children <- addToArr(res, "children", ttip)

    res.onHover <- onHover(ttip, delay)

    return res
  }
}


local onShutdown = function() {
  activeTooltip = null
}


return {
  setupTooltip = setupTooltip
  textTooltip = textTooltip
  onShutdown = onShutdown
}
