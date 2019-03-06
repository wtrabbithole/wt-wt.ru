local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local xboxShopData = ::require("scripts/onlineShop/xboxShopData.nut")

const MODIFICATORS_REQUEST_TIMEOUT_MSEC = 20000

enum bit_unit_status
{
  locked      = 1
  canResearch = 2
  inResearch  = 4
  researched  = 8
  canBuy      = 16
  owned       = 32
  mounted     = 64
  disabled    = 128
  broken      = 256
  inRent      = 512
}

enum unit_rarity
{
  reserve,
  common,
  premium,
  gift
}

enum CheckFeatureLockAction
{
  BUY,
  RESEARCH
}

::chances_text <- [
  { text = "chance_to_met/high",    color = "@chanceHighColor",    brDiff = 0.0 }
  { text = "chance_to_met/average", color = "@chanceAverageColor", brDiff = 0.34 }
  { text = "chance_to_met/low",     color = "@chanceLowColor",     brDiff = 0.71 }
  { text = "chance_to_met/never",   color = "@chanceNeverColor",   brDiff = 1.01 }
]

function getUnitItemStatusText(bitStatus, isGroup = false)
{
  local statusText = ""
  if (bit_unit_status.locked & bitStatus)
    statusText = "locked"
  else if (bit_unit_status.broken & bitStatus)
    statusText = "broken"
  else if (bit_unit_status.disabled & bitStatus)
    statusText = "disabled"

  if (!isGroup && statusText != "")
    return statusText

  if (bit_unit_status.inResearch & bitStatus)
    statusText = "research"
  else if (bit_unit_status.mounted & bitStatus)
    statusText = "mounted"
  else if (bit_unit_status.owned & bitStatus || bit_unit_status.inRent & bitStatus)
    statusText = "owned"
  else if (bit_unit_status.canBuy & bitStatus)
    statusText = "canBuy"
  else if (bit_unit_status.researched & bitStatus)
    statusText = "researched"
  else if (bit_unit_status.canResearch & bitStatus)
    statusText = "canResearch"
  return statusText
}


::basic_unit_roles <- {
  [::ES_UNIT_TYPE_AIRCRAFT] = ["fighter", "assault", "bomber"],
  [::ES_UNIT_TYPE_TANK] = ["tank", "light_tank", "medium_tank", "heavy_tank", "tank_destroyer", "spaa"],
  [::ES_UNIT_TYPE_SHIP] = ["ship", "boat", "heavy_boat", "barge", "destroyer", "light_cruiser",
    "cruiser", "battlecruiser", "battleship", "submarine"],
  [::ES_UNIT_TYPE_HELICOPTER] = ["attack_helicopter", "utility_helicopter"]
}

::unit_role_fonticons <- {
  fighter                  = ::loc("icon/unitclass/fighter"),
  assault                  = ::loc("icon/unitclass/assault"),
  bomber                   = ::loc("icon/unitclass/bomber"),
  attack_helicopter        = ::loc("icon/unitclass/attack_helicopter"),
  utility_helicopter       = ::loc("icon/unitclass/utility_helicopter"),
  light_tank               = ::loc("icon/unitclass/light_tank"),
  medium_tank              = ::loc("icon/unitclass/medium_tank"),
  heavy_tank               = ::loc("icon/unitclass/heavy_tank"),
  tank_destroyer           = ::loc("icon/unitclass/tank_destroyer"),
  spaa                     = ::loc("icon/unitclass/spaa"),
  ship                     = ::loc("icon/unitclass/ship"),
  boat                     = ::loc("icon/unitclass/gun_boat")
  heavy_boat               = ::loc("icon/unitclass/heavy_gun_boat")
  barge                    = ::loc("icon/unitclass/naval_ferry_barge")
  destroyer                = ::loc("icon/unitclass/destroyer")
  light_cruiser            = ::loc("icon/unitclass/light_cruiser")
  cruiser                  = ::loc("icon/unitclass/cruiser")
  battlecruiser            = ::loc("icon/unitclass/battlecruiser")
  battleship               = ::loc("icon/unitclass/battleship")
  submarine                = ::loc("icon/unitclass/submarine")
}

::unit_role_by_tag <- {
  type_light_fighter    = "light_fighter",
  type_medium_fighter   = "medium_fighter",
  type_heavy_fighter    = "heavy_fighter",
  type_naval_fighter    = "naval_fighter",
  type_jet_fighter      = "jet_fighter",
  type_light_bomber     = "light_bomber",
  type_medium_bomber    = "medium_bomber",
  type_heavy_bomber     = "heavy_bomber",
  type_naval_bomber     = "naval_bomber",
  type_jet_bomber       = "jet_bomber",
  type_dive_bomber      = "dive_bomber",
  type_common_bomber    = "common_bomber", //to use as a second type: "Light fighter / Bomber"
  type_common_assault   = "common_assault",
  type_strike_fighter   = "strike_fighter",
  type_attack_helicopter  = "attack_helicopter",
  type_utility_helicopter = "utility_helicopter",
  //tanks:
  type_tank             = "tank" //used in profile stats
  type_light_tank       = "light_tank",
  type_medium_tank      = "medium_tank",
  type_heavy_tank       = "heavy_tank",
  type_tank_destroyer   = "tank_destroyer",
  type_spaa             = "spaa",
  //ships:
  type_ship             = "ship",
  type_boat             = "boat",
  type_heavy_boat       = "heavy_boat",
  type_barge            = "barge",
  type_destroyer        = "destroyer",
  type_light_cruiser    = "light_cruiser",
  type_cruiser          = "cruiser",
  type_battlecruiser    = "battlecruiser",
  type_battleship       = "battleship",
  type_submarine        = "submarine",
  //basic types
  type_fighter          = "medium_fighter",
  type_assault          = "common_assault",
  type_bomber           = "medium_bomber"
}

::unit_role_by_name <- {}

::unlock_condition_unitclasses <- {
    aircraft          = ::ES_UNIT_TYPE_AIRCRAFT
    tank              = ::ES_UNIT_TYPE_TANK
    typeLightTank     = ::ES_UNIT_TYPE_TANK
    typeMediumTank    = ::ES_UNIT_TYPE_TANK
    typeHeavyTank     = ::ES_UNIT_TYPE_TANK
    typeSPG           = ::ES_UNIT_TYPE_TANK
    typeSPAA          = ::ES_UNIT_TYPE_TANK
    typeTankDestroyer = ::ES_UNIT_TYPE_TANK
    typeFighter       = ::ES_UNIT_TYPE_AIRCRAFT
    typeDiveBomber    = ::ES_UNIT_TYPE_AIRCRAFT
    typeBomber        = ::ES_UNIT_TYPE_AIRCRAFT
    typeAssault       = ::ES_UNIT_TYPE_AIRCRAFT
    typeStormovik     = ::ES_UNIT_TYPE_AIRCRAFT
    typeTransport     = ::ES_UNIT_TYPE_AIRCRAFT
    typeStrikeFighter = ::ES_UNIT_TYPE_AIRCRAFT
}

function get_unit_role(unitData) //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
{
  local unit = unitData
  if (typeof(unitData) == "string")
    unit = getAircraftByName(unitData);

  if (!unit)
    return ""; //not found

  local role = ::getTblValue(unit.name, ::unit_role_by_name, "")
  if (role == "")
  {
    foreach(tag in unit.tags)
      if (tag in ::unit_role_by_tag)
      {
        role = ::unit_role_by_tag[tag]
        break
      }
    ::unit_role_by_name[unit.name] <- role
  }

  return role
}

function haveUnitRole(unit, role)
{
  return ::isInArray("type_" + role, unit.tags)
}

function get_unit_basic_role(unit)
{
  local unitType = ::get_es_unit_type(unit)
  local basicRoles = ::getTblValue(unitType, ::basic_unit_roles)
  if (!basicRoles || !basicRoles.len())
    return ""

  foreach(role in basicRoles)
    if (::haveUnitRole(unit, role))
      return role
  return basicRoles[0]
}

function get_role_text(role)
{
  return ::loc("mainmenu/type_" + role)
}

function get_full_unit_role_text(unit)
{
  if (!("tags" in unit) || !unit.tags)
    return ""

  if (::is_submarine(unit))
    return ::get_role_text("submarine")

  local basicRoles = ::getTblValue(::get_es_unit_type(unit), ::basic_unit_roles, [])
  local textsList = []
  foreach(tag in unit.tags)
    if (tag.len()>5 && tag.slice(0, 5)=="type_" && !isInArray(tag.slice(5), basicRoles))
      textsList.append(::loc("mainmenu/"+tag))

  if (textsList.len())
    return ::g_string.implode(textsList, ::loc("mainmenu/unit_type_separator"))

  foreach (t in basicRoles)
    if (isInArray("type_" + t, unit.tags))
      return ::get_role_text(t)
  return ""
}

/*
  typeof @source == Unit     -> @source is unit
  typeof @source == "string" -> @source is role id
*/
function get_unit_role_icon(source)
{
  local role = ::u.isString(source) ? source
    : ::get_unit_basic_role(source)
  return ::unit_role_fonticons?[role] ?? ""
}

