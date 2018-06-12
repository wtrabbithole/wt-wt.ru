local cursors = {
  normal = null
  pick = null
}


local inspectorState = persist("state", @() {
  shown = Watched(false)
  halign = Watched(HALIGN_RIGHT)
  pickerActive = Watched(false)
  highlight = Watched(null)
  selection = Watched(null)
})


local function textButton(text, action) {
  local stateFlags = Watched(0)

  return function() {
    local sf = stateFlags.value
    local color = (sf & S_ACTIVE)   ? Color(100, 120, 200, 120)
                : (sf & S_HOVER)    ? Color(110, 110, 150, 50)
                : (sf & S_KB_FOCUS) ? Color(130, 130, 150, 120)
                                    : Color(100, 120, 160, 80)
    return {
      rendObj = ROBJ_SOLID
      size = SIZE_TO_CONTENT
      margin = [sh(0.5), sh(1)]
      behavior = Behaviors.Button
      color = color
      padding = 5
      children = {
        rendObj = ROBJ_STEXT
        text = text
      }

      watch = stateFlags
      onElemState = @(sf) stateFlags.update(sf)
      onClick = action
    }
  }
}


local function panelToolbar() {
  local btnPick = textButton("Pick", @() inspectorState.pickerActive.update(true))

  local alignText = (inspectorState.halign.value == HALIGN_RIGHT ? "<-" : "->")
  local btnToggleAlign = textButton(alignText, function() {
    inspectorState.halign.update(inspectorState.halign.value==HALIGN_LEFT ? HALIGN_RIGHT : HALIGN_LEFT)
  })

  return {
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    halign = HALIGN_LEFT
    children = [
      btnPick
      btnToggleAlign
    ]
  }
}

local function join(arr, sep) {
  local s = ""
  for (local i=0; i<arr.len(); ++i) {
    if (i)
      s += sep
    s += arr[i]
  }
  return s
}


local function propValue(desc, key) {
  local val = desc[key]
  local tp = type(val)

  if (tp == "instance" && (val instanceof ::PictureHolder)) {
    return {
      rendObj = ROBJ_IMAGE
      size = [fontH(100), fontH(100)]
      image = val
    }
  }

  local text = null

  if (val == null) {
    text = "<null>"
  } else if (tp == "array") {
    text = join(val, ", ")
  } else if (tp == "integer" && key.tolower().find("color")!=null) {
    text = "#"+string.format("%16X", val).slice(8)
  } else if (tp == "userdata" || tp == "userpointer") {
    text = "<userdata/userpointer>"
  } else {
    local s = val.tostring()
    text = s.slice(0, min(100, s.len()))
  }

  local function applyChange(new_val_text) {
    local s = new_val_text
    if (tp == "string") {
      desc[key] = s
    } else if (tp == "integer") {
      if (s.len()) {
        desc[key] = s.tointeger()
      }
    }
  }

  return {
    rendObj = ROBJ_STEXT
    color = Color(155,255,50)
    text = text
  }
}


local function propPanel(desc) {
  local keys = []
  foreach (k,v in desc) {
    keys.append(k)
  }
  keys.sort()

  local panelItems = []
  foreach (k in keys) {
    local item = {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      children = [
        {
          rendObj = ROBJ_STEXT
          text = k.tostring()+" = "
        }
        propValue(desc, k)
      ]
    }
    panelItems.append(item)
  }

  return panelItems
}


local function details() {
  local sel = inspectorState.selection.value

  local text = sel ? sel.locationText : null

  local summaryText = {
    rendObj = ROBJ_TEXTAREA
    behavior = [Behaviors.TextArea, Behaviors.WheelScroll]
    text = text
    size = [flex(), fontH(400)]
  }

  local children = [
    summaryText
  ]

  local panelItems = propPanel(sel.componentDesc)
  children.extend(panelItems)

  return {
    size = [flex(), flex(1)]
    rendObj = ROBJ_SOLID
    color = Color(0,0,50,200)
    flow = FLOW_VERTICAL

    children = children
  }
}


local function inspectorPanel() {
  return {
    rendObj = ROBJ_SOLID
    color = Color(0, 0, 50, 50)
    size = [sw(30), sh(100)]
    hplace = inspectorState.halign.value
    behavior = Behaviors.Button
    watch = [inspectorState.halign, inspectorState.selection]
    clipChildren = true

    flow = FLOW_VERTICAL
    children = [
      panelToolbar,
      (inspectorState.selection.value ? details : null)
    ]
  }
}


local function highlightRect() {
  local hv = inspectorState.highlight.value
  return {
    rendObj = ROBJ_SOLID
    color = Color(50, 50, 0, 50)
    pos = [hv.x, hv.y]
    size = [hv.w, hv.h]

    children = {
      rendObj = ROBJ_FRAME
      color = Color(200, 0, 0, 180)
      size = [hv.w, hv.h]
    }
  }
}

local function elemLocationText(elem, builder) {
  local text = "Source: unknown"

  local location = ::locate_element_source(elem)
  if (location) {
    text = location.source + "," + location.line
    if (location.depth) {
      text += "\nChild at level #" + location.depth
    }
  }

  text += (builder ? "\n(Function)" : "\n(Table)")
  return text
}


local function elementPicker() {
  return {
    size = [sw(100), sh(100)]
    behavior = Behaviors.InspectPicker
    cursor = cursors.pick || cursors.normal
    rendObj = ROBJ_SOLID
    color = Color(20,0,0,20)
    onClick = function(data) {
      if (data) {
        inspectorState.selection.update({
          componentDesc = data.componentDesc
          locationText = elemLocationText(data.elem, data.builder)
        })
      } else {
        inspectorState.selection.update(null)
      }
      inspectorState.pickerActive.update(false)
    }
    onChange = function(highlight) {
      inspectorState.highlight.update(highlight)
    }
    children = [
      (inspectorState.highlight.value ? highlightRect : null),
    ]
    watch = inspectorState.highlight
  }
}



local function inspectorRoot() {
  local children = null

  local function toggle() {
    if (inspectorState.shown.value) {
      inspectorState.shown.update(false)
      inspectorState.pickerActive.update(false)
      inspectorState.selection.update(null)
      inspectorState.highlight.update(null)
    } else {
      inspectorState.shown.update(true)
    }
  }


  if (inspectorState.shown.value) {
    children = [
      (inspectorState.pickerActive.value ? null : inspectorPanel),
      (inspectorState.pickerActive.value ? elementPicker : null),
      {
        hotkeys = [
          ["Ctrl Shift I", toggle],
        ]
      }
    ]
  }


  local res = {
    size = [sw(100), sh(100)]
    zOrder = Layers.Inspector
    children = children
    watch = [inspectorState.pickerActive, inspectorState.shown]
    skipInspection = true
  }

  if (inspectorState.shown.value)
    res.cursor <- cursors.normal

  return res
}


return {
  shown = inspectorState.shown
  root = inspectorRoot
  cursors = cursors
}
