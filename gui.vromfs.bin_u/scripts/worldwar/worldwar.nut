local time = require("scripts/time.nut")
local operationPreloader = require("scripts/worldWar/externalServices/wwOperationPreloader.nut")


const WW_CUR_OPERATION_SAVE_ID = "worldWar/curOperation"
const WW_CUR_OPERATION_COUNTRY_SAVE_ID = "worldWar/curOperationCountry"
const WW_LAST_OPERATION_LOG_SAVE_ID = "worldWar/lastReadLog/operation"
const WW_UNIT_WEAPON_PRESET_PATH = "worldWar/weaponPreset/"
const WW_SKIP_BATTLE_WARNINGS_SAVE_ID = "worldWar/skipBattleWarnings"

enum WW_ARMY_ACTION_STATUS
{
  IDLE = 0
  IN_MOVE = 1
  ENTRENCHED = 2
  IN_BATTLE = 3

  UNKNOWN = 100
}

enum WW_ARMY_RELATION_ID
{
  CLAN,
  ALLY
}

enum WWGS_REFRESH_DELAY //Msec
{
  FORCED = 0
  EXTERNAL_REQUEST = 15000
  LATENT_QUEUE_REFRESH = 60000
}

enum WW_GLOBAL_STATUS_TYPE //bit enum
{
  QUEUE              = 0x0001
  ACTIVE_OPERATIONS  = 0x0002
  MAPS               = 0x0004
  OPERATIONS_GROUPS  = 0x0008

  //masks
  ALL                = 0x000F
}

enum WW_MAP_PRIORITY //bit enum
{
  NONE                       = 0
  HAS_ACTIVE_OPERATIONS      = 0x0001
  CAN_JOIN_BY_ARMY_RELATIONS = 0x0002
  MY_CLAN_IN_QUEUE           = 0x0004
  CAN_JOIN_BY_MY_CLAN        = 0x0008
  LAST_PLAYED                = 0x0010

  MAX                        = 0xFFFF
}

enum WW_BATTLE_ACCESS
{
  NONE     = 0
  OBSERVER = 0x0001
  MANAGER  = 0x0002

  SUPREME  = 0xFFFF
}

enum WW_UNIT_CLASS
{
  FIGHTER  = 0x0001
  BOMBER   = 0x0002
  UNKNOWN  = 0x0004

  NONE   = 0x0000
  COMBINED = 0x0003
}

enum WW_BATTLE_UNITS_REQUIREMENTS
{
  NO_REQUIREMENTS   = "allow"
  BATTLE_UNITS      = "battle"
  OPERATION_UNITS   = "global"
  NO_MATCHING_UNITS = "deny"
}

enum WW_BATTLE_CANT_JOIN_REASON
{
  CAN_JOIN
  NO_WW_ACCESS
  NOT_ACTIVE
  UNKNOWN_SIDE
  WRONG_SIDE
  EXCESS_PLAYERS
  NO_TEAM
  NO_COUNTRY_IN_TEAM
  NO_COUNTRY_BY_SIDE
  NO_TEAM_NAME_BY_SIDE
  TEAM_FULL
  UNITS_NOT_ENOUGH_AVAILABLE
  SQUAD_NOT_LEADER
  SQUAD_WRONG_SIDE
  SQUAD_TEAM_FULL
  SQUAD_NOT_ALL_READY
  SQUAD_MEMBER_ERROR
  SQUAD_UNITS_NOT_ENOUGH_AVAILABLE
  SQUAD_HAVE_UNACCEPTED_INVITES
  SQUAD_NOT_ALL_CREWS_READY
}

enum mapObjectSelect {
  NONE,
  ARMY,
  REINFORCEMENT,
  AIRFIELD,
  BATTLE,
  LOG_ARMY
}

enum WW_ARMY_GROUP_ICON_SIZE {
  BASE   = "base",
  SMALL  = "small",
  MEDIUM = "medium"
}

enum WW_MAP_HIGHLIGHT {
  LAYER_0,
  LAYER_1,
  LAYER_2,
  LAYER_3
}

enum WW_UNIT_SORT_CODE {
  AIR,
  GROUND,
  WATER,
  ARTILLERY,
  INFANTRY,
  UNKNOWN
}

strength_unit_expclass_group <- {
  bomber = "bomber"
  assault = "bomber"
  heavy_tank = "tank"
  tank = "tank"
  tank_destroyer = "tank"
  exp_torpedo_boat = "ships"
  exp_gun_boat = "ships"
  exp_torpedo_gun_boat = "ships"
  exp_submarine_chaser = "ships"
  exp_destroyer = "ships"
  exp_naval_ferry_barge = "ships"
}

::ww_gui_bhv <- {}

