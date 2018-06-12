::g_script_reloader.loadOnce("scripts/ranks_common_shared.nut")

local avatars = ::require("scripts/user/avatars.nut")

if (!("EUCT_TOTAL" in ::getroottable()))
  ::EUCT_TOTAL <- 7 //temporary to work without new exe

::max_player_rank <- 100
::max_country_rank <- 6
::discounts <- { //count from const in warpointsBlk by (name + "Mul")
}
::event_muls <- {
  xpFirstWinInDayMul = 1.0
  wpFirstWinInDayMul = 1.0
}

::current_user_profile <- {
  name = ""
  icon = "cardicon_default"
  pilotId = 0
  country = "country_ussr"
  balance = 0
  rank = 0
  prestige = 0
  rankProgress = 0 //0..100
  medals = 0
  aircrafts = 0
  gold = 0

  exp = -1
  exp_by_country = {}
  ranks = {}
}

::exp_per_rank <- []
::prestige_by_rank <-[]

::g_script_reloader.registerPersistentData("RanksGlobals", ::getroottable(),
  [
    "discounts", "event_muls"
    "exp_per_rank", "max_player_rank", "prestige_by_rank"
  ])

function load_player_exp_table()
{
  local ranks_blk = ::get_ranks_blk()
  local efr = ranks_blk.exp_for_playerRank

  ::exp_per_rank <- []

  if (efr)
    for (local i = 0; i < efr.paramCount(); i++)
      ::exp_per_rank.append(efr.getParamValue(i))

  ::max_player_rank = ::exp_per_rank.len()
}

function init_prestige_by_rank()
{
  local blk = ::get_ranks_blk()
  local prestigeByRank = blk.prestige_by_rank

  ::prestige_by_rank = []
  if (!prestigeByRank)
    return

  for (local i = 0; i < prestigeByRank.paramCount(); i++)
    ::prestige_by_rank.append(prestigeByRank.getParamValue(i))
}

function get_cur_exp_table(country = "", profileData = null, rank = null, exp = null)
{
  local res = null //{ exp, rankExp }
  if (rank == null)
    rank = ::get_player_rank_by_country(country, profileData)
  local maxRank = (country == "") ? ::max_player_rank : ::max_country_rank

  if (rank < maxRank)
  {
    local expTbl = ::exp_per_rank
    if (rank >= expTbl.len())
      return res

    local prev = (rank > 0) ? expTbl[rank - 1] : 0
    local next = expTbl[rank]
    local cur = (exp == null)
                ? get_player_exp_by_country(country, profileData)
                : exp
    res = {
      rank    = rank
      exp     = cur - prev
      rankExp = next - prev
    }
  }
  return res
}

function get_player_rank_by_country(c = null, profileData=null)
{
  if (!profileData)
    profileData = ::current_user_profile
  if (c == null || c == "")
    return profileData.rank
  if (c in profileData.ranks)
    return profileData.ranks[c]
  return 0
}

function get_player_exp_by_country(c = null, profileData=null)
{
  if (!profileData)
    profileData = ::current_user_profile
  if (c == null || c == "")
    return profileData.exp
  if (c in profileData.exp_by_country)
    return profileData.exp_by_country[c]
  return 0
}

function get_rank_by_exp(exp)
{
  local rank = 0
  local rankTbl = ::exp_per_rank
  for (local i = 0; i < rankTbl.len(); i++)
    if (exp >= rankTbl[i])
      rank++

  return rank
}

function calc_rank_progress(profileData = null)
{
  local rankTbl = ::get_cur_exp_table("", profileData)
  if (rankTbl)
    return (1000.0 * rankTbl.exp.tofloat() / rankTbl.rankExp.tofloat()).tointeger()
  return -1
}

function get_prestige_by_rank(rank)
{
  for (local i = ::prestige_by_rank.len() - 1; i >= 0; i--)
    if (rank >= ::prestige_by_rank[i])
      return i
  return 0
}

function get_cur_session_country()
{
  if (::is_multiplayer())
  {
    local sessionInfo = ::get_mp_session_info()
    local team = ::get_mp_local_team()
    if (team==1)
      return sessionInfo.alliesCountry
    if (team==2)
      return sessionInfo.axisCountry
  }
  return null
}

