local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")

/*
if need - put commented in array above
//crew list for tests
  {
    country = "country_usa"
    crews = [
      { aircraft = "pby-5a", trained = ["pby-5a", "b_24d"] }
      { aircraft = "b_24d" }
      { }
    ]
  }
  {
    country = "country_germany"
    crews = [
      { aircraft = "fiat_cr42" }
      { aircraft = "fiat_g50_seria2" }
      { aircraft = "fiat_g50_seria7as" }
      { aircraft = "bf-109e-3" }
      { aircraft = "bf-110c-4" }
      { aircraft = "bf-109f-4" }
    ]
  }
  {
    country = "country_ussr"
    crews = [
      { aircraft = "swordfish_mk1" }
      { aircraft = "gladiator_mk2" }
    ]
  }
*/

::selected_crews <- []
::unlocked_countries <- []
::fake_countries <- ["country_pkg6"]

::g_script_reloader.registerPersistentData("SlotbarGlobals", ::getroottable(), ["selected_crews", "unlocked_countries"])

function build_aircraft_item(id, air, params = {})
{
  local res = ""
  local defaultStatus = "none"
  local getVal = (@(params) function(val, defVal) {
    return ::getTblValue(val, params, defVal)
  })(params)

  if (air && !::isUnitGroup(air))
  {
    local isLocalState        = getVal("isLocalState", true)
    local forceNotInResearch  = getVal("forceNotInResearch", false)
    local inactive            = getVal("inactive", false)
    local shopResearchMode    = getVal("shopResearchMode", false)
    local disabled            = false

    local isOwn               = ::isUnitBought(air)
    local isUsable            = ::isUnitUsable(air)
    local isMounted           = ::isUnitInSlotbar(air)
    local canResearch         = ::canResearchUnit(air)
    local researched          = ::isUnitResearched(air)
    local canBuy              = ::canBuyUnit(air)
    local canBuyOnline        = ::canBuyUnitOnline(air)
    local special             = ::isUnitSpecial(air)
    local reserve             = ::isUnitDefault(air)
    local unitReqExp          = ::getUnitReqExp(air)
    local unitExpGranted      = ::getUnitExp(air)
    local isVehicleInResearch = ::isUnitInResearch(air) && !forceNotInResearch
    local isBroken            = ::isUnitBroken(air)
    local unitRarity          = ::getUnitRarity(air)

    local status = getVal("status", defaultStatus)
    if (status == defaultStatus)
    {
      local bitStatus = 0
      if (!isLocalState || ::is_in_flight())
        bitStatus = bit_unit_status.owned
      else if (isMounted)
        bitStatus = bit_unit_status.mounted
      else if (isOwn)
        bitStatus = bit_unit_status.owned
      else if (canBuy || canBuyOnline)
        bitStatus = bit_unit_status.canBuy
      else if (researched)
        bitStatus = bit_unit_status.researched
      else if (isVehicleInResearch && !forceNotInResearch)
        bitStatus = bit_unit_status.inResearch
      else if (canResearch)
        bitStatus = bit_unit_status.canResearch
      else if (air.isRented())
        bitStatus = bit_unit_status.inRent
      else
      {
        bitStatus = bit_unit_status.locked
        inactive = shopResearchMode
      }

      if (shopResearchMode && !(bitStatus &
           ( bit_unit_status.locked
            | bit_unit_status.canBuy
            | bit_unit_status.inResearch
            | bit_unit_status.canResearch))
          )
      {
        bitStatus = bit_unit_status.disabled
        inactive = true
      }

      status = ::getUnitItemStatusText(bitStatus, false)
    }

    local hasActions = getVal("hasActions", false) && !disabled

    //
    // Bottom button view
    //

    local mainButtonAction = ::show_console_buttons ? "onOpenActionsList" : getVal("mainActionFunc", "")
    local mainButtonText = ::show_console_buttons ? "" : getVal("mainActionText", "")
    local mainButtonIcon = ::show_console_buttons ? "#ui/gameuiskin#slot_menu" : getVal("mainActionIcon", "")
    local checkTexts = mainButtonAction.len() > 0 && (mainButtonText.len() > 0 || mainButtonIcon.len() > 0)
    local checkButton = !isVehicleInResearch || ::has_feature("SpendGold")
    local bottomButtonView = {
      hasButton           = hasActions && checkTexts && checkButton
      spaceButton         = true
      mainButtonText      = mainButtonText
      mainButtonAction    = mainButtonAction
      hasMainButtonIcon   = mainButtonIcon.len()
      mainButtonIcon      = mainButtonIcon
    }

    //
    // Item buttons view
    //

    local weaponsStatus = isLocalState && isUsable ? checkUnitWeapons(air) : ::UNIT_WEAPONS_READY
    local crewId = getVal("crewId", -1)
    local showWarningIcon = getVal("showWarningIcon", false)
    local specType = getVal("specType", null)
    local rentInfo = ::get_unit_item_rent_info(air, params)
    local spareCount = isLocalState ? ::get_spare_aircrafts_count(air.name) : 0

    local hasCrewInfo = crewId >= 0
    local crew = hasCrewInfo ? ::get_crew_by_id(crewId) : null
    local crewLevelText = crew && air ? ::g_crew.getCrewLevel(crew, ::get_es_unit_type(air)).tointeger().tostring() : ""

    local itemButtonsView = {
      itemButtons = {
        hasToBattleButton       = getVal("toBattle", false)
        toBattleButtonAction    = getVal("toBattleButtonAction", "onSlotBattle")
        hasExtraInfoBlock       = getVal("hasExtraInfoBlock", false)

        hasCrewInfo             = hasCrewInfo
        crewLevel               = hasCrewInfo ? crewLevelText : ""
        crewSpecIcon            = hasCrewInfo ? ::g_crew_spec_type.getTypeByCrewAndUnit(crew, air).trainedIcon : ""
        crewStatus              = hasCrewInfo ? ::get_crew_status_by_id(crewId) : ""

        hasSpareCount           = spareCount > 0
        spareCount              = spareCount ? spareCount + ::loc("icon/spare") : ""
        specIconBlock           = showWarningIcon || specType != null
        showWarningIcon         = showWarningIcon
        hasRepairIcon           = isLocalState && isBroken
        hasWeaponsStatus        = weaponsStatus != ::UNIT_WEAPONS_READY
        isWeaponsStatusZero     = weaponsStatus == ::UNIT_WEAPONS_ZERO
        hasRentIcon             = rentInfo.hasIcon
        hasRentProgress         = rentInfo.hasProgress
        rentProgress            = rentInfo.progress
        bonusId                 = id
      }
    }

    if (specType)
    {
      itemButtonsView.itemButtons.specTypeIcon <- specType.trainedIcon
      itemButtonsView.itemButtons.specTypeTooltip <- specType.getName()
    }

    //
    // Air research progress view
    //

    local showProgress = isLocalState && !isOwn && canResearch && !::is_in_flight()
    local airResearchProgressView = {
      airResearchProgress = []
    }
    if (showProgress)
    {
      airResearchProgressView.airResearchProgress.push({
        airResearchProgressValue            = unitReqExp > 0 ? (unitExpGranted.tofloat() / unitReqExp * 1000).tointeger() : 0
        airResearchProgressType             = "new"
        airResearchProgressIsPaused         = !isVehicleInResearch || forceNotInResearch
        airResearchProgressAbsolutePosition = false
        airResearchProgressHasPaused        = true
        airResearchProgressHasDisplay       = false
      })
      local diffExp = getVal("diffExp", 0)
      if (unitExpGranted > diffExp)
      {
        airResearchProgressView.airResearchProgress.push({
          airResearchProgressValue            = ((unitExpGranted.tofloat() - diffExp) / unitReqExp * 1000).tointeger()
          airResearchProgressType             = "old"
          airResearchProgressIsPaused         = !isVehicleInResearch || forceNotInResearch
          airResearchProgressAbsolutePosition = true
          airResearchProgressHasPaused        = true
          airResearchProgressHasDisplay       = false
        })
      }
    }

    //
    // Res view
    //

    local priceText = ::get_unit_item_price_text(air, params)
    local progressText = showProgress ? ::get_unit_item_research_progress_text(air, params, priceText) : ""
    local checkNotification = ::getTblValueByPath("entitlementUnits." + air.name, ::visibleDiscountNotifications)

    local showBR = ::getTblValue("showBR", params, ::has_feature("GlobalShowBattleRating"))
    local curEdiff = ("getEdiffFunc" in params) ?  params.getEdiffFunc() : ::get_current_ediff()

    local resView = {
      slotId              = "td_" + id
      slotInactive        = inactive
      isSlotbarItem       = getVal("isSlotbarItem", false)
      shopItemId          = id
      unitName            = air.name
      premiumPatternType  = special
      shopItemType        = ::get_unit_role(air.name)
      unitClassIcon       = ::get_unit_role_icon(air)
      shopStatus          = status
      unitRarity          = unitRarity
      isBroken            = isLocalState && isBroken
      shopAirImg          = ::image_for_air(air)
      isPkgDev            = air.isPkgDev
      isRecentlyReleased  = air.isRecentlyReleased()
      discountId          = id + "-discount"
      showDiscount        = isLocalState && !isOwn && (!::isUnitGift(air) || checkNotification)
      shopItemTextId      = id + "_txt"
      shopItemText        = ::get_slot_unit_name_text(air, params)
      progressText        = progressText
      progressBlk         = ::handyman.renderCached("gui/slotbar/airResearchProgress", airResearchProgressView)
      showInService       = getVal("showInService", false) && isUsable
      isMounted           = isMounted
      priceText           = priceText
      isLongPriceText     = ::is_unit_price_text_long(priceText)
      isElite             = isLocalState && (isOwn && ::isUnitElite(air)) || (!isOwn && special)
      unitRankText        = ::get_unit_rank_text(air, crew, showBR, curEdiff)
      isItemLocked        = isLocalState && !isUsable && !special && !::isUnitsEraUnlocked(air)
      hasTalismanIcon     = isLocalState && (special || ::shop_is_modification_enabled(air.name, "premExpMul"))
      itemButtons         = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
      tooltipId           = ::g_tooltip.getIdUnit(air.name, getVal("tooltipParams", null))
      bottomButton        = ::handyman.renderCached("gui/slotbar/slotbarItemBottomButton", bottomButtonView)
      hasHoverMenu        = hasActions
    }
    local missionRules = params?.missionRules
    local groupName = missionRules ? missionRules.getRandomUnitsGroupName(air.name) : null
    if (groupName && (!::is_player_unit_alive() || ::get_player_unit_name() != air.name))
    {
      local missionRules = getVal("missionRules", null)
      resView.shopAirImg = missionRules.getRandomUnitsGroupIcon(groupName)
      resView.shopItemType = ""
      resView.unitClassIcon = ""
      resView.isElite = false
      resView.premiumPatternType = false
      resView.unitRarity = ""
      resView.unitRankText = ""
      resView.tooltipId = ::g_tooltip_type.RANDOM_UNIT.getTooltipId(air.name, {groupName = groupName})
    }

    res = ::handyman.renderCached("gui/slotbar/slotbarSlotSingle", resView)
  }
  else if (air && ::isUnitGroup(air)) //group of aircrafts
  {
    local groupStatus         = getVal("status", defaultStatus)
    local forceNotInResearch  = getVal("forceNotInResearch", false)
    local shopResearchMode    = getVal("shopResearchMode", false)
    local showInService       = getVal("showInService", false)
    local inactive            = getVal("inactive", false)

    local reserve           = false
    local special           = false

    local nextAir = air.airsGroup[0]
    local country = nextAir.shopCountry
    local type    = ::get_es_unit_type(nextAir)
    local forceUnitNameOnPlate = false

    local era = getUnitRank(nextAir)
    local showBR = ::getTblValue("showBR", params, ::has_feature("GlobalShowBattleRating"))
    local curEdiff = ("getEdiffFunc" in params) ?  params.getEdiffFunc() : ::get_current_ediff()

    local isGroupUsable     = false
    local isGroupInResearch = false
    local isElite           = true
    local isPkgDev          = false
    local isRecentlyReleased    = false
    local hasTalismanIcon   = false
    local talismanIncomplete = false
    local mountedUnit       = null
    local lastBoughtUnit    = null
    local firstUnboughtUnit = null
    local researchingUnit   = null
    local rentedUnit        = null
    local unitRole          = null
    local bitStatus         = 0

    foreach(a in air.airsGroup)
    {
      local isInResearch = !forceNotInResearch && ::isUnitInResearch(a)
      local isBought = ::isUnitBought(a)
      local isUsable = ::isUnitUsable(a)
      local isMounted =  ::isUnitInSlotbar(a)

      if (isInResearch || (::canResearchUnit(a) && !researchingUnit))
      {
        researchingUnit = a
        isGroupInResearch = isInResearch
      }
      else if (isUsable)
        lastBoughtUnit = a
      else if (!firstUnboughtUnit && (::canBuyUnit(a) || ::canBuyUnitOnline(a)))
        firstUnboughtUnit = a

      if (showInService && isUsable)
      {
        if (::isUnitInSlotbar(a))
          mountedUnit = a
        isGroupUsable = true
      }

      if (a.isRented())
      {
        if (!rentedUnit || a.getRentTimeleft() <= rentedUnit.getRentTimeleft())
          rentedUnit = a
      }

      if (unitRole == null || isInResearch)
        unitRole = ::get_unit_role(nextAir)

      reserve = reserve || ::isUnitDefault(a)
      special = ::isUnitSpecial(a)
      isElite = isElite && ::isUnitElite(a)
      isPkgDev = isPkgDev || a.isPkgDev
      isRecentlyReleased = isRecentlyReleased || a.isRecentlyReleased()

      local hasTalisman = special || ::shop_is_modification_enabled(a.name, "premExpMul")
      hasTalismanIcon = hasTalismanIcon || hasTalisman
      talismanIncomplete = talismanIncomplete || !hasTalisman

      if (::isUnitInSlotbar(a))
        bitStatus = bitStatus | bit_unit_status.mounted
      else if (isBought)
        bitStatus = bitStatus | bit_unit_status.owned
      else if (::canBuyUnit(a) || ::canBuyUnitOnline(a))
        bitStatus = bitStatus | bit_unit_status.canBuy
      else if (::isUnitResearched(a))
        bitStatus = bitStatus | bit_unit_status.researched
      else if (isInResearch)
        bitStatus = bitStatus | bit_unit_status.inResearch
      else if (::canResearchUnit(a))
        bitStatus = bitStatus | bit_unit_status.canResearch
      else if (a.isRented())
        bitStatus = bitStatus | bit_unit_status.inRent
      else
        bitStatus = bitStatus | bit_unit_status.locked

      if (!(bitStatus & bit_unit_status.broken) && ::isUnitBroken(a))
        bitStatus = bitStatus | bit_unit_status.broken
    }

    if (shopResearchMode && !(bitStatus &
           (
             bit_unit_status.canBuy
            | bit_unit_status.inResearch
            | bit_unit_status.canResearch)
          ))
      {
        if (!(bitStatus & bit_unit_status.locked))
          bitStatus = bit_unit_status.disabled
        inactive = true
      }

    // Unit selection priority: 1) rented, 2) researching, 3) mounted, 4) first unbougt, 5) last bought, 6) first in group.
    nextAir = rentedUnit || mountedUnit || isGroupInResearch && researchingUnit || firstUnboughtUnit || lastBoughtUnit || nextAir
    forceUnitNameOnPlate = rentedUnit != null || mountedUnit  != null || isGroupInResearch && researchingUnit != null || firstUnboughtUnit != null
    local unitForBR = rentedUnit || researchingUnit || firstUnboughtUnit || air

    //
    // Bottom button view
    //

    local bottomButtonView = {
      hasButton           = ::show_console_buttons
      spaceButton         = false
      mainButtonAction    = "onAircraftClick"
      mainButtonText      = ""
      mainButtonIcon      = "#ui/gameuiskin#slot_unfold.svg"
      hasMainButtonIcon   = true
    }

    //
    // Item buttons view
    //

    local rentInfo = ::get_unit_item_rent_info(rentedUnit, params)

    local itemButtonsView = {
      itemButtons = {
        hasRentIcon             = rentInfo.hasIcon
        hasRentProgress         = rentInfo.hasProgress
        rentProgress            = rentInfo.progress
      }
    }

    //
    // Air research progress view
    //

    local showProgress = false
    local unitExpProgressValue = 0
    if (researchingUnit)
    {
      showProgress = true
      local unitExpGranted = ::getUnitExp(researchingUnit)
      local unitReqExp = ::getUnitReqExp(researchingUnit)
      unitExpProgressValue = unitReqExp > 0 ? unitExpGranted.tofloat() / unitReqExp.tofloat() * 1000 : 0
    }

    local airResearchProgressView = {
      airResearchProgress = [{
        airResearchProgressValue            = unitExpProgressValue.tostring()
        airResearchProgressType             = "new"
        airResearchProgressIsPaused         = !isGroupInResearch
        airResearchProgressAbsolutePosition = false
        airResearchProgressHasPaused        = true
        airResearchProgressHasDisplay       = true
        airResearchProgressDisplay          = showProgress
      }]
    }

    //
    // Res view
    //

    local shopAirImage = ::get_unit_preset_img(air.name)
    if (!shopAirImage)
      if (::is_tencent_unit_image_reqired(nextAir))
        shopAirImage = ::get_tomoe_unit_icon(air.name) + (air.name.find("_group", 0) ? "" : "_group")
      else
        shopAirImage = "!" + (::getTblValue("image", air) || ("#ui/unitskin#planes_group"))

    local groupSlotView = {
      slotId              = id
      unitRole            = unitRole
      unitClassIcon       = ::get_unit_role_icon(nextAir)
      groupStatus         = groupStatus == defaultStatus ? ::getUnitItemStatusText(bitStatus, true) : groupStatus
      isBroken            = bitStatus & bit_unit_status.broken
      shopAirImg          = shopAirImage
      isPkgDev            = isPkgDev
      isRecentlyReleased  = isRecentlyReleased
      discountId          = id + "-discount"
      shopItemTextId      = id + "_txt"
      shopItemText        = forceUnitNameOnPlate ? "#" + nextAir.name + "_shop" : "#shop/group/" + air.name
      progressText        = showProgress ? ::get_unit_item_research_progress_text(researchingUnit, params) : ""
      progressBlk         = ::handyman.renderCached("gui/slotbar/airResearchProgress", airResearchProgressView)
      showInService       = isGroupUsable
      priceText           = !showProgress && firstUnboughtUnit ? ::get_unit_item_price_text(firstUnboughtUnit, params) : ""
      isMounted           = mountedUnit != null
      isElite             = isElite
      unitRankText        = ::get_unit_rank_text(unitForBR, null, showBR, curEdiff)
      isItemLocked        = !::is_era_available(country, era, type)
      hasTalismanIcon     = hasTalismanIcon
      talismanIncomplete  = talismanIncomplete
      itemButtons         = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
      bonusId             = id
      primaryUnitId       = nextAir.name
      tooltipId           = ::g_tooltip.getIdUnit(nextAir.name, getVal("tooltipParams", null))
      bottomButton        = ::handyman.renderCached("gui/slotbar/slotbarItemBottomButton", bottomButtonView)
      hasFullGroupBlock   = getVal("fullGroupBlock", true)
      fullGroupBlockId    = "td_" + id
      isGroupInactive     = inactive
    }
    res = ::handyman.renderCached("gui/slotbar/slotbarSlotGroup", groupSlotView)
  }
  else //empty air slot
  {
    local specType = getVal("specType", null)
    local itemButtonsView = { itemButtons = {
      specIconBlock = specType != null
    }}

    if (specType)
    {
      itemButtonsView.itemButtons.specTypeIcon <- specType.trainedIcon
      itemButtonsView.itemButtons.specTypeTooltip <- specType.getName()
    }

    local emptyCost = getVal("emptyCost", null)
    local priceText = emptyCost ? emptyCost.getTextAccordingToBalance() : ""
    local emptySlotView = {
      slotId = "td_" + id,
      shopItemId = id,
      shopItemTextId = id + "_txt",
      shopItemTextValue = getVal("emptyText", ""),
      shopItemPriceText = priceText,
      crewImage = getVal("crewImage", null),
      isCrewRecruit = getVal("isCrewRecruit", false),
      itemButtons = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
      isSlotbarItem = getVal("isSlotbarItem", false)
    }
    res = ::handyman.renderCached("gui/slotbar/slotbarSlotEmpty", emptySlotView)
  }

  if (getVal("fullBlock", true))
    res = ::format("td{%s}", res)

  return res
}

