//This is list of all darg native functions and consts, to use in mockups
function Color(r,g,b,a=255) {
  return (a << 24) + (r << 16) + (g << 8) + b;
}


::Watched <-class {
  value=null
  subscribers = null
  constructor(val=null) {
    value=val
    subscribers = {}
  }
  function update(val) {
    value=val
    foreach (key,func in subscribers)
      func(val)
  }
  _call = function(self,val) {
    value=val
    foreach (key,func in subscribers)
      func(val)
  }
  _tostring = function(){
    return "::Watched: " + value
  }
  function trigger() {return null}
  function trace() {return ""}
  function subscribe(func) {
    local infos = func.getfuncinfos()
    local key = (infos?.name ?? "__noname__") + " " + (infos?.src ?? "__no_src__")
    if (! (key in this.subscribers))
      subscribers[key]<-func
  }
}

::Fonts <-{}
::calc_comp_size <- @(comp) [0,0]
::gui_scene <-{
  setShutdownHandler = @(val) null
  circleButtonAsAction = false
  config = {
    defaultFont = 0
    joystickScrollCursor = true
    gamepadCursorSpeed = 1.0
    defSceneBgColor =Color(10,10,10,160)
    setJoystickClickButtons = @(list) null
    gamepadCursorControl = true
    reportNestedWatchedUpdate = false
    gamepadCursorDeadZone = 0.05
    gamepadCursorNonLin = 1.5
    gamepadCursorHoverMinMul = 0.005
    gamepadCursorHoverMaxMul = 0.1
    gamepadCursorHoverMaxTime = 0.5
  }
  cursorPresent = ::Watched(true)
  setHotkeysNavHandler = function(func){assert(::type(func)=="function")}
  setUpdateHandler = function(dt) {}
  setTimeout = function(timeout, func){
    assert([type(0),type(0.0)].find(type(timeout))!=null, "timeout should number")
    assert(type(func)==type(type), "function should be function")
  }
  clearTimer = function(func){
    assert(type(func)==type(type), "function should be function")
  }
}
::ScrollHandler <- class{}
::ElemGroup <- @() {}
enum AnimProp{
  color
  bgColor
  fgColor
  fillColor
  borderColor
  opacity
  rotate
  scale
  translate
  fValue
}

::anim_start<-@(anim) null
::anim_request_stop<-@(anim) null

function vlog(val) {
  print("" +val + "\n")
}

function logerr(val) {
  print("" +val + "\n")
}

function debug(val) {
  print("" +val + "\n")
}

function fontH(height) {
  return height
}

function flex(weight=1) {
  return weight*100
}

function sw(val) {
  return val*1920
}

function w(val) {
  return val.tointeger()
}

function h(val) {
  return val.tointeger()
}

function sh(val) {
  return val*1080
}

function pw(val) {
  return val*100
}

function ph(val) {
  return val*100
}

::Behaviors <- {
  Button = "Button"
  TextArea="TextArea"
  MoveResize = "MoveResize"
  Marquee = "Marquee"
  BoundToArea = "BoundToArea"
}

function Picture(val){return val}
function Cursor(val) {return val}

enum Layers {
  Default
  Upper
  ComboPopup
  MsgBox
  Tooltip
  Inspector
}

const ROBJ_IMAGE = "ROBJ_IMAGE"
const ROBJ_STEXT = "ROBJ_STEXT"
const ROBJ_DTEXT = "ROBJ_DTEXT"
const ROBJ_TEXTAREA = "ROBJ_TEXTAREA"
const ROBJ_BOX = "ROBJ_BOX"
const ROBJ_SOLID = "ROBJ_SOLID"
const ROBJ_FRAME = "ROBJ_FRAME"
const ROBJ_PROGRESS_CIRCULAR = "ROBJ_PROGRESS_CIRCULAR"
const ROBJ_WORLD_BLUR = "ROBJ_WORLD_BLUR"
const ROBJ_WORLD_BLUR_PANEL = "ROBJ_WORLD_BLUR_PANEL"
const ROBJ_VECTOR_CANVAS = "ROBJ_VECTOR_CANVAS"
const VECTOR_POLY = "VECTOR_POLY"
const ROBJ_MASK = "ROBJ_MASK"