function get_unit_actions_list(unit, handler, actions)
{
  local res = {
    handler = handler
    actions = []
  }

  if (!unit || ("airsGroup" in unit) || actions.len()==0 || ::is_in_loading_screen())
    return res

  local inMenu = ::isInMenu()
  local isUsable  = unit.isUsable()
  local profile   = ::get_profile_info()
  local crew = ::getCrewByAir(unit)
  local curEdiff = handler?.getCurrentEdiff ? handler.getCurrentEdiff() : -1

  foreach(action in actions)
  {
    local actionText = ""
    local showAction = false
    local actionFunc = null
    local haveWarning  = false
    local haveDiscount = false
    local enabled    = true
    local icon       = ""
    local isLink = false

    if (action == "showroom")
    {
      actionText = ::loc(isUsable ? "mainmenu/btnShowroom" : "mainmenu/btnPreview")
      icon       = "#ui/gameuiskin#slot_showroom.svg"
      showAction = inMenu
      actionFunc = (@(unit, handler) function () {
        handler.checkedCrewModify((@(unit, handler) function () {
          ::broadcastEvent("BeforeStartShowroom")
          ::show_aircraft = unit
          handler.goForward(::gui_start_decals)
        })(unit, handler))
      })(unit, handler)
    }
    if (action == "preview")
    {
      actionText = ::loc("mainmenu/btnPreview")
      icon       = "#ui/gameuiskin#btn_preview.svg"
      showAction = inMenu
      actionFunc = @() unit.doPreview()
    }
    else if (action == "aircraft")
    {
      if (!crew)
        continue

      actionText = ::loc("multiplayer/changeAircraft")
      icon       = "#ui/gameuiskin#slot_change_aircraft.svg"
      showAction = inMenu && ::SessionLobby.canChangeCrewUnits()
      actionFunc = function () {
        if (::g_crews_list.isSlotbarOverrided)
        {
          ::showInfoMsgBox(::loc("multiplayer/slotbarOverrided"))
          return
        }
        ::queues.checkAndStart(function()
        {
          if (!handler.isValid())
            return

          ::g_squad_utils.checkSquadUnreadyAndDo(this,
            ::Callback(function() {
              ::gui_start_select_unit(crew, handler.getSlotbar() || handler)
            }, this),
            @() null, handler?.shouldCheckCrewsReady)
        },
        null, "isCanModifyCrew")
      }
    }
    else if (action == "crew")
    {
      if (!crew)
        continue

      local discountInfo = ::g_crew.getDiscountInfo(crew.idCountry, crew.idInCountry)

      actionText = ::loc("mainmenu/btnCrew")
      icon       = "#ui/gameuiskin#slot_crew.svg"
      haveWarning = ::isInArray(::get_crew_status_by_id(crew.id), [ "ready", "full" ])
      haveDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo) > 0
      showAction = inMenu && !::g_crews_list.isSlotbarOverrided
      actionFunc = @() crew && ::gui_modal_crew({
        countryId = crew.idCountry,
        idInCountry = crew.idInCountry,
        curEdiff = curEdiff
      })
    }
    else if (action == "weapons")
    {
      actionText = ::loc("mainmenu/btnWeapons")
      icon       = "#ui/gameuiskin#btn_weapons.svg"
      haveWarning = ::checkUnitWeapons(unit) != ::UNIT_WEAPONS_READY
      haveDiscount = ::get_max_weaponry_discount_by_unitName(unit.name) > 0
      showAction = inMenu && !::g_crews_list.isSlotbarOverrided
      actionFunc = (@(unit) function () { ::open_weapons_for_unit(unit, { curEdiff = curEdiff }) })(unit)
    }
    else if (action == "take")
    {
      actionText = ::loc("mainmenu/btnTakeAircraft")
      icon       = "#ui/gameuiskin#slot_crew.svg"
      showAction = inMenu && isUsable && !::isUnitInSlotbar(unit)
      actionFunc = (@(unit, handler) function () {
        handler.onTake(unit)
      })(unit, handler)
    }
    else if (action == "repair")
    {
      local repairCost = ::wp_get_repair_cost(unit.name)
      actionText = ::loc("mainmenu/btnRepair")+": "+::Cost(repairCost).getTextAccordingToBalance()
      icon       = "#ui/gameuiskin#slot_repair.svg"
      haveWarning = true
      showAction = inMenu && isUsable && repairCost > 0 && ::SessionLobby.canChangeCrewUnits()
         && !::g_crews_list.isSlotbarOverrided
      actionFunc = @() unit.repair()
    }
    else if (action == "buy")
    {
      local isSpecial   = ::isUnitSpecial(unit)
      local isGift   = ::isUnitGift(unit)
      local canBuyOnline = ::canBuyUnitOnline(unit)
      local canBuyIngame = !canBuyOnline && ::canBuyUnit(unit)
      local priceText = ""

      if (canBuyIngame)
      {
        priceText = ::getUnitCost(unit).getTextAccordingToBalance()
        if (priceText.len())
          priceText = ::loc("ui/colon") + priceText
      }

      actionText = isGift && xboxShopData.canUseIngameShop() ? ::loc("items/openIn/XboxStore")
                                                             : (::loc("mainmenu/btnOrder") + priceText)

      icon       = isGift ? ( xboxShopData.canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg"
                                                              : "#ui/gameuiskin#store_icon.svg")
                          : isSpecial ? "#ui/gameuiskin#shop_warpoints_premium"
                                      : "#ui/gameuiskin#shop_warpoints"

      showAction = inMenu && (canBuyIngame || canBuyOnline)
      isLink     = canBuyOnline
      if (canBuyOnline)
        actionFunc = (@(unit) function () {
          OnlineShopModel.showGoods({
            unitName = unit.name
          })
        })(unit)
      else
        actionFunc = (@(unit) function () {
          ::buyUnit(unit)
        })(unit)
    }
    else if (action == "research")
    {
      if (::isUnitResearched(unit))
        continue

      local countryExp = ::shop_get_country_excess_exp(::getUnitCountry(unit), ::get_es_unit_type(unit))
      local reqExp = ::getUnitReqExp(unit) - ::getUnitExp(unit)
      local getReqExp = reqExp < countryExp ? reqExp : countryExp
      local needToFlushExp = handler?.shopResearchMode && countryExp > 0 //!!FIX ME: Direct search params in the handler not a good idea

      actionText = needToFlushExp
                   ? ::format(::loc("mainmenu/btnResearch") + " (%s)", ::Cost().setRp(getReqExp).tostring())
                   : ( ::isUnitInResearch(unit) && handler?.setResearchManually
                      ? ::loc("mainmenu/btnConvert")
                      : ::loc("mainmenu/btnResearch"))
      //icon       = "#ui/gameuiskin#slot_research"
      showAction = inMenu && (!::isUnitInResearch(unit) || ::has_feature("SpendGold")) && (::isUnitFeatureLocked(unit) || ::canResearchUnit(unit))
      enabled = showAction
      actionFunc = needToFlushExp
                  ? (@(handler) function() {handler.onSpendExcessExp()})(handler)
                  : ( !handler?.setResearchManually?
                      (@(handler) function () { handler.onCloseShop() })(handler)
                      : (::isUnitInResearch(unit) ?
                          (@(unit, handler) function () { ::gui_modal_convertExp(unit, handler) })(unit, handler)
                          : (@(unit) function () { if (::checkForResearch(unit))
                                                      {
                                                        ::add_big_query_record("choosed_new_research_unit", unit.name)
                                                        ::researchUnit(unit)}
                                                      })(unit)))
    }
    else if (action == "testflight" || action == "testflightforced")
    {
      local shouldSkipUnitCheck = action == "testflightforced"

      actionText = unit.unitType.getTestFlightText()
      icon       = unit.unitType.testFlightIcon
      showAction = inMenu && ::isTestFlightAvailable(unit, shouldSkipUnitCheck)
      actionFunc = function () {
        ::queues.checkAndStart(@() ::gui_start_testflight(unit, null, shouldSkipUnitCheck),
          null, "isCanNewflight")
      }
    }
    else if (action == "info")
    {
      actionText = ::loc("mainmenu/btnAircraftInfo")
      icon       = "#ui/gameuiskin#btn_info.svg"
      showAction = ::isUnitDescriptionValid(unit)
      isLink     = ::has_feature("WikiUnitInfo")
      actionFunc = (@(unit) function () {
        if (::has_feature("WikiUnitInfo"))
          ::open_url(::format(::loc("url/wiki_objects"), unit.name), false, false, "unit_actions")
        else
          ::gui_start_aircraft_info(unit.name)
      })(unit)
    }

    res.actions.append({
      actionName   = action
      text         = actionText
      show         = showAction
      enabled      = enabled
      icon         = icon
      action       = actionFunc
      haveWarning  = haveWarning
      haveDiscount = haveDiscount
      isLink       = isLink
    })
  }

  return res
}

function isAircraft(unit)
{
  return get_es_unit_type(unit) == ::ES_UNIT_TYPE_AIRCRAFT
}

function isShip(unit)
{
  return get_es_unit_type(unit) == ::ES_UNIT_TYPE_SHIP
}

function isTank(unit)
{
  return get_es_unit_type(unit) == ::ES_UNIT_TYPE_TANK
}

function is_submarine(unit)
{
  return get_es_unit_type(unit) == ::ES_UNIT_TYPE_SHIP && ::isInArray("submarine", ::getTblValue("tags", unit, []))
}

function get_es_unit_type(unit)
{
  return ::getTblValue("esUnitType", unit, ::ES_UNIT_TYPE_INVALID)
}

function getUnitTypeTextByUnit(unit)
{
  return ::getUnitTypeText(::get_es_unit_type(unit))
}

function isCountryHaveUnitType(country, unitType)
{
  foreach(unit in ::all_units)
    if (unit.shopCountry == country && ::get_es_unit_type(unit) == unitType)
      return true
  return false
}

function getUnitRarity(unit)
{
  if (::isUnitDefault(unit))
    return "reserve"
  if (::isUnitSpecial(unit))
    return "premium"
  if (::isUnitGift(unit))
    return "gift"
  return "common"
}

function isUnitsEraUnlocked(unit)
{
  return ::is_era_available(::getUnitCountry(unit), ::getUnitRank(unit), ::get_es_unit_type(unit))
}

function getUnitsNeedBuyToOpenNextInEra(countryId, unitType, rank, ranksBlk = null)
{
  ranksBlk = ranksBlk || ::get_ranks_blk()
  local unitTypeText = getUnitTypeText(unitType)

  local commonPath = "needBuyToOpenNextInEra." + countryId + ".needBuyToOpenNextInEra"

  local needToOpen = ::getTblValueByPath(commonPath + unitTypeText + rank, ranksBlk)
  if (needToOpen != null)
    return needToOpen

  needToOpen = ::getTblValue(commonPath + rank, ranksBlk)
  if (needToOpen != null)
    return needToOpen

  return -1
}

function getUnitRank(unit)
{
  if (!unit)
    return -1
  return unit.rank
}

function getUnitCountry(unit)
{
  return ::getTblValue("shopCountry", unit, "")
}

function isUnitDefault(unit)
{
  if (!("name" in unit))
    return false
  return ::is_default_aircraft(unit.name)
}

function isUnitGift(unit)
{
  return unit.gift != null
}

function get_unit_country_icon(unit, needOriginCountry = false)
{
  return ::get_country_icon(needOriginCountry ? unit.getOriginCountry() : unit.shopCountry)
}

function checkAirShopReq(air)
{
  return ::getTblValue("shopReq", air, true)
}

function isUnitGroup(unit)
{
  return unit && "airsGroup" in unit
}

function isGroupPart(unit)
{
  return unit && unit.group != null
}

function canResearchUnit(unit)
{
  local isInShop = ::getTblValue("isInShop", unit)
  if (isInShop == null)
  {
    debugTableData(unit)
    ::dagor.assertf(false, "not existing isInShop param")
    return false
  }

  if (!isInShop)
    return false

  local status = ::shop_unit_research_status(unit.name)
  return (0 != (status & (::ES_ITEM_STATUS_IN_RESEARCH | ::ES_ITEM_STATUS_CAN_RESEARCH))) && !::isUnitMaxExp(unit)
}

function canBuyUnit(unit)
{
  //temporary check while shop_is_unit_available is broken
  /*
  if (::isUnitGift(unit))
    return false

  if (::isUnitSpecial(unit) && !::isUnitBought(unit))
    return true

  if(!("name" in unit))
    return false
  */
  local status = ::shop_unit_research_status(unit.name)
  return (0 != (status & ::ES_ITEM_STATUS_CAN_BUY)) && ::is_unit_visible_in_shop(unit)
}

function is_unit_visible_in_shop(unit)
{
  return unit.isVisibleInShop()
}

function can_crew_take_unit(unit)
{
  return isUnitUsable(unit) && is_unit_visible_in_shop(unit)
}

function canBuyUnitOnline(unit)
{
  return !::isUnitBought(unit) && ::isUnitGift(unit)
}

function isUnitInResearch(unit)
{
  if (!unit)
    return false

  if(!("name" in unit))
    return false

  local status = ::shop_unit_research_status(unit.name)
  return (status == ::ES_ITEM_STATUS_IN_RESEARCH) && !::isUnitMaxExp(unit)
}

function findUnitNoCase(unitName)
{
  unitName = unitName.tolower()
  foreach(name, unit in ::all_units)
    if (name.tolower() == unitName)
      return unit
  return null
}

function getCountryResearchUnit(countryName, unitType)
{
  local unitName = ::shop_get_researchable_unit_name(countryName, unitType)
  return ::getAircraftByName(unitName)
}

function getUnitName(unit, shopName = true)
{
  local unitId = ::u.isUnit(unit) ? unit.name
    : ::u.isString(unit) ? unit
    : ""
  local localized = ::loc(unitId + (shopName ? "_shop" : "_0"), unitId)
  return shopName ? ::stringReplace(localized, " ", ::nbsp) : localized
}

function isUnitDescriptionValid(unit)
{
  if (::is_platform_pc)
    return true // Because there is link to wiki.
  local desc = unit ? ::loc("encyclopedia/" + unit.name + "/desc", "") : ""
  return desc != "" && desc != ::loc("encyclopedia/no_unit_description")
}

function getUnitRealCost(unit)
{
  return ::Cost(unit.cost, unit.costGold)
}

function getUnitCost(unit)
{
  return ::Cost(::wp_get_cost(unit.name),
                ::wp_get_cost_gold(unit.name))
}

function isUnitBought(unit)
{
  return unit ? unit.isBought() : false
}

function isUnitEliteByStatus(status)
{
  return status > ::ES_UNIT_ELITE_STAGE1
}

function isUnitElite(unit)
{
  local unitName = ::getTblValue("name", unit)
  return unitName ? ::isUnitEliteByStatus(::get_unit_elite_status(unitName)) : false
}

function isUnitBroken(unit)
{
  return ::getUnitRepairCost(unit) > 0
}

/**
 * Returns true if unit can be installed in slotbar,
 * unit can be decorated with decals, etc...
 */
function isUnitUsable(unit)
{
  return unit ? unit.isUsable() : false
}

