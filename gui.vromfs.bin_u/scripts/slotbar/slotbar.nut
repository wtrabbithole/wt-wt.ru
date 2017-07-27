::crews_list <- !::g_login.isLoggedIn() ? [] : ::get_crew_info()

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

function build_aircraft_item(id, air, params = {})
{
  local res = ""
  local defaultStatus = "none"
  local getVal = (@(params) function(val, defVal) {
    return ::getTblValue(val, params, defVal)
  })(params)

  if (air && !::isUnitGroup(air))
  {
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

    local bitStatus = 0
    local status = getVal("status", defaultStatus)
    if (status == defaultStatus)
    {
      if (::is_in_flight())
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

    local isActive = getVal("active", false) && !disabled

    //
    // Bottom button view
    //

    local mainButtonAction = ::show_console_buttons ? "onOpenActionsList" : getVal("mainActionFunc", "")
    local mainButtonText = ::show_console_buttons ? "" : getVal("mainActionText", "")
    local mainButtonIcon = ::show_console_buttons ? "#ui/gameuiskin#slot_menu" : getVal("mainActionIcon", "")
    local checkTexts = mainButtonAction.len() > 0 && (mainButtonText.len() > 0 || mainButtonIcon.len() > 0)
    local checkButton = !isVehicleInResearch || ::has_feature("SpendGold")
    local bottomButtonView = {
      hasButton           = isActive && checkTexts && checkButton
      spaceButton         = true
      mainButtonText      = mainButtonText
      mainButtonAction    = mainButtonAction
      hasMainButtonIcon   = mainButtonIcon.len()
      mainButtonIcon      = mainButtonIcon
    }

    //
    // Item buttons view
    //

    local weaponsStatus = checkUnitWeapons(air.name)
    local crewId = getVal("crewId", -1)
    local showWarningIcon = getVal("showWarningIcon", false)
    local specType = getVal("specType", null)
    local rentInfo = ::get_unit_item_rent_info(air, params)
    local spareCount = ::get_spare_aircrafts_count(air.name)

    local hasCrewInfo = crewId >= 0
    local crew = hasCrewInfo ? ::get_crew_by_id(crewId) : null
    local crewLevelText = crew && air ? ::g_crew.getCrewLevel(crew, ::get_es_unit_type(air)).tointeger().tostring() : ""

    local itemButtonsView = {
      itemButtons = {
        hasToBattleButton       = getVal("toBattle", false) && !::show_console_buttons
        toBattleButtonPrefix    = getVal("actionsPrefix", "onSlot")
        hasExtraInfoBlock       = getVal("hasExtraInfoBlock", false)

        hasCrewInfo             = hasCrewInfo
        crewLevel               = hasCrewInfo ? crewLevelText : ""
        crewSpecIcon            = hasCrewInfo ? ::g_crew_spec_type.getTypeByCrewAndUnit(crew, air).trainedIcon : ""
        crewStatus              = hasCrewInfo ? ::get_crew_status_by_id(crewId) : ""

        hasSpareCount           = spareCount > 0
        spareCount              = spareCount ? spareCount + ::loc("icon/spare") : ""
        specIconBlock           = showWarningIcon || specType != null
        showWarningIcon         = showWarningIcon
        hasRepairIcon           = ::wp_get_repair_cost(air.name) > 0
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

    local showProgress = !isOwn && canResearch
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
    local progressText = ::get_unit_item_research_progress_text(air, params, priceText)
    local checkNotification = ::getTblValueByPath("entitlementUnits." + air.name, ::visibleDiscountNotifications)

    local showBR = ::getTblValue("showBR", params, ::has_feature("GlobalShowBattleRating"))
    local curEdiff = ("getEdiffFunc" in params) ?  params.getEdiffFunc() : ::get_current_ediff()

    local resView = {
      slotId              = "td_" + id
      slotInactive        = inactive
      isFullSlotbar       = getVal("fullSlotbar", false)
      shopItemId          = id
      unitName            = air.name
      premiumPatternType  = special
      shopItemType        = ::get_unit_role(air.name)
      unitClassIcon       = ::get_unit_role_icon(air)
      shopStatus          = status
      unitRarity          = unitRarity
      isBroken            = isBroken
      shopAirImg          = ::image_for_air(air)
      discountId          = id + "-discount"
      showDiscount        = !isOwn && (!::isUnitGift(air) || checkNotification)
      shopItemTextId      = id + "_txt"
      shopItemText        = ::get_slot_unit_name_text(air, params)
      progressText        = progressText
      progressBlk         = ::handyman.renderCached("gui/slotbar/airResearchProgress", airResearchProgressView)
      showInService       = getVal("showInService", false) && isUsable
      isMounted           = isMounted
      priceText           = priceText
      isElite             = ::isUnitElite(air)
      unitRankText        = ::get_unit_rank_text(air, crew, showBR, curEdiff)
      isItemLocked        = !isUsable && !special && !::isUnitsEraUnlocked(air)
      hasTalismanIcon     = special || ::shop_is_modification_enabled(air.name, "premExpMul")
      itemButtons         = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
      tooltipId           = ::g_tooltip.getIdUnit(air.name, getVal("tooltipParams", null))
      bottomButton        = ::handyman.renderCached("gui/slotbar/slotbarItemBottomButton", bottomButtonView)
      hasHoverMenu        = !isActive
      hasOnHover          = isActive
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
    local researchUnitName = ::shop_get_researchable_unit_name(country, type)

    local era = getUnitRank(nextAir)
    local showBR = ::getTblValue("showBR", params, ::has_feature("GlobalShowBattleRating"))
    local curEdiff = ("getEdiffFunc" in params) ?  params.getEdiffFunc() : ::get_current_ediff()

    local isGroupUsable     = false
    local isGroupInResearch = false
    local isElite           = true
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
      local isInResearch = !forceNotInResearch && a.name == researchUnitName
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
      mainButtonIcon      = "#ui/gameuiskin#slot_unfold"
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
        shopAirImage = "!#ui/unitskin_tomoe#" + air.name + (air.name.find("_group", 0) ? "" : "_group")
      else
        shopAirImage = "!" + (::getTblValue("image", air) || "#ui/unitskin_air#planes_group")

    local groupSlotView = {
      slotId              = id
      unitRole            = unitRole
      unitClassIcon       = ::get_unit_role_icon(nextAir)
      groupStatus         = groupStatus == defaultStatus ? ::getUnitItemStatusText(bitStatus, true) : groupStatus
      isBroken            = bitStatus & bit_unit_status.broken
      shopAirImg          = shopAirImage
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
    local costGold = ::getTblValue("costGold", emptyCost, 0)
    local priceText = (emptyCost == null)
      ? ""
      : ::getPriceAccordingToPlayersCurrency(emptyCost.cost, costGold, true)
    local emptySlotView = {
      slotId = "td_" + id,
      shopItemId = id,
      shopItemTextId = id + "_txt",
      shopItemTextValue = getVal("emptyText", ""),
      shopItemPriceText = priceText,
      crewImage = getVal("crewImage", null),
      isCrewRecruit = getVal("isCrewRecruit", false),
      itemButtons = ::handyman.renderCached("gui/slotbar/slotbarItemButtons", itemButtonsView)
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

  ::secondsUpdater(holderObj, (@(rentedUnit) function(obj, params) {
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
  if (missionRules && missionRules.needLeftRespawnOnSlots)
  {
    local leftRespawns = missionRules.getUnitLeftRespawns(unit)
    if (leftRespawns != ::RESPAWNS_UNLIMITED)
      res += ::loc("ui/parentheses/space", { text = leftRespawns })
  }
  return res
}

function get_unit_item_price_text(unit, params)
{
  if (::getTblValue("isPriceForcedHidden", params, false))
    return ""

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
      priceText += ::secondsToString(spawnDelay)
    else
    {
      local txtList = []
      if (::crews_list
          && curSlotCountryId in ::crews_list
          && curSlotIdInCountry in ::crews_list[curSlotCountryId].crews
          && ::getTblValue("wpToRespawn", ::crews_list[curSlotCountryId].crews[curSlotIdInCountry], 0) > 0
          && ::is_crew_available_in_session(curSlotIdInCountry, false))
      {
        local sessionWpBalance = ::getTblValue("sessionWpBalance", params, 0)
        local wpToRespawn = ::getTblValue("wpToRespawn", ::crews_list[curSlotCountryId].crews[curSlotIdInCountry], 0)
        wpToRespawn += ::getTblValue("weaponPrice", params, 0)
        txtList.append(::colorTextByValues(::getWpPriceText(wpToRespawn, true), sessionWpBalance, wpToRespawn, true, false))
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
        local spawnCostText = ::implode(txtList, ", ")
        if (priceText.len())
          spawnCostText = ::loc("ui/parentheses", { text = spawnCostText })
        priceText += spawnCostText
      }
    }
  }

  local maxSpawns = ::get_max_spawns_unit_count(unit.name)
  if (curSlotIdInCountry >= 0 && maxSpawns > 1)
  {
    local leftSpawns = maxSpawns - ::get_num_used_unit_spawns(curSlotIdInCountry)
    priceText += ::format("(%s/%s)", leftSpawns.tostring(), maxSpawns.tostring())
  }

  if (priceText == "" && !::is_in_flight())
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
      priceText = ::stripTags(::loc("shop/giftAir/" + unit.gift, "shop/giftAir/alpha"))
    else if (!isUsable && (canBuy || special || !special && researched))
      priceText = ::getPriceAccordingToPlayersCurrency(::wp_get_cost(unit.name), ::wp_get_cost_gold(unit.name), true)

    if (priceText == "" && isBought && showAsTrophyContent && !isReceivedPrizes)
      priceText = ::colorize("goodTextColor", ::loc("shop/unit_bought"))
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

  progressText = (unitExpReq - unitExpCur) + ::loc("currency/researchPoints/sign/colored")

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
      local br = ::get_unit_battle_rating_by_mode(u, ediff)
      minBR = !minBR ? br : ::min(minBR, br)
      maxBR = !maxBR ? br : ::max(maxBR, br)
    }
    return isReserve ? ::stripTags(::loc("shop/reserve")) :
      showBR  ? (minBR != maxBR ? ::format("%.1f-%.1f", minBR, maxBR) : ::format("%.1f", minBR)) :
      ::get_roman_numeral(rank)
  }

  local isReserve = ::isUnitDefault(unit)
  local isSpare = crew && ::is_in_flight() ? ::is_spare_aircraft_in_slot(crew.idInCountry) : false
  return isReserve ? (isSpare ? "" : ::stripTags(::loc("shop/reserve"))) :
    showBR  ? ::format("%.1f", ::get_unit_battle_rating_by_mode(unit, ediff)) :
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
  local crew = ::crews_list[curSlotCountryId].crews[curSlotIdInCountry]
  local unlocked = !::is_crew_locked_by_prev_battle(crew)
  if (unit)
  {
    local tags = ::getSlotbarTags(handler)
    unlocked = unlocked && (!tags || ::check_aircraft_tags(unit.tags, tags))
    unlocked = unlocked && (!country || ::is_crew_available_in_session(curSlotIdInCountry, needDbg))
    unlocked = unlocked && ::isUnitAvailableForGM(unit, ::get_game_mode())
    if (unlocked && !::SessionLobby.canChangeCrewUnits() && !::is_in_flight()
        && ::SessionLobby.getMaxRespawns() == 1)
      unlocked = ::SessionLobby.getMyCurUnit() == unit
  }

  return unlocked
}

function isCountryAllCrewsUnlockedInHangar(countryId)
{
  local crews_list = ::get_crew_info()
  foreach (tbl in crews_list)
    if (tbl.country == countryId)
      foreach (crew in tbl.crews)
        if (::is_crew_locked_by_prev_battle(crew))
          return false
  return true
}

function aircraftRClickMenu(prefix, itemActions, air, handler, position = null)
{
  local menu = ::get_unit_actions_list(air, handler, prefix, itemActions)
  ::gui_right_click_menu(menu, handler, position);
}

function get_slotbar_obj(handler=null, scene=null, canCreateObj = false)
{
  local guiScene = ::get_gui_scene()
  if (!::checkObj(scene))
  {
    scene = guiScene["nav-topMenu"]
    if (!::checkObj(scene))
      scene = guiScene["nav-help"]
  }
  assert(scene && scene.isValid())

  local slotbarObj = scene.findObject("nav-slotbar")
  if (!slotbarObj || !slotbarObj.isValid())
  {
    if (!canCreateObj)
      return null
    local data = "slotbarBg {} slotbarDiv { id:t='nav-slotbar' } "
    guiScene.appendWithBlk(scene, data, handler)
    slotbarObj = scene.findObject("nav-slotbar")
  }
  return slotbarObj
}

::defaultSlotbarActions <- [ "autorefill", "aircraft", "weapons", "crew","showroom", "rankinfo", "testflight", "info", "repair" ]

function init_slotbar(handler, scene = null, isSlotbarActive = true, slotbarCountry = null, params = {})
{
  if (!::g_login.isLoggedIn())
    return
  if (::slotbar_oninit)
  {
    ::script_net_assert_once("slotbar recursion", "init_slotbar: recursive call found")
    return
  }

  ::slotbar_oninit = true
  local country = slotbarCountry
  local slotbarObj = ::get_slotbar_obj(handler, scene, true)
  local guiScene = ::get_gui_scene()
  guiScene.setUpdatesEnabled(false, false);
  guiScene.replaceContent(slotbarObj, "gui/slotbar/slotbar.blk", handler)
  slotbarObj["singleCountry"] = country ? "yes" : "no"

  local selectedIdsData = {
    countryId = -1
    countryVisibleIdx = -1
    idInCountry = -1
    cellId = -1
    selectable = false
  }
  local curPlayerCountry = ::get_profile_info().country
  if (!country && !::SessionLobby.canChangeCountry())
    country = curPlayerCountry
  local curAircraft = ::get_show_aircraft_name()
  local curCrewId = ::getTblValue("crewId", params)
  local foundCurAir = false
  local airShopCountry = null
  local limitCountryChoice = (country == null) && ::getTblValue("limitCountryChoice", params, false)
  if (limitCountryChoice)
    airShopCountry = ::getTblValue("customCountry", params, curPlayerCountry)
  local showCountryName = ::has_feature("SlotbarShowCountryName")

  if (!limitCountryChoice && !country && !curCrewId)
  {
    local air = getAircraftByName(curAircraft)
    if (air && air.shopCountry == curPlayerCountry)
    {
      airShopCountry = air.shopCountry
      if (!::show_aircraft)
        ::show_aircraft = air
    }
    if ((!airShopCountry || !::isCountryAvailable(airShopCountry)) && ::unlocked_countries.len() > 0)
    {
      airShopCountry = curPlayerCountry
      if (!::isCountryAvailable(airShopCountry)) //user have choose country before lock appear in game
        airShopCountry = ::unlocked_countries[0]
      curAircraft = "" //selected aircraft was in locked country
    }
  } else if (country && handler.curSlotIdInCountry >= 0)
  {
    local curCrew = ::getSlotItem(handler.curSlotCountryId, handler.curSlotIdInCountry)
    if (curCrew)
      curCrewId = curCrew.id
  }

  local fullSlotbar = !limitCountryChoice && !country
  if (fullSlotbar && ::getTblValue("showTopPanel", params, true))
    ::initSlotbarTopBar(slotbarObj, true) //show autorefill checkboxes

  local missionRules = ::getTblValue("missionRules", params)
  local showNewSlot = ("showNewSlot" in params)? params.showNewSlot : !slotbarCountry
  local needShowLockedSlots = missionRules == null || missionRules.needShowLockedSlots
  local showEmptySlot = needShowLockedSlots && ::getTblValue("showEmptySlot", params, !slotbarCountry)
  local emptyText = ("emptyText" in params)? params.emptyText : "#shop/chooseAircraft"

  local showBR = ::has_feature("SlotbarShowBattleRating")
  local getEdiffFunc = ("getCurrentEdiff" in handler) ?  handler.getCurrentEdiff.bindenv(handler) : ::get_current_ediff()

  local countriesObj = slotbarObj.findObject("slotbar-countries")
  ::crews_list = ::get_crew_info()

  if (!::crews_list)
  {
    if (::g_login.isLoggedIn() && (::isProductionCircuit() || ::get_cur_circuit_name() == "nightly"))
      ::scene_msg_box("no_connection", null, ::loc("char/no_connection"), [["ok", function () {::gui_start_logout()}]], "ok")
    return
  }
  ::init_selected_crews()
  ::update_crew_skills_available()

  local hObj = slotbarObj.findObject("slotbar_background")
  hObj.show(!country)
  if (::show_console_buttons)
  {
    local lNavObj = hObj.findObject("slotbar_nav_block_left")
    lNavObj.show(!country && !limitCountryChoice)
    local rNavObj = hObj.findObject("slotbar_nav_block_right")
    rNavObj.show(!country && !limitCountryChoice)
  }

/*
  if (!slotbarActions)
    slotbarActions = ::defaultSlotbarActions
*/
  local countryVisibleIdx = -1
  for(local c=0; c<::crews_list.len(); c++)
    if (country==null || country==::crews_list[c].country)
    {
      if (!::is_country_visible(::crews_list[c].country))
        continue

      countryVisibleIdx++
      local itemName = "slotbar-country"+c
      local itemText = format("slotsOption { id:t='%s' _on_deactivate:t='restoreFocus'} ", itemName)
      guiScene.appendWithBlk(countriesObj, itemText, handler)
      local itemObj = countriesObj.findObject(itemName)
      guiScene.replaceContent(itemObj, "gui/slotbar/slotbarItem.blk", handler)

      local cTooltipObj = itemObj.findObject("tooltip_country_")
      if (cTooltipObj)
        cTooltipObj.id = "tooltip_"+::crews_list[c].country

      local unitItems = []

      local filledSlots = -1
      //when current crew not available in this mission, first available crew will be selected.
      local firstAvailableIdsData = {
        idInCountry = -1
        cellId = -1
        selectable = false
      }
      local rowData = ""
      local tblObj = itemObj.findObject("airs_table")
      tblObj.id = "airs_table_"+c
      tblObj.alwaysShowBorder = ::getTblValue("alwaysShowBorder", params, "no")

      for(local i=0; i<::crews_list[c].crews.len(); i++)
      {
        local crew = ::crews_list[c].crews[i]
        local airName = ("aircraft" in crew)? crew.aircraft : ""
        local air = getAircraftByName(airName)
        local unlocked = ::isUnitUnlocked(handler, air, c, i, country, true)
        local status = bit_unit_status.owned
        if (air)
        {
          status = unlocked? bit_unit_status.owned : bit_unit_status.locked

          if (unlocked && !::is_crew_slot_was_ready_at_host(crew.idInCountry, air.name, true))
            status = bit_unit_status.broken
          else if (unlocked)
          {
            local disabled = !::is_unit_enabled_for_slotbar(air, params)
            if (::getTblValue("checkRespawnBases", params, false))
              disabled = disabled || !::get_available_respawn_bases(air.tags).len()
            if (disabled)
              status = bit_unit_status.disabled
          }
        }
        unlocked = unlocked && status == bit_unit_status.owned

        local selectable = unlocked && air != null
        if (selectable && ::getTblValue("haveRespawnCost", params, false))
        {
          local totalSpawnScore = ::getTblValue("totalSpawnScore", params, -1)
          if (totalSpawnScore >= 0 && totalSpawnScore < ::shop_get_spawn_score(airName, ::get_last_weapon(airName)))
            selectable = false
        }

        if ((!air && showEmptySlot) || air && (needShowLockedSlots || unlocked))
        {
          local airParams = {
                              emptyText      = emptyText,
                              crewImage      = "#ui/images/slotbar/slotbar_crew_free_" + ::g_string.slice(::crews_list[c].country, 8)
                              status         = ::getUnitItemStatusText(status),
                              inactive       = ::show_console_buttons && status == bit_unit_status.locked && ::is_in_flight(),
                              active         = isSlotbarActive,
                              toBattle       = ::getTblValue("toBattle", params, false)
                              mainActionFunc = ::SessionLobby.canChangeCrewUnits() ? "onSlotChangeAircraft" : ""
                              mainActionText = "" // "#multiplayer/changeAircraft"
                              mainActionIcon = "#ui/gameuiskin#slot_change_aircraft"
                              crewId         = crew.id
                              fullSlotbar    = country==null
                              showBR         = showBR
                              getEdiffFunc   = getEdiffFunc
                              hasExtraInfoBlock = ::getTblValue("hasExtraInfoBlock", params, country == null)
                              haveRespawnCost = ::getTblValue("haveRespawnCost", params, false)
                              haveSpawnDelay = ::getTblValue("haveSpawnDelay", params, false)
                              totalSpawnScore = ::getTblValue("totalSpawnScore", params, -1)
                              sessionWpBalance = ::getTblValue("sessionWpBalance", params, 0)
                              curSlotIdInCountry = i
                              curSlotCountryId = c
                              unlocked = unlocked
                              tooltipParams = { needCrewInfo = true }
                              missionRules = missionRules
                            }

          local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, ::getTblValue("unitForSpecType", params))
          if (specType.code >= 0)
            airParams.specType <- specType

          local id = ::get_slot_obj_id(c, i)
          rowData += ::build_aircraft_item(id, air, airParams)
          unitItems.append({ id = id, unit = air, params = airParams })
          filledSlots++
        }

        if (air)
        {
          if ((!foundCurAir && selectedIdsData.idInCountry < 0 || !country)
              && (!limitCountryChoice || airShopCountry == ::crews_list[c].country))
            if (curCrewId != null)
            {
              if (curCrewId == crew.id)
              {
                selectedIdsData.countryId = c
                selectedIdsData.countryVisibleIdx = countryVisibleIdx
                selectedIdsData.idInCountry = i
                selectedIdsData.cellId = filledSlots
                selectedIdsData.selectable = selectable
                foundCurAir = true
              }
            }
            else if (curAircraft==airName)
            {
              selectedIdsData.countryId = c
              selectedIdsData.countryVisibleIdx = countryVisibleIdx
              selectedIdsData.idInCountry = i
              selectedIdsData.cellId = filledSlots
              selectedIdsData.selectable = selectable
              foundCurAir = true
            }

          if ((selectable && firstAvailableIdsData.idInCountry < 0)
                || (::selected_crews[c]==i && (selectable || !country)))
          {
            firstAvailableIdsData.idInCountry = i
            firstAvailableIdsData.cellId = filledSlots
            firstAvailableIdsData.selectable = true
          }
        }
      }
      if (firstAvailableIdsData.idInCountry < 0)
      {
        for (local i=0; i<::crews_list[c].crews.len(); i++)
        {
          local crew = ::crews_list[c].crews[i]
          local airName = ("aircraft" in crew)? crew.aircraft : ""
          if (airName != "")
          {
            local cellId = showEmptySlot ? i : 0
            firstAvailableIdsData.idInCountry = i
            firstAvailableIdsData.cellId = cellId
            firstAvailableIdsData.selectable = false
            break
          }
        }
      }
      if ((country || airShopCountry == ::crews_list[c].country || curPlayerCountry == ::crews_list[c].country)
          && (!foundCurAir || (firstAvailableIdsData.selectable && !selectedIdsData.selectable)))
      {
        selectedIdsData.countryId = c
        selectedIdsData.countryVisibleIdx = countryVisibleIdx
        selectedIdsData.idInCountry = firstAvailableIdsData.idInCountry
        selectedIdsData.cellId = firstAvailableIdsData.cellId
        selectedIdsData.selectable = true
        foundCurAir = true
      }
      if (::selected_crews[c] != selectedIdsData.idInCountry && airShopCountry == ::crews_list[c].country)
        ::select_crew(c, selectedIdsData.idInCountry)

      local slotCost = ::get_crew_slot_cost(::crews_list[c].country)
      if (slotCost && showNewSlot && (slotCost.costGold == 0 || ::has_feature("SpendGold")))
        rowData += build_aircraft_item(::get_slot_obj_id(c, ::crews_list[c].crews.len()),
                                       null,
                                       {
                                         emptyText = "#shop/recruitCrew",
                                         crewImage = "#ui/images/slotbar/slotbar_crew_recruit_" + ::g_string.slice(::crews_list[c].country, 8)
                                         isCrewRecruit = true
                                         bgImg = "#ui/opauque#buy_crew",
                                         emptyCost = slotCost,
                                         inactive = true
                                       })
      rowData = "tr { " + rowData + " } "

      guiScene.replaceContentFromText(tblObj, rowData, rowData.len(), handler)
      foreach (unitItem in unitItems)
        ::fill_unit_item_timers(tblObj.findObject(unitItem.id), unitItem.unit, unitItem.params)

      if (limitCountryChoice)
        itemObj.enable(airShopCountry == ::crews_list[c].country)

      local cUnlocked = ::isCountryAvailable(::crews_list[c].country)
      itemObj.inactive = "no"
      if (!cUnlocked)
      {
        itemObj.inactive = "yes"
        itemObj.tooltip = ::loc("mainmenu/countryLocked/tooltip")
      }

      local cImg = ::get_country_icon(::crews_list[c].country, false, !cUnlocked)
      itemObj.findObject("hdr_image")["background-image"] = cImg
      if (!::is_first_win_reward_earned(::crews_list[c].country, ::INVALID_USER_ID))
      {
        local mObj = itemObj.findObject("hdr_bonus")
        showCountryBonus(mObj, ::crews_list[c].country)
      }
      fillCountryInfo(itemObj, ::crews_list[c].country)
      if (showCountryName)
        itemObj.findObject("hdr_caption").setValue(::getVerticalText(::loc(::crews_list[c].country + "/short", "")))

      foreach(i, crew in ::crews_list[c].crews)
        if (("aircraft" in crew) && crew.aircraft!="")
          ::showAirExpWpBonus(tblObj.findObject(::get_slot_obj_id(c, i, true)), crew.aircraft)

      if (country==::crews_list[c].country)
        selectedIdsData.countryId = c
      if (selectedIdsData.countryId == c)
      {
        if (selectedIdsData.idInCountry < 0)
        {
          selectedIdsData.countryId = c
          selectedIdsData.countryVisibleIdx = countryVisibleIdx
          selectedIdsData.idInCountry = firstAvailableIdsData.idInCountry
          selectedIdsData.cellId = firstAvailableIdsData.cellId
        }
        if (selectedIdsData.cellId >= 0)
          ::gui_bhv.columnNavigator.selectCell(tblObj, 0, selectedIdsData.cellId, false)
        else
          ::gui_bhv.columnNavigator.selectCell(tblObj, 0, 0, false)
      } else
        if (firstAvailableIdsData.cellId>=0)
          ::gui_bhv.columnNavigator.selectCell(tblObj, 0, firstAvailableIdsData.cellId, false)
    }

  if (country || selectedIdsData.countryId < 0)
  {
    countriesObj.setValue(0)
    if (selectedIdsData.countryId < 0)
    {
      selectedIdsData.countryId = 0
      selectedIdsData.idInCountry = 0
      selectedIdsData.cellId = 0
    }
  } else
    if (selectedIdsData.countryVisibleIdx >= 0)
      countriesObj.setValue(selectedIdsData.countryVisibleIdx)

  if (selectedIdsData.countryId in ::crews_list)
    ::switch_profile_country(::crews_list[selectedIdsData.countryId].country)

  local selItem = ::get_slot_obj(countriesObj, selectedIdsData.countryId, selectedIdsData.idInCountry)
  if (selItem)
    guiScene.performDelayed(this, (@(selItem) function() {
      if (selItem && selItem.isValid() && selItem.isVisible())
        selItem.scrollToView()
    })(selItem))

  if (handler && ("slotbarScene" in handler))
  {
    handler.slotbarScene = scene
    handler.activeSlotbar = isSlotbarActive
    handler.slotbarCountry = slotbarCountry
    handler.slotbarParams = params
  }

  guiScene.setUpdatesEnabled(true, true);
  ::slotbar_oninit = false

  if (!country && ::crews_list.len()>1)
    initSlotbarAnim(countriesObj, guiScene)

  ::checkSlotbarUpdater(slotbarObj, handler, country)

  if (handler && ("curSlotCountryId" in handler))
  {
    local needEvent = handler.curSlotCountryId >= 0 && handler.curSlotCountryId != selectedIdsData.countryId
                      || handler.curSlotIdInCountry >= 0 && handler.curSlotIdInCountry != selectedIdsData.idInCountry
    if (needEvent)
    {
      local cObj = scene.findObject("airs_table_" + selectedIdsData.countryId)
      if (::checkObj(cObj))
      {
        handler.skipCheckAirSelect = true
        handler.onSlotbarSelect(cObj)
      }
    } else
    {
      handler.curSlotCountryId = selectedIdsData.countryId
      handler.curSlotIdInCountry = selectedIdsData.idInCountry
    }

    if (!country && ("showAircraft" in handler))
    {
      local curCrew = getSlotItem(selectedIdsData.countryId, selectedIdsData.idInCountry)
      if (("aircraft" in curCrew) && curCrew.aircraft != ::hangar_get_current_unit_name())
        handler.showAircraft(curCrew.aircraft)
    }

    local showPresetsPanel = ::getTblValue("showPresetsPanel", params, fullSlotbar)
    if (showPresetsPanel && ::SessionLobby.canChangeCrewUnits())
      handler.presetsListWeak = SlotbarPresetsList(handler).weakref()
  }
}

function get_slotbar_unit_slots(handler, unitId = null, crewId = -1, withEmptySlots = false)
{
  local unitSlots = []

  if (!::handlersManager.isHandlerValid(handler) || !::checkObj(::getTblValue("slotbarScene", handler)))
    return unitSlots

  local slotbarObj = ::get_slotbar_obj(handler, handler.slotbarScene)
  local country = handler.slotbarCountry
  foreach(countryId, countryData in ::crews_list)
    if (!country || countryData.country == country)
      foreach (idInCountry, crew in countryData.crews)
      {
        if (crewId != -1 && crewId != crew.id)
          continue
        local unit = ::g_crew.getCrewUnit(crew)
        if (unitId && unit && unitId != unit.name)
          continue
        local obj = ::get_slot_obj(slotbarObj, countryId, idInCountry)
        if (obj && (unit || withEmptySlots))
          unitSlots.append({
            unit      = unit
            crew      = crew
            countryId = countryId
            obj       = obj
          })
      }

  return unitSlots
}

function update_slotbar_difficulty(handler, unitSlots = null)
{
  unitSlots = unitSlots || ::get_slotbar_unit_slots(handler)

  local showBR = ::has_feature("SlotbarShowBattleRating")
  local curEdiff = handler.getCurrentEdiff.call(handler)

  foreach (slot in unitSlots)
  {
    local obj = slot.obj.findObject("rank_text")
    if (::checkObj(obj))
    {
      local unitRankText = ::get_unit_rank_text(slot.unit, slot.crew, showBR, curEdiff)
      obj.setValue(unitRankText)
    }
  }
}

function update_slotbar_crew(handler, unitSlots = null)
{
  unitSlots = unitSlots || ::get_slotbar_unit_slots(handler)

  foreach (slot in unitSlots)
  {
    slot.obj["crewStatus"] = ::get_crew_status(slot.crew)

    local obj = slot.obj.findObject("crew_level")
    if (::checkObj(obj))
    {
      local crewLevelText = slot.unit ? ::g_crew.getCrewLevel(slot.crew, ::get_es_unit_type(slot.unit)).tointeger().tostring() : ""
      obj.setValue(crewLevelText)
    }

    local obj = slot.obj.findObject("crew_spec")
    if (::checkObj(obj))
    {
      local crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(slot.crew, slot.unit).trainedIcon
      obj["background-image"] = crewSpecIcon
    }
  }
}

function getSlotbarTags(handler)
{
  local tags = null
  if (handler && ("slotbarCheckTags" in handler) && handler.slotbarCheckTags)
    tags = ::aircrafts_filter_tags

  return tags
}

function destroy_slotbar(handler)
{
  if (::checkObj(handler.slotbarScene))
  {
    local obj = handler.slotbarScene.findObject("nav-slotbar")
    if (::checkObj(obj))
      obj.getScene().replaceContentFromText(obj, "", 0, handler)
  }

  handler.slotbarScene = null
  handler.activeSlotbar = false
  handler.slotbarCountry = null
  handler.slotbarParams = null
}

function get_slotbar_box_of_airs(slotbarScene, curSlotCountryId)
{
  local obj = slotbarScene.findObject("airs_table_" + curSlotCountryId)
  if (!::checkObj(obj))
    return null

  local box = ::GuiBox().setFromDaguiObj(obj)
  local pBox = ::GuiBox().setFromDaguiObj(obj.getParent())
  if (box.c2[0] > pBox.c2[0])
    box.c2[0] = pBox.c2[0] + pBox.c1[0] - box.c1[0]
  return box
}

function getBrokenSlotsCount(country)
{
  local count = 0
  foreach(c in ::crews_list)
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

function checkSlotbarUpdater(slotbarObj, handler, country)
{
  local brokenCount = ::getBrokenSlotsCount(country)
  if (!brokenCount)
    return

  local timerObj = slotbarObj.findObject("slotbar_timer")
  if (timerObj)
    ::secondsUpdater(timerObj, (@(handler, country, brokenCount) function(obj, params) {
      if (brokenCount!=::getBrokenSlotsCount(country))
      {
        if (handler)
          obj.getScene().performDelayed(handler, handler.reinitSlotbar)
        return true //remove timer
      }
    })(handler, country, brokenCount))
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
  if ((countryId in ::crews_list) && ("crews" in ::crews_list[countryId])
      && (idInCountry in ::crews_list[countryId].crews))
    return ::crews_list[countryId].crews[idInCountry]
  return null
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
  foreach(cId, cList in ::crews_list)
    if ("crews" in cList)
      foreach(idx, crew in cList.crews)
       if (crew.id==id)
       {
         crew.country <- cList.country
         crew.countryId <- cId
         return crew
       }
  return null
}

function get_country_crews(country, needRefreshCrews = false)
{
  if (needRefreshCrews)
    ::crews_list <- ::get_crew_info()
  foreach(countryData in ::crews_list)
    if (countryData.country == country)
      return countryData.crews
  return []
}

function getCrewByAir(air)
{
  foreach(country in ::crews_list)
    if (country.country == air.shopCountry)
      foreach(crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft==air.name)
          return crew
  return null
}

function getCrewIdTblByAir(air)
{
  foreach(countryId, country in ::crews_list)
    if (country.country == air.shopCountry)
      foreach(idInCountry, crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft==air.name)
          return { crewId = crew.id, countryId = countryId, idInCountry = idInCountry }
  return null
}

function isUnitInSlotbar(air)
{
  return ::getCrewByAir(air) != null
}

function getSlotbarUnitTypes(country)
{
  local res = []
  foreach(countryData in ::crews_list)
    if (countryData.country == country)
      foreach(crew in countryData.crews)
        if (("aircraft" in crew) && crew.aircraft != "")
        {
          local unit = ::getAircraftByName(crew.aircraft)
          if (unit)
            ::append_once(::get_es_unit_type(unit), res)
        }
  return res
}

function get_crews_list_by_country(country, forceUpdate = false)
{
  if (forceUpdate)
    ::crews_list = ::get_crew_info()
  foreach(countryData in ::crews_list)
    if (countryData.country == country)
      return countryData.crews
  return []
}

function getAvailableCrewId(countryId)
{
  local id=-1
  local curAircraft = ::get_show_aircraft_name()
  if ((countryId in ::crews_list) && ("crews" in ::crews_list[countryId]))
    for(local i=0; i<::crews_list[countryId].crews.len(); i++)
    {
      local crew = ::crews_list[countryId].crews[i]
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
  if ((countryId in ::crews_list) && (countryId in ::selected_crews))
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
  foreach(cIdx, country in ::crews_list)
    blk[country.country] = ::getTblValue(cIdx, ::selected_crews, 0)
  ::saveLocalByAccount("selected_crews", blk)
}

function init_selected_crews(forceReload = false)
{
  if (!forceReload && (!::crews_list.len() || ::selected_crews.len() == ::crews_list.len()))
    return

  ::crews_list = get_crew_info()
  local selCrewsBlk = ::loadLocalByAccount("selected_crews", null)
  local needSave = false

  ::selected_crews = array(::crews_list.len(), 0)
  foreach(cIdx, country in ::crews_list)
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
  foreach(cIdx, c in ::crews_list)
    if (c.country == country)
      return getSlotAircraft(cIdx, ::selected_crews[cIdx])
  return null
}

function get_cur_slotbar_unit()
{
  return getSelAircraftByCountry(::get_profile_info().country)
}

function get_cur_available_slotbar_unit(handler)
{
  local unit = get_cur_slotbar_unit()
  if (!handler || !handler.slotbarParams || ::is_unit_enabled_for_slotbar(unit, handler.slotbarParams))
    return unit

  local country = ::get_profile_info().country
  foreach(cIdx, c in ::crews_list)
    if (c.country == country)
      foreach(crew in c.crews)
      {
        local unitName = ::getTblValue("aircraft", crew, "")
        if (unitName == "")
          continue

        local unit = getAircraftByName(unitName)
        if (::is_unit_enabled_for_slotbar(unit, handler.slotbarParams))
          return unit
      }
  return null
}

function is_unit_enabled_for_slotbar(unit, params)
{
  if (!unit)
    return false

  local res = true
  if ("eventId" in params)
  {
    res = false
    local event = ::events.getEvent(params.eventId)
    if (event)
      res = ::events.isUnitAllowedForEventRoom(event, ::getTblValue("room", params), unit)
  }
  else if ("availableUnits" in params)
    res = unit.name in params.availableUnits
  else if (::SessionLobby.isInRoom() && !::is_in_flight())
    res = ::SessionLobby.isUnitAllowed(unit)
  else if ("roomCreationContext" in params)
    res = params.roomCreationContext.isUnitAllowed(unit)

  if (res && "mainMenuSlotbar" in params)
    res = ::game_mode_manager.isUnitAllowedForGameMode(unit)

  if (res && "missionRules" in params)
    res = params.missionRules.getUnitLeftRespawns(unit) != 0

  return res
}

function getSelSlotsTable()
{
  init_selected_crews()
  local slots = {}
  foreach(cIdx, country in ::crews_list)
  {
    local air = getSlotAircraft(cIdx, ::selected_crews[cIdx])
    if (!air)
    {
      dagor.debug("selected crews = ")
      debugTableData(::selected_crews)
      dagor.debug("crews list = ")
      debugTableData(::crews_list)
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
  foreach(cIdx, country in ::crews_list)
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

  local mainObj = slotbarObj.findObject("autorefill-settings")
  if (!::checkObj(mainObj))
    return

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

function nextSlotbarAir(scene, countryId, way)
{
  if (!::checkObj(scene))
    return
  local slotbarObj = ::get_slotbar_obj(null, scene)
  local tblObj = slotbarObj && slotbarObj.findObject("airs_table_"+countryId)
  if (!::checkObj(tblObj)) return
  ::gui_bhv.columnNavigator.selectColumn.call(::gui_bhv.columnNavigator, tblObj, way)
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
  foreach(c in ::crews_list)
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
  if (::is_need_first_country_choice())
    return

  local unlockAll = ::isDiffUnlocked(1, ::ES_UNIT_TYPE_AIRCRAFT) || ::disable_network() || ::has_feature("UnlockAllCountries")
  local curUnlocked = []
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
  ::secondsUpdater(listObj, (@(needTimerList, air, handler) function(obj, params) {
    foreach(name in needTimerList)
    {
      local btnObj = obj.findObject("slot_action_" + name)
      if (!::checkObj(btnObj))
        continue

      if (name == "repair")
      {
        local repairCost = ::wp_get_repair_cost(air.name)
        local text = ::getPriceText(repairCost, 0, false)
        btnObj.setValue(format(::loc("mainmenu/btnRepairNow"), text))

        local taObj = btnObj.findObject("textarea")
        if (::checkObj(taObj))
        {
          local text = ::getPriceText(repairCost, 0, true)
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
  foreach(country in ::crews_list)
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
