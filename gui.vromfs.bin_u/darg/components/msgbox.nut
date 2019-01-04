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
  local function doClose(button_action, isOnEscape = false) {
    if (isOnEscape && params?.onCancel)
      if (params.onCancel() && params?.closeByActionsResult)
        return

    if (button_action && button_action() && params?.closeByActionsResult)
      return

    removeWidget(self)
    if ("onClose" in params && params.onClose)
      params.onClose()
  }
  local uid = params?.uid ?? "msgbox_" + counter++
  removeByUid(uid)

  local skpdescr = {description = {skip=true}}
  local btnsDesc = params?.buttons || [{text="OK" customStyle={hotkeys=[["^Esc | Enter", skpdescr]]}}]
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

      children = btnsDesc.value.map(function(desc, idx) {
        local conHover = desc?.onHover
        local customStyle = desc?.customStyle ?? {}
        local onHover = function(on){
          curBtnIdx.update(idx)
          ::set_kb_focus(btnsDesc.value[curBtnIdx.value])
          conHover?()
        }
        customStyle.__update({onHover=onHover})
        return styling.button(desc.__update({customStyle = customStyle}), @() doClose(desc?.action))
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
  local function activateCurBtn() {
    btnsDesc.value[curBtnIdx.value]?.action?() ?? doClose(defCancel?.action, true)
  }
  local skip = {skip=true}
  self = styling.BgOverlay.__merge({
    uid = uid
    cursor = styling.cursor
    stopMouse = true
    children = styling.Root.__merge({
      key = "msgbox_" + uid
      flow = FLOW_VERTICAL
      halign = HALIGN_CENTER
      children = [
        styling.messageText(params)
        buttonsBlock
      ]
      hotkeys = [
        ["Esc | J:B", {action= @() doClose(defCancel?.action, true), description = ::loc("Close")}],
        ["Right | Tab", {action = @() moveBtnFocus(1) description = skip}],
        ["Left", {action = @() moveBtnFocus(-1) description = skip}],
        ["Enter", {action= activateCurBtn, description= skip}],
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