function isUnitFeatureLocked(unit)
{
  return unit.reqFeature != null && !::has_feature(unit.reqFeature)
}

function checkUnitHideFeature(unit)
{
  return !unit.hideFeature || ::has_feature(unit.hideFeature)
}

function getUnitRepairCost(unit)
{
  if ("name" in unit)
    return ::wp_get_repair_cost(unit.name)
  return 0
}

function buyUnit(unit, silent = false)
{
  if (!::checkFeatureLock(unit, CheckFeatureLockAction.BUY))
    return false

  local unitCost = ::getUnitCost(unit)
  if (unitCost.gold > 0 && !::can_spend_gold_on_unit_with_popup(unit))
    return false

  if (!::canBuyUnit(unit))
  {
    if (::isUnitResearched(unit) && !silent)
      ::show_cant_buy_or_research_unit_msgbox(unit)
    return false
  }

  if (silent)
    return ::impl_buyUnit(unit)

  local unitName  = ::colorize("userlogColoredText", ::getUnitName(unit, true))
  local cost = ::getUnitCost(unit)
  local unitPrice = ::colorize("activeTextColor", cost)
  local msgText = warningIfGold(::loc("shop/needMoneyQuestion_purchaseAircraft",
      {unitName = unitName, cost = unitPrice}),
    cost)

  local additionalCheckBox = null
  if (::facebook_is_logged_in() && ::has_feature("FacebookWallPost"))
  {
    additionalCheckBox = "cardImg{ background-image:t='#ui/gameuiskin#facebook_logo';}" +
                     "CheckBox {" +
                      "id:t='chbox_post_facebook_purchase'" +
                      "text:t='#facebook/shareMsg'" +
                      "value:t='no'" +
                      "on_change_value:t='onFacebookPostPurchaseChange';" +
                      "btnName:t='X';" +
                      "ButtonImg{}" +
                      "CheckBoxImg{}" +
                     "}"
  }

  ::scene_msg_box("need_money", null, msgText,
                  [["yes", (@(unit) function() {::impl_buyUnit(unit) })(unit) ],
                   ["no", function() {} ]],
                  "yes", { cancel_fn = function() {}, data_below_text = additionalCheckBox})
  return true
}

function impl_buyUnit(unit)
{
  if (!unit)
    return false
  if (unit.isBought())
    return false
  if (!::old_check_balance_msgBox(::wp_get_cost(unit.name), ("costGold" in unit) ? ::wp_get_cost_gold(unit.name) : 0))
    return false

  local unitName = unit.name
  local taskId = ::shop_purchase_aircraft(unitName)
  local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/purchase"), null, null)
  ::add_bg_task_cb(taskId, (@(unit, progressBox) function() {
      ::destroyMsgBox(progressBox)

      local config = {
        locId = "purchase_unit"
        subType = ps4_activity_feed.PURCHASE_UNIT
        backgroundPost = true
      }

      local custConfig = {
        requireLocalization = ["unitName", "country"]
        unitNameId = unit.name
        unitName = unit.name + "_shop"
        rank = ::get_roman_numeral(::getUnitRank(unit))
        country = ::getUnitCountry(unit)
        link = ::format(::loc("url/wiki_objects"), unit.name)
      }

      local postFeeds = ::FACEBOOK_POST_WALL_MESSAGE? bit_activity.FACEBOOK : bit_activity.NONE
      if (::is_platform_ps4)
        postFeeds = postFeeds == bit_activity.NONE? bit_activity.PS4_ACTIVITY_FEED : bit_activity.ALL

      ::prepareMessageForWallPostAndSend(config, custConfig, postFeeds)

      ::broadcastEvent("UnitBought", {unitName = unit.name})
    })(unit, progressBox)
  )
  return true
}

function researchUnit(unit, checkCurrentUnit = true)
{
  if (!::canResearchUnit(unit) || (checkCurrentUnit && ::isUnitInResearch(unit)))
    return

  local prevUnitName = ::shop_get_researchable_unit_name(::getUnitCountry(unit), ::get_es_unit_type(unit))
  local taskId = ::shop_set_researchable_unit(unit.name, ::get_es_unit_type(unit))
  local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/purchase0"), null, null)
  local unitName = unit.name
  ::add_bg_task_cb(taskId, (@(unitName, prevUnitName, progressBox) function() {
      ::destroyMsgBox(progressBox)
      ::broadcastEvent("UnitResearch", {unitName = unitName, prevUnitName = prevUnitName})
    })(unitName, prevUnitName, progressBox)
  )
}

function can_spend_gold_on_unit_with_popup(unit)
{
  if (unit.unitType.canSpendGold())
    return true

  ::g_popups.add(::getUnitName(unit), ::loc("msgbox/unitTypeRestrictFromSpendGold"),
    null, null, null, "cant_spend_gold_on_unit")
  return false
}

function show_cant_buy_or_research_unit_msgbox(unit)
{
  local reason = ::getCantBuyUnitReason(unit)
  if (::u.isEmpty(reason))
    return true

  local selectButton = "ok"
  local buttons = [["ok", function () {}]]
  local prevUnit = ::getPrevUnit(unit)
  if (prevUnit && ::canBuyUnit(prevUnit))
  {
    selectButton = "purchase"
    reason += " " + ::loc("mainmenu/canBuyThisVehicle", {price = ::colorize("activeTextColor", ::getUnitCost(prevUnit))})
    buttons = [["purchase", (@(prevUnit) function () { ::buyUnit(prevUnit, true) })(prevUnit)],
             ["cancel", function () {}]]
  }

  ::scene_msg_box("need_buy_prev", null, reason, buttons, selectButton)
  return false
}

function checkFeatureLock(unit, lockAction)
{
  if (!::isUnitFeatureLocked(unit))
    return true
  local params = {
    purchaseAvailable = ::has_feature("OnlineShopPacks")
    featureLockAction = lockAction
    unit = unit
  }

  ::gui_start_modal_wnd(::gui_handlers.VehicleRequireFeatureWindow, params)
  return false
}

function checkForResearch(unit)
{
  // Feature lock has higher priority than ::canResearchUnit.
  if (!::checkFeatureLock(unit, CheckFeatureLockAction.RESEARCH))
    return false

  if (::canResearchUnit(unit))
    return true

  if (!::isUnitSpecial(unit) && !::isUnitGift(unit) && !::isUnitsEraUnlocked(unit))
  {
    ::showInfoMsgBox(getCantBuyUnitReason(unit), "need_unlock_rank")
    return false
  }
  return ::show_cant_buy_or_research_unit_msgbox(unit)
}

/**
 * Used in shop tooltip display logic.
 */
function need_buy_prev_unit(unit)
{
  if (::isUnitBought(unit) || ::isUnitGift(unit))
    return false
  if (!::isUnitSpecial(unit) && !::isUnitsEraUnlocked(unit))
    return false
  if (!::isPrevUnitBought(unit))
    return true
  return false
}

function getCantBuyUnitReason(unit, isShopTooltip = false)
{
  if (!unit)
    return ::loc("leaderboards/notAvailable")

  if (::isUnitBought(unit) || ::isUnitGift(unit))
    return ""

  local special = ::isUnitSpecial(unit)
  if (!special && !::isUnitsEraUnlocked(unit))
  {
    local countryId = ::getUnitCountry(unit)
    local unitType = ::get_es_unit_type(unit)
    local rank = ::getUnitRank(unit)

    for (local prevRank = rank - 1; prevRank > 0; prevRank--)
    {
      local unitsCount = 0
      foreach (u in ::all_units)
        if (::isUnitBought(u) && ::getUnitRank(u) == prevRank && ::getUnitCountry(u) == countryId && ::get_es_unit_type(u) == unitType)
          unitsCount++
      local unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(countryId, unitType, prevRank)
      local unitsLeft = max(0, unitsNeed - unitsCount)

      if (unitsLeft > 0)
      {
        return ::loc("shop/unlockTier/locked", { rank = ::get_roman_numeral(rank) })
          + "\n" + ::loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = ::get_roman_numeral(prevRank), amount = unitsLeft })
      }
    }
    return ::loc("shop/unlockTier/locked", { rank = ::get_roman_numeral(rank) })
  }
  else if (!::isPrevUnitResearched(unit))
  {
    if (isShopTooltip)
      return ::loc("mainmenu/needResearchPreviousVehicle")
    if (!::isUnitResearched(unit))
      return ::loc("msgbox/need_unlock_prev_unit/research",
        {name = ::colorize("userlogColoredText", ::getUnitName(::getPrevUnit(unit), true))})
    return ::loc("msgbox/need_unlock_prev_unit/researchAndPurchase",
      {name = ::colorize("userlogColoredText", ::getUnitName(::getPrevUnit(unit), true))})
  }
  else if (!::isPrevUnitBought(unit))
  {
    if (isShopTooltip)
      return ::loc("mainmenu/needBuyPreviousVehicle")
    return ::loc("msgbox/need_unlock_prev_unit/purchase", {name = ::colorize("userlogColoredText", ::getUnitName(::getPrevUnit(unit), true))})
  }
  else if (unit.reqUnlock && !::is_unlocked_scripted(-1, unit.reqUnlock))
  {
    local unlockBlk = ::g_unlocks.getUnlockById(unit.reqUnlock)
    local conditions = ::build_conditions_config(unlockBlk)

    return ::loc("mainmenu/needUnlock") + "\n" + ::build_unlock_desc(conditions,
      { showProgress = true
        showValueForBitList = true
      }).text
  }
  else if (!special && !::canBuyUnit(unit) && ::canResearchUnit(unit))
    return ::loc(::isUnitInResearch(unit) ? "mainmenu/needResearch/researching" : "mainmenu/needResearch")

  if (!isShopTooltip)
  {
    local info = ::get_profile_info()
    local balance = ::getTblValue("balance", info, 0)
    local balanceG = ::getTblValue("gold", info, 0)

    if (special && (::wp_get_cost_gold(unit.name) > balanceG))
      return ::loc("mainmenu/notEnoughGold")
    else if (!special && (::wp_get_cost(unit.name) > balance))
      return ::loc("mainmenu/notEnoughWP")
   }

  return ""
}

function isUnitAvailableForGM(air, gm)
{
  if (!air.unitType.isAvailable())
    return false
  if (gm == ::GM_TEST_FLIGHT)
    return air.testFlight != ""
  if (gm == ::GM_DYNAMIC || gm == ::GM_BUILDER)
    return air.isAir()
  return true
}

function isTestFlightAvailable(unit, skipUnitCheck = false)
{
  if (!::isUnitAvailableForGM(unit, ::GM_TEST_FLIGHT))
    return false

  if (unit.isUsable()
      || skipUnitCheck
      || ::canResearchUnit(unit)
      || ::isUnitGift(unit)
      || ::isUnitResearched(unit)
      || ::isUnitSpecial(unit)
      || ::g_decorator.approversUnitToPreviewLiveResource == unit)
    return true

  return false
}

function getMaxRankUnboughtUnitByCountry(country, unitType)
{
  local unit = null
  foreach (newUnit in ::all_units)
    if (!country || country == ::getUnitCountry(newUnit))
      if (::getTblValue("rank", newUnit, 0) > ::getTblValue("rank", unit, 0))
        if (unitType == ::get_es_unit_type(newUnit)
            && !::isUnitSpecial(newUnit)
            && ::canBuyUnit(newUnit)
            && ::isPrevUnitBought(newUnit))
          unit = newUnit
  return unit
}

function getMaxRankResearchingUnitByCountry(country, unitType)
{
  local unit = null
  foreach (newUnit in ::all_units)
    if (country == ::getUnitCountry(newUnit))
      if (unitType == ::get_es_unit_type(newUnit) && ::canResearchUnit(newUnit))
        unit = (::getTblValue("rank", newUnit, 0) > ::getTblValue("rank", unit, 0))? newUnit : unit
  return unit
}

function _afterUpdateAirModificators(unit, callback)
{
  if (unit.secondaryWeaponMods)
    unit.secondaryWeaponMods = null //invalidate secondary weapons cache
  ::broadcastEvent("UnitModsRecount", { unit = unit })
  if(callback != null)
    callback()
}