function fill_unit_item_timers(holderObj, unit, params = {})
{
  if (!::checkObj(holderObj) || !unit)
    return

  local rentedUnit = null
  if (::isUnitGroup(unit))
  {
    rentedUnit = unit.airsGroup[0]
    foreach(u in unit.airsGroup)
    {
      if (u.isRented())
        if (!rentedUnit || u.getRentTimeleft() <= rentedUnit.getRentTimeleft())
          rentedUnit = u
    }
  }
  else
    rentedUnit = unit

  if (!rentedUnit || !rentedUnit.isRented())
    return

  SecondsUpdater(holderObj, (@(rentedUnit) function(obj, params) {
    local isActive = false

    // Unit rent time
    local isRented = rentedUnit.isRented()
    if (isRented)
    {
      local objRentProgress = obj.findObject("rent_progress")
      if (::checkObj(objRentProgress))
      {
        local totalRentTimeSec = ::rented_units_get_last_max_full_rent_time(rentedUnit.name) || -1
        local progress = 360 - ::round(360.0 * rentedUnit.getRentTimeleft() / totalRentTimeSec).tointeger()
        if (objRentProgress["sector-angle-1"] != progress)
          objRentProgress["sector-angle-1"] = progress

        isActive = true
      }
    }
    else // at rent time over
    {
      local rentInfo = ::get_unit_item_rent_info(rentedUnit, params)

      local objRentIcon = obj.findObject("rent_icon")
      if (::checkObj(objRentIcon))
        objRentIcon.show(rentInfo.hasIcon)
      local objRentProgress = obj.findObject("rent_progress")
      if (::checkObj(objRentProgress))
        objRentProgress.show(rentInfo.hasProgress)
    }

    return !isActive
  })(rentedUnit))
}

