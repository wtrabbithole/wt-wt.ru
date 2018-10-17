local function label(text, group, params=null) {
  local color = params?.disabled ? Color(160,160,160,255) : Color(255,255,255,255)

  local labelText = {
    group = group
    rendObj = ROBJ_DTEXT
    behavior = Behaviors.Marquee
    margin = sh(0.5)
    text = text
    key = text
    color = color
    size = [flex(), SIZE_TO_CONTENT]
  }.__update(params?.rootParams ?? {})

  local function popupArrow() {
    return {
      rendObj = ROBJ_DTEXT
      text = "V"
      margin = sh(0.25)
      color = color
    }.__update(params?.popArrow ?? {})
  }

  return {
    size = flex()
    flow = FLOW_HORIZONTAL
    valign = VALIGN_MIDDLE
    children = [
      labelText
      popupArrow
    ]
  }.__update(params?.label ?? {})
}


local function listItem(text, action, is_current, params={}) {
  local group = ::ElemGroup()
  local stateFlags = ::Watched(0)

  return function() {
    local textColor
    if (is_current)
      textColor = Color(255,255,255)
    else
      textColor = (stateFlags.value & S_HOVER) ? Color(255,255,255) : Color(120,150,160)

    return {
      behavior = [Behaviors.Button,Behaviors.Marquee]
      size = [flex(), SIZE_TO_CONTENT]
      group = group
      watch = stateFlags

      onClick = action
      onElemState = @(sf) stateFlags.update(sf)

      children = {
        rendObj = ROBJ_DTEXT
        margin = sh(0.5)
        text = text
        group = group
      }.__update(params?.listItemText ?? {})
    }.__update(params?.listItem ?? {})
  }
}


local function closeButton(action) {
  return {
    size = flex()
    behavior = Behaviors.Button
    onClick = action
    rendObj = ROBJ_FRAME
    borderWidth = 1
    color = Color(250,200,50,200)
  }
}


return {
  popupBgColor = Color(20, 30, 36)
  popupBdColor = Color(90,90,90)
  popupBorderWidth = hdpx(1)
  itemGap = {rendObj=ROBJ_FRAME size=[flex(),hdpx(1)] color=Color(90,90,90)}

  root = {}
  label = label
  listItem = listItem
  closeButton = closeButton
}
