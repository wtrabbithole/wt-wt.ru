local baseStyle = require("multiselect.style.nut")

local mkMultiselect = @(selected /*Watched({ <key> = true })*/, options /*[{ key, text }, ...]*/, rootOverride = {}, style = baseStyle)
  @() style.root.__merge({
      watch = selected
      children = options.map(@(option) style.optionCtor(option,
        selected.value?[option.key] ?? false,
        @() selected(function(s) { s[option.key] <- !(s?[option.key] ?? false) })))
    })
    .__merge(rootOverride)

return ::kwarg(mkMultiselect)