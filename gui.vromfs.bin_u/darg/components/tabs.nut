local function defTab(tab_item, is_current, handler) {
  local grp = ::ElemGroup()
  local stateFlags = ::Watched(0)

  return function () {
    local isHover = (stateFlags.value & S_HOVER)
    local fillColor, textColor, borderColor
    if (is_current) {
      textColor = isHover ? Color(255, 255,255) : Color(0, 255, 0)
      fillColor = isHover ? Color(100, 100, 100) : Color(150, 150, 150)
    } else {
      textColor = isHover ? Color(255, 255, 255) : Color(255, 255, 0)
      fillColor = isHover ? Color(100, 100, 100) : Color(50, 50, 50)
    }

    return {
      key = tab_item
      rendObj = ROBJ_SOLID
      halign = HALIGN_CENTER
      valign = VALIGN_MIDDLE
      size = SIZE_TO_CONTENT
      watch = stateFlags
      group = grp

      color = fillColor

      behavior = Behaviors.Button
      onElemState = @(sf) stateFlags.update(sf)

      onClick = handler

      children = {
        rendObj = ROBJ_STEXT
        margin = [sh(1), sh(2)]
        color = textColor

        text = tab_item.text
        group = grp
      }
    }
  }
}


local defHolder = @(){
  rendObj = ROBJ_SOLID
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  padding = [0, sh(1)]
  gap = sh(1)

  color = Color(255, 255, 255)
}


local function tabs(holder, tab) {
  return function(items) {
    local children = items.tabs.map(function(item) {
      return tab(item, item.id == items.currentTab, @() items.onChange(item))
    })

    local result = (typeof holder == "function") ? holder() : holder
    result.children <- extend_to_array(result?.children, children)
    return result
  }
}


local ctor = @(holder = defHolder, tab = defTab) tabs(holder, tab)


return ctor
