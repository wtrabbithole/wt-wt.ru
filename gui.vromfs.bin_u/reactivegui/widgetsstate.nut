local state = persist("widgetsState", @() {
  widgets = Watched([])
})


::interop.updateWidgets <- function (widget_list) {
  state.widgets.value.clear()

  if(!widget_list)
  {
    state.widgets.trigger()
    return
  }

  state.widgets.update(widget_list)
}


return state