function get_slot_obj_id(countryId, idInCountry, isBonus = false)
{
  ::dagor.assertf(countryId != null, "Country ID is null.")
  ::dagor.assertf(idInCountry != null, "Crew IDX is null.")
  local objId = ::format("slot_%s_%s", countryId.tostring(), idInCountry.tostring())
  if (isBonus)
    objId += "-bonus"
  return objId
}

function get_slot_obj(slotbarObj, countryId, idInCountry)
{
  if (!::checkObj(slotbarObj))
    return null
  local slotObj = slotbarObj.findObject(get_slot_obj_id(countryId, idInCountry))
  return ::checkObj(slotObj) ? slotObj : null
}

function get_unit_item_rent_info(unit, params)
{
  local info = {
    hasIcon     = false
    hasProgress = false
    progress    = 0
  }

  if (unit)
  {
    local showAsTrophyContent = ::getTblValue("showAsTrophyContent", params, false)
    local offerRentTimeHours  = ::getTblValue("offerRentTimeHours", params, 0)
    local hasProgress = unit.isRented() && !showAsTrophyContent
    local isRentOffer = showAsTrophyContent && offerRentTimeHours > 0

    info.hasIcon = hasProgress || isRentOffer
    info.hasProgress = hasProgress

    local totalRentTimeSec = hasProgress ?
      (::rented_units_get_last_max_full_rent_time(unit.name) || -1)
      : 3600
    info.progress = hasProgress ?
      (360 - ::round(360.0 * unit.getRentTimeleft() / totalRentTimeSec).tointeger())
      : 0
  }

  return info
}