function get_profile_info()
{
  local info = ::get_cur_rank_info()

  ::current_user_profile.name = info.name //::is_online_available() ? info.name : "" ;
  if (::my_user_name!=info.name && info.name!="")
    ::my_user_name = info.name

  ::current_user_profile.balance = info.wp
  ::current_user_profile.country = info.country || "country_0"
  ::current_user_profile.aircrafts = info.aircrafts
  ::current_user_profile.gold = info.gold
  ::current_user_profile.pilotId = info.pilotId
  ::current_user_profile.icon = avatars.getIconById(info.pilotId)
  ::current_user_profile.medals = ::get_num_unlocked(::UNLOCKABLE_MEDAL, true)
  //dagor.debug("unlocked medals: "+::current_user_profile.medals)

  //Show the current country in the game when you select an outcast.
  if (::current_user_profile.country=="country_0")
  {
    local country = ::get_cur_session_country()
    if (country && country!="")
      ::current_user_profile.country = "country_" + country
  }
  if (::current_user_profile.country!="country_0")
    ::current_user_profile.countryRank <- ::get_player_rank_by_country(::current_user_profile.country)

  local isInClan = ::has_feature("Clans") && (::clan_get_my_clan_id() != "-1")
  ::current_user_profile.clanTag <- isInClan ? ::clan_get_my_clan_tag() : ""
  ::current_user_profile.clanName <- isInClan  ? ::clan_get_my_clan_name() : ""
  ::current_user_profile.clanType <- isInClan  ? ::clan_get_my_clan_type() : ""
  ::clanUserTable[::my_user_name] <- ::current_user_profile.clanTag

  ::current_user_profile.exp <- info.exp
  ::current_user_profile.free_exp <- ::shop_get_free_exp()
  ::current_user_profile.rank <- ::get_rank_by_exp(::current_user_profile.exp)
  ::current_user_profile.prestige <- ::get_prestige_by_rank(::current_user_profile.rank)
  ::current_user_profile.rankProgress <- ::calc_rank_progress(::current_user_profile)

  return ::current_user_profile
}

function get_balance()
{
  local info = ::get_cur_rank_info()
  return { wp = info.wp, gold = info.gold }
}

function get_gui_balance()
{
  local info = ::get_cur_rank_info()
  return ::Balance(info.wp, info.gold, ::shop_get_free_exp())
}

function get_player_rank()
{
  return get_profile_info().rank;
}

function on_mission_started_mp()
{
  dagor.debug("on_mission_started_mp - CLIENT")
  ::g_streaks.clear()
  ::before_first_flight_in_session = true;
  ::clear_spawn_score();
  ::cur_mission_mode <- -1
  ::broadcastEvent("MissionStarted")
}

function get_weapon_image(unitType, weaponBlk, costBlk)
{
  if (unitType == ::ES_UNIT_TYPE_TANK)
  {
    return (costBlk != null ? costBlk.image_tank : null) ||
      (weaponBlk != null ? weaponBlk.image_tank : null) ||
      (costBlk != null ? costBlk.image : null) ||
      (weaponBlk != null ? weaponBlk.image : null) ||
      ""
  }
  else if (unitType == ::ES_UNIT_TYPE_AIRCRAFT)
  {
    return (costBlk != null ? costBlk.image_aircraft : null) ||
      (weaponBlk != null ? weaponBlk.image_aircraft : null) ||
      (costBlk != null ? costBlk.image : null) ||
      (weaponBlk != null ? weaponBlk.image : null) ||
      ""
  }
  else // unitType == ::ES_UNIT_TYPE_INVALID
  {
    return (costBlk != null ? costBlk.image : null) ||
      (weaponBlk != null ? weaponBlk.image : null) ||
      ""
  }
}

//!!FIX ME: should to remove from this function all what not about unit.
function update_aircraft_warpoints(maxCallTimeMsec = 0)
{
  local startTime = ::dagor.getCurTime()
  local errorsTextArray = []
  foreach (unit in ::all_units)
  {
    if (unit.isInited)
      continue

    local errors = unit.initOnce()
    if (errors)
      errorsTextArray.extend(errors)

    if (maxCallTimeMsec && ::dagor.getCurTime() - startTime >= maxCallTimeMsec)
    {
      ::dagor.assertf(errorsTextArray.len() == 0, ::g_string.implode(errorsTextArray, "\n"))
      return PT_STEP_STATUS.SUSPEND
    }
  }

  //update discounts info
  local ws = ::get_warpoints_blk()
  foreach(name, value in ::discounts)
    if (ws[name+"DiscountMul"]!=null)
      ::discounts[name] = (100.0*(1.0 - ws[name+"DiscountMul"])+0.5).tointeger()

  //update bonuses info
  foreach(name, value in ::event_muls)
    if (ws[name]!=null)
      ::event_muls[name] = ws[name]

  ::min_values_to_show_reward_premium.wp = ws.wp_to_show_premium_reward || 0
  ::min_values_to_show_reward_premium.exp = ws.exp_to_show_premium_reward || 0

  ::dagor.assertf(errorsTextArray.len() == 0, ::g_string.implode(errorsTextArray, "\n"))
  return PT_STEP_STATUS.NEXT_STEP
}

