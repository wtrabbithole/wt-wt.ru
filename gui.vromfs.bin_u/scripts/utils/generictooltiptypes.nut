local enums = require("sqStdLibs/helpers/enums.nut")
local workshop = require("scripts/items/workshop/workshop.nut")
local { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")
local { getSkillCategoryByName } = require("scripts/crew/crewSkills.nut")
local { getSkillCategoryTooltipContent } = require("scripts/crew/crewSkillsView.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local { getModificationByName } = require("scripts/weaponry/modificationInfo.nut")
local { getFakeBulletsModByName } = require("scripts/weaponry/bulletsInfo.nut")
local { updateModType,
        getTierDescTbl,
        updateSpareType,
        updateWeaponTooltip } = require("scripts/weaponry/weaponryVisual.nut")
local { updateDecoratorDescription } = require("scripts/customization/decoratorDescription.nut")
local { curSeasonChallengesByStage, getChallengeView } = require("scripts/battlePass/challenges.nut")

::g_tooltip_type <- {
  types = []
}

::g_tooltip_type.template <- {
  typeName = "" //added automatically by type name

  _buildId = function(id, params = null)
  {
    local t = params ? clone params : {}
    t.ttype <- typeName
    t.id    <- id
    return ::save_to_json(t)
  }
  //full params list depend on specific type
  getTooltipId = function(id, params = null, p2 = null, p3 = null)
  {
    return _buildId(id, params)
  }
  getMarkup = @(id, params = null, p2 = null, p3 = null)
    format(@"title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='%s'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }",
      getTooltipId(id, params, p2, p3))

  getTooltipContent = function(id, params) { return "" }
  isCustomTooltipFill = false //if true, need to use fillTooltip instead of getTooltipContent
  fillTooltip = function(obj, handler, id, params) //return isSucceed
  {
    return false
  }
}

enums.addTypesByGlobalName("g_tooltip_type", {
  EMPTY = {
  }

  UNLOCK = { //tooltip by unlock name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params)
    {
      if (!::checkObj(obj))
        return false

      local config = ::build_log_unlock_data(params.__merge({ id = unlockId }))

      if (config.type == -1)
        return false

      ::build_unlock_tooltip_by_config(obj, config, handler)
      return true
    }
  }

  UNLOCK_SHORT = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params)
    {
      if (!::checkObj(obj))
        return false

      local config = null
      local stage = (params?.stage??-1).tointeger()
      local unlock = ::g_unlocks.getUnlockById(unlockId)
      if (unlock==null)
        return false
      config = ::build_conditions_config(unlock, stage)

      local isCompleted = ::is_unlocked(-1, unlockId)
      ::build_unlock_desc(config, {showProgress = !isCompleted, showCost = !isCompleted})
      local reward = ::g_unlock_view.getRewardText(config, stage)

      local header = ::loc(unlockId + "/name")
      local locId = config?.locId??""
      if (locId != "")
        header = ::get_locId_name(config)
      if (stage >= 0)
        header += " " + ::roman_numerals[stage + 1]

      obj.getScene().replaceContent(obj, "gui/unlocks/shortTooltip.blk", handler)
      obj.findObject("header").setValue(header)

      local dObj = obj.findObject("description")
      dObj.setValue(config.text)
      if (!isCompleted)
      {
        local pObj = obj.findObject("progress")
        local progressData = config.getProgressBarData()
        pObj.setValue(progressData.value)
        pObj.show(progressData.show)
      }
      else if(config.text != "")
        obj.findObject("challenge_complete").show(true)

      local rObj = ::showBtn("reward", reward != "", obj)
      rObj.setValue(reward)

      return true
    }
  }

  DECORATION = { //tooltip by decoration id and decoration type
                 //@decorType = UNLOCKABLE_DECAL or UNLOCKABLE_SKIN
                 //can be without exist unlock
                 //for skins decorId is like skin unlock id   -  <unitName>"/"<skinName>
    getTooltipId = function(decorId, decorType, params = null, p3 = null)
    {
      local p = params || {}
      p.decorType <- decorType
      return _buildId(decorId, p)
    }

    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      local unlockType = ::getTblValue("decorType", params, -1)
      local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
      if (decoratorType == ::g_decorator_type.UNKNOWN)
        return false

      local decorator = ::g_decorator.getDecorator(id, decoratorType)
      if (!decorator)
        return false

      obj.getScene().replaceContent(obj, "gui/customization/decalTooltip.blk", handler)

      updateDecoratorDescription(obj, handler, decoratorType, decorator, params)
      return true
    }
  }

  ITEM = { //by item name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, params = null)
    {
      if (!::checkObj(obj))
        return false

      local item = ::ItemsManager.findItemById(itemName)
      if (!item)
        return false

      if (params?.isDisguised || workshop.shouldDisguiseItem(item))
      {
        item = item.makeEmptyInventoryItem()
        item.setDisguise(true)
      }

      local preferMarkup = item.isPreferMarkupDescInTooltip
      obj.getScene().replaceContent(obj, "gui/items/itemTooltip.blk", handler)
      ::ItemsManager.fillItemDescr(item, obj, handler, false, preferMarkup,
        params.__update({ showOnlyCategoriesOfPrizes = true}))
      return true
    }
    onEventItemsShopUpdate = function(eventParams, obj, handler, id, params) {
      fillTooltip(obj, handler, id, params)
    }
  }

  INVENTORY = { //by inventory item uid
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemUid, ...)
    {
      if (!::checkObj(obj))
        return false

      local item = ::ItemsManager.findItemByUid(itemUid)
      if (!item)
        return false

      local preferMarkup = item.isPreferMarkupDescInTooltip
      obj.getScene().replaceContent(obj, "gui/items/itemTooltip.blk", handler)
      ::ItemsManager.fillItemDescr(item, obj, handler, false, preferMarkup,
        { showOnlyCategoriesOfPrizes = true })
      return true
    }
    onEventItemsShopUpdate = function(eventParams, obj, handler, id, params) {
      fillTooltip(obj, handler, id, params)
    }
  }

  SUBTROPHY = { //by item Name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, ...)
    {
      if (!::checkObj(obj))
        return false

      local item = ::ItemsManager.findItemById(itemName)
      if (!item)
        return false
      local data = item.getLongDescriptionMarkup()
      if (data == "")
        return false

      // Showing only trophy content, without title and icon.
      obj.width = "@itemInfoWidth"
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  UNIT = { //by unit name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      if (!::checkObj(obj))
        return false
      local unit = getAircraftByName(id)
      if (!unit)
        return false
      local guiScene = obj.getScene()
      guiScene.setUpdatesEnabled(false, false)
      guiScene.replaceContent(obj, "gui/airTooltip.blk", handler)
      local contentObj = obj.findObject("air_info_tooltip")
      ::showAirInfo(unit, true, contentObj, handler, params)
      guiScene.setUpdatesEnabled(true, true)

      if (obj.getSize()[1] < ::g_dagui_utils.toPixels(obj.getScene(), "1@rh"))
        return true
      local tooltipObj = obj.findObject("air_info_tooltip")
      if (!tooltipObj?.isValid())
        return true

      tooltipObj.height = "1@rh - 2@framePadding"
      local unitImgObj = tooltipObj.findObject("aircraft-image")
      if (unitImgObj?.isValid())
        unitImgObj.height = "fh"
      return true
    }
    onEventUnitModsRecount = function(eventParams, obj, handler, id, params) {
      if (id == ::getTblValue("name", ::getTblValue("unit", eventParams)))
        fillTooltip(obj, handler, id, params)
    }
    onEventSecondWeaponModsUpdated = function(eventParams, obj, handler, id, params) {
      if (id == ::getTblValue("name", ::getTblValue("unit", eventParams)))
        fillTooltip(obj, handler, id, params)
    }
  }

  UNIT_GROUP = {
    isCustomTooltipFill = true
    getTooltipId = function(group, params=null)
    {
      return _buildId({units = group?.units.keys(), name = group?.name}, params)
    }
    fillTooltip = function(obj, handler, group, params)
    {
      if (!::checkObj(obj))
        return false

      local name = ::loc("ui/quotes", {text = ::loc(group.name)})
      local list = []
      foreach(str in group.units)
      {
        local unit = getAircraftByName(str)
        if (!unit)
          continue

        list.append({
          unitName = ::getUnitName(str)
          icon = ::getUnitClassIco(str)
          shopItemType = getUnitRole(unit)
        })
      }

      local columns = []
      local unitsInArmyRowsMax = ::max(::floor(list.len() / 2).tointeger(), 3)
      local hasMultipleColumns = list.len() > unitsInArmyRowsMax
      if (!hasMultipleColumns)
        columns.append({ groupList = list })
      else
      {
        columns.append({ groupList = list.slice(0, unitsInArmyRowsMax), isFirst = true })
        columns.append({ groupList = list.slice(unitsInArmyRowsMax) })
      }

      local data = ::handyman.renderCached("gui/tooltips/unitGroupTooltip", {
        title = $"{::loc("unitsGroup/groupContains", { name = name})}{::loc("ui/colon")}",
        hasMultipleColumns = hasMultipleColumns,
        columns = columns
      })
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  RANDOM_UNIT = { //by unit name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      if (!::checkObj(obj))
        return false
      local groupName = params?.groupName
      local missionRules = ::g_mis_custom_state.getCurMissionRules()
      if (!groupName || !missionRules)
        return false

      local unitsList = missionRules.getRandomUnitsList(groupName)
      local unitsView = []
      local unit
      foreach (unitName in unitsList)
      {
        unit = ::getAircraftByName(unitName)
        if (!unit)
          unitsView.append({name = unitName})
        else
          unitsView.append({
            name = ::getUnitName(unit)
            unitClassIcon = ::getUnitClassIco(unit.name)
            shopItemType = getUnitRole(unit)
            tooltipId = ::g_tooltip.getIdUnit(unit.name, { needShopInfo = true })
          })
      }

      local tooltipParams = {
        groupName = ::loc("respawn/randomUnitsGroup/description",
          {groupName = ::colorize("activeTextColor", missionRules.getRandomUnitsGroupLocName(groupName))})
        rankGroup = ::loc("shop/age") + ::loc("ui/colon") +
          ::colorize("activeTextColor", missionRules.getRandomUnitsGroupLocRank(groupName))
        battleRatingGroup = ::loc("shop/battle_rating") + ::loc("ui/colon") +
          ::colorize("activeTextColor", missionRules.getRandomUnitsGroupLocBattleRating(groupName))
        units = unitsView
      }
      local data = ::handyman.renderCached("gui/tooltips/randomUnitTooltip", tooltipParams)

      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  MODIFICATION = { //by unitName, modName
    getTooltipId = function(unitName, modName = "", params = null, p3 = null)
    {
      local p = params ? clone params : {}
      p.modName <- modName
      return _buildId(unitName, p)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params)
    {
      if (!::checkObj(obj))
        return false

      local unit = getAircraftByName(unitName)
      if (!unit)
        return false

      local modName = ::getTblValue("modName", params, "")
      local mod = getModificationByName(unit, modName) ?? getFakeBulletsModByName(unit, modName)
      if (!mod)
        return false

      updateModType(unit, mod)
      updateWeaponTooltip(obj, unit, mod, handler, params)
      return true
    }
  }

  WEAPON = { //by unitName, weaponName
    getTooltipId = function(unitName, weaponName = "", params = null, p3 = null)
    {
      local p = params ? clone params : {}
      p.weaponName <- weaponName
      return _buildId(unitName, p)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params)
    {
      if (!::checkObj(obj))
        return false

      local unit = getAircraftByName(unitName)
      if (!unit)
        return false

      local weaponName = ::getTblValue("weaponName", params, "")
      local hasPlayerInfo = params?.hasPlayerInfo ?? true
      local effect = hasPlayerInfo ? null : {}
      local weapon = ::u.search(unit.weapons, (@(weaponName) function(w) { return w.name == weaponName })(weaponName))
      if (!weapon)
        return false

      updateWeaponTooltip(obj, unit, weapon, handler, {
        hasPlayerInfo = hasPlayerInfo
        weaponsFilterFunc = params?.weaponBlkPath ? (@(path, blk) path == params.weaponBlkPath) : null
      }, effect)
      return true
    }
  }

  SPARE = { //by unit name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, ...)
    {
      if (!::checkObj(obj))
        return false

      local unit = getAircraftByName(unitName)
      local spare = ::getTblValue("spare", unit)
      if (!spare)
        return false

      updateSpareType(spare)
      updateWeaponTooltip(obj, unit, spare, handler)
      return true
    }
  }

  SKILL_CATEGORY = { //by categoryName, unitTypeName
    getTooltipId = function(categoryName, unitName = "", p2 = null, p3 = null)
    {
      return _buildId(categoryName, { unitName = unitName })
    }
    getTooltipContent = function(categoryName, params)
    {
      local unit = ::getAircraftByName(params?.unitName ?? "")
      local crewUnitType = (unit?.unitType ?? unitTypes.INVALID).crewUnitType
      local skillCategory = getSkillCategoryByName(categoryName)
      local crewCountryId = ::find_in_array(::shopCountriesList, ::get_profile_country_sq(), -1)
      local crewIdInCountry = ::getTblValue(crewCountryId, ::selected_crews, -1)
      local crewData = ::getSlotItem(crewCountryId, crewIdInCountry)
      if (skillCategory != null && crewUnitType != ::CUT_INVALID && crewData != null)
        return getSkillCategoryTooltipContent(skillCategory, crewUnitType, crewData, unit)
      return ""
    }
  }

  CREW_SPECIALIZATION = { //by crewId, unitName, specTypeCode
    getTooltipId = function(crewId, unitName = "", specTypeCode = -1, p3 = null)
    {
      return _buildId(crewId, { unitName = unitName, specTypeCode = specTypeCode })
    }
    getTooltipContent = function(crewIdStr, params)
    {
      local crew = ::get_crew_by_id(::to_integer_safe(crewIdStr, -1))
      local unit = ::getAircraftByName(::getTblValue("unitName", params, ""))
      if (!unit)
        return ""

      local specType = ::g_crew_spec_type.getTypeByCode(::getTblValue("specTypeCode", params, -1))
      if (specType == ::g_crew_spec_type.UNKNOWN)
        specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
      if (specType == ::g_crew_spec_type.UNKNOWN)
        return ""

      return specType.getTooltipContent(crew, unit)
    }
  }

  BUY_CREW_SPEC = { //by crewId, unitName, specTypeCode
    getTooltipId = function(crewId, unitName = "", specTypeCode = -1, p3 = null)
    {
      return _buildId(crewId, { unitName = unitName, specTypeCode = specTypeCode })
    }
    getTooltipContent = function(crewIdStr, params)
    {
      local crew = ::get_crew_by_id(::to_integer_safe(crewIdStr, -1))
      local unit = ::getAircraftByName(::getTblValue("unitName", params, ""))
      if (!unit)
        return ""

      local specType = ::g_crew_spec_type.getTypeByCode(::getTblValue("specTypeCode", params, -1))
      if (specType == ::g_crew_spec_type.UNKNOWN)
        specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit).getNextType()
      if (specType == ::g_crew_spec_type.UNKNOWN)
        return ""

      return specType.getBtnBuyTooltipContent(crew, unit)
    }
  }

  SPECIAL_TASK = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      if (!::check_obj(obj))
        return false

      local warbond = ::g_warbonds.findWarbond(
        ::getTblValue("wbId", params),
        ::getTblValue("wbListId", params)
      )
      local award = warbond? warbond.getAwardById(id) : null
      if (!award)
        return false

      local guiScene = obj.getScene()
      guiScene.replaceContent(obj, "gui/items/itemTooltip.blk", handler)
      if (award.fillItemDesc(obj, handler))
        return true

      obj.findObject("item_name").setValue(award.getNameText())
      obj.findObject("item_desc").setValue(award.getDescText())

      local imageData = award.getDescriptionImage()
      guiScene.replaceContentFromText(obj.findObject("item_icon"), imageData, imageData.len(), handler)
      return true
    }
  }

  BATTLE_TASK = {
    getTooltipContent = function(battleTaskId, params)
    {
      local battleTask = ::g_battle_tasks.getTaskById(battleTaskId)
      if (!battleTask)
        return ""

      local config = ::g_battle_tasks.generateUnlockConfigByTask(battleTask)
      local view = ::g_battle_tasks.generateItemView(config, { isOnlyInfo = true})
      return ::handyman.renderCached("gui/unlocks/battleTasksItem", {items = [view]})
    }
  }

  BATTLE_PASS_CALLENGE = {
    getTooltipContent = function(stage, params)
    {
      local challenge = curSeasonChallengesByStage.value?[stage]
      if (challenge == null)
        return ""

      return ::handyman.renderCached("gui/unlocks/battleTasksItem",
        { items = [getChallengeView(challenge, { isOnlyInfo = true })]})
    }
  }

  REWARD_TOOLTIP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params)
    {
      if (!::checkObj(obj))
        return false

      local unlockBlk = unlockId && unlockId != "" && ::g_unlocks.getUnlockById(unlockId)
      if(!unlockBlk)
        return false

      local config = build_conditions_config(unlockBlk)
      ::build_unlock_desc(config)
      local name = config.id
      local unlockType = config.unlockType
      local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
      local guiScene = obj.getScene()
      if (decoratorType == ::g_decorator_type.DECALS
          || decoratorType == ::g_decorator_type.ATTACHABLES
          || unlockType == ::UNLOCKABLE_MEDAL)
      {
        local bgImage = ::format("background-image:t='%s';", config.image)
        local size = ::format("size:t='128, 128/%f';", config.imgRatio)

        guiScene.appendWithBlk(obj, ::format("img{ %s }", bgImage + size), this)
      }
      else if (decoratorType == ::g_decorator_type.SKINS)
      {
        local unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(name))
        local text = []
        if (unit)
          text.append(::loc("reward/skin_for") + " " + ::getUnitName(unit))
        text.append(decoratorType.getLocDesc(name))

        text = ::locOrStrip(::g_string.implode(text, "\n"))
        local textBlock = "textareaNoTab {smallFont:t='yes'; max-width:t='0.5@sf'; text:t='%s';}"
        guiScene.appendWithBlk(obj, ::format(textBlock, text), this)
      }
      else
        return false

      return true
    }
  }

  TIER = {
    getTooltipId = @(unitName, weaponry, presetName, tierId)
      _buildId(unitName, {weaponry = weaponry, presetName = presetName , tierId = tierId})

    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params)
    {
      if (!::check_obj(obj))
        return false

      local unit = getAircraftByName(unitName)
      if (!unit)
        return false
      local data = ::handyman.renderCached(("gui/weaponry/weaponTooltip"),
        getTierDescTbl(unit, params.weaponry, params.presetName, params.tierId))
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)

      return true
    }
  }
}, null, "typeName")

g_tooltip_type.addTooltipType <- function addTooltipType(tTypes)
{
  enums.addTypesByGlobalName("g_tooltip_type", tTypes, null, "typeName")
}

g_tooltip_type.getTypeByName <- function getTypeByName(typeName)
{
  local res = ::getTblValue(typeName, ::g_tooltip_type)
  return ::u.isTable(res) ? res : EMPTY
}
