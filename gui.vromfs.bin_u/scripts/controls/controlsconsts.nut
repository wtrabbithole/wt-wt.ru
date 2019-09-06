const max_deadzone = 0.5
const max_nonlinearity = 4
const max_camera_smooth = 0.9

const min_camera_speed = 0.5
const max_camera_speed = 8

const ACTION_BAR_NUM_SHELL_TYPE_ACTIONS = 4
const ACTION_BAR_FIRE_EXTINGUISHER_IDX = 5

enum CONTROL_TYPE {
  HEADER
  SECTION
  SHORTCUT
  AXIS_SHORTCUT
  AXIS
  SPINNER
  DROPRIGHT
  SLIDER
  SWITCH_BOX
  MOUSE_AXIS
  //for controls wizard
  MSG_BOX
  SHORTCUT_GROUP
  LISTBOX
  BUTTON
}

enum AXIS_DEVICES {
  STICK,
  THROTTLE,
  GAMEPAD,
  MOUSE,
  UNKNOWN
}
enum ctrlGroups {
  //base bit groups
  DEFAULT       = 0x0001 //== AIR
  AIR           = 0x0001
  TANK          = 0x0002
  SHIP          = 0x0004
  HELICOPTER    = 0x0008
  SUBMARINE     = 0x0010
  UFO           = 0x0020
  WALKER        = 0x0040
  ONLY_COMMON   = 0x0080

  VOICE         = 0x0100
  REPLAY        = 0x0200
  ARTILLERY     = 0x0400

  HANGAR        = 0x0800

  //complex groups mask
  NO_GROUP      = 0x0000
  COMMON        = 0x00FF
}

enum AXIS_MODIFIERS {
  NONE = 0x0,
  MIN = 0x8000,
  MAX = 0x4000,
}

//gamepad axes bitmask
enum GAMEPAD_AXIS {
  NOT_AXIS = 0

  LEFT_STICK_HORIZONTAL = 0x1
  LEFT_STICK_VERTICAL = 0x2
  RIGHT_STICK_HORIZONTAL = 0x4
  RIGHT_STICK_VERTICAL = 0x8

  LEFT_TRIGGER = 0x10
  RIGHT_TRIGGER = 0x20

  LEFT_STICK = 0x3
  RIGHT_STICK = 0xC
}

//mouse axes bitmask
enum MOUSE_AXIS {
  NOT_AXIS = 0x0

  HORIZONTAL_AXIS = 0x1
  VERTICAL_AXIS = 0x2
  WHEEL_AXIS = 0x4

  MOUSE_MOVE = 0x3

  TOTAL = 3
}

enum CONTROL_HELP_PATTERN {
  NONE,
  IMAGE,
  GAMEPAD,
  KEYBOARD_MOUSE
}

enum AxisDirection {
  X,
  Y
}