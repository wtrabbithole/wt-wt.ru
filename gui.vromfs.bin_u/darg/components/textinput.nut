local defaultFrame = function (inputObj, group, sf) {
  return {
    rendObj = ROBJ_FRAME
    borderWidth = [1, 1, 0, 1]
    size = [flex(), SIZE_TO_CONTENT]
    color = (sf.value & S_KB_FOCUS) ? Color(180, 180, 180) : Color(120, 120, 120)
    group = group

    children = {
      rendObj = ROBJ_FRAME
      borderWidth = [0, 0, 1, 0]
      size = [flex(), SIZE_TO_CONTENT]
      color = (sf.value & S_KB_FOCUS) ? Color(250, 250, 250) : Color(180, 180, 180)
      group = group

      children = inputObj
    }
  }
}


local defaultColors = {
  placeHolderColor = Color(160, 160, 160)
  textColor = Color(255,255,255)
  backGroundColor = Color(28, 28, 28, 150)
  highlightFailure = Color(255,60,70)
}


local failAnim = @(trigger) {
  prop = AnimProp.color
  from = defaultColors.highlightFailure
  easing = OutCubic
  duration = 1.0
  trigger = trigger
}


local textInput = function(text_state, options={}, handlers={}, frameCtor=defaultFrame) {
  local group = ::ElemGroup()
  local stateFlags = ::Watched(0)
  local font = options?.font ?? Fonts.medium_text
  local colors = {}

  if ("colors" in options) {
    foreach (colorName, color in defaultColors) {
      colors[colorName] <- options.colors?[colorName] ?? color
    }
  } else {
    colors = defaultColors
  }

  local inputObj = function() {
    local placeholder = null

    if (options?.placeholder && !text_state.value.len()) {
      placeholder = {
        rendObj = ROBJ_STEXT
        font = font
        color = colors.placeHolderColor
        text = options.placeholder
        animations = [failAnim(text_state)]
        margin = [0, sh(0.5)]
      }
    }

    return {
      rendObj = ROBJ_DTEXT
      behavior = Behaviors.TextInput

      size = [flex(), fontH(100)]
      font = font
      color = colors.textColor
      group = group
      margin = [sh(1), sh(0.5)]
      valign = VALIGN_BOTTOM

      animations = [failAnim(text_state)]

      watch = [text_state, stateFlags]
      text = text_state.value
      title = options?.title
      inputType = options?.inputType
      password = options?.password
      key = text_state

      hotkeys = options?.hotkeys

      onChange = function () {
        local changeHook = handlers?.onChange ?? function (newVal) {}
        return function(new_val) {
          changeHook(new_val)
          text_state.update(new_val)
        }
      }()

      onFocus  = handlers?.onFocus
      onBlur   = handlers?.onBlur
      onAttach = handlers?.onAttach
      onReturn = handlers?.onReturn
      onEscape = handlers?.onEscape

      onElemState = @(sf) stateFlags.update(sf)

      children = placeholder
    }
  }

  return {
    margin = options?.margin ?? [sh(1), 0]

    rendObj = ROBJ_SOLID
    color = colors.backGroundColor
    size = [flex(), SIZE_TO_CONTENT]
    group = group
    animations = [failAnim(text_state)]
    valign = VALIGN_MIDDLE

    children = frameCtor(inputObj, group, stateFlags)
  }
}


local export = class{
  defaultColors = defaultColors
  _call = @(self, text_state, options={}, handlers={}, frameCtor=defaultFrame) textInput(text_state, options, handlers, frameCtor)

}()

return export