foreach (fn in [
                 "services/wwService.nut"
                 "externalServices/worldWarTopMenuButtons.nut"
                 "externalServices/worldWarTopMenuSectionsConfigs.nut"
                 "externalServices/wwQueue.nut"
                 "externalServices/inviteWwOperation.nut"
                 "externalServices/inviteWwOperationBattle.nut"
                 "bhvWorldWarMap.nut"
                 "model/wwUnitType.nut"
                 "inOperation/wwOperations.nut"
                 "inOperation/model/wwOperationArmies.nut"
                 "inOperation/model/wwOperationModel.nut"
                 "inOperation/model/wwAirfield.nut"
                 "inOperation/model/wwFormation.nut"
                 "inOperation/model/wwAirfieldFormation.nut"
                 "inOperation/model/wwCustomFormation.nut"
                 "inOperation/model/wwAirfieldCooldownFormation.nut"
                 "inOperation/model/wwArmy.nut"
                 "inOperation/model/wwArmyOwner.nut"
                 "inOperation/model/wwPathTracker.nut"
                 "inOperation/model/wwArtilleryAmmo.nut"
                 "inOperation/model/wwArmyGroup.nut"
                 "inOperation/model/wwBattle.nut"
                 "inOperation/model/wwBattleResults.nut"
                 "inOperation/model/wwUnit.nut"
                 "inOperation/model/wwObjectivesTypes.nut"
                 "inOperation/model/wwArmyMoveState.nut"
                 "inOperation/model/wwReinforcementArmy.nut"
                 "inOperation/model/wwMapControlsButtons.nut"
                 "inOperation/model/wwMapInfoTypes.nut"
                 "inOperation/model/wwMapReinforcementTabType.nut"
                 "inOperation/model/wwArmiesStatusTabType.nut"
                 "inOperation/model/wwOperationLog.nut"
                 "inOperation/model/wwOperationLogTypes.nut"
                 "inOperation/view/wwObjectiveView.nut"
                 "inOperation/view/wwArmyView.nut"
                 "inOperation/view/wwBattleView.nut"
                 "inOperation/view/wwBattleResultsView.nut"
                 "inOperation/view/wwOperationLogView.nut"
                 "inOperation/handler/wwMap.nut"
                 "inOperation/handler/wwObjective.nut"
                 "inOperation/handler/wwOperationLog.nut"
                 "inOperation/handler/wwAirfieldsList.nut"
                 "inOperation/handler/wwArmiesList.nut"
                 "inOperation/handler/wwCommanders.nut"
                 "inOperation/handler/wwArmyGroupHandler.nut"
                 "inOperation/handler/wwReinforcements.nut"
                 "inOperation/handler/wwBattleResults.nut"
                 "operations/model/wwGlobalStatusType.nut"
                 "operations/model/wwGlobalStatus.nut"
                 "operations/model/wwMap.nut"
                 "operations/model/wwOperation.nut"
                 "operations/model/wwOperationsGroup.nut"
                 "operations/handler/wwMapDescription.nut"
                 "operations/handler/wwQueueDescriptionCustomHandler.nut"
                 "operations/handler/wwOperationDescriptionCustomHandler.nut"
                 "operations/handler/wwOperationsListModal.nut"
                 "operations/handler/wwOperationsMapsHandler.nut"
                 "handler/wwMapTooltip.nut"
                 "handler/wwQueueInfo.nut"
                 "handler/wwSquadList.nut"
                 "handler/wwBattleDescription.nut"
                 "handler/wwGlobalBattlesModal.nut"
                 "handler/wwAirfieldFlyOut.nut"
                 "handler/wwObjectivesInfo.nut"
                 "handler/wwMyClanSquadInviteModal.nut"
                 "handler/wwJoinBattleCondition.nut"
                 "worldWarRender.nut"
                 "worldWarBattleJoinProcess.nut"
               ])
  ::g_script_reloader.loadOnce("scripts/worldWar/" + fn) // no need to includeOnce to correct reload this scripts pack runtime

foreach(bhvName, bhvClass in ::ww_gui_bhv)
  ::replace_script_gui_behaviour(bhvName, bhvClass)

::g_world_war <- {
  [PERSISTENT_DATA_PARAMS] = ["configurableValues", "curOperationCountry"]

  armyGroups = []
  isArmyGroupsValid = false
  battles = []
  isBattlesValid = false
  configurableValues = ::DataBlock()

  isLastFlightWasWwBattle = false

  infantryUnits = null
  artilleryUnits = null

  rearZones = null
  curOperationCountry = null
  lastPlayedOperationId = null
  lastPlayedOperationCountry = null

  isDebugMode = false

  myClanParticipateIcon = "#ui/gameuiskin#lb_victories_battles.svg"
  lastPlayedIcon = "#ui/gameuiskin#last_played_operation_marker"

  defaultDiffCode = ::DIFFICULTY_REALISTIC
}

::g_script_reloader.registerPersistentDataFromRoot("g_world_war")

function g_world_war::getSetting(settingName, defaultValue)
{
  return ::get_game_settings_blk()?.ww_settings?[settingName] ?? defaultValue
}

function g_world_war::canPlayWorldwar()
{
  local minRankRequired = getSetting("minCraftRank", 0)
  local unit = ::u.search(::all_units, @(unit)
    unit.canUseByPlayer() && unit.rank >= minRankRequired
  )

  return !!unit
}

function g_world_war::getLockedCountryData()
{
  if (!curOperationCountry)
    return null

  return {
    country = curOperationCountry
    reasonText = ::loc("worldWar/cantChangeCountryInOperation")
  }
}

function g_world_war::canJoinWorldwarBattle()
{
  return ::is_worldwar_enabled() && ::g_world_war.canPlayWorldwar()
}

function g_world_war::getPlayWorldwarConditionText()
{
  local rankText = ::colorize("@unlockHeaderColor",
    ::getUnitRankName(getSetting("minCraftRank", 0)))
  return ::loc("worldWar/playCondition", {rank = rankText})
}

function g_world_war::getCantPlayWorldwarReasonText()
{
  return !canPlayWorldwar() ? getPlayWorldwarConditionText() : ""
}

