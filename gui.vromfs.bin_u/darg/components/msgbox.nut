local defStyling = require("msgbox.style.nut")

local widgets = persist("widgest", @() ::Watched([]))


local function addWidget(w) {
  widgets.value.append(w)
  widgets.trigger()
}


local function removeWidget(w) {
  local idx = widgets.value.indexof(w)
  if (idx != null) {
    widgets.update(@(value) value.remove(idx))
  }
}

local function removeByUid(uid) {
  foreach(idx, w in widgets.value)
    if (w.uid == uid) {
      widgets.update(@(value) value.remove(idx))
      break
    }
}

local function isInList(uid) {
  return widgets.value.findindex(@(w) w.uid == uid)
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
local buttonsBlockId = 0
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
  counter++
  local uid = params?.uid ?? ("msgbox_{0}".subst(counter))
  removeByUid(uid)

  local skip = {skip=true}
  local skpdescr = {description = skip}
  local btnsDesc = params?.buttons || [{text="OK" customStyle={hotkeys=[["^Esc | Enter", skpdescr]]}}]
  if (!(btnsDesc instanceof ::Watched))
    btnsDesc = ::Watched(btnsDesc)
  btnsDesc.update(function(v){
    if (v.len()==1)
      v[0].isCurrent <- true
  })
  local defCancel = null
  local curBtnIdx = ::Watched(function(){
    local res = 0
    foreach (idx, bd in btnsDesc.value) {
      if (bd?.isCurrent)
        res = idx
      if (bd?.isCancel)
        defCancel = bd
    }
    return res
  }())

  local function moveBtnFocus(dir) {
    curBtnIdx.update((curBtnIdx.value + dir + btnsDesc.value.len()) % btnsDesc.value.len())
    ::set_kb_focus(btnsDesc.value[curBtnIdx.value])
  }
  local function activateCurBtn() {
    btnsDesc.value[curBtnIdx.value]?.action?() ?? doClose(defCancel?.action, true)
  }
  local function buttonsBlock(key) {
    return @() {
      watch = [curBtnIdx, btnsDesc]
      key = key
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      gap = hdpx(40)

      children = btnsDesc.value.map(function(desc, idx) {
        local conHover = desc?.onHover
        local onHover = function(on){
          curBtnIdx.update(idx)
          ::set_kb_focus(btnsDesc.value[curBtnIdx.value])
          conHover?()
        }
        local customStyle = (desc?.customStyle ?? {}).__merge({onHover=onHover})
        return styling.button(desc.__update({customStyle = customStyle}), @() doClose(desc?.action))
      })
      behavior = Behaviors.RecalcHandler

      onRecalcLayout = function(initial) {
        if (initial)
          ::set_kb_focus(btnsDesc.value[curBtnIdx.value])
      }

      hotkeys = [
        [styling?.closeKeys ?? "Esc", {action= @() doClose(defCancel?.action, true), description = ::loc("Close")}],
        [styling?.rightKeys ?? "Right | Tab", {action = @() moveBtnFocus(1) description = skip}],
        [styling?.leftKeys ?? "Left", {action = @() moveBtnFocus(-1) description = skip}],
        [styling?.activateKeys ?? "Space | Enter", {action= activateCurBtn, description= skip}],
        [styling?.maskKeys ?? "", {action = @() null, description = skip}]
      ]
    }
  }
  buttonsBlockId++
  local root = styling.Root.__merge({
    key = "msgbox_{0}".subst(uid)
    flow = FLOW_VERTICAL
    halign = HALIGN_CENTER
    children = [
      styling.messageText(params.__merge({ doClose = doClose }))
      buttonsBlock("buttonsBlock_{0}".subst(buttonsBlockId))
    ]
  })
  self = styling.BgOverlay.__merge({
    uid = uid
    cursor = styling.cursor
    stopMouse = true
    children = styling.BgOverlay?.children ? [styling.BgOverlay.children, root] : root
  })

  addWidget(self)

  return self
}


local msgbox = {
  show = show
  widgets = widgets
  isInList = isInList
  removeByUid = removeByUid
  styling = defStyling
}

return msgbox
