local string = require("string")
/*
  todo:
    - somehow provide result of validation - maybe more complex type of inputState, like Watched({text=text isValid=true}))
    - important to know about language and CapsLock. The easiest way - show last symbol in password for 0.25 seconds before hide it with *

    - replace editor in enlisted with this component (it should be already suitable)
*/
local rexInt = string.regexp(@"[\+\-]?[0-9]+")
local function isStringInt(str){
  return rexInt.match(str) //better use one from string.nut
}

local rexFloat = string.regexp(@"(\+|-)?([0-9]+\.?[0-9]*|\.[0-9]+)([eE](\+|-)?[0-9]+)?")
local function isStringFloat(str){
  return rexFloat.match(str) //better use one from string.nut
}

local rexEng = string.regexp(@"[a-z,A-Z]*")
local function isStringEng(str){
  return rexEng.match(str)
}
local function isStringLikelyEmail(str, verbose=true) {
// this check is not rfc fully compatible. We check that @ exist and correctly used, and that local and domain parts exist and they are correct length.
// Domain part also have at least one period and main domain at least 2 symbols
// also come correct emails on google are against RFC, for example a.a.a@gmail.com.

  if (type(str)!="string")
    return false
  local split = ::string.split(str,"@")
  if (split.len()<2)
    return false
  local locpart = split[0]
  if (split.len()>2)
    locpart = split.slice(0,-1).reduce(@(a,b) a+"@"+b)
  if (locpart.len()>64)
    return false
  local dompart = split[split.len()-1]
  if (dompart.len()>253 || dompart.len()<4) //RFC + domain should be at least x.xx
    return false
  local quotes = locpart.find("\"")
  if (quotes && quotes!=0)
    return false //quotes only at the begining
  if (quotes==null && locpart.find("@")!=null)
    return false //no @ without quotes
  if (dompart.find(".")==null || dompart.find(".")>dompart.len()-3)
    return false  //too short first level domain or no periods
  return true
}

local function defaultFrame(inputObj, group, sf) {
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

local function isValidStrByType(str, inputType) {
  if (str=="")
    return true
  if (inputType=="mail")
     return isStringLikelyEmail(str)
  if (inputType=="num")
     return isStringInt(str) || isStringFloat(str)
  if (inputType=="integer")
     return isStringInt(str)
  if (inputType=="float")
     return isStringFloat(str)
  if (inputType=="lat")
     return isStringEng(str)
  return true
}

local imeInputMap = {
  integer = "num",
  ["float"] = "num"
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

local interactiveValidTypes = ["num","lat","integer","float"]

local function textInput(text_state, options={}, handlers={}, frameCtor=defaultFrame) {
  local group = ::ElemGroup()
  local stateFlags = ::Watched(0)
  local font = options?.font ?? Fonts.medium_text
  local colors = {}
  local inputType = options?.inputType
  local imeInputType = imeInputMap?.inputType ?? inputType

  local function isValidResultByInput(new_value) {
    return isValidStrByType(new_value, inputType)
  }

  local function isValidChangeByInput(new_value) {
    if (interactiveValidTypes.find(inputType)==null)
      return true
    return isValidStrByType(new_value, inputType)
  }

  if ("colors" in options) {
    foreach (colorName, color in defaultColors) {
      colors[colorName] <- options.colors?[colorName] ?? color
    }
  } else {
    colors = defaultColors
  }

  local function inputObj() {
    local placeholder = null
    local isValidResult = handlers?.isValidResult ?? isValidResultByInput
    local isValidChange = handlers?.isValidChange ?? isValidChangeByInput
    local text_val = text_state.value
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

    local function onBlur(){
      if (!isValidResult(text_val))
        ::anim_start(text_state)
      if (handlers?.onBlur)
        handlers.onBlur()
    }

    local function onReturn(){
      if (!isValidResult(text_val))
        ::anim_start(text_state)
      if (handlers?.onReturn)
        handlers.onReturn()
    }

    local function onEscape(){
      if (!isValidResult(text_val))
        ::anim_start(text_state)
      if (handlers?.onEscape)
        handlers.onEscape()
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
      inputType = inputType
      password = options?.password
      key = text_state

      hotkeys = options?.hotkeys

      onChange = function () {
        local changeHook = handlers?.onChange ?? function (newVal) {}
        return function(new_val) {
          changeHook(new_val)
          if (!isValidChange(new_val)) {
            ::anim_start(text_state)
            text_state.trigger() // force rebuild
          } else {
            text_state.update(new_val)
          }
        }
      }()

      onFocus  = handlers?.onFocus
      onBlur   = onBlur
      onAttach = handlers?.onAttach
      onReturn = onReturn
      onEscape = onEscape

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