function g_world_war::openMainWnd()
{
  if (!checkPlayWorldwarAccess())
    return

  if (::g_world_war.lastPlayedOperationId)
  {
    local operation = ::g_ww_global_status.getOperationById(::g_world_war.lastPlayedOperationId)
    if (operation)
    {
      joinOperationById(lastPlayedOperationId, lastPlayedOperationCountry)
      return
    }
  }

  openOperationsOrQueues()
}

function g_world_war::openWarMap()
{
  local operationId = ::ww_get_operation_id()
  ::ww_service.subscribeOperation(
    operationId,
    null,
    function(responce) {
      if (::ww_get_operation_id() != operationId)
        return
      ::g_world_war.stopWar()
      ::showInfoMsgBox(::loc("worldwar/cantUpdateOperation"))
    }
  )
  ::handlersManager.loadHandler(::gui_handlers.WwMap)
}

function g_world_war::checkPlayWorldwarAccess()
{
  if (!::is_worldwar_enabled())
  {
    ::show_not_available_msg_box()
    return false
  }
  if (!canPlayWorldwar())
  {
    ::showInfoMsgBox(getPlayWorldwarConditionText())
    return false
  }
  return true
}

function g_world_war::openOperationsOrQueues(needToOpenBattles = false, map = null)
{
  stopWar()

  if (!checkPlayWorldwarAccess())
    return

  ::ww_get_configurable_values(configurableValues)

  if (!::handlersManager.findHandlerClassInScene(::gui_handlers.WwOperationsMapsHandler))
    ::handlersManager.loadHandler(::gui_handlers.WwOperationsMapsHandler,
      { needToOpenBattles = needToOpenBattles
        autoOpenMapOperation = map })
}

function g_world_war::joinOperationById(operationId, country = null, isSilence = false, onSuccess = null)
{
  local operation = ::g_ww_global_status.getOperationById(operationId)
  if (!operation)
  {
    if (!isSilence)
      ::showInfoMsgBox(::loc("worldwar/operationNotFound"))
    return
  }

  stopWar()

  if (::u.isEmpty(country))
    country = operation.getMyAssignCountry() || ::get_profile_country_sq()

  operation.join(country, null, isSilence, onSuccess)
}

function g_world_war::onJoinOperationSuccess(operationId, country, isSilence, onSuccess)
{
  local operation = ::g_ww_global_status.getOperationById(operationId)
  local sideSelectSuccess = false
  if (operation)
  {
    if (getMyArmyGroup() != null)
      sideSelectSuccess = ::ww_select_player_side_for_army_group_member()
    else
      sideSelectSuccess = ::ww_select_player_side_for_regular_user(country)
  }
  curOperationCountry = country

  if (!sideSelectSuccess)
  {
    openOperationsOrQueues()
    return
  }

  saveLastPlayed(operationId, country)

  if (!isSilence)
    openWarMap()

  // To force an extra ui update when operation is fully loaded, and lastPlayedOperationId changed.
  ::ww_event("LoadOperation")

  if (onSuccess)
    onSuccess()
}

function g_world_war::openJoinOperationByIdWnd()
{
  ::gui_modal_editbox_wnd({
    charMask="1234567890"
    allowEmpty = false
    okFunc = function(value) {
      local operationId = ::to_integer_safe(value)
      joinOperationById(operationId)
    }
    owner = this
  })
}

function g_world_war::onEventLoadingStateChange(p)
{
  if (::is_in_flight())
  {
    ::g_squad_manager.cancelWwBattlePrepare()
    isLastFlightWasWwBattle = ::g_mis_custom_state.getCurMissionRules().isWorldWar
  }
}

function g_world_war::stopWar()
{
  rearZones = null
  curOperationCountry = null

  ::g_tooltip.removeAll()
  ::g_ww_logs.clear()
  if (!::ww_is_operation_loaded())
    return

  ::ww_stop_war()
  ::ww_event("StopWorldWar")
}

function g_world_war::saveLastPlayed(operationId, country)
{
  lastPlayedOperationId = operationId
  lastPlayedOperationCountry = country
  ::saveLocalByAccount(WW_CUR_OPERATION_SAVE_ID, operationId)
  ::saveLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, country)
}

function g_world_war::loadLastPlayed()
{
  lastPlayedOperationId = ::loadLocalByAccount(WW_CUR_OPERATION_SAVE_ID)
  if (lastPlayedOperationId)
    lastPlayedOperationCountry = ::loadLocalByAccount(WW_CUR_OPERATION_COUNTRY_SAVE_ID, ::get_profile_country_sq())
}

function g_world_war::onEventSignOut(p)
{
  stopWar()
}

function g_world_war::onEventLoginComplete(p)
{
  loadLastPlayed()
  ::g_ww_global_status.refreshData()
  updateUserlogsAccess()
}

function g_world_war::onEventScriptsReloaded(p)
{
  loadLastPlayed()
}

function g_world_war::leaveWWBattleQueues(battle = null)
{
  if (::g_squad_manager.isSquadMember())
    return

  ::g_squad_manager.cancelWwBattlePrepare()

  if (battle)
  {
    local queue = ::queues.findQueueByName(battle.getQueueId())
    ::queues.leaveQueue(queue)
  }
  else
    ::queues.leaveQueueByType(QUEUE_TYPE_BIT.WW_BATTLE)
}

