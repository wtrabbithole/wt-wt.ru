local styling = ::with_table({}, function() {
  cursor = null


  Root = class {
    rendObj = ROBJ_SOLID
    color = Color(50,50,50,50)
    size = [sw(100), sh(50)]
    vplace = VALIGN_MIDDLE
  }


  BgOverlay = class {
    rendObj = ROBJ_SOLID
    size = [sw(100), sh(100)]
    color = Color(20, 20, 20, 150)
    behavior = Behaviors.Button
  }


  button = function(desc, on_click) {
    local buttonGrp = ::ElemGroup()

    return {
      key = desc
      behavior = Behaviors.Button
      group = buttonGrp

      rendObj = ROBJ_SOLID
      color = Color(0, 0, 100, 150)
      size = SIZE_TO_CONTENT
      margin = [sh(0.5), sh(1)]

      children = {
        rendObj = ROBJ_STEXT
        margin = sh(1)
        text = desc?.text ?? "???"
        group = buttonGrp
      }

      onClick = on_click
    }
  }


  messageText = function(params) {
    return {
      size = flex()
      halign = HALIGN_CENTER
      valign = VALIGN_MIDDLE
      padding = [sh(2), 0]
      children = {
        rendObj = ROBJ_STEXT
        text = params?.text
      }
    }
  }

})


return styling
