//This is list of all darg native functions and consts, to use in mockups

Watched <-class {
  value=null
  constructor(val) {value=val}
  function update(val) {value=val}
  function trace() {return ""}
}

function vlog(val) {
  print("" +val + "\n")
}

function logerr(val) {
  print("" +val + "\n")
}

function debug(val) {
  print("" +val + "\n")
}

function Color(r,g,b,a=255) {
  return (a << 24) + (r << 16) + (g << 8) + b;
}

function flex(weight=1) {
  return weight*100
}

function sw(val) {
  return val*1920
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
}

function Picture(val){return val}

const ROBJ_IMAGE = "ROBJ_IMAGE"
const ROBJ_STEXT = "ROBJ_STEXT"
const ROBJ_DTEXT = "ROBJ_DTEXT"
const ROBJ_TEXTAREA = "ROBJ_TEXTAREA"
const ROBJ_BOX = "ROBJ_BOX"
const ROBJ_SOLID = "ROBJ_SOLID"
const ROBJ_FRAME = "ROBJ_FRAME"
const ROBJ_PROGRESS_CIRCULAR = "ROBJ_PROGRESS_CIRCULAR"

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

const Linear="Linear"
const InQuad="InQuad"
const OutQuad="OutQuad"
const InOutQuad="InOutQuad"
const InCubic="InCubic"
const OutCubic="OutCubic"
const InOutCubic="InOutCubic"
const InQuart="InQuart"
const OutQuart="OutQuart"
const InOutQuart="InOutQuart"
const InOutBezier="InOutBezier"
const CosineFull="CosineFull"
const InStep="InStep"
const OutStep="OutStep"

const S_KB_FOCUS="S_KB_FOCUS"
const S_HOVER="S_HOVER"
const S_TOP_HOVER="S_TOP_HOVER"
const S_ACTIVE="S_ACTIVE"
const S_DRAG="S_DRAG"

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