const FLOW_PARENT_RELATIVE = "PARENT_RELATIVE"
const FLOW_HORIZONTAL = "FLOW_HORIZONTAL"
const FLOW_VERTICAL = "FLOW_VERTICAL"

const HALIGN_LEFT = "HALIGN_LEFT"
const HALIGN_CENTER ="HALIGN_CENTER"
const HALIGN_RIGHT="HALIGN_RIGHT"
const VALIGN_TOP="VALIGN_TOP"
const VALIGN_MIDDLE="VALIGN_MIDDLE"
const VALIGN_BOTTOM="VALIGN_BOTTOM"

const VECTOR_WIDTH="VECTOR_WIDTH"
const VECTOR_COLOR="VECTOR_COLOR"
const VECTOR_FILL_COLOR="VECTOR_FILL_COLOR"
const VECTOR_LINE="VECTOR_LINE"
const VECTOR_ELLIPSE="VECTOR_ELLIPSE"
const VECTOR_RECTANGLE="VECTOR_RECTANGLE"

const FFT_NONE="FFT_NONE"
const FFT_SHADOW="FFT_SHADOW"
const FFT_GLOW="FFT_GLOW"
const FFT_BLUR="FFT_BLUR"
const FFT_OUTLINE="FFT_OUTLINE"

const O_HORIZONTAL="O_HORIZONTAL"
const O_VERTICAL="O_VERTICAL"

const TOVERFLOW_CLIP="TOVERFLOW_CLIP"
const TOVERFLOW_CHAR="TOVERFLOW_CHAR"
const TOVERFLOW_WORD="TOVERFLOW_WORD"
const TOVERFLOW_LINE="TOVERFLOW_LINE"
const EVENT_BREAK = "EVENT_BREAK"
const EVENT_CONTINUE= "EVENT_CONTINUE"





const Linear = "Linear"

const InQuad = "InQuad"
const OutQuad = "OutQuad"
const InOutQuad = "InOutQuad"

const InCubic = "InCubic"
const OutCubic = "OutCubic"
const InOutCubic = "InOutCubic"

const InQuintic = "InQuintic"
const OutQuintic = "OutQuintic"
const InOutQuintic = "InOutQuintic"

const InQuart = "InQuart"
const OutQuart = "OutQuart"
const InOutQuart = "InOutQuart"

const InSine = "InSine"
const OutSine = "OutSine"
const InOutSine = "InOutSine"

const InCirc = "InCirc"
const OutCirc = "OutCirc"
const InOutCirc = "InOutCirc"

const InExp = "InExp"
const OutExp = "OutExp"
const InOutExp = "InOutExp"

const InElastic = "InElastic"
const OutElastic = "OutElastic"
const InOutElastic = "InOutElastic"

const InBack = "InBack"
const OutBack = "OutBack"
const InOutBack = "InOutBack"

const InBounce = "InBounce"
const OutBounce = "OutBounce"
const InOutBounce = "InOutBounce"

const InOutBezier = "InOutBezier"
const CosineFull = "CosineFull"

const InStep = "InStep"
const OutStep = "OutStep"

const Blink = "Blink"
const DoubleBlink = "DoubleBlink"
const BlinkSin = "BlinkSin"
const BlinkCos = "BlinkCos"

const Discrete8 = "Discrete8"

const Shake4 = "Shake4"
const Shake6 = "Shake6"



const S_KB_FOCUS=0
const S_HOVER=1
const S_TOP_HOVER=2
const S_ACTIVE=3
const S_DRAG=4

const MR_NONE="MR_NONE"
const MR_T="MR_T"
const MR_R="MR_R"
const MR_B="MR_B"
const MR_L="MR_L"
const MR_LT="MR_LT"
const MR_RT="MR_RT"
const MR_LB="MR_LB"
const MR_RB="MR_RB"
const MR_AREA="MR_AREA"
const SIZE_TO_CONTENT="SIZE_TO_CONTENT"