function get_slot_unit_name_text(unit, params)
{
  local res = ::getUnitName(unit)
  local missionRules = ::getTblValue("missionRules", params)
  local groupName = missionRules ? missionRules.getRandomUnitsGroupName(unit.name) : null
  if (groupName)
    res = missionRules.getRandomUnitsGroupLocName(groupName)
  if (missionRules && missionRules.isWorldWarUnit(unit.name))
    res = ::loc("icon/worldWar/colored") + res
  if (missionRules && missionRules.needLeftRespawnOnSlots)
  {
    local leftRespawns = missionRules.getUnitLeftRespawns(unit)
    local leftWeaponPresetsText = missionRules.getUnitLeftWeaponShortText(unit)
    local text = leftRespawns != ::RESPAWNS_UNLIMITED
      ? missionRules.isUnitAvailableBySpawnScore(unit)
        ? ::loc("icon/star/white")
        : leftRespawns.tostring()
      : ""

    if (leftWeaponPresetsText.len())
      text += (text.len() ? "/" : "") + leftWeaponPresetsText

    if (text.len())
      res += ::loc("ui/parentheses/space", { text = text })
  }
  return res
}

::is_unit_price_text_long <- @(text) ::utf8_strlen(::g_dagui_utils.removeTextareaTags(text)) > 13

