local safeAreaMenu = require("scripts/options/safeAreaMenu.nut")
local safeAreaHud = require("scripts/options/safeAreaHud.nut")

function get_system_options()
{
  return {
    name = "graphicsParameters"
    fillFuncName = "fillSystemOptions"
    onApplyHandler = ::onApplySystemOptions
    options = []
  }
}

function get_main_options()
{
  local isInFlight = ::is_in_flight()
  local hasTripleColorSmokeFeature = ::has_feature("AerobaticTricolorSmoke")
  local isFirstTutorial = (::current_campaign_name == "tutorial_pacific_41") &&
    (::current_campaign_mission == "tutorial01")
  local curUnit = ::get_player_cur_unit()
  local canChangeViewType = false
  if ( ! isFirstTutorial && curUnit)
    canChangeViewType = curUnit.unitType.canChangeViewType

  return {
    name = isInFlight ? "main" : "mainParameters"
    isSearchAvaliable = true
    options = [

      ["options/mainParameters"],
      [::USEROPT_LANGUAGE, "spinner", ! isInFlight && ::canSwitchGameLocalization()],
      [::USEROPT_AUTOLOGIN, "spinner", ! isInFlight && !::is_ps4_or_xbox],
      [::USEROPT_FONTS_CSS, "spinner"],
      [::USEROPT_CLUSTER, "spinner", ! isInFlight && ::is_platform_ps4],

      ["options/header/commonBattleParameters"],
      [::USEROPT_HUD_SHOW_BONUSES, "spinner"],
      [::USEROPT_DAMAGE_INDICATOR_SIZE, "slider"],
      [::USEROPT_CAMERA_SHAKE_MULTIPLIER, "slider"],
      [::USEROPT_AUTO_SQUAD, "spinner"],
      [::USEROPT_QUEUE_JIP, "spinner"],

      ["options/header/air"],
      [::USEROPT_VIEWTYPE, "spinner", ! isInFlight],
      [::USEROPT_GUN_TARGET_DISTANCE, "spinner", ! isInFlight],
      [::USEROPT_GUN_VERTICAL_TARGETING, "spinner", ! isInFlight],
      [::USEROPT_BOMB_ACTIVATION_TIME, "spinner", ! isInFlight],
      [::USEROPT_AEROBATICS_SMOKE_TYPE, "spinner"],
      [::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, "spinner", hasTripleColorSmokeFeature],
      [::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, "spinner", hasTripleColorSmokeFeature],
      [::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR, "spinner", hasTripleColorSmokeFeature],
      [::USEROPT_SHOW_PILOT, "spinner"],
      [::USEROPT_AUTOPILOT_ON_BOMBVIEW, "spinner"],
      [::USEROPT_AUTOREARM_ON_AIRFIELD, "spinner"],
      [::USEROPT_CROSSHAIR_TYPE, "combobox"],
      [::USEROPT_CROSSHAIR_COLOR, "combobox"],
      [::USEROPT_INDICATEDSPEED, "spinner"],
      [::USEROPT_CROSSHAIR_DEFLECTION, "spinner"],
      [::USEROPT_AIR_DAMAGE_DISPLAY, "spinner"],
      [::USEROPT_GUNNER_FPS_CAMERA, "spinner"],

      ["options/header/tank"],
      [::USEROPT_GRASS_IN_TANK_VISION, "spinner"],
      [::USEROPT_XRAY_DEATH, "spinner", ::has_feature("Tanks") && ::has_feature("XrayDeath")],
      [::USEROPT_XRAY_KILL, "spinner", ::has_feature("Tanks") && ::has_feature("XrayKill")],
      [::USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT, "spinner",
        ::has_feature("Tanks") && ( ! isInFlight || ! ::is_tank_gunner_camera_from_sight_available())],
      [::USEROPT_TANK_ALT_CROSSHAIR, "spinner", ::has_feature("Tanks")],
      [::USEROPT_SHOW_DESTROYED_PARTS, "spinner", ::has_feature("Tanks")],
      [::USEROPT_TACTICAL_MAP_SIZE, "slider"],
      [::USEROPT_MAP_ZOOM_BY_LEVEL, "spinner"],

      ["options/header/ship"],
      [::USEROPT_DEPTHCHARGE_ACTIVATION_TIME, "spinner", ! isInFlight],
      // TODO: separate from tank [::USEROPT_TACTICAL_MAP_SIZE, "slider"],
      // TODO: separate from tank [::USEROPT_MAP_ZOOM_BY_LEVEL, "spinner"],

      ["options/header/interface"],
      [::USEROPT_HUD_SCREEN_SAFE_AREA, "spinner", safeAreaHud.canChangeValue()],
      [::USEROPT_GAME_HUD, "spinner", isInFlight],
      [::USEROPT_GAMMA, "slider", ::can_change_gamma()],
      [::USEROPT_HUD_INDICATORS, "spinner", "get_option_hud_indicators" in getroottable()],
      [::USEROPT_HUE_SQUAD, "spinner"],
      [::USEROPT_HUE_ALLY, "spinner"],
      [::USEROPT_HUE_ENEMY, "spinner"],
      [::USEROPT_STROBE_ALLY, "spinner"],
      [::USEROPT_STROBE_ENEMY, "spinner"],
      [::USEROPT_HUD_SHOW_FUEL, "spinner"],
      [::USEROPT_HUD_SHOW_AMMO, "spinner"],
      [::USEROPT_HUD_SHOW_TEMPERATURE, "spinner"],
      [::USEROPT_INGAME_VIEWTYPE, "spinner", isInFlight && canChangeViewType],

      ["options/header/measureUnits"],
      [::USEROPT_MEASUREUNITS_SPEED, "spinner"],
      [::USEROPT_MEASUREUNITS_ALT, "spinner"],
      [::USEROPT_MEASUREUNITS_DIST, "spinner"],
      [::USEROPT_MEASUREUNITS_CLIMBSPEED, "spinner"],
      [::USEROPT_MEASUREUNITS_TEMPERATURE, "spinner"],

      ["options/header/playersMarkers"],
      [::USEROPT_SHOW_INDICATORS, "spinner"],
      [::USEROPT_SHOW_INDICATORS_TYPE, "spinner"],
      [::USEROPT_SHOW_INDICATORS_NICK, "spinner"],
      [::USEROPT_SHOW_INDICATORS_AIRCRAFT, "spinner"],
      [::USEROPT_SHOW_INDICATORS_TITLE, "spinner"],
      [::USEROPT_SHOW_INDICATORS_DIST, "spinner"],

      ["options/header/chatAndVoiceChat"],
      [::USEROPT_ONLY_FRIENDLIST_CONTACT, "spinner", ! isInFlight],
      [::USEROPT_AUTO_SHOW_CHAT, "spinner"],
      [::USEROPT_CHAT_MESSAGES_FILTER, "spinner"],
      [::USEROPT_CHAT_FILTER, "spinner"],

      //TODO fillVoiceChatOptions
      //[::USEROPT_VOICE_CHAT, "spinner"],
      //[::USEROPT_VOLUME_VOICE_IN, "slider"],
      //[::USEROPT_VOLUME_VOICE_OUT, "slider"],
      //[::USEROPT_PTT, "spinner"],
      //[::USEROPT_VOICE_DEVICE_OUT, "combobox", ! ::is_platform_ps4 && ::gchat_voice_get_device_out_count() > 0]
      //[::USEROPT_VOICE_DEVICE_IN, "combobox", ! ::is_platform_ps4 && ::gchat_voice_get_device_in_count() > 0]

      ["options/header/gamepad"],
      [::USEROPT_XCHG_STICKS, "spinner"],
      [::USEROPT_VIBRATION, "spinner"],
      [::USEROPT_ENABLE_CONSOLE_MODE, "spinner", !::get_is_console_mode_force_enabled()],
      [::USEROPT_GAMEPAD_CURSOR_CONTROLLER, "spinner",
        ! isInFlight && ::g_gamepad_cursor_controls.canChangeValue()],
      [::USEROPT_USE_CONTROLLER_LIGHT, "spinner", ::is_platform_ps4 && ::has_feature("ControllerLight")],

      ["options/header/replaysAndSpectatorMode"],
      [::USEROPT_AUTOSAVE_REPLAYS, "spinner", ! isInFlight],
      [::USEROPT_HUE_SPECTATOR_ALLY, "spinner"],
      [::USEROPT_HUE_SPECTATOR_ENEMY, "spinner"],
      [::USEROPT_REPLAY_ALL_INDICATORS, "spinner"],

      ["options/header/otherOptions"],
      [::USEROPT_MENU_SCREEN_SAFE_AREA, "spinner", safeAreaMenu.canChangeValue()],
      [::USEROPT_SUBTITLES, "spinner"],
      [::USEROPT_HUD_SCREENSHOT_LOGO, "spinner", ::is_platform_pc],
    ]
  }
}

