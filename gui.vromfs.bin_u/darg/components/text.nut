local loc = ("loc" in ::getroottable()) ? loc : @(text) text

local function text(text, params={}, addchildren = null) {
  if (text == null)
    return null

  local children = params?.children
  if (children && type(children) !="array")
    children = [children]
  if (addchildren && children) {
    if (type(addchildren)=="array")
      children.extend(addchildren)
    else
      children.append(addchildren)
  }

  local localize = params?.localize ?? true
  local watch = params?.watch
  local watchedtext = false
  local txt = ""
  local rendObj = params?.rendObj ?? ROBJ_DTEXT
  assert (rendObj == ROBJ_DTEXT || rendObj == ROBJ_STEXT, "rendObj for text should be ROBJ_STEXT or ROBJ_DTEXT")
  if (type(text) == "string")  {
    txt = (localize) ? loc(text) : text
  }
  if (type(text) == "instance" && text instanceof Watched) {
    txt = (localize) ? loc(text.value) : text.value
    watchedtext = true
  }
  local ret = {
    size = SIZE_TO_CONTENT
    halign = HALIGN_LEFT
    font = Fonts.medium_text
  }.__update(params).__update({text = txt, rendObj = rendObj})
  ret.__update({children=children})
  if (watch || watchedtext)
    return @() ret
  else
    return ret
}

local function dtext(text_val, params={}, children=[]) {
  return text(text_val, params.__merge({rendObj = ROBJ_DTEXT}), children)
}
local function stext(text_val, params={}, children = []) {
  return text(text_val, params.__merge({rendObj = ROBJ_STEXT}), children)
}
return {
  text = text
  dtext = dtext
  stext = stext
}
