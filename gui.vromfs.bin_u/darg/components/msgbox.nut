local frp = require("frp")
local defStyling = require("msgbox.style.nut")

local widgets = persist("widgets", @() [])
local msgboxGeneration = persist("msgboxGeneration", @() Watched(0))

local function getCurMsgbox(){
  if (widgets.len()==0)
    return null
  return widgets.top()
}

local log = ::getroottable()?.log ?? @(...) ::print(" ".join(vargv))

local function addWidget(w) {
  widgets.append(w)
  msgboxGeneration(msgboxGeneration.value+1)
}

local function removeWidget(w) {
  local idx = widgets.indexof(w)
  if (idx == null)
    return
  widgets.remove(idx)
  msgboxGeneration(msgboxGeneration.value+1)
}

local function removeAllMsgboxes() {
  widgets.clear()
  msgboxGeneration(msgboxGeneration.value+1)
}

local function removeMsgboxByUid(uid) {
  local idx = widgets.findindex(@(w) w.uid == uid)
  if (idx == null)
    return
  widgets.remove(idx)
  msgboxGeneration(msgboxGeneration.value+1)
}

local function isMsgboxInList(uid) {
  return widgets.findindex(@(w) w.uid == uid)
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

local skip = {skip=true}
local skpdescr = {description = skip}
local defaultButtons = [{text="OK" customStyle={hotkeys=[["^Esc | Enter", skpdescr]]}}]


local function show(params, styling=defStyling) {
  log($"[MSGBOX] show: text = '{params?.text}'")
  local self = null

  local function doClose() {
    removeWidget(self)
    if ("onClose" in params && params.onClose)
      params.onClose()

    log($"[MSGBOX] closed: text = '{params?.text}'")
  }

  local function handleButton(button_action) {
    if (button_action) {
      if (button_action?.getfuncinfos?().parameters.len()==2) {
        // handler performs closing itself
        button_action({doClose=doClose})
        return // stop processing, handler will do everything what is needed
      }

      button_action()
    }

    doClose()
  }

  local uid = params?.uid ?? {}
  if (params?.uid)
    removeMsgboxByUid(uid)

  local btnsDesc = params?.buttons ?? defaultButtons
  if (!(btnsDesc instanceof ::Watched))
    btnsDesc = ::Watched(btnsDesc, frp.DONT_CHECK_NESTED)

  local defCancel = null
  local initialBtnIdx = 0

  foreach (idx, bd in btnsDesc.value) {
    if (bd?.isCurrent)
      initialBtnIdx = idx
    if (bd?.isCancel)
      defCancel = bd
  }

  local curBtnIdx = ::Watched(initialBtnIdx)

  local function moveBtnFocus(dir) {
    curBtnIdx.update((curBtnIdx.value + dir + btnsDesc.value.len()) % btnsDesc.value.len())
  }

  local function activateCurBtn() {
    log($"[MSGBOX] handling active '{btnsDesc.value[curBtnIdx.value]?.text}' button: text = '{params?.text}'")
    handleButton(btnsDesc.value[curBtnIdx.value]?.action)
  }

  local buttonsBlockKey = {}

  local function buttonsBlock() {
    return @() {
      watch = [curBtnIdx, btnsDesc]
      key = buttonsBlockKey
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      gap = hdpx(40)

      children = btnsDesc.value.map(function(desc, idx) {
        local conHover = desc?.onHover
        local function onHover(on){
          curBtnIdx.update(idx)
          conHover?()
        }
        local onRecalcLayout = (initialBtnIdx==idx)
          ? function(initial, elem) {
              if (initial && styling?.moveMouseCursor.value)
                ::move_mouse_cursor(elem)
            }
          : null
        local behaviors = desc?.customStyle?.behavior ?? desc?.customStyle?.behavior
        behaviors = ::type(behaviors) == "array" ? behaviors : [behaviors]
        behaviors.append(Behaviors.RecalcHandler, Behaviors.Button)
        local customStyle = (desc?.customStyle ?? {}).__merge({
          onHover = onHover
          behavior = behaviors
          onRecalcLayout = onRecalcLayout
        })
        local function onClick() {
          log($"[MSGBOX] clicked '{desc?.text}' button: text = '{params?.text}'")
          handleButton(desc?.action)
        }
        return styling.button(desc.__merge({customStyle = customStyle, key=desc}), onClick)
      })

      hotkeys = [
        [styling?.closeKeys ?? "Esc", {action= @() handleButton(params?.onCancel ?? defCancel?.action), description = styling?.closeTxt}],
        [styling?.rightKeys ?? "Right | Tab", {action = @() moveBtnFocus(1) description = skip}],
        [styling?.leftKeys ?? "Left", {action = @() moveBtnFocus(-1) description = skip}],
        [styling?.activateKeys ?? "Space | Enter", {action= activateCurBtn, description= skip}],
        [styling?.maskKeys ?? "", {action = @() null, description = skip}]
      ]
    }
  }

  local root = styling.Root.__merge({
    key = uid
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    children = [
      styling.messageText(params.__merge({ handleButton = handleButton }))
      buttonsBlock()
    ]
  })

  self = styling.BgOverlay.__merge({
    uid = uid
    cursor = styling.cursor
    stopMouse = true
    children = [styling.BgOverlay?.children, root]
  })

  addWidget(self)

  return self
}


return {
  show
  showMsgbox = show
  getCurMsgbox
  msgboxGeneration
  removeAllMsgboxes
  isMsgboxInList
  removeMsgboxByUid
  styling = defStyling
}
