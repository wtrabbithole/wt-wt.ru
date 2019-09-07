local comboStyle = require("combobox.style.nut")


local function combobox(watches, options, combo_style=comboStyle) {
  local comboOpen = ::Watched(false)
  local group = ::ElemGroup()
  local stateFlags = ::Watched(0)
  local doClose = @() comboOpen.update(false)
  local wdata, wdisable
  local dropDirDown = combo_style?.dropDir != "up"

  if (type(watches) == "table") {
    wdata = watches.value
    wdisable = watches.disable
  } else {
    wdata = watches
    wdisable = {value=false}
  }

  local function dropdownList() {
    local children = options.map(function(item) {
      local value
      local text
      local isCurrent
      local tp = type(item)

      if (tp == "array") {
        value = item[0]
        text  = item[1]
        isCurrent = wdata.value==value
      } else if (tp == "instance") {
        value = item.value()
        text  = item.tostring()
        isCurrent = item.isCurrent()
      } else {
        value = item
        text = value.tostring()
        isCurrent = wdata.value==value
      }

      local function handler() {
        wdata.update(value)
        comboOpen.update(false)
      }
      return combo_style.listItem(text, handler, isCurrent)
    })


    local overlay = {
      pos = [-9000, -9000]
      size = [19999, 19999]
      behavior = Behaviors.ComboPopup
      eventPassThrough = true

      onClick = doClose
    }

    local baseButtonOverride = combo_style.closeButton(doClose)

    local popupContent = {
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_BOX
      fillColor = combo_style?.popupBgColor ?? Color(10,10,10)
      borderColor = combo_style?.popupBdColor ?? Color(80,80,80)
      borderWidth = combo_style?.popupBorderWidth ?? 0
      padding = combo_style?.popupBorderWidth ?? 0
      flow = FLOW_VERTICAL
      stopMouse = true
      clipChildren = true

      children = children
      gap = combo_style?.itemGap

      transform = {
        pivot = [0.5, dropDirDown ? 0 : 1]
      }
      animations = [
        { prop=AnimProp.opacity, from=0, to=1, duration=0.12, play=true, easing=InOutQuad }
        { prop=AnimProp.scale, from=[1,0], to=[1,1], duration=0.12, play=true, easing=InOutQuad }
      ]
    }

    local popupWrapper = {
      size = flex()
      flow = FLOW_VERTICAL
      vplace = dropDirDown ? VALIGN_TOP : VALIGN_BOTTOM
      valign = dropDirDown ? VALIGN_TOP : VALIGN_BOTTOM
      //rendObj = ROBJ_SOLID
      //color = Color(0,100,0,50)
      children = [
        {size = [flex(), ph(100)]}
        {size = [flex(), 2]}
        popupContent
      ]
    }

    if (!dropDirDown) {
      popupWrapper.children.reverse()
    }

    return {
      zOrder = Layers.ComboPopup
      size = flex()
      children = [
        overlay
        baseButtonOverride
        popupWrapper
      ]
      transform = { pivot=[0.5, dropDirDown ? 1.1 : -0.1]}
      animations = [
        { prop=AnimProp.opacity, from=1, to=0, duration=0.15, playFadeOut=true}
        { prop=AnimProp.scale, from=[1,1], to=[1,0], duration=0.15, playFadeOut=true, easing=OutQuad}
      ]
    }
  }

  local function combo() {
    local curValue = wdata.value
    local labelText = curValue!=null ? curValue.tostring() : ""
    foreach (item in options) {
      local tp = type(item)
      if (tp == "array") {
        if (item[0] == curValue) { labelText = item[1]; break }
      } else if (tp == "instance") {
        if (item.isCurrent()) { labelText = item.tostring(); break }
      } else if (item == curValue)
        break
    }
    local sf = stateFlags.value

    local children = (combo_style?.rootCtor !=null) ?
      [
        combo_style?.rootCtor({group=group, stateFlags=stateFlags, disabled=wdisable.value, comboOpen=comboOpen, text=labelText})
      ]
    :
      [
        combo_style.label(labelText, group, {disabled=wdisable.value})
      ]

    if (comboOpen.value && !wdisable.value) {
      children.append(dropdownList)
    }

    local clickHandler = wdisable.value ? null : @() comboOpen.update(!comboOpen.value)

    local desc = (combo_style?.root ?? {}).__update({
      size = flex()
      //behavior = wdisable.value ? null : Behaviors.Button
      behavior = Behaviors.Button
      watch = [comboOpen, watches?.disable]
      group = group
      onElemState=@(sf) stateFlags(sf)

      children = children
      onClick = wdisable.value ? null : clickHandler
    })

    return desc
  }

  return combo
}


return combobox
