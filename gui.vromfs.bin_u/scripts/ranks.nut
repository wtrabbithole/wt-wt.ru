const UNIT_PARAMS_INITED_KEY = "isInited"

::g_script_reloader.loadOnce("scripts/ranks_common.nut")
::g_script_reloader.loadOnce("scripts/custom_common.nut")

if (!("EUCT_TOTAL" in ::getroottable()))
  ::EUCT_TOTAL <- 7 //temporary to work without new exe

::pilot_icons_list <- []
::max_player_rank <- 100
::max_country_rank <- 6
::discounts <- { //count from const in warpointsBlk by (name + "Mul")
}
::event_muls <- {
  xpFirstWinInDayMul = 1.0
  wpFirstWinInDayMul = 1.0
}
::lockTimeMaxLimitSec <- 0

function update_pilot_icons_list()
{
  ::pilot_icons_list <- []
  local unlocksArray = ::g_unlocks.getUnlocksByTypeInBlkOrder("pilot")
  foreach(unlock in unlocksArray)
    ::pilot_icons_list.append(unlock.id)
}

function get_pilot_icon_by_id(id)
{
  return ::getTblValue(id, ::pilot_icons_list, "cardicon_default")
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
    "pilot_icons_list"
    "lockTimeMaxLimitSec", "discounts", "event_muls"
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
  ::current_user_profile.icon = ::get_pilot_icon_by_id(info.pilotId)
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

//--------------------------------------------------------
function update_aircraft_warpoints(maxCallTimeMsec = 0)
{
  local startTime = ::dagor.getCurTime()
  local ws = ::get_warpoints_blk()
  local cost = ::get_wpcost_blk()
  local modificationsBlk = ::get_modifications_blk()
  local modsBlkModifications = modificationsBlk.modifications
  local errorsTextArray = []

  local freeRepairs = ws.freeRepairs? ws.freeRepairs : 0
  ::lockTimeMaxLimitSec = ws.lockTimeMaxLimitSec

  local weaponProperties = [
    "reqRank", "reqExp", "mass_per_sec", "mass_per_sec_diff",
    "repairCostCoef", "repairCostCoefArcade", "repairCostCoefHistorical", "repairCostCoefSimulation",
    "caliber", "deactivationIsAllowed", "isTurretBelt", "bulletsIconParam"]
  local reqNames = ["reqWeapon", "reqModification"]
  local upgradeNames = ["weaponUpgrade1", "weaponUpgrade2", "weaponUpgrade3", "weaponUpgrade4"]

  local updateWeaponReq = (@(weaponProperties, reqNames, modsBlkModifications) function(unitType, weapon, blk) {
    if (!::checkDataBlock(blk))
      return

    local weaponBlk = modsBlkModifications[weapon.name]
    if (blk.value != null)
      weapon.cost <- blk.value
    if (blk.costGold)
    {
      weapon.costGold <- blk.costGold
      weapon.cost <- 0
    }
    weapon.tier <- blk.tier? blk.tier.tointeger() : 1
    weapon.modClass <- (weaponBlk != null ? weaponBlk.modClass : null) || blk.modClass || ""
    weapon.image <- ::get_weapon_image(unitType, weaponBlk, blk)

    if (weapon.name == "tank_additional_armor")
      weapon.requiresModelReload <- true

    foreach(p in weaponProperties)
    {
      local val = (blk != null ? blk[p] : null) ||
        (weaponBlk != null ? weaponBlk[p] : null)
      if (val != null)
        weapon[p] <- val
    }

    local prevModification = (blk && blk["prevModification"]) || (weaponBlk && weaponBlk["prevModification"])
    if (::u.isString(prevModification) && prevModification.len())
      weapon["prevModification"] <- prevModification

    foreach(rp in reqNames)
    {
      local reqData = []
      foreach (req in (blk % rp))
        if (::u.isString(req) && req.len())
          reqData.append(req)
      if (reqData.len() > 0)
        weapon[rp] <- reqData
    }
  })(weaponProperties, reqNames, modsBlkModifications)

  local getWeaponUpgrades = (@(upgradeNames) function(weapon, blk) {
    foreach(upgradeName in upgradeNames)
    {
      if (!blk[upgradeName])
        break

      if (!("weaponUpgrades" in weapon))
        weapon.weaponUpgrades <- []
      weapon.weaponUpgrades.append(::split(blk[upgradeName], "/"))
    }
  })(upgradeNames)

  foreach (air in ::all_units)
  {
    if (UNIT_PARAMS_INITED_KEY in air)
      continue

    local ac = cost[air.name]
    if (::checkDataBlock(ac))
    {
      local unitType = ::get_es_unit_type(air)
      air.cost <- ac.value
      if (ac.costGold != null)
        air.costGold <- ac.costGold
      air.repairCost <- ac.repairCost
      air.repairTimeHrsArcade     <- ac.repairTimeHrsArcade     || 0
      air.repairTimeHrsHistorical <- ac.repairTimeHrsHistorical || 0
      air.repairTimeHrsSimulation <- ac.repairTimeHrsSimulation || 0
      air.freeRepairs <- (ac.freeRepairs!=null)? ac.freeRepairs : freeRepairs
      if (ac.gift!=null) air.gift <- ac.gift
      if (ac.giftParam!=null) air.giftParam <- ac.giftParam
      if (ac.premPackAir!=null) air.premPackAir <- ac.premPackAir

      foreach (weapon in air.weapons)
        weapon.type <- ::g_weaponry_types.WEAPON.type

      if (::checkDataBlock(ac.weapons))
      {
        foreach (weapon in air.weapons)
          if (ac.weapons[weapon.name])
            updateWeaponReq(unitType, weapon, ac.weapons[weapon.name])
        getWeaponUpgrades(air, ac)
      }

      air.modifications <- []
      if (::checkDataBlock(ac.modifications))
        foreach(modName, modBlk in ac.modifications)
        {
          local mod = { name = modName, type = ::g_weaponry_types.MODIFICATION.type }
          air.modifications.append(mod)
          updateWeaponReq(unitType, mod, modBlk)
          getWeaponUpgrades(mod, modBlk)
          if (::is_modclass_expendable(mod))
            mod.type = ::g_weaponry_types.EXPENDABLES.type

          if (modBlk.maxToRespawn)
            mod.maxToRespawn <- modBlk.maxToRespawn

          //validate prevModification. it used in gui only.
          if (("prevModification" in mod) && !(ac.modifications[mod.prevModification]))
            errorsTextArray.append(format("Not exist prevModification '%s' for '%s' (%s)",
                                   delete mod.prevModification, modName, air.name))
        }

      if (::checkDataBlock(ac.spare))
      {
        air.spare <- {
          name = "spare"
          type = ::g_weaponry_types.SPARE.type
          cost = ac.spare.value? ac.spare.value : 0
          image = ::get_weapon_image(unitType, modsBlkModifications.spare, ac.spare)
        }
        if (ac.spare.costGold != null)
          air.spare.costGold <- ac.spare.costGold
      }

      air.commonWeaponImage <-  ac.commonWeaponImage? ac.commonWeaponImage : "#ui/gameuiskin#weapon"
      local tiersCountForUnlock = 4
      local tierUnlock = array(tiersCountForUnlock, 1)
      for(local i = 1; i < tiersCountForUnlock+1; i++)
      {
        tierUnlock[i-1] = 0
        if(ac["needBuyToOpenNextInTier" + i.tostring()])
          tierUnlock[i-1] = ac["needBuyToOpenNextInTier" + i.tostring()]
      }
      air.needBuyToOpenNextInTier <- tierUnlock
    }
    else
    {
      air.cost <- 0
      air.repairCost <- 0
      air.repairTimeHrsArcade     <- 0
      air.repairTimeHrsHistorical <- 0
      air.repairTimeHrsSimulation <- 0
    }

    air[UNIT_PARAMS_INITED_KEY] <- true

    if (maxCallTimeMsec && ::dagor.getCurTime() - startTime >= maxCallTimeMsec)
    {
      ::dagor.assertf(errorsTextArray.len() == 0, ::g_string.implode(errorsTextArray, "\n"))
      return PT_STEP_STATUS.SUSPEND
    }
  }

  //update discounts info
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
  local crews = ::get_crew_info()
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