function g_world_war::onEventWWGlobalStatusChanged(p)
{
  if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)
    ::g_squad_manager.updateMyMemberData()
}

function g_world_war::checkOpenGlobalBattlesModal()
{
  if (!::g_squad_manager.getWwOperationBattle())
    return

  if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
    return

  if (!::g_squad_manager.isSquadMember() || !::g_squad_manager.isMeReady())
    return

  ::g_world_war.stopWar()
  ::gui_handlers.WwGlobalBattlesModal.open()
}

function g_world_war::onEventSquadSetReady(params)
{
  checkOpenGlobalBattlesModal()
}

function g_world_war::isDebugModeEnabled()
{
  return isDebugMode
}

function g_world_war::setDebugMode(value)
{
  if (!::has_feature("worldWarMaster"))
    value = false

  if (value == isDebugMode)
    return

  isDebugMode = value
  ::ww_event("ChangedDebugMode")
}

function g_world_war::updateArmyGroups()
{
  if (isArmyGroupsValid)
    return

  isArmyGroupsValid = true

  armyGroups.clear()

  local blk = ::DataBlock()
  ::ww_get_army_groups_info(blk)

  if (!("armyGroups" in blk))
    return

  local itemCount = blk.armyGroups.blockCount()

  for (local i = 0; i < itemCount; i++)
  {
    local itemBlk = blk.armyGroups.getBlock(i)
    local group   = ::WwArmyGroup(itemBlk)

    if (group.isValid())
      armyGroups.push(group)
  }
}

function g_world_war::updateInfantryUnits()
{
  infantryUnits = ::g_world_war.getWWConfigurableValue("infantryUnits", null)
}

function g_world_war::updateArtilleryUnits()
{
  artilleryUnits = ::g_world_war.getWWConfigurableValue("artilleryUnits", null)
}

function g_world_war::getArtilleryUnitParamsByBlk(blk)
{
  if (!artilleryUnits)
    ::g_world_war.updateArtilleryUnits()

  for (local i = 0; i < blk.blockCount(); i++)
  {
    local wwUnitName = blk.getBlock(i).getBlockName()
    if (wwUnitName in artilleryUnits)
      return artilleryUnits[wwUnitName]
  }
}

function g_world_war::updateRearZones()
{
  local blk = ::DataBlock()
  ::ww_get_rear_zones(blk)

  rearZones = {}
  foreach (zoneName, zoneOwner in blk)
  {
    local sideName = ::ww_side_val_to_name(zoneOwner)
    if (!(sideName in rearZones))
      rearZones[sideName] <- []

    rearZones[sideName].append(zoneName)
  }
}

function g_world_war::getRearZones()
{
  if (!rearZones)
    updateRearZones()

  return rearZones
}

function g_world_war::getRearZonesBySide(side)
{
  return getRearZones()?[::ww_side_val_to_name(side)] ?? []
}

function g_world_war::getRearZonesOwnedToSide(side)
{
  return getRearZonesBySide(side).filter(@(idx, zone) ::ww_get_zone_side_by_name(zone) == side)
}

function g_world_war::getRearZonesLostBySide(side)
{
  return getRearZonesBySide(side).filter(@(idx, zone) ::ww_get_zone_side_by_name(zone) != side)
}

function g_world_war::getSelectedArmies()
{
  return ::u.map(::ww_get_selected_armies_names(), function(name)
  {
    return ::g_world_war.getArmyByName(name)
  })
}

function g_world_war::getSidesStrenghtInfo()
{
  local blk = ::DataBlock()
  ::ww_get_sides_info(blk)

  local unitsStrenghtBySide = {}
  foreach(side in getCommonSidesOrder())
    unitsStrenghtBySide[side] <- []

  local sidesBlk = blk["sides"]
  if (sidesBlk == null)
    return unitsStrenghtBySide

  for (local i = 0; i < sidesBlk.blockCount(); ++i)
  {
    local wwUnitsList = []
    local sideBlk = sidesBlk.getBlock(i)
    local unitsBlk = sideBlk["units"]

    for (local j = 0; j < unitsBlk.blockCount(); ++j)
    {
      local unitsTypeBlk = unitsBlk.getBlock(j)
      local unitTypeBlk = unitsTypeBlk["units"]
      wwUnitsList.extend(::WwUnit.loadUnitsFromBlk(unitTypeBlk))
    }

    local collectedWwUnits = ::u.values(::g_world_war.collectUnitsData(wwUnitsList))
    collectedWwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)
    unitsStrenghtBySide[sideBlk.getBlockName().tointeger()] = collectedWwUnits
  }

  return unitsStrenghtBySide
}

function g_world_war::getAllOperationUnitsBySide(side)
{
  local allOperationUnits = {}
  local blk = ::DataBlock()
  ::ww_get_sides_info(blk)

  local sidesBlk = blk["sides"]
  if (sidesBlk == null)
    return allOperationUnits

  local sideBlk = sidesBlk[side.tostring()]
  if (sideBlk == null)
    return allOperationUnits

  foreach (unitName in sideBlk.unitsEverSeen % "item")
    if (::getAircraftByName(unitName))
      allOperationUnits[unitName] <- true

  return allOperationUnits
}

function g_world_war::filterArmiesByManagementAccess(armiesArray)
{
  return ::u.filter(armiesArray, function(army) { return army.hasManageAccess() })
}

function g_world_war::haveManagementAccessForSelectedArmies()
{
  local armiesArray = getSelectedArmies()
  return filterArmiesByManagementAccess(armiesArray).len() > 0
}

