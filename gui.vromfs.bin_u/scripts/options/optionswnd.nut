function get_system_options()
{
  return {
    name = "graphicsParameters"
    fillFuncName = "fillSystemOptions"
    onApplyHandler = ::onApplySystemOptions
    options = []
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
        [::USEROPT_VOLUME_VOICE_IN, "sliderProgress"],
        [::USEROPT_VOLUME_VOICE_OUT, "sliderProgress"],
        [::USEROPT_PTT, "spinner"]
      ]
    };

  if (!::is_platform_ps4)
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

function gui_start_gameplay(owner = null, curOption = null)
{
  local tripleColorAerobaticsSmoke = ::has_feature("AerobaticTricolorSmoke");

  local options =
  [
    { name = "mainParameters"
      options = [
        [::USEROPT_LANGUAGE, "spinner", ::canSwitchGameLocalization()],
        [::USEROPT_CLUSTER, "spinner", ::is_platform_ps4],
        [::USEROPT_AUTOLOGIN, "spinner", !::is_platform_ps4],
        [::USEROPT_ONLY_FRIENDLIST_CONTACT, "spinner"],
        [::USEROPT_VIEWTYPE, "spinner"],
        //[::USEROPT_USE_TRACKIR_ZOOM, "spinner"],
        [::USEROPT_GUN_TARGET_DISTANCE, "spinner"],
        [::USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
        [::USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
        [::USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [::USEROPT_AEROBATICS_SMOKE_TYPE, "spinner"],
        [::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, "spinner", tripleColorAerobaticsSmoke],
        [::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, "spinner", tripleColorAerobaticsSmoke],
        [::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR, "spinner", tripleColorAerobaticsSmoke],
        [::USEROPT_SHOW_PILOT, "spinner"],
        [::USEROPT_AUTOPILOT_ON_BOMBVIEW, "spinner"],
        [::USEROPT_AUTOREARM_ON_AIRFIELD, "spinner"],
        [::USEROPT_VIBRATION, "spinner"],
        [::USEROPT_GRASS_IN_TANK_VISION, "spinner"],
        [::USEROPT_XCHG_STICKS, "spinner"],
        [::USEROPT_MEASUREUNITS_SPEED, "spinner"],
        [::USEROPT_MEASUREUNITS_ALT, "spinner"],
        [::USEROPT_MEASUREUNITS_DIST, "spinner"],
        [::USEROPT_MEASUREUNITS_CLIMBSPEED, "spinner"],
        [::USEROPT_MEASUREUNITS_TEMPERATURE, "spinner"],
        [::USEROPT_QUEUE_JIP, "spinner"],
        [::USEROPT_AUTO_SQUAD, "spinner"],
        [::USEROPT_AUTOSAVE_REPLAYS, "spinner"],
        [::USEROPT_GAMMA, "sliderProgress", ::can_change_gamma()],
        [::USEROPT_XRAY_DEATH, "spinner", ::has_feature("Tanks") && ::has_feature("XrayDeath")],
        [::USEROPT_USE_CONTROLLER_LIGHT, "spinner", ::is_platform_ps4 && ::has_feature("ControllerLight")],
        [::USEROPT_CAMERA_SHAKE_MULTIPLIER, "sliderProgress"],
      ]
    }
    { name = "interface"
      options = [
        [::USEROPT_FONTS_CSS, "spinner", ::can_change_fonts()],
        [::USEROPT_ENABLE_CONSOLE_MODE, "spinner", !::get_is_console_mode_force_enabled()],
        [::USEROPT_GAMEPAD_CURSOR_CONTROLLER, "spinner", ::g_gamepad_cursor_controls.canChangeValue()],
        [::USEROPT_MENU_SCREEN_SAFE_AREA, "spinner", ::g_option_menu_safearea.canChangeValue()],
        [::USEROPT_HUD_SCREEN_SAFE_AREA, "spinner", !::is_platform_ps4],
        //[::USEROPT_GAME_HUD, "spinner"],
        [::USEROPT_CROSSHAIR_TYPE, "combobox"],
        [::USEROPT_CROSSHAIR_COLOR, "combobox"],
        [::USEROPT_INDICATEDSPEED, "spinner"],
        [::USEROPT_AUTO_SHOW_CHAT, "spinner"],
        [::USEROPT_CHAT_MESSAGES_FILTER, "spinner"],
        [::USEROPT_CHAT_FILTER, "spinner"],
        [::USEROPT_DAMAGE_INDICATOR_SIZE, "sliderProgress"],
        [::USEROPT_TACTICAL_MAP_SIZE, "sliderProgress"],
        [::USEROPT_MAP_ZOOM_BY_LEVEL, "spinner"],
        [::USEROPT_SUBTITLES, "spinner"],
        [::USEROPT_CROSSHAIR_DEFLECTION, "spinner"],
        //[::USEROPT_CROSSHAIR_SPEED, "spinner"],
        [::USEROPT_SHOW_INDICATORS, "spinner"],
        [::USEROPT_SHOW_INDICATORS_TYPE, "spinner"],
        [::USEROPT_SHOW_INDICATORS_NICK, "spinner"],
        [::USEROPT_SHOW_INDICATORS_AIRCRAFT, "spinner"],
        [::USEROPT_SHOW_INDICATORS_TITLE, "spinner"],
        [::USEROPT_SHOW_INDICATORS_DIST, "spinner"],
        [::USEROPT_REPLAY_ALL_INDICATORS, "spinner"],
        [::USEROPT_HUD_SCREENSHOT_LOGO, "spinner", ::is_platform_pc],
        [::USEROPT_HUD_SHOW_BONUSES, "spinner"],
        [::USEROPT_HUD_SHOW_FUEL, "spinner"],
        [::USEROPT_HUD_SHOW_AMMO, "spinner"],
        [::USEROPT_HUD_SHOW_TEMPERATURE, "spinner"],
        [::USEROPT_HUD_INDICATORS, "spinner", "get_option_hud_indicators" in getroottable()],
        [::USEROPT_HUE_SQUAD, "spinner"],
        [::USEROPT_HUE_ALLY, "spinner"],
        [::USEROPT_HUE_ENEMY, "spinner"],
        [::USEROPT_STROBE_ALLY, "spinner"],
        [::USEROPT_STROBE_ENEMY, "spinner"],
        [::USEROPT_HUE_SPECTATOR_ALLY, "spinner"],
        [::USEROPT_HUE_SPECTATOR_ENEMY, "spinner"],
        [::USEROPT_AIR_DAMAGE_DISPLAY, "spinner"],
        [::USEROPT_XRAY_KILL, "spinner", ::has_feature("Tanks") && ::has_feature("XrayKill")],
        [::USEROPT_SHOW_DESTROYED_PARTS, "spinner", ::has_feature("Tanks")],
        [::USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT, "spinner", ::has_feature("Tanks")],

    //    [::USEROPT_SUBTITLES_RADIO, "spinner"],
    //    [::USEROPT_HUD_COLOR, "combobox"],
    //    [::USEROPT_AI_GUNNER_TIME, "spinner"],
      ]
    }
    { name = "sound"
      options = [
    //    [::USEROPT_ZOOM_SENSE, "sliderProgress"],
        [::USEROPT_VOICE_MESSAGE_VOICE, "spinner"],
        [::USEROPT_SPEECH_TYPE "spinner"],
        [::USEROPT_VOLUME_MASTER, "sliderProgress"],
        [::USEROPT_VOLUME_MUSIC, "sliderProgress"],
        [::USEROPT_VOLUME_MENU_MUSIC, "sliderProgress"],
        [::USEROPT_VOLUME_SFX, "sliderProgress"],
        [::USEROPT_VOLUME_ENGINE, "sliderProgress"],
        [::USEROPT_VOLUME_GUNS, "sliderProgress"],
        [::USEROPT_VOLUME_RADIO, "sliderProgress"],
        [::USEROPT_VOLUME_DIALOGS, "sliderProgress"],
        [::USEROPT_VOLUME_TINNITUS, "sliderProgress"],
        [::USEROPT_HANGAR_SOUND, "spinner"],
      ]
    }
  ]

  if(::sysopt.canUseGraphicsOptions())
    options.insert(1, ::get_system_options())

  if (::gchat_is_voice_enabled())
    options.append(get_voicechat_options());

  append_internet_radio_options(options)
  append_social_options(options)

  foreach(o in options)
    if (o.name == curOption)
      o.selected <- true;

  local params = {
    titleText = ::loc("mainmenu/btnGameplay")
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
}

function gui_start_ingameoptions(owner=null) //!!FIX ME: better to have one options generate function instead of 2
{
  ::init_options()

  local tripleColorAerobaticsSmoke = ::has_feature("AerobaticTricolorSmoke");

  local isFirstTutorial = (::current_campaign_name == "tutorial_pacific_41") &&
    (::current_campaign_mission == "tutorial01")
  local curUnit = ::get_player_cur_unit()
  local canChangeViewType = false
  if (!isFirstTutorial && curUnit)
    canChangeViewType = curUnit.unitType.canChangeViewType

  local options =
  [
    { name = "main"
      options = [
        [::USEROPT_INGAME_VIEWTYPE, "spinner", canChangeViewType],
        //[::USEROPT_USE_TRACKIR_ZOOM, "spinner"],
        //[::USEROPT_GUN_TARGET_DISTANCE, "spinner"],
        //[::USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
        //[::USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
        [::USEROPT_AEROBATICS_SMOKE_TYPE, "spinner"],
        [::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, "spinner", tripleColorAerobaticsSmoke],
        [::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, "spinner", tripleColorAerobaticsSmoke],
        [::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR, "spinner", tripleColorAerobaticsSmoke],
        [::USEROPT_SHOW_PILOT, "spinner"],
        [::USEROPT_AUTOPILOT_ON_BOMBVIEW, "spinner"],
        [::USEROPT_AUTOREARM_ON_AIRFIELD, "spinner"],
        [::USEROPT_VIBRATION, "spinner"],
        [::USEROPT_GRASS_IN_TANK_VISION, "spinner"],
        [::USEROPT_XCHG_STICKS, "spinner"],
        [::USEROPT_MEASUREUNITS_SPEED, "spinner"],
        [::USEROPT_MEASUREUNITS_ALT, "spinner"],
        [::USEROPT_MEASUREUNITS_DIST, "spinner"],
        [::USEROPT_MEASUREUNITS_CLIMBSPEED, "spinner"],
        [::USEROPT_MEASUREUNITS_TEMPERATURE, "spinner"],
        [::USEROPT_QUEUE_JIP, "spinner"],
        [::USEROPT_AUTO_SQUAD, "spinner"],
        [::USEROPT_GAMMA, "sliderProgress", ::can_change_gamma()],
        [::USEROPT_XRAY_DEATH, "spinner", ::has_feature("Tanks") && ::has_feature("XrayDeath")],
        [::USEROPT_USE_CONTROLLER_LIGHT, "spinner", ::is_platform_ps4 && ::has_feature("ControllerLight")],
        [::USEROPT_CAMERA_SHAKE_MULTIPLIER, "sliderProgress"],
      ]
    }
    { name = "interface"
      options = [
        [::USEROPT_FONTS_CSS, "spinner", ::can_change_fonts()],
        [::USEROPT_ENABLE_CONSOLE_MODE, "spinner", !::get_is_console_mode_force_enabled()],
        [::USEROPT_MENU_SCREEN_SAFE_AREA, "spinner", ::g_option_menu_safearea.canChangeValue()],
        [::USEROPT_HUD_SCREEN_SAFE_AREA, "spinner", !::is_platform_ps4],
        [::USEROPT_GAME_HUD, "spinner"],
        [::USEROPT_CROSSHAIR_TYPE, "combobox"],
        [::USEROPT_CROSSHAIR_COLOR, "combobox"],
        [::USEROPT_INDICATEDSPEED, "spinner"],
        [::USEROPT_AUTO_SHOW_CHAT, "spinner"],
        [::USEROPT_CHAT_MESSAGES_FILTER, "spinner"],
        [::USEROPT_CHAT_FILTER, "spinner"],
        [::USEROPT_DAMAGE_INDICATOR_SIZE, "sliderProgress"],
        [::USEROPT_TACTICAL_MAP_SIZE, "sliderProgress"],
        [::USEROPT_MAP_ZOOM_BY_LEVEL, "spinner"],
        [::USEROPT_SUBTITLES, "spinner"],
        [::USEROPT_CROSSHAIR_DEFLECTION, "spinner"],
        //[::USEROPT_CROSSHAIR_SPEED, "spinner"],
        [::USEROPT_SHOW_INDICATORS, "spinner"],
        [::USEROPT_SHOW_INDICATORS_TYPE, "spinner"],
        [::USEROPT_SHOW_INDICATORS_NICK, "spinner"],
        [::USEROPT_SHOW_INDICATORS_AIRCRAFT, "spinner"],
        [::USEROPT_SHOW_INDICATORS_TITLE, "spinner"],
        [::USEROPT_SHOW_INDICATORS_DIST, "spinner"],
        [::USEROPT_REPLAY_ALL_INDICATORS, "spinner"],
        [::USEROPT_HUD_SCREENSHOT_LOGO, "spinner", ::is_platform_pc],
        [::USEROPT_HUD_SHOW_BONUSES, "spinner"],
        [::USEROPT_HUD_SHOW_FUEL, "spinner"],
        [::USEROPT_HUD_SHOW_AMMO, "spinner"],
        [::USEROPT_HUD_SHOW_TEMPERATURE, "spinner"],
        [::USEROPT_HUD_INDICATORS, "combobox", "get_option_hud_indicators" in getroottable()],
        [::USEROPT_HUE_SQUAD, "spinner"],
        [::USEROPT_HUE_ALLY, "spinner"],
        [::USEROPT_HUE_ENEMY, "spinner"],
        [::USEROPT_STROBE_ALLY, "spinner"],
        [::USEROPT_STROBE_ENEMY, "spinner"],
        [::USEROPT_HUE_SPECTATOR_ALLY, "spinner"],
        [::USEROPT_HUE_SPECTATOR_ENEMY, "spinner"],
        [::USEROPT_AIR_DAMAGE_DISPLAY, "spinner"],
        [::USEROPT_XRAY_KILL, "spinner", ::has_feature("Tanks") && ::has_feature("XrayKill")],
        [::USEROPT_SHOW_DESTROYED_PARTS, "spinner", ::has_feature("Tanks")],
        [::USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT, "spinner", ::has_feature("Tanks") && !::is_tank_gunner_camera_from_sight_available()],
//        [::USEROPT_SUBTITLES_RADIO, "spinner"],
//        [::USEROPT_HUD_COLOR, "combobox"],
//        [::USEROPT_AI_GUNNER_TIME, "spinner"],
      ]
    }
    { name = "sound"
      options = [
        [::USEROPT_VOICE_MESSAGE_VOICE, "spinner"],

        [::USEROPT_VOLUME_MASTER, "sliderProgress"],
        [::USEROPT_VOLUME_MUSIC, "sliderProgress"],
        [::USEROPT_VOLUME_MENU_MUSIC, "sliderProgress"],
        [::USEROPT_VOLUME_SFX, "sliderProgress"],
        [::USEROPT_VOLUME_ENGINE, "sliderProgress"],
        [::USEROPT_VOLUME_GUNS, "sliderProgress"],
        [::USEROPT_VOLUME_RADIO, "sliderProgress"],
        [::USEROPT_VOLUME_DIALOGS, "sliderProgress"],
        [::USEROPT_VOLUME_TINNITUS, "sliderProgress"],
        [::USEROPT_HANGAR_SOUND, "spinner"],
      ]
    }
  ]

  if(::sysopt.canUseGraphicsOptions())
    options.insert(1, ::get_system_options())

  if (::gchat_is_voice_enabled())
    options.append(get_voicechat_options());

  append_internet_radio_options(options)
  append_social_options(options)

  local isMp = ::is_multiplayer()
  local params = {
    titleText = isMp? null : ::loc("flightmenu/title")
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

  if ("WebUI" in getroottable())
    ::showBtn("web_ui_button", ::is_platform_pc && ::WebUI.get_port() != 0, handler.scene)
}