//return true when modificators already valid.
function check_unit_mods_update(air, callBack = null, forceUpdate = false)
{
  if (!air.isInited)
  {
    ::script_net_assert_once("not inited unit request", "try to call check_unit_mods_update for not inited unit")
    return false
  }

  if (air.modificatorsRequestTime > 0
    && air.modificatorsRequestTime + MODIFICATORS_REQUEST_TIMEOUT_MSEC > ::dagor.getCurTime())
  {
    if (forceUpdate)
      ::remove_calculate_modification_effect_jobs()
    else
      return false
  }
  else if (!forceUpdate && air.modificators)
    return true

  if (::isShip(air))
  {
    air.modificatorsRequestTime = ::dagor.getCurTime()
    calculate_ship_parameters_async(air.name, this, (@(air, callBack) function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect)
      {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }
        if (!air.modificatorsBase)
          air.modificatorsBase = air.modificators
      }

      ::_afterUpdateAirModificators(air, callBack)
    })(air, callBack))
    return false
  }

  if (isTank(air))
  {
    air.modificatorsRequestTime = ::dagor.getCurTime()
    calculate_tank_parameters_async(air.name, this, (@(air, callBack) function(effect, ...) {
      air.modificatorsRequestTime = -1
      if (effect)
      {
        air.modificators = {
          arcade = effect.arcade
          historical = effect.historical
          fullreal = effect.fullreal
        }
        if (!air.modificatorsBase) // TODO: Needs tank params _without_ user progress here.
          air.modificatorsBase = air.modificators
      }
      ::_afterUpdateAirModificators(air, callBack)
    })(air, callBack))
    return false
  }

  air.modificatorsRequestTime = ::dagor.getCurTime()
  ::calculate_min_and_max_parameters(air.name, this, (@(air, callBack) function(effect, ...) {
    air.modificatorsRequestTime = -1
    if (effect)
    {
      air.modificators = {
        arcade = effect.arcade
        historical = effect.historical
        fullreal = effect.fullreal
      }
      air.minChars = effect.min
      air.maxChars = effect.max
    }
    ::_afterUpdateAirModificators(air, callBack)
  })(air, callBack))
  return false
}

// modName == ""  mean 'all mods'.
function updateAirAfterSwitchMod(air, modName = null)
{
  if (!air)
    return

  if (air.name == ::hangar_get_current_unit_name() && modName)
  {
    local modsList = modName == "" ? air.modifications : [ ::getModificationByName(air, modName) ]
    foreach (mod in modsList)
    {
      if (!::getTblValue("requiresModelReload", mod, false))
        continue
      ::hangar_force_reload_model()
      break
    }
  }

  if (!::isUnitGroup(air))
    ::check_unit_mods_update(air, null, true)
}

//return true when already counted
function check_secondary_weapon_mods_recount(unit, callback = null)
{
  switch(::get_es_unit_type(unit))
  {
    case ::ES_UNIT_TYPE_AIRCRAFT:
    case ::ES_UNIT_TYPE_HELICOPTER:

      local weaponName = ::get_last_weapon(unit.name)
      local secondaryMods = unit.secondaryWeaponMods
      if (secondaryMods && secondaryMods.weaponName == weaponName)
      {
        if (secondaryMods.effect)
          return true
        if (callback)
          secondaryMods.callback = callback
        return false
      }

      unit.secondaryWeaponMods = {
        weaponName = weaponName
        effect = null
        callback = callback
      }

      ::calculate_mod_or_weapon_effect(unit.name, weaponName, false, this, function(effect, ...) {
        local secondaryMods = unit.secondaryWeaponMods
        if (!secondaryMods || weaponName != secondaryMods.weaponName)
          return

        secondaryMods.effect <- effect || {}
        ::broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
        if(secondaryMods.callback != null)
        {
          secondaryMods.callback()
          secondaryMods.callback = null
        }
      })
      return false

    case ::ES_UNIT_TYPE_SHIP:

      local torpedoMod = "torpedoes_movement_mode"
      local mod = ::getModificationByName(unit, torpedoMod)
      if (!mod || mod?.effects)
        return true
      ::calculate_mod_or_weapon_effect(unit.name, torpedoMod, true, this, function(effect, ...) {
        mod.effects <- effect
        if (callback)
          callback()
        ::broadcastEvent("SecondWeaponModsUpdated", { unit = unit })
      })
      return false

    default:
      return true
  }
}

function getUnitExp(unit)
{
  return ::shop_get_unit_exp(unit.name)
}

function getUnitReqExp(unit)
{
  if(!("reqExp" in unit))
    return 0
  return unit.reqExp
}

function isUnitMaxExp(unit) //temporary while not exist correct status between in_research and canBuy
{
  return ::isUnitSpecial(unit) || (::getUnitReqExp(unit) <= ::getUnitExp(unit))
}

function getNextTierModsCount(unit, tier)
{
  if (tier < 1 || tier > unit.needBuyToOpenNextInTier.len() || !("modifications" in unit))
    return 0

  local req = unit.needBuyToOpenNextInTier[tier-1]
  foreach(mod in unit.modifications)
    if (("tier" in mod) && mod.tier == tier &&
        !::wp_get_modification_cost_gold(unit.name, mod.name) &&
        ::getModificationBulletsGroup(mod.name) == "" &&
        ::isModResearched(unit, mod)
       )
      req--
  return max(req, 0)
}

function generateUnitShopInfo()
{
  local blk = ::get_shop_blk()
  local totalCountries = blk.blockCount()

  for(local c = 0; c < totalCountries; c++)  //country
  {
    local cblk = blk.getBlock(c)
    local totalPages = cblk.blockCount()

    for(local p = 0; p < totalPages; p++)
    {
      local pblk = cblk.getBlock(p)
      local totalRanges = pblk.blockCount()

      for(local r = 0; r < totalRanges; r++)
      {
        local rblk = pblk.getBlock(r)
        local totalAirs = rblk.blockCount()
        local prevAir = null

        for(local a = 0; a < totalAirs; a++)
        {
          local airBlk = rblk.getBlock(a)
          local air = ::getAircraftByName(airBlk.getBlockName())

          if (airBlk.reqAir != null)
            prevAir = airBlk.reqAir

          if (air)
          {
            air.applyShopBlk(airBlk, prevAir)
            prevAir = air.name
          }
          else //aircraft group
          {
            local groupTotal = airBlk.blockCount()
            local firstIGroup = null
            local groupName = airBlk.getBlockName()
            for(local ga = 0; ga < groupTotal; ga++)
            {
              local gAirBlk = airBlk.getBlock(ga)
              air = ::getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                continue
              air.applyShopBlk(gAirBlk, prevAir, groupName)
              prevAir = air.name
              if (!firstIGroup)
                firstIGroup = air
            }

            if (firstIGroup
                && !::isUnitSpecial(firstIGroup)
                && !::isUnitGift(firstIGroup))
              prevAir = firstIGroup.name
            else
              prevAir = null
          }
        }
      }
    }
  }
}

function has_platform_from_blk_str(blk, fieldName, defValue = false, separator = "; ")
{
  local listStr = blk[fieldName]
  if (!::u.isString(listStr))
    return defValue
  return ::isInArray(::target_platform, ::split(listStr, separator))
}

function getPrevUnit(unit)
{
  return "reqAir" in unit ? ::getAircraftByName(unit.reqAir) : null
}

function isUnitLocked(unit)
{
  local status = ::shop_unit_research_status(unit.name)
  return 0 != (status & ::ES_ITEM_STATUS_LOCKED)
}

function isUnitResearched(unit)
{
  if (::isUnitBought(unit))
    return true

  local status = ::shop_unit_research_status(unit.name)
  return (0 != (status & (::ES_ITEM_STATUS_CAN_BUY | ::ES_ITEM_STATUS_RESEARCHED)))
}

function isPrevUnitResearched(unit)
{
  local prevUnit = ::getPrevUnit(unit)
  if (!prevUnit || ::isUnitResearched(prevUnit))
    return true
  return false
}

function isPrevUnitBought(unit)
{
  local prevUnit = ::getPrevUnit(unit)
  if (!prevUnit || ::isUnitBought(prevUnit))
    return true
  return false
}

function getNextUnits(unit)
{
  local res = []
  foreach (item in ::all_units)
    if ("reqAir" in item && unit.name == item.reqAir)
      res.append(item)
  return res
}

function setOrClearNextUnitToResearch(unit, country, type) //return -1 when clear prev
{
  if (unit)
    return ::shop_set_researchable_unit(unit.name, type)

  ::shop_reset_researchable_unit(country, type)
  return -1
}

function getMinBestLevelingRank(unit)
{
  if (!unit)
    return -1

  local unitRank = ::getUnitRank(unit)
  if (::isUnitSpecial(unit) || unitRank == 1)
    return 1
  local result = unitRank - ::getHighestRankDiffNoPenalty(true)
  return result > 0 ? result : 1
}

function getMaxBestLevelingRank(unit)
{
  if (!unit)
    return -1

  local unitRank = ::getUnitRank(unit)
  if (unitRank == ::max_country_rank)
    return ::max_country_rank
  local result = unitRank + ::getHighestRankDiffNoPenalty()
  return result <= ::max_country_rank ? result : ::max_country_rank
}

function getHighestRankDiffNoPenalty(inverse = false)
{
  local ranksBlk = ::get_ranks_blk()
  local paramPrefix = inverse
                      ? "expMulWithTierDiffMinus"
                      : "expMulWithTierDiff"

  for (local rankDif = 0; rankDif < ::max_country_rank; rankDif++)
    if (ranksBlk[paramPrefix + rankDif] < 0.8)
      return rankDif - 1
}

function getUnitRankName(rank, full = false)
{
  return full? ::loc("shop/age/" + rank.tostring() + "/name") : ::get_roman_numeral(rank)
}

function get_battle_type_by_unit(unit)
{
  return (::get_es_unit_type(unit) == ::ES_UNIT_TYPE_TANK)? BATTLE_TYPES.TANK : BATTLE_TYPES.AIR
}

function get_unit_tooltip_image(unit)
{
  if (unit.customTooltipImage)
    return unit.customTooltipImage

  switch (::get_es_unit_type(unit))
  {
    case ::ES_UNIT_TYPE_AIRCRAFT:       return "ui/aircrafts/" + unit.name
    case ::ES_UNIT_TYPE_HELICOPTER:     return "ui/aircrafts/" + unit.name
    case ::ES_UNIT_TYPE_TANK:           return "ui/tanks/" + unit.name
    case ::ES_UNIT_TYPE_SHIP:           return "ui/ships/" + unit.name
  }
  return ""
}

function get_chance_to_met_text(battleRating1, battleRating2)
{
  local brDiff = fabs(battleRating1.tofloat() - battleRating2.tofloat())
  local brData = null
  foreach(data in ::chances_text)
    if (!brData
        || (data.brDiff <= brDiff && data.brDiff > brData.brDiff))
      brData = data
  return brData? format("<color=%s>%s</color>", brData.color, ::loc(brData.text)) : ""
}

function getCharacteristicActualValue(air, characteristicName, prepareTextFunc, modeName, showLocalState = true)
{
  local modificators = showLocalState ? "modificators" : "modificatorsBase"

  local showReferenceText = false
  if (!(characteristicName[0] in air.shop))
    air.shop[characteristicName[0]] <- 0;

  local value = air.shop[characteristicName[0]] + (air[modificators] ? air[modificators][modeName][characteristicName[1]] : 0)
  local min = air.minChars ? air.shop[characteristicName[0]] + air.minChars[modeName][characteristicName[1]] : value
  local max = air.maxChars ? air.shop[characteristicName[0]] + air.maxChars[modeName][characteristicName[1]] : value
  local text = prepareTextFunc(value)
  if(air[modificators] && air[modificators][modeName][characteristicName[1]] == 0)
  {
    text = "<color=@goodTextColor>" + text + "</color>*"
    showReferenceText = true
  }

  local weaponModValue = ::getTblValueByPath("secondaryWeaponMods.effect." + modeName + "." + characteristicName[1], air, 0)
  local weaponModText = ""
  if(weaponModValue != 0)
    weaponModText = "<color=@badTextColor>" + (weaponModValue > 0 ? " + " : " - ") + prepareTextFunc(fabs(weaponModValue)) + "</color>"
  return [text, weaponModText, min, max, value, air.shop[characteristicName[0]], showReferenceText]
}