function g_world_war::getMyAccessLevelListForCurrentBattle()
{
  local list = {}
  if (!::ww_is_player_on_war())
    return list

  foreach(group in getArmyGroups())
  {
    list[group.owner.armyGroupIdx] <- group.getAccessLevel()
  }

  return list
}

function g_world_war::haveManagementAccessForAnyGroup()
{
  local result = ::u.search(getMyAccessLevelListForCurrentBattle(),
    function(access) {
      return access & WW_BATTLE_ACCESS.MANAGER
    }
  ) || WW_BATTLE_ACCESS.NONE
  return result >= WW_BATTLE_ACCESS.MANAGER
}

function g_world_war::isSquadsInviteEnable()
{
  return ::has_feature("WorldWarSquadInvite") &&
         ::g_world_war.haveManagementAccessForAnyGroup() &&
         ::clan_get_my_clan_id().tointeger() >= 0
}

function g_world_war::isGroupAvailable(group, accessList = null)
{
  if (!group || !group.isValid() || !group.owner.isValid())
    return false

  if (group.owner.side != ::ww_get_player_side())
    return false

  if (!accessList)
    accessList = getMyAccessLevelListForCurrentBattle()

  local access = ::getTblValue(group.owner.armyGroupIdx, accessList, WW_BATTLE_ACCESS.NONE)
  return access & WW_BATTLE_ACCESS.MANAGER
}

// return array of WwArmyGroup
function g_world_war::getArmyGroups(filterFunc = null)
{
  updateArmyGroups()

  return filterFunc ? ::u.filter(armyGroups, filterFunc) : armyGroups
}


// return array of WwArmyGroup
function g_world_war::getArmyGroupsBySide(side, filterFunc = null)
{
  return getArmyGroups
  (
    (@(side, filterFunc) function (group) {
      if (group.owner.side != side)
        return false

      return filterFunc ? filterFunc(group) : true
    })(side, filterFunc)
  )
}


// return WwArmyGroup or null
function g_world_war::getArmyGroupByArmy(army)
{
  return ::u.search(getArmyGroups(),
    (@(army) function (group) {
      return group.isMyArmy(army)
    })(army)
  )
}

function g_world_war::getMyArmyGroup()
{
  return ::u.search(getArmyGroups(),
      function(group)
      {
        return ::isInArray(::my_user_id_int64, group.observerUids)
      }
    )
}

function g_world_war::getArmyByName(armyName)
{
  if (!armyName)
    return null
  return ::WwArmy(armyName)
}

function g_world_war::getArmyByArmyGroup(armyGroup)
{
  local armyName = ::u.search(::ww_get_armies_names(), (@(armyGroup) function(armyName) {
      local army = ::g_world_war.getArmyByName(armyName)
      return armyGroup.isMyArmy(army)
    })(armyGroup))

  if (!armyName)
    return null
  return ::g_world_war.getArmyByName(armyName)
}

function g_world_war::getBattleById(battleId)
{
  local battles = getBattles(
      (@(battleId) function(checkedBattle) {
        return checkedBattle.id == battleId
      })(battleId)
    )

  return battles.len() > 0 ? battles[0] : ::WwBattle()
}


function g_world_war::getAirfieldByIndex(index)
{
  return ::WwAirfield(index)
}


function g_world_war::getAirfieldsCount()
{
  return ::ww_get_airfields_count();
}

function g_world_war::getAirfieldsArrayBySide(side)
{
  local array = []
  for (local index = 0; index < getAirfieldsCount(); index++)
  {
    local field = getAirfieldByIndex(index)
    if (field.isMySide(side))
      array.append(field)
  }

  return array
}

function g_world_war::getBattles(filterFunc = null, forced = false)
{
  updateBattles(forced)
  return filterFunc ? ::u.filter(battles, filterFunc) : battles
}

function g_world_war::getBattleForArmy(army, playerSide = ::SIDE_NONE)
{
  if (!army)
    return null

  return ::u.search(getBattles(),
    (@(army) function (battle) {
      return !battle.isFinished() && battle.isArmyJoined(army.name)
    })(army)
  )
}

function g_world_war::isBattleAvailableToPlay(wwBattle)
{
  return wwBattle && wwBattle.isValid() && !wwBattle.isAutoBattle() && !wwBattle.isFinished()
}


function g_world_war::updateBattles(forced = false)
{
  if (isBattlesValid && !forced)
    return

  isBattlesValid = true

  battles.clear()

  local blk = ::DataBlock()
  ::ww_get_battles_info(blk)

  if (!("battles" in blk))
    return

  local itemCount = blk.battles.blockCount()

  for (local i = 0; i < itemCount; i++)
  {
    local itemBlk = blk.battles.getBlock(i)
    local battle   = ::WwBattle(itemBlk)

    if (battle.isValid())
      battles.push(battle)
  }
}


function g_world_war::updateConfigurableValues()
{
  ::ww_get_configurable_values(configurableValues)
}


function g_world_war::onEventWWLoadOperationFirstTime(params = {})
{
  updateConfigurableValues()
}

function g_world_war::onEventWWLoadOperation(params = {})
{
  isArmyGroupsValid = false
  isBattlesValid = false
}

function g_world_war::getWWConfigurableValue(paramPath, defaultValue)
{
  return ::get_blk_value_by_path(configurableValues, paramPath, defaultValue)
}