function get_unit_item_price_text(unit, params)
{
  local isLocalState        = ::getTblValue("isLocalState", params, true)
  local haveRespawnCost     = ::getTblValue("haveRespawnCost", params, false)
  local haveSpawnDelay      = ::getTblValue("haveSpawnDelay", params, false)
  local curSlotIdInCountry  = ::getTblValue("curSlotIdInCountry", params, -1)
  local curSlotCountryId    = ::getTblValue("curSlotCountryId", params, -1)
  local slotDelayData       = ::getTblValue("slotDelayData", params, null)

  local priceText = ""

  if (curSlotIdInCountry >= 0 && ::is_spare_aircraft_in_slot(curSlotIdInCountry))
    priceText += ::loc("spare/spare/short") + " "

  if ((haveRespawnCost || haveSpawnDelay) && ::getTblValue("unlocked", params, true))
  {
    local spawnDelay = slotDelayData != null
      ? slotDelayData.slotDelay - ((::dagor.getCurTime() - slotDelayData.updateTime)/1000).tointeger()
      : ::get_slot_delay(unit.name)
    if (haveSpawnDelay && spawnDelay > 0)
      priceText += time.secondsToString(spawnDelay)
    else
    {
      local txtList = []
      local wpToRespawn = ::get_unit_wp_to_respawn(unit.name)
      if (wpToRespawn > 0 && ::is_crew_available_in_session(curSlotIdInCountry, false))
      {
        local sessionWpBalance = ::getTblValue("sessionWpBalance", params, 0)
        wpToRespawn += ::getTblValue("weaponPrice", params, 0)
        txtList.append(::colorTextByValues(::Cost(wpToRespawn).toStringWithParams({isWpAlwaysShown = true}),
          sessionWpBalance, wpToRespawn, true, false))
      }

      local reqUnitSpawnScore = ::shop_get_spawn_score(unit.name, ::get_last_weapon(unit.name))
      local totalSpawnScore = ::getTblValue("totalSpawnScore", params, -1)
      if (reqUnitSpawnScore > 0 && totalSpawnScore > -1)
      {
        local spawnScoreText = reqUnitSpawnScore
        if (reqUnitSpawnScore > totalSpawnScore)
          spawnScoreText = "<color=@badTextColor>" + reqUnitSpawnScore + "</color>"
        txtList.append(::loc("shop/spawnScore", {cost = spawnScoreText}))
      }

      if (txtList.len())
      {
        local spawnCostText = ::g_string.implode(txtList, ", ")
        if (priceText.len())
          spawnCostText = ::loc("ui/parentheses", { text = spawnCostText })
        priceText += spawnCostText
      }
    }
  }

  if (::is_in_flight())
  {
    local maxSpawns = ::get_max_spawns_unit_count(unit.name)
    if (curSlotIdInCountry >= 0 && maxSpawns > 1)
    {
      local leftSpawns = maxSpawns - ::get_num_used_unit_spawns(curSlotIdInCountry)
      priceText += ::format("(%s/%s)", leftSpawns.tostring(), maxSpawns.tostring())
    }
  } else if (isLocalState && priceText == "")
  {
    local gift                = ::isUnitGift(unit)
    local canBuy              = ::canBuyUnit(unit)
    local isUsable            = ::isUnitUsable(unit)
    local isBought            = ::isUnitBought(unit)
    local special             = ::isUnitSpecial(unit)
    local researched          = ::isUnitResearched(unit)
    local showAsTrophyContent = ::getTblValue("showAsTrophyContent", params, false)
    local isReceivedPrizes    = ::getTblValue("isReceivedPrizes", params, false)
    local overlayPrice        = ::getTblValue("overlayPrice", params, -1)

    if (overlayPrice >= 0)
      priceText = ::getPriceAccordingToPlayersCurrency(overlayPrice, 0, true)
    else if (!isUsable && gift)
      priceText = ::g_string.stripTags(::loc("shop/giftAir/" + unit.gift, "shop/giftAir/alpha"))
    else if (!isUsable && (canBuy || special || !special && researched))
      priceText = ::getPriceAccordingToPlayersCurrency(::wp_get_cost(unit.name), ::wp_get_cost_gold(unit.name), true)

    if (priceText == "" && isBought && showAsTrophyContent && !isReceivedPrizes)
      priceText = ::colorize("goodTextColor", ::loc("mainmenu/itemReceived"))
  }

  return priceText
}

function get_unit_item_research_progress_text(unit, params, priceText = "")
{
  local progressText = ""

  if (!::u.isEmpty(priceText))
    return progressText
  if (!::canResearchUnit(unit))
    return progressText

  local unitExpReq  = ::getUnitReqExp(unit)
  local unitExpCur  = ::getUnitExp(unit)
  if (unitExpReq <= 0 || unitExpReq <= unitExpCur)
    return progressText

  local forceNotInResearch  = ::getTblValue("forceNotInResearch", params, false)
  local isVehicleInResearch = !forceNotInResearch && ::isUnitInResearch(unit)

  progressText = ::Cost().setRp(unitExpReq - unitExpCur).tostring()

  local flushExp = ::getTblValue("flushExp", params, 0)
  local isFull = flushExp > 0 && flushExp >= unitExpReq

  local color = isFull  ? "goodTextColor" :
    isVehicleInResearch ? "cardProgressBonusColor" :
                          ""
  if (color != "")
    progressText = ::colorize(color, progressText)
  return progressText
}

