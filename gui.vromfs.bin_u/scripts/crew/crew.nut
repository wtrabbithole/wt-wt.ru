const UPGR_CREW_TUTORIAL_SKILL_NUMBER = 2

::g_crew <- {
  crewLevelBySkill = 5 //crew level from any maxed out skill
  totalSkillsSteps = 5 //steps available for leveling.
  minCrewLevel = {
    [::CUT_AIRCRAFT] = 1.5,
    [::CUT_TANK] = 1,
    [::CUT_SHIP] = 1
  }
  maxCrewLevel = {
    [::CUT_AIRCRAFT] = 75,
    [::CUT_TANK] = 150,
    [::CUT_SHIP] = 100
  }
}

function g_crew::isAllCrewsMinLevel()
{
  foreach (checkedCountrys in ::g_crews_list.get())
    foreach (crew in checkedCountrys.crews)
      foreach (unitType in ::g_unit_type.types)
        if (unitType.isAvailable()
            && ::g_crew.getCrewLevel(crew, unitType.crewUnitType) > ::g_crew.getMinCrewLevel(unitType.crewUnitType))
          return false

  return true
}

function g_crew::isAllCrewsHasBasicSpec()
{
  local basicCrewSpecType = ::g_crew_spec_type.BASIC
  foreach(checkedCountrys in ::g_crews_list.get())
    foreach(crew in checkedCountrys.crews)
      foreach(unitName, value in crew.trainedSpec)
      {
        local crewUnitSpecType = ::g_crew_spec_type.getTypeByCrewAndUnitName(crew, unitName)
        if (crewUnitSpecType != basicCrewSpecType)
          return false
      }

  return true
}

function g_crew::getMinCrewLevel(crewUnitType)
{
  return ::g_crew.minCrewLevel?[crewUnitType] ?? 0
}

function g_crew::getMaxCrewLevel(crewUnitType)
{
  return ::g_crew.maxCrewLevel?[crewUnitType] ?? 0
}

function g_crew::getDiscountInfo(countryId = -1, idInCountry = -1)
{
  if (countryId < 0 || idInCountry < 0)
    return {}

  local countrySlot = ::getTblValue(countryId, ::g_crews_list.get(), {})
  local crewSlot = "crews" in countrySlot && idInCountry in countrySlot.crews? countrySlot.crews[idInCountry] : {}

  local country = countrySlot.country
  local unitNames = ::getTblValue("trained", crewSlot, [])

  local buyPointsDiscount = 0
  local packNames = []
  local blk = ::get_warpoints_blk()
  if (blk.crewSkillPointsCost)
    foreach(block in blk.crewSkillPointsCost)
      packNames.append(block.getBlockName())

  local result = {}
  result.buyPoints <- ::getDiscountByPath(["skills", country, packNames], ::get_price_blk())
  foreach (type in ::g_crew_spec_type.types)
    if (type.hasPrevType())
      result[type.specName] <- type.getDiscountValueByUnitNames(unitNames)
  return result
}

function g_crew::getMaxDiscountByInfo(discountInfo, includeBuyPoints = true)
{
  local maxDiscount = 0
  foreach(name, discount in discountInfo)
    if (name != "buyPoints" || includeBuyPoints)
      maxDiscount = ::max(maxDiscount, discount)

  return maxDiscount
}

function g_crew::getDiscountsTooltipByInfo(discountInfo, showBuyPoints = true)
{
  local maxDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo, showBuyPoints).tostring()

  local numPositiveDiscounts = 0
  local positiveDiscountCrewSpecType = null
  foreach (type in ::g_crew_spec_type.types)
    if (type.hasPrevType() && discountInfo[type.specName] > 0)
    {
      ++numPositiveDiscounts
      positiveDiscountCrewSpecType = type
    }

  if (numPositiveDiscounts == 0)
  {
    if (showBuyPoints && discountInfo.buyPoints > 0)
      return ::format(::loc("discount/buyPoints/tooltip"), maxDiscount)
    else
      return ""
  }

  if (numPositiveDiscounts == 1)
    return positiveDiscountCrewSpecType.getDiscountTooltipByValue(maxDiscount)

  local table = {}
  foreach(type in ::g_crew_spec_type.types)
    if (type.hasPrevType())
      table[type.getNameLocId()] <- discountInfo[type.specName]

  if (showBuyPoints)
    table["mainmenu/btnBuySkillPoints"] <- discountInfo.buyPoints

  return ::g_discount.generateDiscountInfo(table, ::format(::loc("discount/specialization/tooltip"), maxDiscount)).discountTooltip
}