function checkAllowed(tbl)
{
  if (::disable_network())
    return true;

  local silent = (("silent" in tbl) && tbl.silent)

  if ("silentFeature" in tbl)
    if (!::has_feature(tbl.silentFeature))
    {
      if (!silent)
      {
        local handler = this
        msgBox("in_demo_only", ::loc("msgbox/notAvailbleInDemo"),
               [["ok", (@(handler) function() {if ("stopSearch" in handler) handler.stopSearch = false;})(handler) ]], "ok")
      }
      return false
    }

  if ("minLevel" in tbl)
    if (::get_profile_info().rank < tbl.minLevel)
    {
      if (!silent)
      {

        local handler = this
        msgBox("in_demo_only", ::format(::loc("charServer/needRankFmt"), tbl.minLevel),
               [["ok", (@(handler) function() {if ("stopSearch" in handler) handler.stopSearch = false;})(handler) ]], "ok")
      }
      return false
    }

  if (("minRank" in tbl) && ("rankCountry" in tbl))
    if (!haveCountryRankAir("country_"+tbl.rankCountry, tbl.minRank))
    {
      if (!silent)
      {
        local country = "country_"+tbl.rankCountry
        local handler = this
        msgBox("in_demo_only", ::loc("charServer/needAirRankFmt", { tier = tbl.minRank, country = ::loc(country) }),
               [["ok", (@(handler) function() {if ("stopSearch" in handler) handler.stopSearch = false;})(handler) ]], "ok")
      }
      return false;
    }

  if ("unlock" in tbl)
  {
    if (!::is_unlocked_scripted(::UNLOCKABLE_SINGLEMISSION, tbl.unlock) && !::is_debug_mode_enabled)
    {
      if (!silent)
      {
        local after = function() {
          if (::session_list_handler)
            if ("stopSearch" in ::session_list_handler)
              ::session_list_handler.stopSearch = false;
        }
        ::show_sm_unlock_description(tbl.unlock, after)
      }
      return false;
    }
  }

  //check entitlement - this is always last
  if ("entitlement" in tbl)
  {
    if (::has_entitlement(tbl.entitlement))
      return true;
    else if (!silent && (tbl.entitlement == "PremiumAccount"))
    {
      local guiScene = ::get_gui_scene()
      local handler = this
      if (!handler || handler == getroottable())
        handler = ::get_cur_base_gui_handler()
      local askFunc = (@(guiScene, handler) function(locText, entitlement) {
        if (::has_feature("EnablePremiumPurchase"))
        {
          local text = ::loc("charServer/noEntitlement/"+locText)
          handler.msgBox("no_entitlement", text,
          [
            ["yes", (@(guiScene, handler, entitlement) function() { guiScene.performDelayed(handler, (@(entitlement) function() {
                onOnlineShopPremium();
              })(entitlement)) })(guiScene, handler, entitlement) ],
            ["no", function() {} ]
          ], "yes")
        }
        else
          ::scene_msg_box("premium_not_available", null, ::loc("charServer/notAvailableYet"),
            [["cancel"]], "cancel")
      })(guiScene, handler)

      askFunc("loc" in tbl ? tbl.loc : tbl.entitlement, tbl.entitlement);
    }
    return false;
  }
  return true;
}

function get_aircraft_rank(curAir)
{
  local wpcost = ::get_wpcost_blk()
  return (curAir in wpcost) ? wpcost[curAir].rank : 0
}

function haveCountryRankAir(country, rank)
{
  local crews = ::g_crews_list.get()
  foreach (c in crews)
    if (c.country == country)
      foreach(crew in c.crews)
        if (("aircraft" in crew) && get_aircraft_rank(crew.aircraft)>=rank)
          return true
  return false
}

function getExpMulWithDiff(diff)
{
  local blk = ::get_ranks_blk()
  return blk.getReal("expMulWithDiff"+diff.tostring(), 1.0)
}
