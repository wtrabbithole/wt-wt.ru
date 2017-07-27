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
  getTooltipId = function(id, p1 = null, p2 = null, p3 = null)
  {
    return _buildId(id)
  }

  getTooltipContent = function(id, params) { return "" }
  isCustomTooltipFill = false //if true, need to use fillTooltip instead of getTooltipContent
  fillTooltip = function(obj, handler, id, params) //return isSucceed
  {
    return false
  }
}

::g_enum_utils.addTypesByGlobalName("g_tooltip_type", {
  EMPTY = {
  }

  UNLOCK = { //tooltip by unlock name
    getTooltipId = function(id, params = null, p2 = null, p3 = null)
    {
      return _buildId(id, params)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params)
    {
      if (!::checkObj(obj))
        return false

      local stage = ::getTblValue("stage", params, -1)
      local showProgress = ::getTblValue("showProgress", params, false)

      local config = ::build_log_unlock_data({ id = unlockId, stage = stage }, showProgress)
      if (config.type == -1)
        return false

      ::build_unlock_tooltip_by_config(obj, config, handler)
      return true
    }
  }

  DECORATION = { //tooltip by decoration id and decoration type
                 //@decorType = UNLOCKABLE_DECAL or UNLOCKABLE_SKIN
                 //can be without exist unlock
                 //for skins decorId is like skin unlock id   -  <unitName>"/"<skinName>
    getTooltipId = function(decorId, decorType, ...)
    {
      return _buildId(decorId, { decorType = decorType })
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

      local unlockId = ::getTblValue("unlockId", decorator)
      local img = decoratorType.getImage(decorator)
      local imgRatio = decoratorType.getRatio(decorator)
      local header = decorator.getName()
      local desc = decorator.getDesc()
      local isAllowed = decoratorType.isPlayerHaveDecorator(id)

      local config = null
      local unlockBlk = g_unlocks.getUnlockById(unlockId)
      if (unlockBlk)
      {
        config = ::build_conditions_config(unlockBlk)
        ::build_unlock_desc(config)
      }

      obj.getScene().replaceContent(obj, "gui/decalTooltip.blk", handler)

      local iObj = obj.findObject("image")
      iObj["background-image"] = img

      if (img != "")
      {
        local iDivObj = iObj.getParent()
        iDivObj.height = ::format("%d*@decalIconHeight", ((imgRatio < 3) ? 2 : 1))
        iDivObj.width  = imgRatio + "h"
        iDivObj.show(true)
      }

      obj.findObject("header").setValue(header)

      if (::getTblValue("isRevenueShare", config))
        desc += (desc.len() ? "\n" : "") + ::colorize("advertTextColor", ::loc("content/revenue_share"))
      obj.findObject("description").setValue(desc)

      local canBuy = false
      if (!isAllowed)
      {
        local cost = decorator.getCost()
        if (!cost.isZero())
        {
          canBuy = true
          local aObj = ::showBtn("price", true, obj)
          if (::checkObj(aObj))
            aObj.setValue(::loc("ugm/price") + ::loc("ui/colon") + ::colorize("white", cost.getTextAccordingToBalance()))
        }
      }

      /*
      //is decal acces text really need here? it very custom by chosen unit.
      //and why we dont have same texts for skins?
      local decalAccess = (type == ::UNLOCKABLE_DECAL) ? getDecalAccessData(id) : ""
      if (decalAccess != "")
      {
        local aObj = obj.findObject("rectriction")
        aObj.setValue("<color=@badTextColor>" + decalAccess + "</color>")
        aObj.show(true)
      }
      */

      //fill unlock info
      local cObj = obj.findObject("conditions")
      cObj.show(true)

      local conditionsText = config ? ::UnlockConditions.getConditionsText(config.conditions, config.curVal, config.maxVal) : ""
      local iconName = ""
      if (conditionsText == "")
      {
        if (isAllowed)
        {
          if (!::g_unlocks.isDefaultSkin(id))
          {
            iconName = "favorite"
            conditionsText = ::loc("shop/unit_bought")
          }
        }
        else if (canBuy)
          conditionsText = ::loc("shop/object/can_be_purchased")
        else
        {
          iconName = "locked"
          conditionsText = ::loc("multiplayer/notAvailable")
        }
      }
      else
        iconName = ::is_unlocked_scripted(unlockType, unlockId) ? "favorite" : "locked"

      local dObj = cObj.findObject("unlock_description")
      dObj.setValue(conditionsText)

      if (!isAllowed && config)
      {
        local progressData = config.getProgressBarData()
        if (progressData.show)
        {
          local pObj = cObj.findObject("progress")
          pObj.setValue(progressData.value)
          pObj.show(true)
        }
      }

      if (iconName != "")
        iconName = ::format("#ui/gameuiskin#%s", iconName)
      cObj.findObject("state")["background-image"] = iconName
      return true
    }
  }

  ITEM = { //by item name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, ...)
    {
      if (!::checkObj(obj))
        return false

      local item = ::ItemsManager.findItemById(itemName)
      if (!item)
        return false

      local preferMarkup = item.iType == itemType.TROPHY
      obj.getScene().replaceContent(obj, "gui/items/itemTooltip.blk", handler)
      ::ItemsManager.fillItemDescr(item, obj, handler, false, preferMarkup)
      return true
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

      local preferMarkup = item.iType == itemType.TROPHY
      obj.getScene().replaceContent(obj, "gui/items/itemTooltip.blk", handler)
      ::ItemsManager.fillItemDescr(item, obj, handler, false, preferMarkup)
      return true
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
    getTooltipId = function(id, params = null, p2 = null, p3 = null)
    {
      return _buildId(id, params)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      if (!::checkObj(obj))
        return false
      local unit = getAircraftByName(id)
      if (!unit)
        return false

      obj.getScene().replaceContent(obj, "gui/airTooltip.blk", handler)
      local contentObj = obj.findObject("air_info_tooltip")
      ::showAirInfo(unit, true, contentObj, handler, params)
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
      local mod = ::getModificationByName(unit, modName, true)
      if (!mod)
        return false

      ::weaponVisual.updateModType(unit, mod)
      ::weaponVisual.updateWeaponTooltip(obj, unit, mod, handler, params)
      return true
    }
  }

  WEAPON = { //by unitName, weaponName
    getTooltipId = function(unitName, weaponName = "", p2 = null, p3 = null)
    {
      return _buildId(unitName, { weaponName = weaponName })
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
      local weapon = ::u.search(unit.weapons, (@(weaponName) function(w) { return w.name == weaponName })(weaponName))
      if (!weapon)
        return false

      ::weaponVisual.updateWeaponTooltip(obj, unit, weapon, handler)
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

      ::weaponVisual.updateSpareType(spare)
      ::weaponVisual.updateWeaponTooltip(obj, unit, spare, handler)
      return true
    }
  }

  SKILL_CATEGORY = { //by categoryName, unitTypeName
    getTooltipId = function(categoryName, unitTypeName = "", p2 = null, p3 = null)
    {
      return _buildId(categoryName, { unitTypeName = unitTypeName })
    }
    getTooltipContent = function(categoryName, params)
    {
      local unitTypeName = ::getTblValue("unitTypeName", params, "")
      local unitType = ::getUnitTypeByText(unitTypeName)
      local skillCategory = ::g_crew_skills.getSkillCategoryByName(categoryName)
      local crewCountryId = ::find_in_array(::shopCountriesList, ::get_profile_info().country, -1)
      local crewIdInCountry = ::getTblValue(crewCountryId, ::selected_crews, -1)
      local crewData = ::getSlotItem(crewCountryId, crewIdInCountry)
      if (skillCategory != null && unitType != ::ES_UNIT_TYPE_INVALID && crewData != null)
        return ::g_crew_skills.getSkillCategoryTooltipContent(skillCategory, unitType, crewData)
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
      if (!crew || !unit)
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
      if (!crew || !unit)
        return ""

      local specType = ::g_crew_spec_type.getTypeByCode(::getTblValue("specTypeCode", params, -1))
      if (specType == ::g_crew_spec_type.UNKNOWN)
        specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit).getNextType()
      if (specType == ::g_crew_spec_type.UNKNOWN)
        return ""

      return specType.getBtnBuyTooltipContent(crew, unit)
    }
  }

  WW_MAP_TOOLTIP_TYPE_ARMY = { //by crewId, unitName, specTypeCode
    getTooltipId = function(id, params)
    {
      return _buildId(id, params)
    }

    getTooltipContent = function(id, params)
    {
      if (!::is_worldwar_enabled())
        return false

      local army = ::g_world_war.getArmyByName(params.armyName)
      if (army)
        return ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfo", army.getView())
      return ""
    }
  }

  WW_MAP_TOOLTIP_TYPE_BATTLE = {
    getTooltipId = function(id, params)
    {
      return _buildId(id, params)
    }

    getTooltipContent = function(id, params)
    {
      if (!::is_worldwar_enabled())
        return ""

      local battle = ::g_world_war.getBattleById(params.battleName)
      if (!battle.isValid())
        return ""

      local view = battle.getView()
      view.defineTeamBlock()
      view.showBattleStatus = true
      view.hideDesc = true
      return ::handyman.renderCached("gui/worldWar/battleDescription", view)
    }
  }

  WW_MAP_TOOLTIP_TYPE_GROUP = {
    getTooltipId = function(id, params)
    {
      return _buildId(id, params)
    }

    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params)
    {
      if (!::is_worldwar_enabled())
        return false

      local group = ::u.search(::g_world_war.getArmyGroups(), (@(id) function(group) { return group.clanId == id})(id))
      if (!group)
        return false

      local clanId = group.clanId
      local clanTag = group.name

      if (::is_in_clan() &&
          (::clan_get_my_clan_id() == clanId
          || ::clan_get_my_clan_tag() == clanTag)
         )
      {
        ::getMyClanData()
        if (!::my_clan_info)
          return false

        local clanInfo = ::my_clan_info
        local content = ::handyman.renderCached("gui/worldWar/worldWarClanTooltip", clanInfo)
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
        return
      }

      local taskId = ::clan_request_info(clanId, "", "")
      local onTaskSuccess = (@(obj, handler) function() {
        local clanInfo = ::get_clan_info_table()
        if (!clanInfo)
          return

        local content = ::handyman.renderCached("gui/worldWar/worldWarClanTooltip", clanInfo)
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      })(obj, handler)

      local onTaskError = (@(obj, handler) function(error) {
        local content = ::handyman.renderCached("gui/commonParts/errorFrame", {errorNum = error})
        obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
      })(obj, handler)
      ::g_tasker.addTask(taskId, {showProgressBox = false}, onTaskSuccess, onTaskError)
    }
  }
}, null, "typeName")

function g_tooltip_type::getTypeByName(typeName)
{
  local res = ::getTblValue(typeName, ::g_tooltip_type)
  return ::u.isTable(res) ? res : EMPTY
}
