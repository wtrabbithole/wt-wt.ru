const COOP_MAX_PLAYERS = 4

::enable_coop_in_QMB <- false
::enable_coop_in_DynCampaign <- false
::enable_coop_in_SingleMissions <- false
::enable_custom_battles <- false

enum MIS_PROGRESS //value received from get_mission_progress
{
  COMPLETED_ARCADE    = 0
  COMPLETED_REALISTIC = 1
  COMPLETED_SIMULATOR = 2
  UNLOCKED            = 3 //unlocked but not completed
  LOCKED              = 4
}

::g_script_reloader.registerPersistentData("MissionsUtilsGlobals", ::getroottable(),
  [
    "enable_coop_in_QMB", "enable_coop_in_DynCampaign", "enable_coop_in_SingleMissions", "enable_custom_battles"
  ])

function is_mission_complete(chapterName, missionName) //different by mp_modes
{
  local progress = ::get_mission_progress(chapterName + "/" + missionName)
  return progress >= 0 && progress < 3
}

function is_mission_unlocked(info)
{
  if (!(::get_game_type() & ::GT_COOPERATIVE))
    return true

  local name = info.getStr("name","")
  local chapterName = info.getStr("chapter",::get_cur_game_mode_name())
  local progress = ::get_mission_progress(chapterName + "/" + name)
  return progress < 4 || ::is_debug_mode_enabled
}

function is_user_mission(missionBlk)
{
  return missionBlk.userMission == true //can be null
}

function can_play_gamemode_by_squad(gm)
{
  if (!::g_squad_manager.isNotAloneOnline())
    return true

  if (gm == ::GM_SINGLE_MISSION)
    return ::enable_coop_in_SingleMissions
  if (gm == ::GM_DYNAMIC)
    return ::enable_coop_in_DynCampaign
  if (gm == ::GM_BUILDER)
    return ::enable_coop_in_QMB
  if (gm == ::GM_SKIRMISH)
    return ::enable_custom_battles

  return false
}

//return 0 when no limits
function get_max_players_for_gamemode(gm)
{
  if (::isInArray(gm, [::GM_SINGLE_MISSION, ::GM_DYNAMIC, ::GM_BUILDER]))
    return COOP_MAX_PLAYERS
  return 0
}

function is_skirmish_with_killstreaks(misBlk)
{
  return misBlk.getBool("allowedKillStreaks", false);
}

function is_tank_bots_allowed(misBlk)
{
  return misBlk.getBool("isTanksAllowed", false)
}

function is_ship_bots_allowed(misBlk)
{
  return misBlk.getBool("isShipsAllowed", false)
}

function is_mission_for_tanks(misBlk)
{
  // Works for missions in Skirmish.
  if (misBlk && is_tank_bots_allowed(misBlk))
    return true

  local fullMissionBlk = null
  local url = ::getTblValue("url", misBlk)
  if (url != null)
    fullMissionBlk = ::getTblValue("fullMissionBlk", ::g_url_missions.findMissionByUrl(url))
  else
    fullMissionBlk = misBlk && misBlk.mis_file && ::DataBlock(misBlk.mis_file)

  if (fullMissionBlk)
    return has_tanks_in_full_mission_blk(fullMissionBlk)

  return false
}

function has_tanks_in_full_mission_blk(fullMissionBlk)
{
  local unitsBlk = fullMissionBlk && fullMissionBlk.units
  local playerBlk = fullMissionBlk && ::get_blk_value_by_path(fullMissionBlk, "mission_settings/player")
  local wings = playerBlk ? (playerBlk % "wing") : []
  local unitsCache = {}
  if (unitsBlk && wings.len())
    for (local i = 0; i < unitsBlk.blockCount(); i++)
    {
      local block = unitsBlk.getBlock(i)
      if (block && ::isInArray(block.name, wings))
        if (block.unit_class) // && ::isTank(::findUnitNoCase(block.unit_class)))
        {
          if (!(block.unit_class in unitsCache))
            unitsCache[block.unit_class] <- ::isTank(::findUnitNoCase(block.unit_class))
          if (unitsCache[block.unit_class])
            return true
        }
    }

  return false
}

function select_next_avail_campaign_mission(chapterName, missionName)
{
  if (::get_game_mode() != ::GM_CAMPAIGN)
    return

  local misList = ::g_mislist_type.BASE.getMissionsList(true)
  local isCurFound = false
  foreach(mission in misList)
  {
    if (mission.isHeader || !mission.isUnlocked)
      continue

    if (!isCurFound)
    {
      if (mission.id == missionName && mission.chapter == chapterName)
        isCurFound = true
      continue
    }

    ::add_last_played(mission.chapter, mission.id, ::GM_CAMPAIGN, false)
    break
  }
}

function buildRewardText(name, reward, highlighted=false, coloredIcon=false, additionalReward = false)
{
  local rewText = reward.tostring()
  if (rewText != "")
  {
    if (highlighted)
      rewText = ::format("<color=@highlightedTextColor>%s</color>", (additionalReward? ("+(" + rewText + ")") : rewText))
    rewText = name + ((name != "")? ::loc("ui/colon"): "") + rewText
  }
  return rewText
}

