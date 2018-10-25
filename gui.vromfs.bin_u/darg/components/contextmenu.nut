local style = require("contextMenu.style.nut")

local currentContextMenu = Watched([])

local function closeMenu () {
  currentContextMenu.update([])
}


local wrapAction = @(action) function () {
  action()
  closeMenu()
}


local overlay = {
  pos = [-9000, -9000]
  size = [19999, 19999]
  stopHover = true
  behavior = Behaviors.Button

  onClick = closeMenu
}


local function contextMenu(x, y, width, actions, menu_style = style) {
  local menu = {
    rendObj = ROBJ_SOLID
    size = [width, SIZE_TO_CONTENT]
    pos = [x, y]
    flow = FLOW_VERTICAL
    color = menu_style.menuBgColor

    children = actions.map(@(item) menu_style.listItem(item.text, wrapAction(item.action)))
  }

  local holder = {
    zOrder = Layers.Tooltip
    size = flex()
    children = [
      overlay
      menu
    ]
  }
  currentContextMenu.value.append(holder)
  currentContextMenu.trigger()
}


return {
  contextMenu = contextMenu
  widgets = currentContextMenu
}
