
// Note:
// This enums is shared between squirrel and C++ code
// any change requires version.nut update.
// Also do not reorder mouse axes order in order to
// keep compatibility with old controls presets.
enum MouseAxis
{
  MOUSE_X,
  MOUSE_Y,
  MOUSE_SCROLL,
  MOUSE_SCROLL_TANK,
  MOUSE_SCROLL_SHIP,
  MOUSE_SCROLL_SUBMARINE,
  MOUSE_SCROLL_HELICOPTER,
  NUM_MOUSE_AXIS_TOTAL
};

enum CtrlsInGui
{
  CTRL_ALLOW_VEHICLE_KEYBOARD = 0x0001,
  CTRL_ALLOW_VEHICLE_XINPUT   = 0x0002,
  CTRL_ALLOW_VEHICLE_JOY      = 0x0004,
  CTRL_ALLOW_VEHICLE_MOUSE    = 0x0008,

  CTRL_ALLOW_MP_STATISTICS    = 0x0010,
  CTRL_ALLOW_MP_CHAT          = 0x0020,
  CTRL_ALLOW_TACTICAL_MAP     = 0x0040,
  CTRL_ALLOW_FLIGHT_MENU      = 0x0080,
  CTRL_ALLOW_ARTILLERY        = 0x0100,
  CTRL_ALLOW_WHEEL_MENU       = 0x0200,
  CTRL_ALLOW_SPECTATOR        = 0x0400,
  CTRL_ALLOW_ANSEL            = 0x0800,

  CTRL_IN_MP_STATISTICS       = 0x1000,
  CTRL_IN_MP_CHAT             = 0x2000,
  CTRL_IN_TACTICAL_MAP        = 0x4000,
  CTRL_IN_FLIGHT_MENU         = 0x8000,

  //masks
  CTRL_ALLOW_NONE             = 0x0000,
  CTRL_ALLOW_FULL             = 0x0FFF,
  CTRL_WINDOWS_ALL            = 0xF000,

  CTRL_ALLOW_VEHICLE_FULL     = 0x000F
};

enum AxisInvertOption
{
  INVERT_Y,
  INVERT_GUNNER_Y,
  INVERT_THROTTLE,
  INVERT_TANK_Y,
  INVERT_SHIP_Y,
  INVERT_HELICOPTER_Y,
  INVERT_SPECTATOR_Y,
  INVERT_SUBMARINE_Y
};

enum DargWidgets
{
   NONE = 0
  ,HUD
  ,SHIP_OBSTACLE_RF
  ,FOOTBALL
};

enum HelicopterParams
{
  RPM = 0,
  THROTTLE = 1,
  SPEED = 2,
  CANNON = 3,
  CANNON_ADDITIONAL = 4,
  ROCKET = 5,
  AGM = 6,
  AAM = 7,
  BOMBS = 8,
  FLARES = 9,
  RATE_OF_FIRE = 10,
  OIL_1 = 11,
  OIL_2 = 12,
  OIL_3 = 13,
  WATER_1 = 14,
  WATER_2 = 15,
  WATER_3 = 16,
  ENGINE_1 = 17,
  ENGINE_2 = 18,
  ENGINE_3 = 19
};

enum TemperatureState
{
  DEFAULT_TEMPERATURE = 0,
  OVERHEAT = 1,
  EMPTY_TANK = 2,
  FUEL_LEAK = 3,
  BLANK = 4
};

enum HelicopterThrottleMode
{
  DEFAULT_MODE = 0,
  BRAKE = 1,
  CLIMB = 2,
  WEP = 3
};