function g_crew::createCrewBuyPointsHandler(crew)
{
  local params = {
    crew = crew
  }
  return ::handlersManager.loadHandler(::gui_handlers.CrewBuyPointsHandler, params)
}

/**
 * This function is used both in CrewModalHandler,
 * CrewBuyPointsHandler and CrewUnitSpecHandler.
 */
function g_crew::getButtonRow(obj, scene, tblObj = null)
{
  if (tblObj == null)
    tblObj = scene.findObject("skills_table")
  local curRow = tblObj.getValue()
  local newRow = curRow
  if (obj)
  {
    local holderId = obj.holderId
    if (holderId)
      newRow = holderId.tointeger()
    else
    {
      local pObj = obj.getParent()
      if (pObj)
      {
        local row = pObj.id.tointeger()
        if (row >= 0)
          newRow = row
      }
    }
  }
  if (newRow < 0 || newRow >= tblObj.childrenCount())
    newRow = 0
  if (curRow != newRow)
  {
    curRow = newRow
    tblObj.setValue(curRow)
    ::selectTableNavigatorObj(tblObj)
  }
  return curRow
}

function g_crew::createCrewUnitSpecHandler(containerObj)
{
  local scene = containerObj.findObject("specs_table")
  if (!::checkObj(scene))
    return null
  local params = {
    scene = scene
  }
  return ::handlersManager.loadHandler(::gui_handlers.CrewUnitSpecHandler, params)
}

//crewUnitType == -1 - all unitTypes
function g_crew::isCrewMaxLevel(crew, country, crewUnitType = -1)
{
  foreach(page in ::crew_skills)
  {
    if (crewUnitType >= 0 && !page.isVisible(crewUnitType))
      continue

    foreach(skillItem in page.items)
      if ((crewUnitType < 0 || skillItem.isVisible(crewUnitType))
          && ::is_country_has_any_es_unit_type(country,
            ::g_unit_type.getEsUnitTypeMaskByCrewUnitTypeMask(skillItem.crewUnitTypeMask))
          && getMaxSkillValue(skillItem) > getSkillValue(crew.id, page.id, skillItem.name))
        return false
  }
  return true
}

function g_crew::getSkillItem(memberName, skillName)
{
  foreach(page in ::crew_skills)
    if (page.id == memberName)
    {
      foreach(skillItem in page.items)
        if (skillItem.name == skillName)
          return skillItem
      break
    }
  return null
}

function g_crew::getSkillValue(crewId, crewType, skillName)
{
  local path = ::format("%s.%s", crewType, skillName)
  local crewSkills = ::g_unit_crew_cache.getUnitCrewDataById(crewId)
  return ::getTblValueByPath(path, crewSkills, 0)
}

function g_crew::getSkillNewValue(skillItem, crew)
{
  local res = ::getTblValue("newValue", skillItem, null)
  if (res != null)
    return res
  return getSkillValue(crew.id, skillItem.memberName, skillItem.name)
}

function g_crew::createCrewSkillsPageHandler(containerObj, crewModalHandler, crew)
{
  local scene = containerObj.findObject("skills_table")
  if (!::checkObj(scene))
    return null
  local params = {
    scene = scene
    crewModalHandlerWeak = crewModalHandler
    crew = crew
  }
  return ::handlersManager.loadHandler(::gui_handlers.CrewSkillsPageHandler, params)
}

function g_crew::getSkillCost(skillItem, value, prevValue = -1)
{
  local cost = ::getTblValue(value - 1, skillItem.costTbl, 0)
  if (prevValue < 0)
    prevValue = value - 1
  local prevCost = ::getTblValue(prevValue - 1, skillItem.costTbl, 0)
  return cost - prevCost
}

