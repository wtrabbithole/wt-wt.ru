local loc = ("loc" in ::getroottable()) ? ::loc : @(text) text

local function textarea(text, params={}) {
  local watchedtext = false
  local localize = params?.localize ?? true
  local txt = ""
  if (::type(text) == "string")  {
    txt = (localize) ? loc(text) : text
  }
  if (::type(text) == "instance" && text instanceof ::Watched) {
    txt = (localize) ? loc(text.value) : text.value
    watchedtext = true
  }
  local ret = {
    size = ::flex()
    font = ::Fonts.small_text
    halign = HALIGN_LEFT
  }.__update(params).__update({rendObj=ROBJ_TEXTAREA behavior = Behaviors.TextArea text=txt})

  if (ret?.watch || watchedtext)
    return @() ret
  else
    return ret
}

return textarea