function getRewardTextByBlk(dataBlk, misName, diff, langId, highlighted=false, coloredIcon=false,
                            additionalReward = false, rewardMoney = null)
{
  local res = ""
  local misDataBlk = dataBlk[misName]

  if (!rewardMoney)
  {
    local getRewValue = (@(dataBlk, misDataBlk, diff) function(key, def = null) {
      local pId = key + "EarnedWinDiff" + diff
      return (misDataBlk && misDataBlk[pId]!=null) ? misDataBlk[pId] : (dataBlk[pId]!=null)? dataBlk[pId] : def
    })(dataBlk, misDataBlk, diff)

    local muls = ::get_player_multipliers()
    rewardMoney = ::Cost(getRewValue("wp", 0) * muls.wpMultiplier,
                            getRewValue("gold", 0),
                            getRewValue("xp", 0) * muls.xpMultiplier)
  }

  res = buildRewardText(::loc(langId), rewardMoney, highlighted, coloredIcon, additionalReward)
  if (diff == 0 && misDataBlk && misDataBlk.slot)
  {
    local slot = misDataBlk.slot;
    foreach(c in ::g_crews_list.get())
      if (c.crews.len() < slot || (c.crews.len() == slot && c.crews[slot-1].isEmpty == 1))
      {
        res += ((res=="")? "" : ", ") + ::loc("options/crewName") + slot
        break
      }
  }
  return res
}

function add_mission_list_full(gm_builder, add, dynlist)
{
  add_custom_mission_list_full(gm_builder, add, dynlist)
  ::game_mode_maps.clear()
}

function get_mission_meta_info(missionName)
{
  local urlMission = ::g_url_missions.findMissionByName(missionName)
  if (urlMission != null)
    return urlMission.getMetaInfo()

  return ::get_meta_mission_info_by_name(missionName)
}

function gui_start_campaign(checkPack = true)
{
  if (checkPack)
    return ::check_package_and_ask_download("hc_pacific", null, ::gui_start_campaign_no_pack, null, "campaign")

  ::gui_start_mislist(true, ::GM_CAMPAIGN)

  if (::check_for_victory && ! ::is_system_ui_active())
  {
    ::check_for_victory = false
    ::play_movie("video/victory", false, true, true)
  }
}

function gui_start_campaign_no_pack()
{
  ::gui_start_campaign(false)
}

function gui_start_menuCampaign()
{
  ::gui_start_mainmenu()
  ::gui_start_campaign()
}

function gui_start_singleMissions()
{
  ::gui_start_mislist(true, ::GM_SINGLE_MISSION)
}

function gui_start_menuSingleMissions()
{
  ::gui_start_mainmenu()
  ::gui_start_singleMissions()
}

function gui_start_userMissions()
{
  ::gui_start_mislist(true, ::GM_SINGLE_MISSION, { misListType = ::g_mislist_type.UGM })
}

function gui_create_skirmish()
{
  ::gui_start_mislist(true, ::GM_SKIRMISH)
}

function is_any_campaign_available()
{
  local mbc = ::get_meta_missions_info_by_campaigns(::GM_CAMPAIGN)
  foreach(item in mbc)
    if (::has_entitlement(item.name) || ::has_feature(item.name))
      return true
  return false
}

function gui_start_singleplayer_from_coop()
{
  ::select_game_mode(::GM_SINGLE_MISSION);
  gui_start_missions();
}

function gui_start_mislist(isModal=false, setGameMode=null, addParams = {})
{
  local hClass = isModal? ::gui_handlers.SingleMissionsModal : ::gui_handlers.SingleMissions
  local params = {
    return_func = isModal? gui_start_mislist : ::handlersManager.getLastBaseHandlerStartFunc()
  }
  foreach(key, value in addParams)
    params[key] <- value

  local gm = get_game_mode()
  if (setGameMode!=null)
  {
    params.wndGameMode <- setGameMode
    gm = setGameMode
  }

  params.canSwitchMisListType <- gm == ::GM_SKIRMISH

  local showAllCampaigns = gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION
  ::current_campaign_id = showAllCampaigns? null : ::get_game_mode_name(gm)
  params.showAllCampaigns <- showAllCampaigns

  if (!isModal)
  {
    params.backSceneFunc = ::gui_start_mainmenu
    if (::SessionLobby.isInRoom() && (::get_game_mode() == ::GM_DYNAMIC))
      params.backSceneFunc = ::gui_start_dynamic_summary
  }

  ::handlersManager.loadHandler(hClass, params)
  if (!isModal)
    ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mislist)
}

function gui_start_benchmark()
{
  if (::is_platform_ps4)
  {
    ::ps4_vsync_enabled = ::d3d_get_vsync_enabled()
    ::d3d_enable_vsync(false)
  }
  ::gui_start_mislist(true, ::GM_BENCHMARK)
}

function gui_start_tutorial()
{
  ::gui_start_mislist(true, ::GM_TRAINING)
}

function is_custom_battles_enabled() { return ::enable_custom_battles }

function init_coop_flags()
{
  ::enable_coop_in_QMB            <- ::has_feature(::is_platform_ps4 ? "QmbCoopPs4"            : "QmbCoopPc")
  ::enable_coop_in_DynCampaign    <- ::has_feature(::is_platform_ps4 ? "DynCampaignCoopPs4"    : "DynCampaignCoopPc")
  ::enable_coop_in_SingleMissions <- ::has_feature(::is_platform_ps4 ? "SingleMissionsCoopPs4" : "SingleMissionsCoopPc")
  ::enable_custom_battles         <- ::has_feature(::is_platform_ps4 ? "CustomBattlesPs4"      : "CustomBattlesPc")
  ::broadcastEvent("GameModesAvailability")
}