function g_crew::getMaxSkillValue(skillItem)
{
  return skillItem.costTbl.len()
}

function g_crew::getSkillStepSize(skillItem)
{
  local maxSkill = getMaxSkillValue(skillItem)
  return ceil(maxSkill.tofloat() / getTotalSteps(skillItem)).tointeger() || 1
}

function g_crew::getTotalSteps(skillItem)
{
  return ::min(totalSkillsSteps, ::g_crew.getMaxSkillValue(skillItem) || 1)
}

function g_crew::getSkillMaxCrewLevel(skillItem)
{
  return crewLevelBySkill
}

function g_crew::skillValueToStep(skillItem, value)
{
  local step = getSkillStepSize(skillItem)
  return value.tointeger() / step
}

function g_crew::skillStepToValue(skillItem, curStep)
{
  return curStep * getSkillStepSize(skillItem)
}

function g_crew::getNextSkillStepValue(skillItem, curValue, increment = true, stepsAmount = 1)
{
  local step = getSkillStepSize(skillItem)
  if (!increment)
    return ::max(curValue - step * stepsAmount - (curValue % step), 0)

  local maxSkill = getMaxSkillValue(skillItem)
  return ::min(curValue + step * stepsAmount - (curValue % step), maxSkill)
}

function g_crew::getNextSkillStepCost(skillItem, curValue, stepsAmount = 1)
{
  local nextValue = getNextSkillStepValue(skillItem, curValue, true, stepsAmount)
  if (nextValue == curValue)
    return 0
  return getSkillCost(skillItem, nextValue, curValue)
}

function g_crew::getMaxAvailbleStepValue(skillItem, curValue, skillPoints)
{
  local maxValue = getMaxSkillValue(skillItem)
  local maxCost = skillPoints + getSkillCost(skillItem, curValue, 0)
  if (getSkillCost(skillItem, maxValue, 0) <= maxCost) //to correct work if maxValue % step != 0
    return maxValue

  local resValue = curValue
  local step = getSkillStepSize(skillItem)
  for(local i = getNextSkillStepValue(skillItem, curValue); i < maxValue; i += step)
    if (getSkillCost(skillItem, i, 0) <= maxCost)
      resValue = i
  return resValue
}

//crewUnitType == -1 - all unitTypes
//action = function(page, skillItem)
function g_crew::doWithAllSkills(crew, crewUnitType, action)
{
  local country = getCrewCountry(crew)
  foreach(page in ::crew_skills)
  {
    if (crewUnitType >= 0 && !page.isVisible(crewUnitType))
      continue

    foreach(skillItem in page.items)
      if ((crewUnitType < 0 || skillItem.isVisible(crewUnitType))
          && ::is_country_has_any_es_unit_type(country,
            ::g_unit_type.getEsUnitTypeMaskByCrewUnitTypeMask(skillItem.crewUnitTypeMask)))
        action(page, skillItem)
  }
}

//crewUnitType == -1 - all unitTypes
function g_crew::getSkillPointsToMaxAllSkills(crew, crewUnitType = -1)
{
  local res = 0
  doWithAllSkills(crew, crewUnitType,
    function(page, skillItem)
    {
      local maxValue = getMaxSkillValue(skillItem)
      local curValue = getSkillValue(crew.id, page.id, skillItem.name)
      if (curValue < maxValue)
        res += getSkillCost(skillItem, maxValue, curValue)
    }
  )
  return res
}

function g_crew::getCrewName(crew)
{
  local number =  ::getTblValue("idInCountry", crew, -1) + 1
  return ::loc("options/crewName") + number
}

function g_crew::getCrewUnit(crew)
{
  local unitName = ::getTblValue("aircraft", crew)
  if (!unitName || unitName == "")
    return null
  return ::getAircraftByName(unitName)
}

function g_crew::getCrewCountry(crew)
{
  local countryData = ::getTblValue(crew.idCountry, ::g_crews_list.get())
  return countryData ? countryData.country : ""
}

