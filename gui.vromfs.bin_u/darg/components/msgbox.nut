local defStyling = require("msgbox.style.nut")
local frp = require("daRg/frp.nut")

local widgets = Watched([])


local function addWidget(w) {
  widgets.value.append(w)
  widgets.trigger()
}


local function removeWidget(w) {
  local idx = widgets.value.find(w)
  if (idx != null) {
    widgets.value.remove(idx)
    widgets.trigger()
  }
}

local function removeByUid(uid) {
  foreach(idx, w in widgets.value)
    if (w.uid == uid) {
      widgets.value.remove(idx)
      widgets.trigger()
      break
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
local counter = 0
local function show(params, styling=defStyling) {
  local self = null
  local function doClose(button_action) {
    removeWidget(self)
    if (button_action)
      button_action()
    if ("onClose" in params && params.onClose)
      params.onClose()
  }
  local uid = params?.uid ?? "msgbox_" + counter++
  removeByUid(uid)

  local btnsDesc = params?.buttons || [{text="OK"}]
  if (!(btnsDesc instanceof Watched))
    btnsDesc = Watched(btnsDesc)

  local defCancel = null
  local curBtnIdx = frp.map(btnsDesc, function(btns) {
    local res = 0
    foreach (idx, bd in btnsDesc.value) {
      if (bd?.isCurrent)
        res = idx
      if (bd?.isCancel)
        defCancel = bd
    }
    return res
  })

  local function buttonsBlock() {
    return {
      watch = [curBtnIdx, btnsDesc]
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL

      children = btnsDesc.value.map(function(desc) {
        return styling.button(desc, @() doClose(desc?.action))
      })
      behavior = Behaviors.RecalcHandler

      onRecalcLayout = function(elem, initial) {
        if (initial) {
          ::set_kb_focus(btnsDesc.value[curBtnIdx.value])
        }
      }
    }
  }

  local function moveBtnFocus(dir) {
    curBtnIdx.update((curBtnIdx.value + dir + btnsDesc.value.len()) % btnsDesc.value.len())
    ::set_kb_focus(btnsDesc.value[curBtnIdx.value])
  }

  self = styling.BgOverlay.__merge({
    uid = uid
    cursor = styling.cursor
    stopHotkeys = true
    stopHover = true

    children = styling.Root.__merge({
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
    })
  })

  addWidget(self)

  return self
}


local msgbox = {
  show = show
  widgets = widgets
  styling = defStyling
}

return msgbox