function get_sound_options()
{
  return {
    name = "sound"
    options = [
      [::USEROPT_VOICE_MESSAGE_VOICE, "spinner"],
      [::USEROPT_SPEECH_TYPE "spinner", ! ::is_in_flight()],
      [::USEROPT_VOLUME_MASTER, "slider"],
      [::USEROPT_VOLUME_MUSIC, "slider"],
      [::USEROPT_VOLUME_MENU_MUSIC, "slider"],
      [::USEROPT_VOLUME_SFX, "slider"],
      [::USEROPT_VOLUME_ENGINE, "slider"],
      [::USEROPT_VOLUME_GUNS, "slider"],
      [::USEROPT_VOLUME_RADIO, "slider"],
      [::USEROPT_VOLUME_DIALOGS, "slider"],
      [::USEROPT_VOLUME_TINNITUS, "slider"],
      [::USEROPT_HANGAR_SOUND, "spinner"]
    ]
  }
}

function onApplySystemOptions()
{
  ::sysopt.onConfigApply()
}

function get_voicechat_options()
{
  local voice_options =
    { name = "voicechat"
      fillFuncName = "fillVoiceChatOptions"
      options = [
        [::USEROPT_VOICE_CHAT, "spinner"],
        [::USEROPT_VOLUME_VOICE_IN, "slider"],
        [::USEROPT_VOLUME_VOICE_OUT, "slider"],
        [::USEROPT_PTT, "spinner"]
      ]
    };

  if (!::is_ps4_or_xbox)
  {
    if (::gchat_voice_get_device_out_count() > 0)
      voice_options.options.insert(1, [::USEROPT_VOICE_DEVICE_OUT, "combobox"]);
    if (::gchat_voice_get_device_in_count() > 0)
      voice_options.options.insert(1, [::USEROPT_VOICE_DEVICE_IN, "combobox"]);
  }

  return voice_options;
}