function g_world_war::getOperationObjectives()
{
  local blk = ::DataBlock()
  ::ww_get_operation_objectives(blk)
  return blk
}

function g_world_war::isCurrentOperationFinished()
{
  if (!::ww_is_operation_loaded())
    return false

  return ::ww_get_operation_winner() != ::SIDE_NONE
}

function g_world_war::getReinforcementsInfo()
{
  local blk = ::DataBlock()
  ::ww_get_reinforcements_info(blk)
  return blk
}

function g_world_war::getReinforcementsArrayBySide(side)
{
  local reinforcementsInfo = getReinforcementsInfo()
  if (!reinforcementsInfo.reinforcements)
    return []

  local array = []
  for (local i = 0; i < reinforcementsInfo.reinforcements.blockCount(); i++)
  {
    local reinforcement = reinforcementsInfo.reinforcements.getBlock(i)
    local wwReinforcementArmy = ::WwReinforcementArmy(reinforcement)
    if (::has_feature("worldWarMaster") ||
         (wwReinforcementArmy.isMySide(side)
         && wwReinforcementArmy.hasManageAccess())
       )
        array.append(wwReinforcementArmy)
  }

  return array
}

function g_world_war::getMyReinforcementsArray()
{
  return ::u.filter(getReinforcementsArrayBySide(::ww_get_player_side()),
    function(reinf) { return reinf.hasManageAccess()}
  )
}

function g_world_war::getMyReadyReinforcementsArray()
{
  return ::u.filter(getMyReinforcementsArray(), function(reinf) { return reinf.isReady() })
}

function g_world_war::hasSuspendedReinforcements()
{
  return ::u.search(
      getMyReinforcementsArray(),
      function(reinf) {
        return !reinf.isReady()
      }
    ) != null
}

function g_world_war::getReinforcementByName(name, blk = null)
{
  if (!name || !name.len())
    return null
  if (!blk)
    blk = getReinforcementsInfo()
  if (!blk || !blk.reinforcements)
    return null

  for (local i = 0; i < blk.reinforcements.blockCount(); i++)
  {
    local reinforcement = blk.reinforcements.getBlock(i)
    if (!reinforcement)
      continue

    if (reinforcement.getBlockName() == name)
      return ::WwReinforcementArmy(reinforcement)
  }

  return null
}

function g_world_war::sendReinforcementRequest(cellIdx, name)
{
  local params = ::DataBlock()
  params.setInt("cellIdx", cellIdx)
  params.setStr("name", name)
  return ::ww_send_operation_request("cln_ww_emplace_reinforcement", params)
}

function g_world_war::isArmySelected(armyName)
{
  return ::isInArray(armyName, ::ww_get_selected_armies_names())
}

function g_world_war::moveSelectedArmyToCell(cellIdx, params = {})
{
  local army = ::getTblValue("army", params)
  if (!army)
    return

  local moveType = "EMT_ATTACK" //default move type
  local targetAirfieldIdx = ::getTblValue("targetAirfieldIdx", params, -1)
  local target = ::getTblValue("target", params)

  local blk = ::DataBlock()
  if (targetAirfieldIdx >= 0)
  {
    local airfield = ::g_world_war.getAirfieldByIndex(targetAirfieldIdx)
    if (::g_ww_unit_type.isAir(army.unitType) && army.isMySide(airfield.side))
    {
      moveType = "EMT_BACK_TO_AIRFIELD"
      blk.setInt("targetAirfieldIdx", targetAirfieldIdx)
    }
  }

  blk.setStr("moveType", moveType)
  blk.setStr("army", army.name)
  blk.setInt("targetCellIdx", cellIdx)

  local appendToPath = ::getTblValue("appendToPath", params, false)
  if (appendToPath)
    blk.setBool("appendToPath", appendToPath)
  if (target)
    blk.addStr("targetName", target)

  playArmyActionSound("moveSound", army)

  local taskId = ::ww_send_operation_request("cln_ww_move_army_to", blk)
  ::g_tasker.addTask(taskId, null, @() null,
    function (errorCode) {
      ::g_world_war.popupCharErrorMsg("move_army_error")
    })
}


// TODO: make this function to work like moveSelectedArmyToCell
// to avoid duplication code for ground and air arimies.
function g_world_war::moveSelectedArmiesToCell(cellIdx, armies = [], target = null, appendPath = false)
{
  //MOVE TYPE - EMT_ATTACK always
  if (cellIdx < 0  || armies.len() == 0)
    return

  local params = ::DataBlock()
  for (local i = 0; i < armies.len(); i++)
  {
    params.addStr("army" + i, armies[i].name)
    params.addInt("targetCellIdx" + i, cellIdx)
  }

  if (appendPath)
    params.addBool("appendToPath", true)
  if (target)
    params.addStr("targetName", target)

  playArmyActionSound("moveSound", armies[0])
  ::ww_send_operation_request("cln_ww_move_armies_to", params)
}


function g_world_war::playArmyActionSound(soundId, wwArmy, wwUnitTypeCode = null)
{
  if ((!wwArmy || !wwArmy.isValid()) && !wwUnitTypeCode)
    return

  local unitTypeCode = wwUnitTypeCode ||
                       wwArmy.getOverrideUnitType() ||
                       wwArmy.getUnitType()
  local armyType = ::g_ww_unit_type.getUnitTypeByCode(unitTypeCode)
  ::play_gui_sound(armyType[soundId])
}