function setReferenceMarker(obj, min, max, refer, modeName)
{
  if(!::checkObj(obj))
    return

  local refMarkerObj = obj.findObject("aircraft-reference-marker")
  if (::checkObj(refMarkerObj))
  {
    if(min == max || (modeName == "arcade"))
    {
      refMarkerObj.show(false)
      return
    }

    refMarkerObj.show(true)
    local left = (refer - min) / (max - min)
    refMarkerObj.left = ::format("%.3fpw - 0.5w)", left)
  }
}

function fillAirCharProgress(progressObj, min, max, cur)
{
  if(!::checkObj(progressObj))
    return
  if(min == max)
    return progressObj.show(false)
  else
    progressObj.show(true)
  local value = ((cur - min) / (max - min)) * 1000.0
  progressObj.setValue(value)
}

function fillAirInfoTimers(holderObj, air, needShopInfo)
{
  SecondsUpdater(holderObj, (@(air, needShopInfo) function(obj, params) {
    local isActive = false

    // Unit repair cost
    local hp = shop_get_aircraft_hp(air.name)
    local isBroken = hp >= 0 && hp < 1
    isActive = isActive || isBroken
    local hpTrObj = obj.findObject("aircraft-condition-tr")
    if (hpTrObj)
      if (isBroken)
      {
        //local hpText = format("%d%%", floor(hp*100))
        //hpText += (hp < 1)? " (" + time.hoursToString(shop_time_until_repair(air.name)) + ")" : ""
        local hpText = ::loc("shop/damaged") + " (" + time.hoursToString(shop_time_until_repair(air.name), false, true) + ")"
        hpTrObj.show(true)
        hpTrObj.findObject("aircraft-condition").setValue(hpText)
      } else
        hpTrObj.show(false)
    if (needShopInfo && isBroken && obj.findObject("aircraft-repair_cost-tr"))
    {
      local cost = ::wp_get_repair_cost(air.name)
      obj.findObject("aircraft-repair_cost-tr").show(cost > 0)
      obj.findObject("aircraft-repair_cost").setValue(::getPriceAccordingToPlayersCurrency(cost, 0))
    }

    // Unit rent time
    local isRented = air.isRented()
    isActive = isActive || isRented
    local rentObj = obj.findObject("unit_rent_time")
    if (::checkObj(rentObj))
    {
      local sec = air.getRentTimeleft()
      local show = sec > 0
      local value = ""
      if (show)
      {
        local timeStr = time.hoursToString(time.secondsToHours(sec), false, true, true)
        value = ::colorize("goodTextColor", ::loc("mainmenu/unitRentTimeleft") + ::loc("ui/colon") + timeStr)
      }
      if (rentObj.isVisible() != show)
        rentObj.show(show)
      if (show && rentObj.getValue() != value)
        rentObj.setValue(value)
    }

    return !isActive
  })(air, needShopInfo))
}

function get_show_aircraft_name()
{
  return ::show_aircraft? ::show_aircraft.name : ::hangar_get_current_unit_name()
}

function get_show_aircraft()
{
  return ::show_aircraft? ::show_aircraft : ::getAircraftByName(::hangar_get_current_unit_name())
}

function set_show_aircraft(unit)
{
  if (!unit)
    return
  ::show_aircraft = unit
  ::hangar_model_load_manager.loadModel(unit.name)
}