function g_crew::getCrewTrainCost(crew, unit)
{
  local res = ::Cost()
  if (!unit)
    return res
  if (crew)
    res.wp = ::get_training_cost(crew.id, unit.name).cost
  else
    res.wp = unit.trainCost
  return res
}

function g_crew::getCrewLevel(crew, crewUnitType, countByNewValues = false)
{
  ::load_crew_skills_once()

  local res = 0.0
  foreach(page in ::crew_skills)
    if (page.isVisible(crewUnitType))
      foreach(item in page.items)
      {
        if (!item.isVisible(crewUnitType))
          continue

        local skill = getSkillValue(crew.id, page.id, item.name)
        if (countByNewValues)
          skill = ::getTblValue("newValue", item, skill)
        res += getSkillCrewLevel(item, skill)
      }
  return res
}

function g_crew::getCrewSkillPoints(crew)
{
  return ::getTblValue("skillPoints", crew, 0)
}

function g_crew::getSkillCrewLevel(skillItem, newValue, prevValue = 0)
{
  local maxValue = getMaxSkillValue(skillItem)
  local level = (newValue.tofloat() - prevValue) / maxValue  * getSkillMaxCrewLevel(skillItem)
  return ::round_by_value(level, 0.01)
}

function g_crew::upgradeUnitSpec(crew, unit, crewUnitTypeToCheck = null, nextSpecType = null)
{
  if (!unit)
    return ::showInfoMsgBox(::loc("shop/aircraftNotSelected"))

  local curSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
  if (!curSpecType.hasNextType())
    return

  if (!nextSpecType)
    nextSpecType = curSpecType.getNextType()
  local upgradesAmount = nextSpecType.code - curSpecType.code
  if (upgradesAmount <= 0)
    return

  local unitTypeSkillsMsg = "<b>" + ::colorize("warningTextColor", ::loc("crew/qualifyOnlyForSameType")) + "</b>"

  local crewUnitType = unit.getCrewUnitType()
  local reqLevel = nextSpecType.getReqCrewLevel(unit)
  local crewLevel = getCrewLevel(crew, crewUnitType)

  local msgLocId = "shop/needMoneyQuestion_increaseQualify"
  local msgLocParams = {
    unitName = ::colorize("userlogColoredText", ::getUnitName(unit))
    wantedQualify = ::colorize("userlogColoredText", nextSpecType.getName())
    reqLevel = ::colorize("badTextColor", reqLevel)
  }

  if (reqLevel > crewLevel)
  {
    nextSpecType = curSpecType.getNextMaxAvailableType(unit, crewLevel)
    upgradesAmount = nextSpecType.code - curSpecType.code
    if (upgradesAmount <= 0)
    {
      local msgText = ::loc("crew/msg/qualifyRequirement", msgLocParams)
      if (crewUnitTypeToCheck != null && crewUnitType != crewUnitTypeToCheck)
        msgText += "\n" + unitTypeSkillsMsg
      ::showInfoMsgBox(msgText)
      return
    } else
    {
      msgLocId = "shop/ask/increaseLowerQualify"
      msgLocParams.targetQualify <- ::colorize("userlogColoredText", nextSpecType.getName())
    }
  }

  local cost = curSpecType.getUpgradeCostByCrewAndByUnit(crew, unit, nextSpecType.code)
  if (cost.gold > 0 && !::can_spend_gold_on_unit_with_popup(unit))
    return

  msgLocParams.cost <- ::colorize("activeTextColor", cost.tostring())

  if (cost.isZero())
    return _upgradeUnitSpec(crew, unit, upgradesAmount)

  local msgText = warningIfGold(
    ::loc(msgLocId, msgLocParams) + "\n\n"
      + ::loc("shop/crewQualifyBonuses",
        {qualification = ::colorize("userlogColoredText", nextSpecType.getName())
          bonuses = nextSpecType.getFullBonusesText(crewUnitType, curSpecType.code)})
      + "\n" + unitTypeSkillsMsg,
    cost)
  ::scene_msg_box("purchase_ask", null, msgText,
    [
      ["yes", (@(cost, crew, unit, upgradesAmount) function() {
                 if (::check_balance_msgBox(cost))
                   ::g_crew._upgradeUnitSpec(crew, unit, upgradesAmount)
               })(cost, crew, unit, upgradesAmount)
      ],
      ["no", function(){}]
    ],
    "yes",
    {
      cancel_fn = function() {}
      font = "fontNormal"
    }
  )
}

