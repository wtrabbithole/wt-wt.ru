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
  ONLY_COMMON   = 0x0080

  VOICE         = 0x0100
  REPLAY        = 0x0200
  ARTILLERY     = 0x0400

  HANGAR        = 0x0800

  //complex groups mask
  NO_GROUP      = 0x0000
  COMMON        = 0x00FF
}
