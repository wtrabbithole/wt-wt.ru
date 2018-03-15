local defStyling = require("textButton.style.nut")
local fa = require("fontawesome.map.nut")

local textColor = function(sf, style={}) {
  local styling = mergeRecursive(defStyling, style)
  if (sf & S_ACTIVE)    return styling.TextActive
  if (sf & S_HOVER)     return styling.TextHover
  if (sf & S_KB_FOCUS)  return styling.TextFocused
  return style.TextNormal
}

local borderColor = function(sf, style={}) {
  local styling = mergeRecursive(defStyling, style)
  if (sf & S_ACTIVE)    return styling.BdActive
  if (sf & S_HOVER)     return styling.BdHover
  if (sf & S_KB_FOCUS)  return styling.BdFocused
  return styling.BdNormal
}

local fillColor = function(sf, style={}) {
  local styling = mergeRecursive(defStyling, style)
  if (sf & S_ACTIVE)    return styling.BgActive
  if (sf & S_HOVER)     return styling.BgHover
  if (sf & S_KB_FOCUS)  return styling.BgFocused
  return style.BgNormal
}

local fillColorTransp = function(sf, style={}) {
  local styling = mergeRecursive(defStyling, style)
  if (sf & S_ACTIVE)    return styling.BgActive
  if (sf & S_HOVER)     return styling.BgHover
  if (sf & S_KB_FOCUS)  return styling.BgFocused
  return Color(0,0,0,0)
}


local textButton = @(fill_color, border_width) function(text, handler, params={}) {
  local group = ::ElemGroup()
  local stateFlags = Watched(0)
  local styling = params?.styling ?? defStyling
  local btnMargin =  params?.margin ?? defStyling.btnMargin
  local textMargin = params?.textMargin ?? defStyling.textMargin

  local font = params.get("font", Fonts.medium_text)
  local size = params.get("size", SIZE_TO_CONTENT)
  local halign = params.get("halign", HALIGN_LEFT)
  local valign = params.get("valign", VALIGN_MIDDLE)
  local sound = params?.styling?.sound ?? {}
  local builder = function(sf) {
    return {
      margin = params.get("margin", btnMargin)
      key = params.get("key")

      group = group

      rendObj = ROBJ_BOX
      size = size
      fillColor = fill_color(sf, styling)
      borderWidth = border_width
      halign = halign
      valign = valign
      borderColor = borderColor(sf, styling)
      sound = sound

      children = {
        rendObj = ROBJ_STEXT
        text = text
        margin = textMargin
        font = font
        group = group
        color = textColor(sf, styling)
      }

      behavior = Behaviors.Button
      onClick = handler
    }.__update(params)
  }

  return watchElemState(builder)
}


local export = class{
  Bordered = textButton(fillColor, 1)
  Underline = textButton(fillColor, [0,0,1,0])
  Flat = textButton(fillColor, 0)
  Transp = textButton(fillColorTransp, 0)
  FA =          @(fa_key, handler, params={}) Flat     (fa.get(fa_key,"N"), handler, {margin = 0 font = Fonts.fontawesome halign = HALIGN_CENTER valign=VALIGN_MIDDLE}.__update(params))
  FA_Bordered = @(fa_key, handler, params={}) Bordered (fa.get(fa_key,"N"), handler, {margin = 0 font = Fonts.fontawesome halign = HALIGN_CENTER valign=VALIGN_MIDDLE}.__update(params))
  FA_Transp   = @(fa_key, handler, params={}) Transp   (fa.get(fa_key,"N"), handler, {margin = 0 font = Fonts.fontawesome halign = HALIGN_CENTER valign=VALIGN_MIDDLE}.__update(params))

  _call = @(self, text, handler, params={}) Flat(text, handler, params)
}()


return export