function g_crew::_upgradeUnitSpec(crew, unit, upgradesAmount = 1)
{
  local taskId = ::shop_specialize_crew(crew.id, unit.name)
  local progBox = { showProgressBox = true }
  upgradesAmount--
  local onTaskSuccess = (@(crew, unit, upgradesAmount) function() {
    ::updateAirAfterSwitchMod(unit)
    ::update_gamercards()
    ::broadcastEvent("QualificationIncreased", { unit = unit})

    if (upgradesAmount > 0)
      return ::g_crew._upgradeUnitSpec(crew, unit, upgradesAmount)
    if (::getTblValue("aircraft", crew) != unit.name)
      ::showInfoMsgBox(::format(::loc("msgbox/qualificationIncreased"), ::getUnitName(unit)))
  })(crew, unit, upgradesAmount)

  ::g_tasker.addTask(taskId, progBox, onTaskSuccess)
}

function g_crew::getBestTrainedCrewIdxForUnit(unit, mustBeEmpty, compareToCrew = null)
{
  if (!unit)
    return -1

  local crews = ::get_crews_list_by_country(unit.shopCountry)
  if (!crews.len())
    return -1

  local maxSpecCrewIdx = -1
  local maxSpecCode = -1

  if (compareToCrew)
  {
    maxSpecCrewIdx = ::getTblValue("idInCountry", compareToCrew, maxSpecCrewIdx)
    maxSpecCode = ::g_crew_spec_type.getTypeByCrewAndUnit(compareToCrew, unit).code
  }

  foreach(idx, crew in crews)
  {
    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    if (specType.code > maxSpecCode && (!mustBeEmpty || ::is_crew_slot_empty(crew)))
    {
      maxSpecCrewIdx = idx
      maxSpecCode = specType.code
    }
  }

  return maxSpecCrewIdx
}

function g_crew::onEventCrewSkillsChanged(params)
{
  if (!params?.isOnlyPointsChanged)
  {
    local unit = getCrewUnit(params.crew)
    if (unit)
      unit.invalidateModificators()
  }
  ::update_crew_skills_available(true)
}

function g_crew::purchaseNewSlot(country, onTaskSuccess, onTaskFail = null)
{
  local taskId = ::purchase_crew_slot(country)
  return ::g_tasker.addTask(taskId, { showProgressBox = true }, onTaskSuccess, onTaskFail)
}

function g_crew::buyAllSkills(crew, crewUnitType)
{
  local totalPointsToMax = getSkillPointsToMaxAllSkills(crew, crewUnitType)
  if (totalPointsToMax <= 0)
    return

  local curPoints = ::getTblValue("skillPoints", crew, 0)
  if (curPoints >= totalPointsToMax)
    return maximazeAllSkillsImpl(crew, crewUnitType)

  local packs = ::g_crew_points.getPacksToBuyAmount(getCrewCountry(crew), totalPointsToMax)
  if (!packs.len())
    return

  ::g_crew_points.buyPack(crew, packs, ::Callback(@() maximazeAllSkillsImpl(crew, crewUnitType), this))
}

function g_crew::maximazeAllSkillsImpl(crew, crewUnitType)
{
  local blk = ::DataBlock()
  doWithAllSkills(crew, crewUnitType,
    function(page, skillItem)
    {
      local maxValue = getMaxSkillValue(skillItem)
      local curValue = getSkillValue(crew.id, page.id, skillItem.name)
      if (maxValue > curValue)
        blk.addBlock(page.id)[skillItem.name] = maxValue - curValue
    }
  )

  local isTaskCreated = ::g_tasker.addTask(
    ::shop_upgrade_crew(crew.id, blk),
    { showProgressBox = true },
    function()
    {
      ::broadcastEvent("CrewSkillsChanged", { crew = crew })
      ::g_crews_list.flushSlotbarUpdate()
    },
    @(err) ::g_crews_list.flushSlotbarUpdate()
  )

  if (isTaskCreated)
    ::g_crews_list.suspendSlotbarUpdates()
}

