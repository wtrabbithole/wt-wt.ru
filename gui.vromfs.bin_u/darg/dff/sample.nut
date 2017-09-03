return {
  rendObj = ROBJ_SOLID
  color = Color(30,40,50)
  cursor = cursors.normal
  halign = HALIGN_LEFT
  valign = VALIGN_MIDDLE
  flow = FLOW_HORIZONTAL
  children =
    elem({flow = FLOW_VERTICAL
        padding = sh(10)
        size = flex()
      }
      elem({}, text(1), text(2), text(3), 
          elem({margin=10 gap=10}, 
            text("a")
            text("b")
            text("c",{color=_Color.red})))
   )
}
