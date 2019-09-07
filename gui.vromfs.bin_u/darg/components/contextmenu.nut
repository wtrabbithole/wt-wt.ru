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
  stopMouse = true
  behavior = Behaviors.Button

  onClick = closeMenu
}



local function contextMenu(x, y, width, actions, menu_style = style) {
  local listItem = menu_style?.listItem ?? style.listItem
  local menuBgColor = menu_style?.menuBgColor ?? style.menuBgColor
  local closeHotkeys = menu_style?.closeHotkeys ?? [ ["Esc", closeMenu] ]
  local function defMenuCtor(){
    return {
      rendObj = ROBJ_SOLID
      size = [width, SIZE_TO_CONTENT]
      pos = [x, y]
      flow = FLOW_VERTICAL
      color = menuBgColor
      safeAreaMargin = [sh(2), sh(2)]
      transform = {}
      behavior = Behaviors.BoundToArea

      hotkeys = closeHotkeys
      children = actions.map(@(item) menu_style.listItem(item.text, wrapAction(item.action)))
    }
  }
  local menuCtor = menu_style?.menuCtor ?? defMenuCtor

  local menu = menuCtor()

  local holder = {
    zOrder = Layers.Tooltip
    size = flex()
    children = [
      overlay
      menu
    ]
  }
  ::set_kb_focus(null)
  currentContextMenu.value.append(holder)
  currentContextMenu.trigger()
}


return {
  contextMenu = contextMenu
  widgets = currentContextMenu
}