function showAirInfo(air, show, holderObj = null, handler = null, params = null)
{
  handler = handler || ::handlersManager.getActiveBaseHandler()

  if (!::checkObj(holderObj))
  {
    if(holderObj != null)
      return

    if (handler)
      holderObj = handler.scene.findObject("slot_info")
    if (!::checkObj(holderObj))
      return
  }

  holderObj.show(show)
  if (!show || !air)
    return

  local isInFlight = ::is_in_flight()

  local showLocalState   = ::getTblValue("showLocalState", params, true)

  local getEdiffFunc = ::getTblValue("getCurrentEdiff", handler)
  local ediff = getEdiffFunc ? getEdiffFunc.call(handler) : ::get_current_ediff()
  local difficulty = ::get_difficulty_by_ediff(ediff)
  local diffCode = difficulty.diffCode

  local unitType = ::get_es_unit_type(air)
  local crew = ::getCrewByAir(air)

  local isOwn = ::isUnitBought(air)
  local special = ::isUnitSpecial(air)
  local cost = ::wp_get_cost(air.name)
  local costGold = ::wp_get_cost_gold(air.name)
  local aircraftPrice = special ? costGold : cost
  local gift = ::isUnitGift(air)
  local showPrice = showLocalState && !isOwn && aircraftPrice > 0 && !gift
  local isResearched = ::isUnitResearched(air)
  local canResearch = ::canResearchUnit(air)
  local rBlk = ::get_ranks_blk()
  local wBlk = ::get_warpoints_blk()
  local needShopInfo = ::getTblValue("needShopInfo", params, false)
  local needCrewInfo = ::getTblValue("needCrewInfo", params, false)

  local isRented = air.isRented()
  local rentTimeHours = ::getTblValue("rentTimeHours", params, -1)
  local isReceivedPrizes = params?.isReceivedPrizes ??  false
  local showAsRent = showLocalState && isRented || rentTimeHours > 0

  local isSecondaryModsValid = ::check_unit_mods_update(air)
                            && ::check_secondary_weapon_mods_recount(air)

  local obj = holderObj.findObject("aircraft-name")
  if (::checkObj(obj))
    obj.setValue(::getUnitName(air.name, false))

  obj = holderObj.findObject("aircraft-type")
  if (::checkObj(obj))
  {
    local fonticon = ::get_unit_role_icon(air)
    local typeText = ::get_full_unit_role_text(air)
    obj.show(typeText != "")
    obj.setValue(::colorize(::getUnitClassColor(air), fonticon + " " + typeText))
  }

  obj = holderObj.findObject("player_country_exp")
  if (::checkObj(obj))
  {
    obj.show(showLocalState && canResearch)
    if (showLocalState && canResearch)
    {
      local expCur = ::getUnitExp(air)
      local expInvest = ::getTblValue("researchExpInvest", params, 0)
      local expTotal = air.reqExp
      local isResearching = ::isUnitInResearch(air)

      ::fill_progress_bar(obj, expCur - expInvest, expCur, expTotal, !isResearching)

      local labelObj = obj.findObject("exp")
      if (::checkObj(labelObj))
      {
        local statusText = isResearching ? ::loc("shop/in_research") + ::loc("ui/colon") : ""
        local unitsText = ::loc("currency/researchPoints/sign/colored")
        local expText = ::format("%s%s%s%s",
          statusText,
          ::Cost().setRp(expCur).toStringWithParams({isRpAlwaysShown = true}),
          ::loc("ui/slash"),
          ::Cost().setRp(expTotal).tostring())
        expText = ::colorize(isResearching ? "cardProgressTextColor" : "commonTextColor", expText)
        if (expInvest > 0)
          expText += ::colorize("cardProgressTextBonusColor", ::loc("ui/parentheses/space",
            { text = "+ " + ::Cost().setRp(expInvest).tostring() }))
        labelObj.setValue(expText)
      }
    }
  }

  obj = holderObj.findObject("aircraft-countryImg")
  if (::checkObj(obj))
    obj["background-image"] = ::get_unit_country_icon(air, true)

  if (::has_feature("UnitTooltipImage"))
  {
    obj = holderObj.findObject("aircraft-image")
    if (::checkObj(obj))
      obj["background-image"] = ::get_unit_tooltip_image(air)
  }

  local ageObj = holderObj.findObject("aircraft-age")
  if (::checkObj(ageObj))
  {
    local nameObj = ageObj.findObject("age_number")
    if (::checkObj(nameObj))
      nameObj.setValue(::loc("shop/age") + ::getUnitRankName(air.rank, true) + ::loc("ui/colon"))
    local yearsObj = ageObj.findObject("age_years")
    if (::checkObj(yearsObj))
      yearsObj.setValue(::getUnitRankName(air.rank))
  }

  //count unit ratings
  local battleRating = air.getBattleRating(ediff)
  holderObj.findObject("aircraft-battle_rating-header").setValue(::loc("shop/battle_rating") + ::loc("ui/colon"))
  holderObj.findObject("aircraft-battle_rating").setValue(format("%.1f", battleRating))

  local meetObj = holderObj.findObject("aircraft-chance_to_met_tr")
  if (::checkObj(meetObj))
  {
    local erCompare = ::getTblValue("economicRankCompare", params)
    if (erCompare != null)
    {
      if (typeof(erCompare) == "table")
        erCompare = ::getTblValue(air.shopCountry, erCompare, 0.0)
      local text = ::get_chance_to_met_text(battleRating, ::calc_battle_rating_from_rank(erCompare))
      meetObj.findObject("aircraft-chance_to_met").setValue(text)
    }
    meetObj.show(erCompare != null)
  }

  if (showLocalState && (canResearch || (!isOwn && !special && !gift)))
  {
    local prevUnitObj = holderObj.findObject("aircraft-prevUnit_bonus_tr")
    local prevUnit = ::getPrevUnit(air)
    if (::checkObj(prevUnitObj) && prevUnit)
    {
      prevUnitObj.show(true)
      local tdNameObj = prevUnitObj.findObject("aircraft-prevUnit")
      if (::checkObj(tdNameObj))
        tdNameObj.setValue(::format(::loc("shop/prevUnitEfficiencyResearch"), ::getUnitName(prevUnit, true)))
      local tdValueObj = prevUnitObj.findObject("aircraft-prevUnit_bonus")
      if (::checkObj(tdValueObj))
      {
        local curVal = 1
        local param_name = "prevAirExpMulMode"
        if(rBlk[param_name + diffCode.tostring()]!=null)
          curVal = rBlk[param_name + diffCode.tostring()]

        if (curVal != 1)
          tdValueObj.setValue(::format("<color=@userlogColoredText>%s%%</color>", (curVal*100).tostring()))
        else
          prevUnitObj.show(false)
      }
    }
  }

  local rpObj = holderObj.findObject("aircraft-require_rp_tr")
  if (::checkObj(rpObj))
  {
    local showRpReq = showLocalState && !isOwn && !special && !gift && !isResearched && !canResearch
    rpObj.show(showRpReq)
    if (showRpReq)
      rpObj.findObject("aircraft-require_rp").setValue(::Cost().setRp(air.reqExp).tostring())
  }

  if(showPrice)
  {
    local priceObj = holderObj.findObject("aircraft-price-tr")
    if (priceObj)
    {
      priceObj.show(true)
      holderObj.findObject("aircraft-price").setValue(::getPriceAccordingToPlayersCurrency(cost, costGold))
    }
  }

  local modCharacteristics = {
    [::ES_UNIT_TYPE_AIRCRAFT] = [
      {id = "maxSpeed", id2 = "speed", prepareTextFunc = function(value){return ::countMeasure(0, value)}},
      {id = "turnTime", id2 = "virage", prepareTextFunc = function(value){return format("%.1f %s", value, ::loc("measureUnits/seconds"))}},
      {id = "climbSpeed", id2 = "climb", prepareTextFunc = function(value){return ::countMeasure(3, value)}}
    ],
    [::ES_UNIT_TYPE_TANK] = [
      {id = "mass", id2 = "mass", prepareTextFunc = function(value){return format("%.1f %s", (value / 1000.0), ::loc("measureUnits/ton"))}},
      {id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = function(value){return ::countMeasure(0, value)}},
      {id = "turnTurretTime", id2 = "turnTurretSpeed", prepareTextFunc = function(value){return format("%.1f%s", value.tofloat(), ::loc("measureUnits/deg_per_sec"))}}
    ],
    [::ES_UNIT_TYPE_SHIP] = [
      //TODO ship modificators
      {id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = function(value){return ::countMeasure(0, value)}}
    ],
    [::ES_UNIT_TYPE_HELICOPTER] = [
      {id = "maxSpeed", id2 = "speed", prepareTextFunc = function(value){return ::countMeasure(0, value)}}
    ]
  }

  local showReferenceText = false
  foreach(item in ::getTblValue(unitType, modCharacteristics, {}))
  {
    local characteristicArr = ::getCharacteristicActualValue(air, [item.id, item.id2], item.prepareTextFunc, difficulty.crewSkillName, showLocalState)
    holderObj.findObject("aircraft-" + item.id).setValue(characteristicArr[0])

    if (!showLocalState)
      continue

    local wmodObj = holderObj.findObject("aircraft-weaponmod-" + item.id)
    if (wmodObj)
      wmodObj.setValue(characteristicArr[1])

    local progressObj = holderObj.findObject("aircraft-progress-" + item.id)
    setReferenceMarker(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[5], difficulty.crewSkillName)
    fillAirCharProgress(progressObj, characteristicArr[2], characteristicArr[3], characteristicArr[4])
    showReferenceText = showReferenceText || characteristicArr[6]

    local waitObj = holderObj.findObject("aircraft-" + item.id + "-wait")
    if (waitObj)
      waitObj.show(!isSecondaryModsValid)
  }
  local refTextObj = holderObj.findObject("references_text")
  if (::checkObj(refTextObj)) refTextObj.show(showReferenceText)

  holderObj.findObject("aircraft-speedAlt").setValue(air.shop.maxSpeedAlt>0? ::countMeasure(1, air.shop.maxSpeedAlt) : ::loc("shop/max_speed_alt_sea"))
//    holderObj.findObject("aircraft-climbTime").setValue(format("%02d:%02d", air.shop.climbTime.tointeger() / 60, air.shop.climbTime.tointeger() % 60))
//    holderObj.findObject("aircraft-climbAlt").setValue(::countMeasure(1, air.shop.climbAlt))
  holderObj.findObject("aircraft-altitude").setValue(::countMeasure(1, air.shop.maxAltitude))
  holderObj.findObject("aircraft-airfieldLen").setValue(::countMeasure(1, air.shop.airfieldLen))
  holderObj.findObject("aircraft-wingLoading").setValue(::countMeasure(5, air.shop.wingLoading))
//  holderObj.findObject("aircraft-range").setValue(::countMeasure(2, air.shop.range * 1000.0))

  local totalCrewObj = holderObj.findObject("total-crew")
  if (::check_obj(totalCrewObj))
    totalCrewObj.setValue(air.getCrewTotalCount().tostring())

  local airplaneParameters = ::has_feature("CardAirplaneParameters")
  local airplanePowerParameters = airplaneParameters && ::has_feature("CardAirplanePowerParameters")

  local showCharacteristics = {
    ["aircraft-turnTurretTime-tr"]        = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-angleVerticalGuidance-tr"] = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-shotFreq-tr"]              = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-reloadTime-tr"]            = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-weaponPresets-tr"]         = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-massPerSec-tr"]            = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-armorThicknessHull-tr"]    = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-armorThicknessTurret-tr"]  = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercing-tr"]         = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-armorPiercingDist-tr"]     = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-mass-tr"]                  = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-horsePowers-tr"]           = [ ::ES_UNIT_TYPE_TANK ],
    ["aircraft-maxSpeed-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK,
                                              ::ES_UNIT_TYPE_SHIP, ::ES_UNIT_TYPE_HELICOPTER],
    ["aircraft-maxDepth-tr"]              = [ ::ES_UNIT_TYPE_SHIP],
    ["aircraft-speedAlt-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-altitude-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER ],
    ["aircraft-turnTime-tr"]              = [ ::ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-climbSpeed-tr"]            = [ ::ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-airfieldLen-tr"]           = [ ::ES_UNIT_TYPE_AIRCRAFT ],
    ["aircraft-wingLoading-tr"]           = airplaneParameters ? [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER]
                                              : [::ES_UNIT_TYPE_INVALID],
    ["aircraft-visibilityFactor-tr"]      = [ ::ES_UNIT_TYPE_TANK ]
  }

  foreach (rowId, showForTypes in showCharacteristics)
  {
    local rowObj = holderObj.findObject(rowId)
    if (rowObj)
      rowObj.show(::isInArray(unitType, showForTypes))
  }

  local powerToWeightRatioObject = holderObj.findObject("aircraft-powerToWeightRatio-tr")
  if (airplanePowerParameters
    && ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])
    && "powerToWeightRatio" in air.shop)
  {
    holderObj.findObject("aircraft-powerToWeightRatio").setValue(::countMeasure(6, air.shop.powerToWeightRatio))
    powerToWeightRatioObject.show(true)
  }
  else
    powerToWeightRatioObject.show(false)

  local thrustToWeightRatioObject = holderObj.findObject("aircraft-thrustToWeightRatio-tr")
  if (airplanePowerParameters
    && ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])
    && "thrustToWeightRatio" in air.shop)
  {
    holderObj.findObject("aircraft-thrustToWeightRatio").setValue(format("%.2f", air.shop.thrustToWeightRatio))
    thrustToWeightRatioObject.show(true)
  }
  else
    thrustToWeightRatioObject.show(false)

  local modificators = showLocalState ? "modificators" : "modificatorsBase"
  if (isTank(air) && air[modificators])
  {
    local currentParams = air[modificators][difficulty.crewSkillName]
    local horsePowers = currentParams.horsePowers;
    local horsePowersRPM = currentParams.maxHorsePowersRPM;
    holderObj.findObject("aircraft-horsePowers").setValue(
      ::format("%s %s %d %s", ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(horsePowers),
        ::loc("shop/unitValidCondition"), horsePowersRPM.tointeger(), ::loc("measureUnits/rpm")))
    local thickness = currentParams.armorThicknessHull;
    holderObj.findObject("aircraft-armorThicknessHull").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), ::loc("measureUnits/mm")))
    thickness = currentParams.armorThicknessTurret;
    holderObj.findObject("aircraft-armorThicknessTurret").setValue(format("%d / %d / %d %s", thickness[0].tointeger(), thickness[1].tointeger(), thickness[2].tointeger(), ::loc("measureUnits/mm")))
    local angles = currentParams.angleVerticalGuidance;
    holderObj.findObject("aircraft-angleVerticalGuidance").setValue(format("%d / %d%s", angles[0].tointeger(), angles[1].tointeger(), ::loc("measureUnits/deg")))
    local armorPiercing = currentParams.armorPiercing;
    if (armorPiercing.len() > 0)
    {
      local textParts = []
      local countOutputValue = min(armorPiercing.len(), 3)
      for(local i = 0; i < countOutputValue; i++)
        textParts.append(armorPiercing[i].tointeger())
      holderObj.findObject("aircraft-armorPiercing").setValue(format("%s %s", ::g_string.implode(textParts, " / "), ::loc("measureUnits/mm")))
      local armorPiercingDist = currentParams.armorPiercingDist;
      textParts.clear()
      countOutputValue = min(armorPiercingDist.len(), 3)
      for(local i = 0; i < countOutputValue; i++)
        textParts.append(armorPiercingDist[i].tointeger())
      holderObj.findObject("aircraft-armorPiercingDist").setValue(format("%s %s", ::g_string.implode(textParts, " / "), ::loc("measureUnits/meters_alt")))
    }
    else
    {
      holderObj.findObject("aircraft-armorPiercing-tr").show(false)
      holderObj.findObject("aircraft-armorPiercingDist-tr").show(false)
    }

    local shotFreq = ("shotFreq" in currentParams && currentParams.shotFreq > 0) ? currentParams.shotFreq : null;
    local reloadTime = ("reloadTime" in currentParams && currentParams.reloadTime > 0) ? currentParams.reloadTime : null;
    if ((currentParams?.reloadTimeByDiff?[diffCode] ?? 0) > 0)
      reloadTime = currentParams.reloadTimeByDiff[diffCode]
    local visibilityFactor = ("visibilityFactor" in currentParams && currentParams.visibilityFactor > 0) ? currentParams.visibilityFactor : null;

    holderObj.findObject("aircraft-shotFreq-tr").show(shotFreq);
    holderObj.findObject("aircraft-reloadTime-tr").show(reloadTime);
    holderObj.findObject("aircraft-visibilityFactor-tr").show(visibilityFactor);
    if (shotFreq)
    {
      local val = ::roundToDigits(time.minutesToSeconds(shotFreq), 3).tostring()
      holderObj.findObject("aircraft-shotFreq").setValue(format("%s %s", val, ::loc("measureUnits/shotPerMinute")))
    }
    if (reloadTime)
      holderObj.findObject("aircraft-reloadTime").setValue(format("%.1f %s", reloadTime, ::loc("measureUnits/seconds")))
    if (visibilityFactor)
    {
      holderObj.findObject("aircraft-visibilityFactor-title").setValue(::loc("shop/visibilityFactor") + ::loc("ui/colon"))
      holderObj.findObject("aircraft-visibilityFactor-value").setValue(format("%d %%", visibilityFactor))
    }
  }

  if(unitType == ::ES_UNIT_TYPE_SHIP)
  {
    local unitTags = ::getTblValue(air.name, ::get_unittags_blk(), {})

    // ship-displacement
    local displacementKilos = unitTags?.Shop?.displacement
    holderObj.findObject("ship-displacement-tr").show(displacementKilos != null)
    if(displacementKilos!= null)
    {
      local displacementString = ::g_measure_type.SHIP_DISPLACEMENT_TON.getMeasureUnitsText(displacementKilos/1000, true)
      holderObj.findObject("ship-displacement-title").setValue(::loc("info/ship/displacement") + ::loc("ui/colon"))
      holderObj.findObject("ship-displacement-value").setValue(displacementString)
    }

    // submarine-depth
    local depthValue = unitTags?.Shop?.maxDepth ?? 0
    holderObj.findObject("aircraft-maxDepth-tr").show(depthValue > 0)
    if(depthValue > 0)
      holderObj.findObject("aircraft-maxDepth").setValue(depthValue + ::loc("measureUnits/meters_alt"))

    // ship-citadelArmor
    local armorThicknessCitadel = ::getTblValueByPath("Shop.armorThicknessCitadel", unitTags, null)
    holderObj.findObject("ship-citadelArmor-tr").show(armorThicknessCitadel != null)
    if(armorThicknessCitadel != null)
    {
      holderObj.findObject("ship-citadelArmor-title").setValue(::loc("info/ship/citadelArmor") + ::loc("ui/colon"))
      holderObj.findObject("ship-citadelArmor-value").setValue(
        format("%d / %d / %d %s", armorThicknessCitadel.x.tointeger(), armorThicknessCitadel.y.tointeger(),
          armorThicknessCitadel.z.tointeger(), ::loc("measureUnits/mm")))
    }

    // ship-mainFireTower
    local armorThicknessMainFireTower = ::getTblValueByPath("Shop.armorThicknessTurretMainCaliber", unitTags, null)
    holderObj.findObject("ship-mainFireTower-tr").show(armorThicknessMainFireTower != null)
    if(armorThicknessMainFireTower != null)
    {
      holderObj.findObject("ship-mainFireTower-title").setValue(::loc("info/ship/mainFireTower") + ::loc("ui/colon"))
      holderObj.findObject("ship-mainFireTower-value").setValue(
        format("%d / %d / %d %s", armorThicknessMainFireTower.x.tointeger(), armorThicknessMainFireTower.y.tointeger(),
          armorThicknessMainFireTower.z.tointeger(), ::loc("measureUnits/mm")))
    }
  }
  else
  {
    holderObj.findObject("ship-displacement-tr").show(false)
    holderObj.findObject("ship-citadelArmor-tr").show(false)
    holderObj.findObject("ship-mainFireTower-tr").show(false)
  }

  if (needShopInfo && holderObj.findObject("aircraft-train_cost-tr"))
    if (air.trainCost > 0)
    {
      holderObj.findObject("aircraft-train_cost-tr").show(true)
      holderObj.findObject("aircraft-train_cost").setValue(::getPriceAccordingToPlayersCurrency(air.trainCost, 0))
    }

  if (holderObj.findObject("aircraft-reward_rp-tr") || holderObj.findObject("aircraft-reward_wp-tr"))
  {
    local hasPremium  = ::havePremium()
    local hasTalisman = special || ::shop_is_modification_enabled(air.name, "premExpMul")
    local boosterEffects = ::getTblValue("boosterEffects", params,
      ::ItemsManager.getBoostersEffects(::ItemsManager.getActiveBoostersArray()))

    local wpMuls = air.getWpRewardMulList(difficulty)
    if (showAsRent)
      wpMuls.premMul = 1.0
    local wpMultText = ::format("%.1f", wpMuls.wpMul)
    if (wpMuls.premMul != 1.0)
      wpMultText += ::colorize("fadedTextColor", ::loc("ui/multiply")) + ::colorize("yellow", ::format("%.1f", wpMuls.premMul))

    local rewardFormula = {
      rp = {
        currency      = "currency/researchPoints/sign/colored"
        multText      = air.expMul.tostring()
        multiplier    = air.expMul
        premUnitMul   = 1.0
        noBonus       = 1.0
        premAccBonus  = hasPremium  ? ((rBlk.xpMultiplier || 1.0) - 1.0)    : 0.0
        premModBonus  = hasTalisman ? ((rBlk.goldPlaneExpMul || 1.0) - 1.0) : 0.0
        boosterBonus  = ::getTblValue(::BoosterEffectType.RP.name, boosterEffects, 0) / 100.0
      }
      wp = {
        currency      = "warpoints/short/colored"
        multText      = wpMultText
        multiplier    = wpMuls.wpMul
        premUnitMul   = wpMuls.premMul
        noBonus       = 1.0
        premAccBonus  = hasPremium ? ((wBlk.wpMultiplier || 1.0) - 1.0) : 0.0
        premModBonus  = 0.0
        boosterBonus  = ::getTblValue(::BoosterEffectType.WP.name, boosterEffects, 0) / 100.0
      }
    }

    foreach (id, f in rewardFormula)
    {
      if (!holderObj.findObject("aircraft-reward_" + id + "-tr"))
        continue

      local result = f.multiplier * f.premUnitMul * ( f.noBonus + f.premAccBonus + f.premModBonus + f.boosterBonus )
      local resultText = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(result)
      resultText = ::colorize("activeTextColor", resultText) + ::loc(f.currency)

      local formula = ::handyman.renderCached("gui/debriefing/rewardSources", {
        multiplier = f.multText
        noBonus    = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.noBonus)
        premAcc    = f.premAccBonus  > 0 ? ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.premAccBonus)  : null
        premMod    = f.premModBonus  > 0 ? ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.premModBonus)  : null
        booster    = f.boosterBonus  > 0 ? ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(f.boosterBonus)  : null
      })

      holderObj.getScene().replaceContentFromText(holderObj.findObject("aircraft-reward_" + id), formula, formula.len(), handler)
      holderObj.findObject("aircraft-reward_" + id + "-label").setValue(::loc("reward") + " " + resultText + ::loc("ui/colon"))
    }
  }

  if (holderObj.findObject("aircraft-spare-tr"))
  {
    local spareCount = showLocalState ? ::get_spare_aircrafts_count(air.name) : 0
    holderObj.findObject("aircraft-spare-tr").show(spareCount > 0)
    if (spareCount > 0)
      holderObj.findObject("aircraft-spare").setValue(spareCount.tostring() + ::loc("icon/spare"))
  }

  local fullRepairTd = holderObj.findObject("aircraft-full_repair_cost-td")
  if (fullRepairTd)
  {
    local repairCostData = ""
    local discountsList = {}
    local freeRepairsUnlimited = ::isUnitDefault(air)
    local egdCode = difficulty.egdCode
    if (freeRepairsUnlimited)
      repairCostData = ::format("textareaNoTab { smallFont:t='yes'; text:t='%s' }", ::loc("shop/free"))
    else
    {
      local avgRepairMul = wBlk.avgRepairMul? wBlk.avgRepairMul : 1.0
      local avgCost = (avgRepairMul * ::wp_get_repair_cost_by_mode(air.name, egdCode, showLocalState)).tointeger()
      local modeName = ::get_name_by_gamemode(egdCode, false)
      discountsList[modeName] <- modeName + "-discount"
      repairCostData += format("tdiv { " +
                                 "textareaNoTab {smallFont:t='yes' text:t='%s' }" +
                                 "discount { id:t='%s'; text:t=''; pos:t='-1*@scrn_tgt/100.0, 0.5ph-0.55h'; position:t='relative'; rotation:t='8' }" +
                               "}\n",
                          ((repairCostData!="")?"/ ":"") + ::getPriceAccordingToPlayersCurrency(avgCost.tointeger(), 0),
                          discountsList[modeName]
                        )
    }
    holderObj.getScene().replaceContentFromText(fullRepairTd, repairCostData, repairCostData.len(), null)
    foreach(modeName, objName in discountsList)
      ::showAirDiscount(fullRepairTd.findObject(objName), air.name, "repair", modeName)

    if (!freeRepairsUnlimited)
    {
      local hours = showLocalState ? ::shop_get_full_repair_time_by_mode(air.name, egdCode)
        : ::getTblValue("repairTimeHrs" + ::get_name_by_gamemode(egdCode, true), air, 0)
      local repairTimeText = time.hoursToString(hours, false)
      local label = ::loc(showLocalState && crew ? "shop/full_repair_time_crew" : "shop/full_repair_time")
      holderObj.findObject("aircraft-full_repair_time_crew-tr").show(true)
      holderObj.findObject("aircraft-full_repair_time_crew-tr").tooltip = label
      holderObj.findObject("aircraft-full_repair_time_label").setValue(label)
      holderObj.findObject("aircraft-full_repair_time_crew").setValue(repairTimeText)

      local freeRepairs = showAsRent ? 0
        : showLocalState ? air.freeRepairs - shop_get_free_repairs_used(air.name)
        : air.freeRepairs
      local showFreeRepairs = freeRepairs > 0
      holderObj.findObject("aircraft-free_repairs-tr").show(showFreeRepairs)
      if (showFreeRepairs)
        holderObj.findObject("aircraft-free_repairs").setValue(freeRepairs.tostring())
    }
    else
    {
      holderObj.findObject("aircraft-full_repair_time_crew-tr").show(false)
      holderObj.findObject("aircraft-free_repairs-tr").show(false)
//        if (holderObj.findObject("aircraft-full_repair_time-tr"))
//          holderObj.findObject("aircraft-full_repair_time-tr").show(false)
      ::hideBonus(holderObj.findObject("aircraft-full_repair_cost-discount"))
    }
  }

  local addInfoTextsList = []

  if (air.isPkgDev)
    addInfoTextsList.append(::colorize("badTextColor", ::loc("locatedInPackage", { package = "PKG_DEV" })))
  if (air.isRecentlyReleased())
    addInfoTextsList.append(::colorize("chapterUnlockedColor", ::loc("shop/unitIsRecentlyReleased")))

  if (isInFlight)
  {
    local disabledUnitByBRText = crew && !::is_crew_available_in_session(crew.idInCountry, false)
      && ::SessionLobby.getNotAvailableUnitByBRText(air)
    local missionRules = ::g_mis_custom_state.getCurMissionRules()
    if (missionRules.isWorldWarUnit(air.name))
    {
      addInfoTextsList.append(::loc("icon/worldWar/colored") + ::colorize("activeTextColor",::loc("worldwar/unit")))
      addInfoTextsList.append(::loc("worldwar/unit/desc"))
    }
    if (missionRules.hasCustomUnitRespawns())
    {
      local respawnsleft = missionRules.getUnitLeftRespawns(air)
      if (respawnsleft == 0 || (respawnsleft>0 && !disabledUnitByBRText))
      {
        if (missionRules.isUnitAvailableBySpawnScore(air))
        {
          addInfoTextsList.append(::loc("icon/star/white") + ::colorize("activeTextColor",::loc("worldWar/unit/wwSpawnScore")))
          addInfoTextsList.append(::loc("worldWar/unit/wwSpawnScore/desc"))
        }
        else
        {
          local respText = missionRules.getRespawnInfoTextForUnitInfo(air)
          local color = respawnsleft ? "@userlogColoredText" : "@warningTextColor"
          addInfoTextsList.append(::colorize(color, respText))
        }
      } else if (disabledUnitByBRText)
          addInfoTextsList.append(::colorize("badTextColor", disabledUnitByBRText))
    }
  }

  local warbondId = ::getTblValue("wbId", params)
  if (warbondId)
  {
    local warbond = ::g_warbonds.findWarbond(warbondId, ::getTblValue("wbListId", params))
    local award = warbond? warbond.getAwardById(air.name) : null
    if (award)
      addInfoTextsList.extend(award.getAdditionalTextsArray())
  }

  if (rentTimeHours != -1)
  {
    if (rentTimeHours > 0)
    {
      local rentTimeStr = ::colorize("activeTextColor", time.hoursToString(rentTimeHours))
      addInfoTextsList.append(::colorize("userlogColoredText", ::loc("shop/rentFor", { time =  rentTimeStr })))
    }
    else
      addInfoTextsList.append(::colorize("userlogColoredText", ::loc("trophy/unlockables_names/trophy")))
    if (isOwn && !isReceivedPrizes)
    {
      local text = ::loc("mainmenu/itemReceived") + ::loc("ui/dot") + " " +
        ::loc(params?.relatedItem ? "mainmenu/activateOnlyOnce" : "mainmenu/receiveOnlyOnce")
      addInfoTextsList.append(::colorize("badTextColor", text))
    }
  }
  else
  {
    if (::isUnitGift(air))
      addInfoTextsList.append(::colorize("userlogColoredText",
        ::format(::loc("shop/giftAir/"+air.gift+"/info"), air.giftParam ? ::loc(air.giftParam) : "")))
    if (::isUnitDefault(air))
      addInfoTextsList.append(::loc("shop/reserve/info"))
    if (showLocalState && !::isUnitBought(air) && ::isUnitResearched(air) && !::canBuyUnitOnline(air) && ::canBuyUnit(air))
    {
      local priceText = ::colorize("activeTextColor", ::getUnitCost(air).getTextAccordingToBalance())
      addInfoTextsList.append(::colorize("userlogColoredText", ::loc("mainmenu/canBuyThisVehicle", { price = priceText })))
    }
  }

  local infoObj = holderObj.findObject("aircraft-addInfo")
  if (::checkObj(infoObj))
    infoObj.setValue(::g_string.implode(addInfoTextsList, "\n"))

  if (needCrewInfo && crew)
  {
    local crewUnitType = air.getCrewUnitType()
    local crewLevel = ::g_crew.getCrewLevel(crew, crewUnitType)
    local crewStatus = ::get_crew_status(crew)
    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, air)
    local crewSpecIcon = specType.trainedIcon
    local crewSpecName = specType.getName()

    obj = holderObj.findObject("aircraft-crew_info")
    if (::checkObj(obj))
      obj.show(true)

    obj = holderObj.findObject("aircraft-crew_name")
    if (::checkObj(obj))
      obj.setValue(::g_crew.getCrewName(crew))

    obj = holderObj.findObject("aircraft-crew_level")
    if (::checkObj(obj))
      obj.setValue(::loc("crew/usedSkills") + " " + crewLevel)
    obj = holderObj.findObject("aircraft-crew_spec-label")
    if (::checkObj(obj))
      obj.setValue(::loc("crew/trained") + ::loc("ui/colon"))
    obj = holderObj.findObject("aircraft-crew_spec-icon")
    if (::checkObj(obj))
      obj["background-image"] = crewSpecIcon
    obj = holderObj.findObject("aircraft-crew_spec")
    if (::checkObj(obj))
      obj.setValue(crewSpecName)

    obj = holderObj.findObject("aircraft-crew_points")
    if (::checkObj(obj) && !isInFlight && crewStatus != "")
    {
      local crewPointsText = ::colorize("white", ::get_crew_sp_text(::g_crew_skills.getCrewPoints(crew)))
      obj.show(true)
      obj.setValue(::loc("crew/availablePoints/advice") + ::loc("ui/colon") + crewPointsText)
      obj["crewStatus"] = crewStatus
    }
  }

  if (needShopInfo && !isRented)
  {
    local reason = ::getCantBuyUnitReason(air, true)
    local addTextObj = holderObj.findObject("aircraft-cant_buy_info")
    if (::checkObj(addTextObj) && !::u.isEmpty(reason))
    {
      addTextObj.setValue(::colorize("redMenuButtonColor", reason))

      local unitNest = holderObj.findObject("prev_unit_nest")
      if (::checkObj(unitNest) && (!::isPrevUnitResearched(air) || !::isPrevUnitBought(air)) &&
        ::is_era_available(air.shopCountry, ::getUnitRank(air), unitType))
      {
        local prevUnit = ::getPrevUnit(air)
        local unitBlk = ::build_aircraft_item(prevUnit.name, prevUnit)
        holderObj.getScene().replaceContentFromText(unitNest, unitBlk, unitBlk.len(), handler)
        ::fill_unit_item_timers(unitNest.findObject(prevUnit.name), prevUnit)
      }
    }
  }

  if (::has_entitlement("AccessTest") && needShopInfo && holderObj.findObject("aircraft-surviveRating"))
  {
    local blk = ::get_global_stats_blk()
    if (blk["aircrafts"])
    {
      local stats = blk["aircrafts"][air.name]
      local surviveText = ::loc("multiplayer/notAvailable")
      local winsText = ::loc("multiplayer/notAvailable")
      local usageText = ::loc("multiplayer/notAvailable")
      local rating = -1
      if (stats)
      {
        local survive = (stats["flyouts_deaths"]!=null)? stats["flyouts_deaths"] : 1.0
        survive = (survive==0)? 0 : 1.0 - 1.0/survive
        surviveText = roundToDigits(100.0*survive, 2) + "%"
        local wins = (stats["wins_flyouts"]!=null)? stats["wins_flyouts"] : 0.0
        winsText = roundToDigits(100.0*wins, 2) + "%"

        local usage = (stats["flyouts_factor"]!=null)? stats["flyouts_factor"] : 0.0
        if (usage >= 0.000001)
        {
          rating = 0
          foreach(r in ::usageRating_amount)
            if (usage > r)
              rating++
          usageText = ::loc("shop/usageRating/" + rating)
          if (::has_entitlement("AccessTest"))
            usageText += " (" + roundToDigits(100.0*usage, 2) + "%)"
        }
      }
      holderObj.findObject("aircraft-surviveRating-tr").show(true)
      holderObj.findObject("aircraft-surviveRating").setValue(surviveText)
      holderObj.findObject("aircraft-winsRating-tr").show(true)
      holderObj.findObject("aircraft-winsRating").setValue(winsText)
      holderObj.findObject("aircraft-usageRating-tr").show(true)
      if (rating>=0)
        holderObj.findObject("aircraft-usageRating").overlayTextColor = "usageRating" + rating;
      holderObj.findObject("aircraft-usageRating").setValue(usageText)
    }
  }

  local weaponsInfoText = ::getWeaponInfoText(air,
    { weaponPreset = showLocalState ? -1 : 0, ediff = ediff, isLocalState = showLocalState })
  obj = holderObj.findObject("weaponsInfo")
  if (obj) obj.setValue(weaponsInfoText)

  local lastPrimaryWeaponName = showLocalState ? ::get_last_primary_weapon(air) : ""
  local lastPrimaryWeapon = ::getModificationByName(air, lastPrimaryWeaponName)
  local massPerSecValue = ::getTblValue("mass_per_sec_diff", lastPrimaryWeapon, 0)

  local weaponIndex = -1
  local wPresets = 0
  if (air.weapons.len() > 0)
  {
    local lastWeapon = showLocalState ? ::get_last_weapon(air.name) : ""
    weaponIndex = 0
    foreach(idx, weapon in air.weapons)
    {
      if (::isWeaponAux(weapon))
        continue
      wPresets++
      if (lastWeapon == weapon.name && "mass_per_sec" in weapon)
        weaponIndex = idx
    }
  }

  if (weaponIndex != -1)
  {
    local weapon = air.weapons[weaponIndex]
    massPerSecValue += ::getTblValue("mass_per_sec", weapon, 0)
  }

  if (massPerSecValue != 0)
  {
    local massPerSecText = format("%.2f %s", massPerSecValue, ::loc("measureUnits/kgPerSec"))
    obj = holderObj.findObject("aircraft-massPerSec")
    if (::checkObj(obj))
      obj.setValue(massPerSecText)
  }
  obj = holderObj.findObject("aircraft-massPerSec-tr")
  if (::checkObj(obj))
    obj.show(massPerSecValue != 0)

  obj = holderObj.findObject("aircraft-research-efficiency")
  if (::checkObj(obj))
  {
    local minAge = ::getMinBestLevelingRank(air)
    local maxAge = ::getMaxBestLevelingRank(air)
    local rangeText = (minAge == maxAge) ? (::get_roman_numeral(minAge) + ::nbsp + ::loc("shop/age")) :
        (::get_roman_numeral(minAge) + ::nbsp + ::loc("ui/mdash") + ::nbsp + ::get_roman_numeral(maxAge) + ::nbsp + ::loc("mainmenu/ranks"))
    obj.setValue(rangeText)
  }

  obj = holderObj.findObject("aircraft-weaponPresets")
  if (::checkObj(obj))
    obj.setValue(wPresets.tostring())

  obj = holderObj.findObject("current_game_mode_footnote_text")
  if (::checkObj(obj))
  {
    local battleType = ::get_battle_type_by_ediff(ediff)
    local fonticon = !::CAN_USE_EDIFF ? "" :
      ::loc(battleType == BATTLE_TYPES.AIR ? "icon/unittype/aircraft" : "icon/unittype/tank")
    local diffName = ::g_string.implode([ fonticon, difficulty.getLocName() ], ::nbsp)

    local unitStateId = !showLocalState ? "reference"
      : crew ? "current_crew"
      : "current"
    local unitState = ::loc("shop/showing_unit_state/" + unitStateId)

    obj.setValue(::loc("shop/all_info_relevant_to_current_game_mode") + ::loc("ui/colon") + diffName + "\n" + unitState)
  }

  obj = holderObj.findObject("unit_rent_time")
  if (::checkObj(obj))
    obj.show(false)

  if (showLocalState)
  {
    ::setCrewUnlockTime(holderObj.findObject("aircraft-lockedCrew"), air)
    ::fillAirInfoTimers(holderObj, air, needShopInfo)
  }
}

