local defStyling = require("msgbox.style.nut")


local widgets = Watched([])


local addWidget = function(w) {
  widgets.value.append(w)
  widgets.trigger()
}


local removeWidget = function(w) {
  local idx = widgets.value.find(w)
  if (idx != null) {
    widgets.value.remove(idx)
    widgets.trigger()
  }
}


/// Adds messagebox to widgets list
/// params = {
///   text = 'message text'
///   onClose = function() {} // optional close event callback
///   buttons = [   // array
///      {
///         text = 'button_caption'
///         action = function() {} // click handler
///         isCurrent = false // flag for focused button
///         isCancel = false // flag for button activated by Esc
///      }
///      ...
///   ]
///
local show = function(params, styling=defStyling) {
  local self = null

  local doClose = function(button_action) {
    removeWidget(self)
    if (button_action)
      button_action()
    if ("onClose" in params)
      params.onClose()
  }

  local btnsDesc = params?.buttons || [{text="OK"}]
  local curBtnIdx = Watched(0)
  local defCancel = null

  foreach (idx, bd in btnsDesc) {
    if (bd?.isCurrent)
      curBtnIdx.update(idx)
    if (bd?.isCancel)
      defCancel = bd
  }


  local buttons = btnsDesc.map(function(desc) {
    return styling.button(desc, @() doClose(desc?.action))
  })

  local buttonsBlock = function() {
    return {
      watch = curBtnIdx
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL

      children = buttons

      behavior = Behaviors.RecalcHandler

      onRecalcLayout = function(elem, initial) {
        if (initial) {
          ::set_kb_focus(btnsDesc[curBtnIdx.value])
        }
      }
    }
  }


  local moveBtnFocus = function(dir) {
    curBtnIdx.update((curBtnIdx.value + dir + btnsDesc.len()) % btnsDesc.len())
    ::set_kb_focus(btnsDesc[curBtnIdx.value])
  }

  self = class extends styling.BgOverlay {
    cursor = styling.cursor
    stopHotkeys = true
    stopHover = true

    children = class extends styling.Root {
      flow = FLOW_VERTICAL
      halign = HALIGN_CENTER
      children = [
        styling.messageText(params)
        buttonsBlock
      ]

      hotkeys = [
        ["Esc", @() doClose(defCancel?.action)],
        ["Right | Tab", @() moveBtnFocus(1)],
        ["Left", @() moveBtnFocus(-1)],
      ]
    }
  }

  addWidget(self)

  return self
}


local msgbox = {
  show = show
  widgets = widgets
  styling = defStyling
}

return msgbox