function get_unit_rank_text(unit, crew = null, showBR = false, ediff = -1)
{
  if (::isUnitGroup(unit))
  {
    local isReserve = false
    local rank = 0
    local minBR = 0
    local maxBR = 0
    foreach(u in unit.airsGroup)
    {
      isReserve = isReserve || ::isUnitDefault(u)
      rank = rank || u.rank
      local br = u.getBattleRating(ediff)
      minBR = !minBR ? br : ::min(minBR, br)
      maxBR = !maxBR ? br : ::max(maxBR, br)
    }
    return isReserve ? ::g_string.stripTags(::loc("shop/reserve")) :
      showBR  ? (minBR != maxBR ? ::format("%.1f-%.1f", minBR, maxBR) : ::format("%.1f", minBR)) :
      ::get_roman_numeral(rank)
  }

  local isReserve = ::isUnitDefault(unit)
  local isSpare = crew && ::is_in_flight() ? ::is_spare_aircraft_in_slot(crew.idInCountry) : false
  return isReserve ? (isSpare ? "" : ::g_string.stripTags(::loc("shop/reserve"))) :
    showBR  ? ::format("%.1f", unit.getBattleRating(ediff)) :
    ::get_roman_numeral(unit.rank)
}

function updateAirStatus(obj, air)
{
  if (!air)
    return

  if (::checkObj(obj))
  {
    local isMounted = ::isUnitInSlotbar(air)
    local bitStatus = 0
    if (isMounted)
      bitStatus = bit_unit_status.mounted
    else
      bitStatus = bit_unit_status.owned

    obj.shopStat = ::getUnitItemStatusText(bitStatus, false)

    local inServiceObj = obj.findObject("inService")
    if (::checkObj(inServiceObj))
      inServiceObj.show(isMounted)
  }

  ::updateAirAfterSwitchMod(air)
}

function is_crew_locked_by_prev_battle(crew)
{
  return ::isInMenu() && ::getTblValue("lockedTillSec", crew, 0) > 0
}

function isUnitUnlocked(handler, unit, curSlotCountryId, curSlotIdInCountry, country = null, needDbg = false)
{
  local crew = ::g_crews_list.get()[curSlotCountryId].crews[curSlotIdInCountry]
  local unlocked = !::is_crew_locked_by_prev_battle(crew)
  if (unit)
  {
    local tags = ::getSlotbarTags(handler)
    unlocked = unlocked && (!tags || ::check_aircraft_tags(unit.tags, tags))
    unlocked = unlocked && (!country || ::is_crew_available_in_session(curSlotIdInCountry, needDbg))
    unlocked = unlocked && (::isUnitAvailableForGM(unit, ::get_game_mode()) || ::is_in_flight())
    if (unlocked && !::SessionLobby.canChangeCrewUnits() && !::is_in_flight()
        && ::SessionLobby.getMaxRespawns() == 1)
      unlocked = ::SessionLobby.getMyCurUnit() == unit
  }

  return unlocked
}

function isCountryAllCrewsUnlockedInHangar(countryId)
{
  foreach (tbl in ::g_crews_list.get())
    if (tbl.country == countryId)
      foreach (crew in tbl.crews)
        if (::is_crew_locked_by_prev_battle(crew))
          return false
  return true
}

function getSlotbarTags(handler) //!!FIX ME: Why it here?
{
  return handler?.ownerWeak?.slotbarCheckTags ? ::aircrafts_filter_tags : null
}

function getBrokenSlotsCount(country)
{
  local count = 0
  foreach(c in ::g_crews_list.get())
    if (!country || country == c.country)
      foreach(crew in c.crews)
        if (("aircraft" in crew) && crew.aircraft!="")
        {
          local hp = shop_get_aircraft_hp(crew.aircraft)
          if (hp >= 0 && hp < 1)
            count++
        }
  return count
}

function initSlotbarAnim(countriesObj, guiScene, first=true)
{
  guiScene.performDelayed(this, (@(countriesObj, guiScene, first) function() {
    if (!countriesObj || !countriesObj.isValid())
      return
    local total = countriesObj.childrenCount()
    if (total < 2)
      return

    local minWidth = countriesObj.getChild(0).getSize()[0]
    local maxWidth = minWidth

    for(local i=0; i<total; i++)
    {
      local width = countriesObj.getChild(i).getSize()[0]
      if (width!=minWidth)
      {
        if (width<minWidth)
          minWidth=width
        else
          maxWidth=width
        break
      }
    }
    if (minWidth==maxWidth)
    {
      if (first) //try to reinit anim once
        ::initSlotbarAnim(countriesObj, guiScene, false)
      return
    }

    local selected = countriesObj.getValue()
    if (selected < 0)
      selected = 0
    for(local i=total-1; i>=0; i--)
    {
      local option = countriesObj.getChild(i)
      option["width-base"] = minWidth.tostring()
      option["width-end"] = maxWidth.tostring()
      option["width"] = (selected==i)? maxWidth.tostring() : minWidth.tostring()
      option["_size-timer"] = (selected==i)? "1" : "0"
      option.setFloatProp(::dagui_propid.add_name_id("_size-timer"), (selected==i)? 1.0 : 0.0);
    }
  })(countriesObj, guiScene, first))
}

function getSlotItem(countryId, idInCountry)
{
  return ::g_crews_list.get()?[countryId]?.crews?[idInCountry]
}

function getSlotAircraft(countryId, idInCountry)
{
  local crew = getSlotItem(countryId, idInCountry)
  local airName = ("aircraft" in crew)? crew.aircraft : ""
  local air = getAircraftByName(airName)
  return air
}

function get_crew_by_id(id)
{
  foreach(cId, cList in ::g_crews_list.get())
    if ("crews" in cList)
      foreach(idx, crew in cList.crews)
       if (crew.id==id)
         return crew
  return null
}

function getCrewByAir(air)
{
  foreach(country in ::g_crews_list.get())
    if (country.country == air.shopCountry)
      foreach(crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft==air.name)
          return crew
  return null
}

function isUnitInSlotbar(air)
{
  return ::getCrewByAir(air) != null
}

