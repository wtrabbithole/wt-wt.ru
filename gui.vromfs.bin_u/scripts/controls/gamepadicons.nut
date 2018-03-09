local ICO_PRESET_DEFAULT = "#ui/gameuiskin#x_"
local ICO_PRESET_PS4 = "#ui/gameuiskin#ps_"
local ICO_PRESET_XBOXONE = "#ui/gameuiskin#xone_"

local controlsList = { //table for faster check existance
  button_a = true
  button_a_pressed = true
  button_b = true
  button_b_pressed = true
  button_x = true
  button_x_pressed = true
  button_y = true
  button_y_pressed = true

  button_back = true
  button_back_pressed = true
  button_share = true
  button_share_pressed = true
  button_start = true
  button_start_pressed = true

  l_trigger = true
  l_trigger_pressed = true
  r_trigger = true
  r_trigger_pressed = true
  l_shoulder = true
  l_shoulder_pressed = true
  r_shoulder = true
  r_shoulder_pressed = true

  dirpad = true
  dirpad_down = true
  dirpad_left = true
  dirpad_right = true
  dirpad_up = true

  l_stick = true
  l_stick_4 = true
  l_stick_down = true
  l_stick_left = true
  l_stick_pressed = true
  l_stick_right = true
  l_stick_to_left_n_right = true
  l_stick_to_up_n_down = true
  l_stick_up = true

  r_stick = true
  r_stick_4 = true
  r_stick_down = true
  r_stick_left = true
  r_stick_pressed = true
  r_stick_right = true
  r_stick_to_left_n_right = true
  r_stick_to_up_n_down = true
  r_stick_up = true

  table_plays_icon = true
  team_dirpad = true
  touchpad = true
  touchpad_pressed = true
}

local btnNameByIndex = [
  "dirpad_up"     //  0 JOY_XBOX_REAL_BTN_D_UP
  "dirpad_down"   //  1 JOY_XBOX_REAL_BTN_D_DOWN
  "dirpad_left"   //  2 JOY_XBOX_REAL_BTN_D_LEFT
  "dirpad_right"  //  3 JOY_XBOX_REAL_BTN_D_RIGHT
  "button_start"  //  4 JOY_XBOX_REAL_BTN_START // PS4 Options
  "button_back"   //  5 JOY_XBOX_REAL_BTN_BACK  // PS4 Touchscreen Press
  "l_stick_pressed"//  6 JOY_XBOX_REAL_BTN_L_THUMB
  "r_stick_pressed"//  7 JOY_XBOX_REAL_BTN_R_THUMB
  "l_shoulder"    //  8 JOY_XBOX_REAL_BTN_L_SHOULDER
  "r_shoulder"    //  9 JOY_XBOX_REAL_BTN_R_SHOULDER
  "table_plays_icon" // 10 JOY_XBOX_REAL_BTN_0X0400
  "table_plays_icon" // 11 JOY_XBOX_REAL_BTN_0X0800
  "button_a"      // 12 JOY_XBOX_REAL_BTN_A // PS4 (X)
  "button_b"      // 13 JOY_XBOX_REAL_BTN_B // PS4 (O)
  "button_x"      // 14 JOY_XBOX_REAL_BTN_X // PS4 (Sq)
  "button_y"      // 15 JOY_XBOX_REAL_BTN_Y // PS4 (Tr)
  "l_trigger"     // 16 JOY_XBOX_REAL_BTN_L_TRIGGER
  "r_trigger"     // 17 JOY_XBOX_REAL_BTN_R_TRIGGER
  "l_stick_right" // 18 JOY_XBOX_REAL_BTN_L_THUMB_RIGHT
  "l_stick_left"  // 19 JOY_XBOX_REAL_BTN_L_THUMB_LEFT
  "l_stick_up"    // 20 JOY_XBOX_REAL_BTN_L_THUMB_UP
  "l_stick_down"  // 21 JOY_XBOX_REAL_BTN_L_THUMB_DOWN
  "r_stick_right" // 22 JOY_XBOX_REAL_BTN_R_THUMB_RIGHT
  "r_stick_left"  // 23 JOY_XBOX_REAL_BTN_R_THUMB_LEFT
  "r_stick_up"    // 24 JOY_XBOX_REAL_BTN_R_THUMB_UP
  "r_stick_down"  // 25 JOY_XBOX_REAL_BTN_R_THUMB_DOWN
  "l_stick_pressed" // 26 JOY_XBOX_REAL_BTN_L_THUMB
  "r_stick_pressed" // 27 JOY_XBOX_REAL_BTN_R_THUMB
]

local mouseButtonTextures = [
  "mouse_left"
  "mouse_right"
  "mouse_center"
]

local ps4TouchpadImagesByMouseIdx = [
  "touchpad"
  "touchpad_pressed"
]

local curPreset = ::is_platform_ps4 ? ICO_PRESET_PS4
  : ::is_platform_xboxone ? ICO_PRESET_XBOXONE
  : ICO_PRESET_DEFAULT

local getTexture = @(id, preset = curPreset) (id in controlsList) ? preset + id : ""
local getTextureByButtonIdx = @(idx) getTexture(btnNameByIndex?[idx])

local cssString = null
local getCssString = function()
{
  if (cssString)
    return cssString

  cssString = ""
  foreach(name, value in controlsList)
    cssString += ::format("@const control_%s:%s;", name, getTexture(name))
  return cssString
}

local getMouseTexture = function(idx, preset = curPreset)
{
  if (::is_platform_ps4 && idx in ps4TouchpadImagesByMouseIdx)
    return preset + ps4TouchpadImagesByMouseIdx[idx]

  if (idx in mouseButtonTextures)
    return "#ui/gameuiskin#" + mouseButtonTextures[idx]

  return getTextureByButtonIdx(idx, preset)
}

return {
  TOTAL_BUTTON_INDEXES = btnNameByIndex.len()
  ICO_PRESET_DEFAULT       = ICO_PRESET_DEFAULT
  ICO_PRESET_PS4           = ICO_PRESET_PS4
  ICO_PRESET_XBOXONE       = ICO_PRESET_XBOXONE

  fullIconsList = controlsList

  getTexture = getTexture
  getTextureByButtonIdx = getTextureByButtonIdx
  getMouseTexture = getMouseTexture
  hasMouseTexture = @(idx) mouseButtonTextures?[idx] != null
  hasTextureByButtonIdx = @(idx) btnNameByIndex?[idx] != null
  getButtonNameByIdx = @(idx) btnNameByIndex?[idx] ?? ""
  getCssString = getCssString
}