function get_max_era_available_by_country(country, unitType = ::ES_UNIT_TYPE_INVALID)
{
  for(local era = 1; era <= ::max_country_rank; era++)
    if (!::is_era_available(country, era, unitType))
      return (era - 1)
  return ::max_country_rank
}

function fill_progress_bar(obj, curExp, newExp, maxExp, isPaused = false)
{
  if (!::checkObj(obj) || !maxExp)
    return

  local guiScene = obj.getScene()
  if (!guiScene)
    return

  guiScene.replaceContent(obj, "gui/countryExpItem.blk", this)

  local barObj = obj.findObject("expProgressOld")
  if (::checkObj(barObj))
  {
    barObj.show(true)
    barObj.setValue(1000.0 * curExp / maxExp)
    barObj.paused = isPaused ? "yes" : "no"
  }

  barObj = obj.findObject("expProgress")
  if (::checkObj(barObj))
  {
    barObj.show(true)
    barObj.setValue(1000.0 * newExp / maxExp)
    barObj.paused = isPaused ? "yes" : "no"
  }
}

::__types_for_coutries <- null //for avoid recalculations
function get_unit_types_in_countries()
{
  if (::__types_for_coutries)
    return ::__types_for_coutries

  local defaultCountryData = {}
  foreach(unitType in ::g_unit_type.types)
    defaultCountryData[unitType.esUnitType] <- false

  ::__types_for_coutries = {}
  foreach(country in ::shopCountriesList)
    ::__types_for_coutries[country] <- clone defaultCountryData

  foreach(unit in ::all_units)
  {
    if (!unit.unitType.isAvailable())
      continue
    local esUnitType = unit.unitType.esUnitType
    local countryData = ::getTblValue(::getUnitCountry(unit), ::__types_for_coutries)
    if (::getTblValue(esUnitType, countryData, true))
      continue
    countryData[esUnitType] <- ::isUnitBought(unit)
  }

  return ::__types_for_coutries
}