function g_world_war::moveSelectedArmes(toX, toY, target = null, append = false)
{
  if (!::g_world_war.haveManagementAccessForSelectedArmies())
    return

  if (!hasEntrenchedInList(::ww_get_selected_armies_names()))
  {
    requestMoveSelectedArmies(toX, toY, target, append)
    return
  }

  ::gui_handlers.FramedMessageBox.open({
    title = ::loc("worldwar/armyAskDigout")
    message = ::loc("worldwar/armyAskDigoutText")
    onOpenSound = "ww_unit_entrench_move_notify"
    buttons = [
      {
        id = "no",
        text = ::loc("msgbox/btn_no"),
        shortcut = "B"
      }
      {
        id = "yes",
        text = ::loc("msgbox/btn_yes"),
        cb = ::Callback(@() requestMoveSelectedArmies(toX, toY, target, append), this)
        shortcut = "A"
      }
    ]
  })
}


function g_world_war::requestMoveSelectedArmies(toX, toY, target, append)
{
  local groundArmies = []
  local selectedArmies = ::ww_get_selected_armies_names()
  for (local i = selectedArmies.len() - 1; i >=0 ; i--)
  {
    local army = ::g_world_war.getArmyByName(selectedArmies.remove(i))
    if (!army.isValid())
      continue

    if (::g_ww_unit_type.isAir(army.unitType))
    {
      local cellIdx = ::ww_get_map_cell_by_coords(toX, toY)
      local targetAirfieldIdx = ::ww_find_airfield_by_coordinates(toX, toY)
      ::g_world_war.moveSelectedArmyToCell(cellIdx, {
        army = army
        target = target
        targetAirfieldIdx = targetAirfieldIdx
        appendToPath = append
      })
      continue
    }

    groundArmies.append(army)
  }

  if (groundArmies.len())
  {
    local cellIdx = ::ww_get_map_cell_by_coords(toX, toY)
    moveSelectedArmiesToCell(cellIdx, groundArmies, target, append)
  }
}


function g_world_war::hasEntrenchedInList(armyNamesList)
{
  for (local i = 0; i < armyNamesList.len(); i++)
  {
    local army = getArmyByName(armyNamesList[i])
    if (army && army.isEntrenched())
      return true
  }
  return false
}


function g_world_war::startArtilleryFire(mapPos, army)
{
  local blk = ::DataBlock()
  blk.setStr("army", army.name)
  blk.setStr("point", mapPos.x.tostring() + "," + mapPos.y.tostring())
  blk.setStr("radius", ww_artillery_get_attack_radius().tostring())

  local taskId = ::ww_send_operation_request("cln_ww_artillery_strike", blk)
  ::g_tasker.addTask(taskId, null,
    function () {
      ::ww_artillery_turn_fire(false)
      ::ww_event("ArmyStatusChanged")
    },
    function (errorCode) {
      ::g_world_war.popupCharErrorMsg("cant_fire", ::loc("worldwar/artillery/cant_fire"))
    })
}

function g_world_war::stopSelectedArmy()
{
  local filteredArray = filterArmiesByManagementAccess(getSelectedArmies())
  if (!filteredArray.len())
    return

  local params = ::DataBlock()
  foreach(idx, army in filteredArray)
    params.addStr("army" + idx, army.name)
  ::ww_send_operation_request("cln_ww_stop_armies", params)
}

function g_world_war::entrenchSelectedArmy()
{
  local filteredArray = filterArmiesByManagementAccess(getSelectedArmies())
  if (!filteredArray.len())
    return

  local entrenchedArmies = ::u.filter(filteredArray, function(army) { return !army.isEntrenched() })
  if (!entrenchedArmies.len())
    return

  local params = ::DataBlock()
  foreach(idx, army in entrenchedArmies)
    params.addStr("army" + idx, army.name)
  ::play_gui_sound("ww_unit_entrench")
  ::ww_send_operation_request("cln_ww_entrench_armies", params)
}

function g_world_war::moveSelectedAircraftsToCell(cellIdx, unitsList, owner, target = null)
{
  if (cellIdx < 0)
    return -1

  if (unitsList.len() == 0)
    return -1

  local params = ::DataBlock()
  params.addInt("targetCellIdx", cellIdx)
  params.addInt("airfield", ::ww_get_selected_airfield())
  params.addStr("side", ::ww_side_val_to_name(owner.side))
  params.addStr("country", owner.country)
  params.addInt("armyGroupIdx", owner.armyGroupIdx)

  local i = 0
  foreach (unitName, unitTable in unitsList)
  {
    if (unitTable.count == 0)
      continue

    params.addStr("unitName" + i, unitName)
    params.addInt("unitCount" + i, ::getTblValue("count", unitTable, 0))
    params.addStr("unitWeapon" + i, ::getTblValue("weapon", unitTable, ""))
    i++
  }

  if (target)
    params.addStr("targetName", target)

  playArmyActionSound("moveSound", null, ::UT_AIR)

  return ::ww_send_operation_request("cln_ww_move_army_to", params)
}

function g_world_war::getUnitRole(unitName)
{
  local role = ::get_unit_role(unitName)
  if (role != "")
    return role

  return unitName
}

function g_world_war::sortUnitsByTypeAndCount(a, b)
{
  local aType = a.wwUnitType.code
  local bType = b.wwUnitType.code
  if (aType != bType)
    return aType - bType
  return a.count - b.count
}

