local comboStyle = {}

::with_table(comboStyle, function() {
  font = 0

  popupBgColor = Color(20, 30, 36)

  Root = class {}

  label = function(text, group, params=null) {
    local color = params?.disabled ? Color(160,160,160,255) : Color(255,255,255,255)
    local labelText = {
      group = group
      rendObj = ROBJ_STEXT
      margin = sh(0.5)
      text = text
      color = color
      size = [flex(), SIZE_TO_CONTENT]
    }

    local popupArrow = function() {
      return {
        rendObj = ROBJ_STEXT
        text = "V"
        margin = sh(0.25)
        color = color
      }
    }

    return {
      size = flex()
      flow = FLOW_HORIZONTAL
      valign = VALIGN_MIDDLE
      children = [
        labelText
        popupArrow
      ]
    }
  }


  listItem = function(text, action, is_current) {
    local group = ::ElemGroup()
    local stateFlags = ::Watched(0)

    return function() {
      local textColor
      if (is_current)
        textColor = Color(255,255,255)
      else
        textColor = (stateFlags.value & S_HOVER) ? Color(255,255,255) : Color(120,150,160)

      return {
        behavior = Behaviors.Button
        size = [flex(), SIZE_TO_CONTENT]
        group = group
        watch = stateFlags

        onClick = action
        onElemState = @(sf) stateFlags.update(sf)

        children = {
          rendObj = ROBJ_STEXT
          margin = sh(0.5)
          text = text
          group = group
        }
      }
    }
  }


  closeButton = function(action) {
    return {
      size = flex()
      behavior = Behaviors.Button
      onClick = action
      rendObj = ROBJ_FRAME
      borderWidth = 1
      color = Color(250,200,50,200)
    }
  }
})


return comboStyle