function get_countries_by_unit_type(unitType)
{
  local res = []
  foreach (countryName, countryData in ::get_unit_types_in_countries())
    if (::getTblValue(unitType, countryData))
      res.append(countryName)

  return res
}

function is_country_has_any_es_unit_type(country, esUnitTypeMask)
{
  local typesList = ::getTblValue(country, ::get_unit_types_in_countries(), {})
  foreach(esUnitType, isInCountry in typesList)
    if (isInCountry && (esUnitTypeMask & (1 << esUnitType)))
      return true
  return false
}

function get_player_cur_unit()
{
  local unit = null
  if (::is_in_flight())
  {
    local unitId = ("get_player_unit_name" in getroottable())? ::get_player_unit_name() : ::cur_aircraft_name
    unit = unitId && ::getAircraftByName(unitId)
  }
  else
    unit = ::show_aircraft
  return unit
}

function is_loaded_model_high_quality(def = true)
{
  if (::hangar_get_loaded_unit_name() == "")
    return def
  return ::hangar_is_high_quality()
}

function getNotResearchedUnitByFeature(country = null, unitType = null)
{
  foreach(unit in ::all_units)
    if (    (!country || ::getUnitCountry(unit) == country)
         && (unitType == null || ::get_es_unit_type(unit) == unitType)
         && ::isUnitFeatureLocked(unit)
       )
      return unit
  return null
}

function get_units_list(filterFunc)
{
  local res = []
  foreach(unit in ::all_units)
    if (filterFunc(unit))
      res.append(unit)
  return res
}

function get_units_count_at_rank(rank, type, country, exact_rank, needBought = true)
{
  local count = 0
  foreach (unit in ::all_units)
  {
    if (needBought && !::isUnitBought(unit))
      continue

    // Keep this in sync with getUnitsCountAtRank() in chard
    if (
        (::ES_UNIT_TYPE_TOTAL == type || ::get_es_unit_type(unit) == type) &&
        (unit.rank == rank || (!exact_rank && unit.rank > rank) ) &&
        ("" == country || unit.shopCountry == country)
       )
    {
      count++
    }
  }
  return count
}

function find_units_by_loc_name(unitLocName, searchIds = false, needIncludeNotInShop = false)
{
  needIncludeNotInShop = needIncludeNotInShop && ::is_dev_version

  local comparePrep = function(text) {
    text = ::g_string.utf8ToLower(text.tostring())
    foreach (symbol in [ ::nbsp, " ", "-", "_" ])
      text = ::stringReplace(text, symbol, "")
    return text
  }

  local searchStr = comparePrep(unitLocName)
  if (searchStr == "")
    return []

  return ::u.filter(::all_units, @(unit)
    (needIncludeNotInShop || unit.isInShop) && (
      comparePrep(::getUnitName(unit, false)).find(searchStr) != null ||
      comparePrep(::getUnitName(unit)).find(searchStr) != null ||
      searchIds && comparePrep(unit.name).find(searchStr) != null )
  )
}

{
  local unitCacheName = null
  local unitCacheBlk = null
  function get_full_unit_blk(unitName) //better to not use this funtion, and collect all data from wpcost and unittags
  {
    if (unitName != unitCacheName)
    {
      unitCacheName = unitName
      unitCacheBlk = ::DataBlock(::get_unit_file_name(unitName))
    }
    return unitCacheBlk
  }
}

function get_fm_file(unitId, unitBlkData = null)
{
  local unitPath = ::get_unit_file_name(unitId)
  if (unitBlkData == null)
    unitBlkData = ::get_full_unit_blk(unitId)
  local nodes = ::split(unitPath, "/")
  if (nodes.len())
    nodes.pop()
  local unitDir = ::g_string.implode(nodes, "/")
  local fmPath = unitDir + "/" + (unitBlkData.fmFile || ("fm/" + unitId))
  return ::DataBlock(fmPath)
}
