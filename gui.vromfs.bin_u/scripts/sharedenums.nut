// Note:
// This enums is shared between squirrel and C++ code
// any change requires version.nut update.
// Also do not reorder mouse axes order in order to
// keep compatibility with old controls presets.
global enum MouseAxis
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

global enum CtrlsInGui
{
  CTRL_ALLOW_VEHICLE_KEYBOARD = 0x00000001,
  CTRL_ALLOW_VEHICLE_XINPUT   = 0x00000002,
  CTRL_ALLOW_VEHICLE_JOY      = 0x00000004,
  CTRL_ALLOW_VEHICLE_MOUSE    = 0x00000008,

  CTRL_ALLOW_MP_STATISTICS    = 0x00000010,
  CTRL_ALLOW_MP_CHAT          = 0x00000020,
  CTRL_ALLOW_TACTICAL_MAP     = 0x00000040,
  CTRL_ALLOW_FLIGHT_MENU      = 0x00000080,
  CTRL_ALLOW_ARTILLERY        = 0x00000100,
  CTRL_ALLOW_WHEEL_MENU       = 0x00000200,
  CTRL_ALLOW_SPECTATOR        = 0x00000400,
  CTRL_ALLOW_ANSEL            = 0x00000800,

  CTRL_IN_MP_STATISTICS       = 0x00001000,
  CTRL_IN_MP_CHAT             = 0x00002000,
  CTRL_IN_TACTICAL_MAP        = 0x00004000,
  CTRL_IN_FLIGHT_MENU         = 0x00008000,
  CTRL_IN_MULTIFUNC_MENU      = 0x00010000,

  //masks
  CTRL_ALLOW_NONE             = 0x00000000,
  CTRL_ALLOW_FULL             = 0x00000FFF,
  CTRL_WINDOWS_ALL            = 0x000FF000,

  CTRL_ALLOW_VEHICLE_FULL     = 0x0000000F
};

global enum AxisInvertOption
{
  INVERT_Y,
  INVERT_GUNNER_Y,
  INVERT_THROTTLE,
  INVERT_TANK_Y,
  INVERT_SHIP_Y,
  INVERT_HELICOPTER_Y,
  INVERT_HELICOPTER_GUNNER_Y,
  INVERT_EXT_TANK_Y,
  INVERT_SPECTATOR_Y,
  INVERT_SUBMARINE_Y,
};

global enum DargWidgets
{
   NONE = 0
  ,HUD
  ,SHIP_OBSTACLE_RF
  ,SCOREBOARD
  ,CHANGE_LOG
  ,DAMAGE_PANEL
};

global enum HelicopterParams
{
  RPM = 0,
  THROTTLE = 1,
  SPEED = 2,
  CANNON_1 = 3,
  CANNON_2 = 4,
  CANNON_3 = 5,
  MACHINE_GUN = 6,
  CANNON_ADDITIONAL = 7,
  ROCKET = 8,
  AGM = 9,
  AAM = 10,
  BOMBS = 11,
  FLARES = 12,
  IRCM = 13,
  RATE_OF_FIRE = 14,
  OIL_1 = 15,
  OIL_2 = 16,
  OIL_3 = 17,
  WATER_1 = 18,
  WATER_2 = 19,
  WATER_3 = 20,
  ENGINE_1 = 21,
  ENGINE_2 = 22,
  ENGINE_3 = 23,
  TRANSMISSION_1 = 24,
  TRANSMISSION_2 = 25,
  TRANSMISSION_3 = 26,
  TRANSMISSION_4 = 27,
  TRANSMISSION_5 = 28,
  TRANSMISSION_6 = 29,
  FUEL = 30
};

global enum TemperatureState
{
  DEFAULT_TEMPERATURE = 0,
  OVERHEAT = 1,
  EMPTY_TANK = 2,
  FUEL_LEAK = 3,
  BLANK = 4
};

global enum HelicopterThrottleMode
{
  DEFAULT_MODE = 0,
  BRAKE = 1,
  CLIMB = 2,
  WEP = 3,
  AIRCRAFT_DEFAULT_MODE = 4,
  AIRCRAFT_BRAKE = 5,
  AIRCRAFT_WEP = 6
};

global enum RadarViewMode
{
  B_SCOPE_ROUND = 0,
  B_SCOPE_SQUARE = 1,
  MODE_COUNT = 2
};

global enum FlaresMode
{
  PERIODIC_FLARES    = 1,
  MLWS_SLAVED_FLARES = 2
};

global enum WeaponMode
{
  CCIP_MODE = 1,
  CCRP_MODE = 2
};

global enum IRCMMode
{
  IRCM_ENABLED = 1,
  IRCM_DAMAGED = 2,
  IRCM_DISABLED = 3
};

