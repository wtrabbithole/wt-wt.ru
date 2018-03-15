local loc = ("loc" in ::getroottable()) ? loc : @(text) text

local function text(text, params={}) {
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

  if (watch || watchedtext) 
    return @() ret
  else
    return ret
}

local function stext(text_val, params={}) {
  local params_ = {}.__update(params).__update({rendObj = ROBJ_DTEXT})
  return text(text_val, params_)  
}
local function dtext(text_val, params={}) {
  local params_ = {}.__update(params).__update({rendObj = ROBJ_STEXT})
  return text(text_val, params_)  
}
return {
  text = text
  dtext = dtext
  stext = stext
}