function g_world_war::sortUnitsBySortCodeAndCount(a, b)
{
  local aSortCode = a.wwUnitType.sortCode
  local bSortCode = b.wwUnitType.sortCode
  if (aSortCode != bSortCode)
    return aSortCode - bSortCode

  local aCount = a.count
  local bCount = b.count
  return aCount.tointeger() - bCount.tointeger()
}

function g_world_war::getOperationTimeSec()
{
  return time.millisecondsToSecondsInt(::ww_get_operation_time_millisec())
}

function g_world_war::requestLogs(loadAmount, useLogMark, cb, errorCb)
{
  local logMark = useLogMark ? ::g_ww_logs.lastMark : ""
  local reqBlk = DataBlock()
  reqBlk.setInt("count", loadAmount)
  reqBlk.setStr("last", logMark)
  local taskId = ::ww_operation_request_log(reqBlk)

  if (taskId < 0) // taskId == -1 means request result is ready
    cb()
  else
    ::g_tasker.addTask(taskId, null, cb, errorCb)
}

function g_world_war::getSidesOrder(battle = null)
{
  local playerSide = (battle && ::u.isWwGlobalBattle(battle))
    ? battle.getSideByCountry(::get_profile_country_sq())
    : ::ww_get_player_side()

  if (playerSide == ::SIDE_NONE)
    playerSide = ::SIDE_1

  local enemySide  = ::g_world_war.getOppositeSide(playerSide)
  return [ playerSide, enemySide ]
}

function g_world_war::getCommonSidesOrder()
{
  return [::SIDE_1, ::SIDE_2]
}

function g_world_war::getOppositeSide(side)
{
  return side == ::SIDE_2 ? ::SIDE_1 : ::SIDE_2
}

function g_world_war::get_last_weapon_preset(unitName)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return ""

  local weaponName = ::loadLocalByAccount(WW_UNIT_WEAPON_PRESET_PATH + unitName, "")
  foreach(weapon in unit.weapons)
    if (weapon.name == weaponName)
      return weaponName

  return unit.weapons.len() ? unit.weapons[0].name : ""
}

function g_world_war::set_last_weapon_preset(unitName, weaponName)
{
  ::saveLocalByAccount(WW_UNIT_WEAPON_PRESET_PATH + unitName, weaponName)
}

function g_world_war::collectUnitsData(unitsArray, isViewStrengthList = true)
{
  local collectedUnits = {}
  foreach(wwUnit in unitsArray)
  {
    local id = isViewStrengthList ? wwUnit.stengthGroupExpClass : wwUnit.expClass
    if (!(id in collectedUnits))
      collectedUnits[id] <- wwUnit
    else
      collectedUnits[id].count += wwUnit.count
  }

  return collectedUnits
}

function g_world_war::addOperationInvite(operationId, clanName, isStarted, inviteTime)
{
  if (!::is_worldwar_enabled() || !canPlayWorldwar())
    return

  if (operationId != ::ww_get_operation_id())
    ::g_invites.addInvite(::g_invites_classes.WwOperation,
      { operationId = operationId,
        clanName = clanName,
        isStarted = isStarted,
        inviteTime = inviteTime }
    )
}

function g_world_war::addSquadInviteToWWBattle(params)
{
  local squadronId = params?.squadronId
  local operationId = params?.battle?.operationId
  local battleId = params?.battle?.battleId
  if (!squadronId || !operationId || !battleId)
    return

  if (squadronId != ::clan_get_my_clan_id() || !::g_squad_manager.isSquadLeader())
    return

  ::g_invites.addInvite(::g_invites_classes.WwOperationBattle, {
    operationId = operationId,
    battleId = battleId
  })
  ::g_invites.rescheduleInvitesTask()
}

function g_world_war::getSaveOperationLogId()
{
  return WW_LAST_OPERATION_LOG_SAVE_ID + ::ww_get_operation_id()
}

function g_world_war::updateUserlogsAccess()
{
  if (!::is_worldwar_enabled())
    return

  local wwUserLogTypes = [::EULT_WW_START_OPERATION,
                          ::EULT_WW_CREATE_OPERATION,
                          ::EULT_WW_END_OPERATION]
  for (local i = ::hidden_userlogs.len() - 1; i >= 0; i--)
    if (::isInArray(::hidden_userlogs[i], wwUserLogTypes))
      ::hidden_userlogs.remove(i)
}

function g_world_war::updateOperationPreviewAndDo(operationId, cb, hasProgressBox = false)
{
  operationPreloader.loadPreview(operationId, cb, hasProgressBox)
}

function g_world_war::onEventWWOperationPreviewLoaded(params = {})
{
  isArmyGroupsValid = false
  isBattlesValid = false
  updateConfigurableValues()
}

function g_world_war::popupCharErrorMsg(groupName = null, titleText = "")
{
  local errorMsgId = get_char_error_msg()
  if (!errorMsgId)
    return

  if (errorMsgId == "WRONG_REINFORCEMENT_NAME")
    return

  local popupText = ::loc("worldwar/charError/" + errorMsgId,
    ::loc("worldwar/charError/defaultError", ""))
  if (popupText.len() || titleText.len())
    ::g_popups.add(titleText, popupText, null, null, null, groupName)
}

function ww_event(name, params = {})
{
  ::broadcastEvent("WW" + name, params || {})
}

::subscribe_handler(::g_world_war, ::g_listener_priority.DEFAULT_HANDLER)