function g_crew::getSkillPageIdToRunTutorial(crew)
{
  local unit = ::g_crew.getCrewUnit(crew)
  if (!unit)
    return null

  local crewUnitType = unit.getCrewUnitType()
  foreach(skillPage in ::crew_skills)
    if (skillPage.isVisible(crewUnitType))
      if (hasSkillPointsToRunTutorial(crew, crewUnitType, skillPage))
        return skillPage.id

  return null
}

function g_crew::hasSkillPointsToRunTutorial(crew, crewUnitType, skillPage)
{
  local skillCount = 0
  local skillPointsNeeded = 0
  foreach(idx, item in skillPage.items)
    if (item.isVisible(crewUnitType))
    {
      local itemSkillValue = getSkillValue(crew.id, skillPage.id, item.name)
      skillPointsNeeded += getNextSkillStepCost(item, itemSkillValue)
      skillCount ++
      if (skillCount >= UPGR_CREW_TUTORIAL_SKILL_NUMBER)
        break
    }

  if (skillCount < UPGR_CREW_TUTORIAL_SKILL_NUMBER)
    return false

  return getCrewSkillPoints(crew) >= skillPointsNeeded
}

::subscribe_handler(::g_crew, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)

::min_steps_for_crew_status <- [1, 2, 3]

::crew_skills <- []
::crew_air_train_req <- {} //[crewUnitType] = array
::crew_skills_available <- {}
::is_crew_skills_available_inited <- false
/*
  ::crew_skills <- [
    { id = "pilot"
      items = [{ name = eyesight, costTbl = [1, 5, 10]}, ...]
    }
  ]
*/

function load_crew_skills()
{
  ::crew_skills=[]
  ::crew_air_train_req <- {}

  local blk = ::get_skills_blk()
  ::g_crew.crewLevelBySkill = blk.skill_to_level_ratio || ::g_crew.crewLevelBySkill
  ::g_crew.totalSkillsSteps = blk.max_skill_level_steps || ::g_crew.totalSkillsSteps

  local dataBlk = blk.crew_skills
  if (dataBlk)
    foreach (pName, pageBlk in dataBlk)
    {
      local unitTypeTag = pageBlk.type || ""
      local defaultCrewUnitTypeMask = ::g_unit_type.getTypeMaskByTagsString(unitTypeTag, "; ", "bitCrewType")
      local page = {
        id = pName,
        crewUnitTypeMask = defaultCrewUnitTypeMask
        items = []
        isVisible = function(crewUnitType) { return (crewUnitTypeMask & (1 << crewUnitType)) != 0 }
      }
      foreach(sName, itemBlk in pageBlk)
      {
        if (!::u.isInstance(itemBlk))
          continue
        local item = {
          name = sName,
          memberName = page.id
          crewUnitTypeMask = ::g_unit_type.getTypeMaskByTagsString(itemBlk.type || "", "; ", "bitCrewType")
                         || defaultCrewUnitTypeMask
          costTbl = []
          isVisible = function(crewUnitType) { return (crewUnitTypeMask & (1 << crewUnitType)) != 0 }
        }
        page.crewUnitTypeMask = page.crewUnitTypeMask | item.crewUnitTypeMask

        local costBlk = itemBlk.skill_level_exp
        local idx = 1
        local totalCost = 0
        while(costBlk["level"+idx]!=null)
        {
          totalCost += costBlk["level"+idx]
          item.costTbl.append(totalCost)
          idx++
        }
        item.useSpecializations <- itemBlk.use_specializations || false
        item.useLeadership <- itemBlk.use_leadership || false
        page.items.append(item)
      }
      ::crew_skills.append(page)
    }

  ::broadcastEvent("CrewSkillsReloaded")

  local reqBlk = blk.train_req
  if (reqBlk == null)
    return

  foreach (type in ::g_unit_type.types)
  {
    if (!type.isAvailable() || ::crew_air_train_req?[type.crewUnitType] != null)
      continue

    local typeBlk = reqBlk[type.getCrewTag()]
    if (typeBlk == null)
      continue

    local trainReq = []
    local costBlk = null
    local tIdx = 0
    do
    {
      tIdx++
      costBlk = typeBlk["train"+tIdx]
      if (costBlk)
      {
        trainReq.append([])
        for(local idx=0; idx <= ::max_country_rank; idx++)
          trainReq[tIdx-1].append(costBlk["rank"+idx] || 0)
      }
    }
    while(costBlk!=null)

    ::crew_air_train_req[type.crewUnitType] <- trainReq
  }
}

