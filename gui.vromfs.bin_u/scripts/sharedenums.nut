
//Note:
//This enums is shared between squirrel and C++ code
//any change requires version.nut update
//
enum EMouseAxis
{
    MouseAileronsAxis,
    MouseElevatorAxis,
    MouseThrottleAxis,
    MouseZoomAxis,
    MouseShipEngineAxis,
    EMouseAxisNumTotal
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

  //masks
  CTRL_ALLOW_NONE             = 0x0000,
  CTRL_ALLOW_FULL             = 0xFFFF,

  CTRL_ALLOW_VEHICLE_FULL     = 0x000F
};