function getSlotbarUnitTypes(country)
{
  local res = []
  foreach(countryData in ::g_crews_list.get())
    if (countryData.country == country)
      foreach(crew in countryData.crews)
        if (("aircraft" in crew) && crew.aircraft != "")
        {
          local unit = ::getAircraftByName(crew.aircraft)
          if (unit)
            ::u.appendOnce(::get_es_unit_type(unit), res)
        }
  return res
}

function get_crews_list_by_country(country)
{
  foreach(countryData in ::g_crews_list.get())
    if (countryData.country == country)
      return countryData.crews
  return []
}

function getAvailableCrewId(countryId)
{
  local id=-1
  local curAircraft = ::get_show_aircraft_name()
  if ((countryId in ::g_crews_list.get()) && ("crews" in ::g_crews_list.get()[countryId]))
    for(local i=0; i<::g_crews_list.get()[countryId].crews.len(); i++)
    {
      local crew = ::g_crews_list.get()[countryId].crews[i]
      if (("aircraft" in crew) && crew.aircraft!="")
      {
        if (id<0) id=i
        if (crew.aircraft==curAircraft)
        {
          id=i
          break
        }
      }
    }
  return id
}

function selectAvailableCrew(countryId)
{
  local isAnyUnitInSlotbar = false
  if ((countryId in ::g_crews_list.get()) && (countryId in ::selected_crews))
  {
    local id = getAvailableCrewId(countryId)
    isAnyUnitInSlotbar = id >= 0

    if (!isAnyUnitInSlotbar)
      id = 0

    ::selected_crews[countryId] = id
  }
  return isAnyUnitInSlotbar
}

function save_selected_crews()
{
  if (!::g_login.isLoggedIn())
    return

  local blk = ::DataBlock()
  foreach(cIdx, country in ::g_crews_list.get())
    blk[country.country] = ::getTblValue(cIdx, ::selected_crews, 0)
  ::saveLocalByAccount("selected_crews", blk)
}

function init_selected_crews(forceReload = false)
{
  if (!forceReload && (!::g_crews_list.get().len() || ::selected_crews.len() == ::g_crews_list.get().len()))
    return

  local selCrewsBlk = ::loadLocalByAccount("selected_crews", null)
  local needSave = false

  ::selected_crews = array(::g_crews_list.get().len(), 0)
  foreach(cIdx, country in ::g_crews_list.get())
  {
    local crewIdx = selCrewsBlk && selCrewsBlk[country.country] || 0
    if (("crews" in country)
        && (crewIdx in country.crews)
        && ("aircraft" in country.crews[crewIdx])
        && country.crews[crewIdx].aircraft != "")
          ::selected_crews[cIdx] = crewIdx
    else
    {
      if (!selectAvailableCrew(cIdx))
      {
        local requestData = [{
          crewId = country.crews[0].id
          airName = ::getReserveAircraftName({country = country.country})
        }]
        ::batch_train_crew(requestData)
      }
      needSave = true
    }
  }
  if (needSave)
    ::save_selected_crews()
  ::broadcastEvent("CrewChanged")
}

function select_crew_silent_no_check(countryId, idInCountry)
{
  if (::selected_crews[countryId] != idInCountry)
  {
    ::selected_crews[countryId] = idInCountry
    ::save_selected_crews()
  }
}

function select_crew(countryId, idInCountry, airChanged = false)
{
  init_selected_crews()
  local air = getSlotAircraft(countryId, idInCountry)
  if (!air || (::selected_crews[countryId] == idInCountry && !airChanged))
    return

  ::select_crew_silent_no_check(countryId, idInCountry)
  ::broadcastEvent("CrewChanged")
  ::g_squad_utils.updateMyCountryData()
}

function getSelAircraftByCountry(country)
{
  init_selected_crews()
  foreach(cIdx, c in ::g_crews_list.get())
    if (c.country == country)
      return getSlotAircraft(cIdx, ::selected_crews[cIdx])
  return null
}

function get_cur_slotbar_unit()
{
  return getSelAircraftByCountry(::get_profile_country_sq())
}

function is_unit_enabled_for_slotbar(unit, params)
{
  if (!unit)
    return false

  local res = true
  if (params?.eventId)
  {
    res = false
    local event = ::events.getEvent(params.eventId)
    if (event)
      res = ::events.isUnitAllowedForEventRoom(event, ::getTblValue("room", params), unit)
  }
  else if (params?.availableUnits)
    res = unit.name in params.availableUnits
  else if (::SessionLobby.isInRoom() && !::is_in_flight())
    res = ::SessionLobby.isUnitAllowed(unit)
  else if (params?.roomCreationContext)
    res = params.roomCreationContext.isUnitAllowed(unit)

  if (res && params?.mainMenuSlotbar)
    res = ::game_mode_manager.isUnitAllowedForGameMode(unit)

  local missionRules = params?.missionRules
  if (res && missionRules)
  {
    local isAvaliableUnit = (missionRules.getUnitLeftRespawns(unit) != 0
      || missionRules.isUnitAvailableBySpawnScore(unit))
      && missionRules.isUnitEnabledByRandomGroups(unit.name)
    local isControlledUnit = !::is_respawn_screen()
      && ::is_player_unit_alive()
      && ::get_player_unit_name() == unit.name

    res = isAvaliableUnit || isControlledUnit
  }

  return res
}

function isUnitInCustomList(unit, params)
{
  if (!unit)
    return false

  return params?.customUnitsList ? unit.name in params.customUnitsList : true
}

function getSelSlotsTable()
{
  init_selected_crews()
  local slots = {}
  foreach(cIdx, country in ::g_crews_list.get())
  {
    local air = getSlotAircraft(cIdx, ::selected_crews[cIdx])
    if (!air)
    {
      dagor.debug("selected crews = ")
      debugTableData(::selected_crews)
      dagor.debug("crews list = ")
      debugTableData(::g_crews_list.get())
//      dagor.assertf(false, "Incorrect selected_crews list on getSelSlotsTable")
      selectAvailableCrew(cIdx)
    }
    slots[country.country] <- ::selected_crews[cIdx]
  }
  return slots
}

function getSelAirsTable()
{
  init_selected_crews()
  local airs = {}
  foreach(cIdx, country in ::g_crews_list.get())
  {
    local air = getSlotAircraft(cIdx, ::selected_crews[cIdx])
    airs[country.country] <- air? air.name : ""
  }
  return airs
}