function load_crew_skills_once()
{
  if (::crew_skills.len()==0)
    ::load_crew_skills()
}

function get_crew_skill_value(crew_skills, crew_type, skill_name)
{
  if (crew_skills && crew_skills[crew_type]
      && crew_skills[crew_type][skill_name]!=null)
      return crew_skills[crew_type][skill_name]
  return 0
}

function count_available_skills(crew, crewUnitType) //return part of availbleskills 0..1
{
  local curPoints = ("skillPoints" in crew)? crew.skillPoints : 0
  if (!curPoints)
    return 0.0

  local crewSkills = ::get_aircraft_crew_by_id(crew.id)
  local notMaxTotal = 0
  local available = [0, 0, 0]

  foreach(page in ::crew_skills)
    foreach(item in page.items)
    {
      if (!item.isVisible(crewUnitType))
        continue

      local totalSteps = ::g_crew.getTotalSteps(item)
      local value = ::get_crew_skill_value(crewSkills, page.id, item.name)
      local curStep = ::g_crew.skillValueToStep(item, value)
      if (curStep == totalSteps)
        continue

      notMaxTotal++
      foreach(idx, amount in ::min_steps_for_crew_status)
      {
        if (curStep + amount > totalSteps)
          continue

        if (::g_crew.getNextSkillStepCost(item, value, amount) <= curPoints)
          available[idx]++
      }
    }

  if (notMaxTotal==0)
    return 0

  for(local i=2; i>=0; i--)
    if (available[i] >= 0.5*notMaxTotal)
      return i+1
  return 0
}

function update_crew_skills_available(forceUpdate = false)
{
  if (::is_crew_skills_available_inited && !forceUpdate)
    return
  ::is_crew_skills_available_inited = true

  ::load_crew_skills_once()
  ::crew_skills_available = {}
  foreach(cList in ::g_crews_list.get())
    foreach(idx, crew in cList?.crews || [])
    {
      local data = {}
      foreach (unitType in ::g_unit_type.types)
      {
        local crewUnitType = unitType.crewUnitType
        if (!data?[crewUnitType])
          data[crewUnitType] <- ::count_available_skills(crew, crewUnitType)
      }
      ::crew_skills_available[crew.id] <- data
    }
}

function get_crew_status(crew)
{
  local status = ""
  if (::is_in_flight())
    return status
  foreach(id, data in ::crew_skills_available)
  {
    if (id != crew.id)
      continue
    if (!("aircraft" in crew))
      break
    local unit = ::getAircraftByName(crew.aircraft)
    if (!unit)
      break
    local crewUnitType = unit.getCrewUnitType()
    if (!(crewUnitType in data))
      break

    local res = data[crewUnitType]
    if (res==3) status = "full"
    else if (res==2) status = "ready"
    else if (res==1) status = "show"
    else status = ""
    break
  }
  return status
}

function get_crew_status_by_id(crew_id)
{
  local crewData = ::get_crew_by_id(crew_id)
  return crewData ? ::get_crew_status(crewData) : ""
}

function is_crew_slot_empty(crew)
{
  return ::getTblValue("aircraft", crew, "") == ""
}

function get_first_empty_crew_slot(country = null)
{
  if (!country)
    country = ::get_profile_country_sq()

  local crew = null
  foreach (idx, crewBlock in ::g_crews_list.get())
    if (crewBlock.country == country)
    {
      crew = crewBlock.crews
      break
    }

  if (crew == null)
    return -1

  foreach(idx, crewBlock in crew)
    if (::is_crew_slot_empty(crewBlock))
      return idx

  return -1
}
