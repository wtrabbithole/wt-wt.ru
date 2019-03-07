local list = Watched([])

local WND_PARAMS = {
  key = null //generate automatically when not set
  children= null
  onClick = null //remove current modal window when not set

  size = flex()
  behavior = Behaviors.Button
  stopMouse = true

  animations = [
    { prop=AnimProp.opacity, from=0.0, to=1.0, duration=0.3, play=true, easing=OutCubic }
    { prop=AnimProp.opacity, from=1.0, to=0.0, duration=0.25, playFadeOut=true, easing=OutCubic }
  ]
}

local function remove(key) {
  foreach(idx, wnd in list.value)
    if (wnd.key == key) {
      list.value.remove(idx)
      list.trigger()
      return true
    }
  return false
}

local lastWndIdx = 0
local function add(wnd = WND_PARAMS) {
  wnd = WND_PARAMS.__merge(wnd)
  if (wnd.key != null)
    remove(wnd.key)
  else
    wnd.key = "modal_wnd_" + lastWndIdx++
  wnd.onClick = wnd.onClick ?? @() remove(wnd.key)
  list.value.append(wnd)
  list.trigger()
}

return {
  list = list
  add = add
  remove = remove

  hideAll = @() list([])

  component = @() {
    watch = list
    size = flex()
    children = list.value
  }
}