function initSlotbarTopBar(slotbarObj, show)
{
  if (!::checkObj(slotbarObj))
    return

  local containerObj = slotbarObj.findObject("slotbar_buttons_place")
  local mainObj = slotbarObj.findObject("autorefill-settings")
  if (!::check_obj(containerObj) || !::check_obj(mainObj))
    return

  containerObj.show(show)
  mainObj.show(show)
  if (!show)
    return

  local obj = mainObj.findObject("slots-autorepair")
  if (::checkObj(obj))
    obj.setValue(::get_auto_refill(0))

  local obj = mainObj.findObject("slots-autoweapon")
  if (::checkObj(obj))
    obj.setValue(::get_auto_refill(1))
}

function set_autorefill_by_obj(obj)
{
  if (::slotbar_oninit || !obj) return
  local mode = -1
  if (obj.id == "slots-autorepair") mode = 0
  else if (obj.id == "slots-autoweapon") mode = 1

  if (mode>=0)
  {
    local value = obj.getValue()
    set_auto_refill(mode, value)
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)

    ::slotbar_oninit = true
    ::broadcastEvent("AutorefillChanged", { id = obj.id, value = value })
    ::slotbar_oninit = false
  }
}

function isCountryAvailable(country)
{
  if (country=="country_0" || country=="")
    return true

  return ::isInArray(country, ::unlocked_countries) || ::is_country_available(country)
}

function is_country_visible(country)
{
  if (country == "country_china")
    return ::has_feature("CountryChina")
  return true
}

function isAnyBaseCountryUnlocked()
{
  local notBaseCount = 0
  foreach(c in ::fake_countries)
    if (::isInArray(c, ::unlocked_countries))
      notBaseCount++
  return ::unlocked_countries.len() > notBaseCount
}

function isAllBaseCountriesUnlocked()
{
  foreach(c in ::g_crews_list.get())
    if (!::isInArray(c.country, ::unlocked_countries))
      return false
  return true
}

function unlockCountry(country, hideInUserlog = false, reqUnlock = true)
{
  if (reqUnlock)
    ::req_unlock_by_client(country, hideInUserlog)

  if (!::isInArray(country, ::unlocked_countries))
    ::unlocked_countries.append(country)
}

function checkUnlockedCountries()
{
  local curUnlocked = []
  if (::is_need_first_country_choice())
    return curUnlocked

  local unlockAll = ::isDiffUnlocked(1, ::ES_UNIT_TYPE_AIRCRAFT) || ::disable_network() || ::has_feature("UnlockAllCountries")
  local wasInList = ::unlocked_countries.len()
  foreach(i, country in ::shopCountriesList)
    if (::is_country_available(country))
    {
      if (!::isInArray(country, ::unlocked_countries))
      {
        ::unlocked_countries.append(country)
        curUnlocked.append(country)
      }
    }
    else if (unlockAll || ::isInArray(country, ::fake_countries))
    {
      unlockCountry(country, !::g_login.isLoggedIn())
      curUnlocked.append(country)
    }
  if (wasInList != ::unlocked_countries.len())
    ::broadcastEvent("UnlockedCountriesUpdate")
  return curUnlocked
}

function checkUnlockedCountriesByAirs() //starter packs
{
  local haveUnlocked = false
  foreach(air in ::all_units)
    if (!::isUnitDefault(air)
        && ::isUnitUsable(air)
        && !::isCountryAvailable(air.shopCountry))
    {
      unlockCountry(air.shopCountry)
      haveUnlocked = true
    }
  if (haveUnlocked)
    ::broadcastEvent("UnlockedCountriesUpdate")
  return haveUnlocked
}

function getNextCountryToUnlock()
{
  foreach(country in ::shopCountriesList)
    if (!isCountryAvailable(country))
      return country
  return null
}

function num_countries_unlocked_by_domination()
{
  for(local d=0; d<3; d++)
    if (::stat_get_value_respawns(d, 1) >= 0)
      return 1
  return 0
}

function get_slotbar_countries(cleared = false)
{
  local res = []
  foreach(country in ::shopCountriesList)
  {
    if (cleared && ::isInArray(country, ::fake_countries))
      continue
    res.append(country)
  }
  return res
}

function addAirButtonsTimer(listObj, needTimerList, air, handler)
{
  SecondsUpdater(listObj, (@(needTimerList, air, handler) function(obj, params) {
    foreach(name in needTimerList)
    {
      local btnObj = obj.findObject("slot_action_" + name)
      if (!::checkObj(btnObj))
        continue

      if (name == "repair")
      {
        local repairCost = ::wp_get_repair_cost(air.name)
        local text = ::Cost(repairCost).getUncoloredText()
        btnObj.setValue(format(::loc("mainmenu/btnRepairNow"), text))

        local taObj = btnObj.findObject("textarea")
        if (::checkObj(taObj))
        {
          local text = ::Cost(repairCost).tostring()
          if (get_balance().wp < repairCost)
            text = "<color=@badTextColor>" + text + "</color>"
          taObj.setValue(format(::loc("mainmenu/btnRepairNow"), text))
        }
      }
    }
  })(needTimerList, air, handler))
}

function gotTanksInSlots(checkCountryId=null, checkUnitId=null)
{
  foreach(country in ::g_crews_list.get())
    if (::isCountryAvailable(country.country) && (!checkCountryId || checkCountryId == country.country))
      foreach(crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft != "" && (!checkUnitId || checkUnitId == crew.aircraft) && ::isTank(::getAircraftByName(crew.aircraft)))
          return true
  return false
}

function tanksDriveGamemodeRestrictionMsgBox(featureName, curCountry=null, curUnit=null, msg=null)
{
  if (::has_feature(featureName) || !::gotTanksInSlots(curCountry, curUnit))
    return false

  msg = msg || "cbt_tanks/forbidden/tank_access"
  msg = ::loc(msg) + "\n" + ::loc("cbt_tanks/supported_game_modes") + "\n" + ::loc("cbt_tanks/temporary_restriction_release")
  ::showInfoMsgBox(msg, "cbt_tanks_forbidden")
  return true
}