function append_social_options(options)
{
  if(!::has_feature("Facebook"))
    return null

  local block = {
    name = "social"
    fillFuncName = "fillSocialOptions"
    options = []
  }

  options.append(block)
}

function append_internet_radio_options(options)
{
  if (!::has_feature("Radio"))
    return null

  local block = {
    name = "internet_radio"
    fillFuncName = "fillInternetRadioOptions"
    options = [
      [::USEROPT_INTERNET_RADIO_ACTIVE, "spinner"],
      [::USEROPT_INTERNET_RADIO_STATION, "combobox"],
    ]
  }
  options.append(block)
}

function can_change_gamma()
{
  return ::target_platform != "macosx" && (!::is_platform_windows || ::getSystemConfigOption("video/mode") == "fullscreen")
}

function gui_start_options(owner = null, curOption = null)
{
  local isInFlight = ::is_in_flight()
  if(isInFlight)
    ::init_options()

  local options =
  [
    get_main_options()
    get_sound_options()
  ]

  if(::sysopt.canUseGraphicsOptions())
    options.insert(1, ::get_system_options())

  if (::gchat_is_voice_enabled())
    options.append(get_voicechat_options())

  append_internet_radio_options(options)
  append_social_options(options)

  if(curOption != null)
    foreach(o in options)
      if (o.name == curOption)
        o.selected <- true;

  local params = {
    titleText = isInFlight ?
      ::is_multiplayer() ? null : ::loc("flightmenu/title")
      : ::loc("mainmenu/btnGameplay")
    optGroups = options
    wndOptionsMode = ::OPTIONS_MODE_GAMEPLAY
    sceneNavBlkName = "gui/options/navOptionsIngame.blk"
    owner = owner
  }
  params.cancelFunc <- function()
  {
    ::set_option_gamma(::get_option_gamma(), false)
    for (local i = 0; i < ::SND_NUM_TYPES; i++)
      ::set_sound_volume(i, ::get_sound_volume(i), false)
  }

  local handler = ::handlersManager.loadHandler(::gui_handlers.GroupOptionsModal, params)

  ::showBtn("btn_postfx_settings", !::is_compatibility_mode(), handler.scene)

  if (isInFlight && "WebUI" in getroottable())
    ::showBtn("web_ui_button", ::is_platform_pc && ::WebUI.get_port() != 0, handler.scene)
}
