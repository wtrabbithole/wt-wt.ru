::g_crew_skills <- {
  DEFAULT_MAX_SKILL_LEVEL = 50

  skillCategories = []
  skillCategoryByName = {}
  skillsLoaded = false
  maxSkillValueByMemberAndSkill = {}
  skillParameterInfo = {} //skillName = { measureType = <string>, sortOrder = <int> }
}

function g_crew_skills::updateSkills()
{
  if (!skillsLoaded)
  {
    skillsLoaded = true
    loadSkills()
  }
}

function g_crew_skills::getSkillCategories()
{
  updateSkills()
  return skillCategories
}

function g_crew_skills::getSkillCategoryByName(categoryName)
{
  updateSkills()
  return ::getTblValue(categoryName, skillCategoryByName, null)
}

function g_crew_skills::getSkillParameterInfo(parameterName)
{
  updateSkills()
  return ::getTblValue(parameterName, skillParameterInfo)
}

function g_crew_skills::getMeasureTypeBySkillParameterName(parameterName)
{
  return ::getTblValue("measureType", getSkillParameterInfo(parameterName), ::g_measure_type.UNKNOWN)
}

function g_crew_skills::getSortOrderBySkillParameterName(parameterName)
{
  return ::getTblValue("sortOrder", getSkillParameterInfo(parameterName), 0)
}

function g_crew_skills::loadSkills()
{
  ::load_crew_skills_once()
  local skillsBlk = ::get_skills_blk()
  skillCategories.clear()
  skillCategoryByName.clear()
  maxSkillValueByMemberAndSkill.clear()
  local calcBlk = skillsBlk.crew_skills_calc
  if (calcBlk == null)
    return
  foreach (memberName, memberBlk in calcBlk)
  {
    if (!::u.isDataBlock(memberBlk))
      continue

    maxSkillValueByMemberAndSkill[memberName] <- {}
    foreach (skillName, skillBlk in memberBlk)
    {
      if (!::u.isDataBlock(skillBlk))
        continue // Not actually a skill blk.
      local skillItem = ::g_crew.getSkillItem(memberName, skillName)
      if (!skillItem)
        continue

      //!!FIX ME: need to full use the same skillItems as in g_crew instead of duplicate code
      // Max skill value
      local crewSkillsBlk = skillsBlk.crew_skills
      local maxSkillValue = ::getTblValue("max_skill_level", skillBlk, DEFAULT_MAX_SKILL_LEVEL)
      maxSkillValueByMemberAndSkill[memberName][skillName] <- maxSkillValue

      // Skill category
      local categoryName = skillBlk.skill_category
      if (categoryName == null)
        continue

      local skillCategory = ::getTblValue(categoryName, skillCategoryByName, null)
      if (skillCategory == null)
        skillCategory = createCategory(categoryName)

      local categorySkill = {
        memberName = memberName
        skillName = skillName
        skillItem = skillItem
        isVisible = function(esUnitType) { return skillItem.isVisible(esUnitType) }
      }
      skillCategory.unitTypeMask = skillCategory.unitTypeMask | skillItem.unitTypeMask
      skillCategory.skillItems.push(categorySkill)
    }
  }

  skillParameterInfo.clear()
  local typesBlk = skillsBlk.measure_type_by_skill_parameter
  if (typesBlk != null)
  {
    local sortOrder = 0
    foreach (parameterName, typeName in typesBlk)
      skillParameterInfo[parameterName] <- {
        measureType = ::g_measure_type.getTypeByName(typeName, true)
        sortOrder = ++sortOrder
      }
  }
}

function g_crew_skills::createCategory(categoryName)
{
  local category = {
    categoryName = categoryName
    skillItems = []
    unitTypeMask = 0
  }
  skillCategories.push(category)
  skillCategoryByName[categoryName] <- category
  return category
}

function g_crew_skills::getSkillCategoryValue(crewData, skillCategory, unitType)
{
  local skillValue = 0
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.isVisible(unitType))
      skillValue += getCrewSkillValue(crewData, skillItem.memberName, skillItem.skillName)
  return skillValue
}

function g_crew_skills::getSkillCategoryCrewLevel(crewData, skillCategory, unitType)
{
  local res = 0
  foreach (categorySkill in skillCategory.skillItems)
  {
    if (!categorySkill.isVisible(unitType))
      continue

    local value = getCrewSkillValue(crewData, categorySkill.memberName, categorySkill.skillName)
    res += ::g_crew.getSkillCrewLevel(categorySkill.skillItem, value)
  }
  return res
}

function g_crew_skills::getSkillCategoryMaxValue(skillCategory, unitType)
{
  local skillValue = 0
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.isVisible(unitType))
      skillValue += getMaxSkillValue(skillItem.memberName, skillItem.skillName)
  return skillValue
}

function g_crew_skills::getSkillCategoryMaxCrewLevel(skillCategory, unitType)
{
  local crewLevel = 0
  foreach (categorySkill in skillCategory.skillItems)
    if (categorySkill.isVisible(unitType))
      crewLevel += ::g_crew.getSkillMaxCrewLevel(categorySkill.skillItem)
  return crewLevel
}

function g_crew_skills::getCrewSkillValue(crewData, memberName, skillName)
{
  local unitCrewData = ::g_unit_crew_cache.getUnitCrewDataById(crewData.id)
  local memberData = ::getTblValue(memberName, unitCrewData, null)
  return ::getTblValue(skillName, memberData, 0)
}

function g_crew_skills::getMaxSkillValue(memberName, skillName)
{
  updateSkills()
  local maxSkillValueBySkill = ::getTblValue(memberName, maxSkillValueByMemberAndSkill, null)
  return ::getTblValue(skillName, maxSkillValueBySkill, 0)
}

/** @see slotInfoPanel.nut */
function g_crew_skills::getSkillCategoryView(crewData, unit)
{
  local unitType = ::get_es_unit_type(unit)
  local view = []
  foreach (skillCategory in getSkillCategories())
  {
    local isSupported = (skillCategory.unitTypeMask & (1 << unitType)) != 0
      && (unit.gunnersCount > 0 || categoryHasNonGunnerSkills(skillCategory))
    if (!isSupported)
      continue
    local unitTypeName = ::getUnitTypeText(unitType)
    view.push({
      categoryName = getSkillCategoryName(skillCategory)
      categoryTooltip = ::g_tooltip.getIdCrewSkillCategory(skillCategory.categoryName, unitTypeName)
      categoryValue = getSkillCategoryCrewLevel(crewData, skillCategory, unitType)
      categoryMaxValue = getSkillCategoryMaxCrewLevel(skillCategory, unitType)
    })
  }
  return view
}

function g_crew_skills::getCategoryParameterRows(skillCategory, unitType, crew)
{
  local dominationId = ::get_current_domination_mode_shop().id
  local difficulty = ::g_difficulty.getDifficultyByCrewSkillName(dominationId)
  return ::g_crew_skill_parameters.getSkillListParameterRowsView(crew, difficulty, skillCategory.skillItems, unitType)
}

function g_crew_skills::getSkillCategoryTooltipContent(skillCategory, unitType, crewData)
{
  local headerLocId = "crewSkillCategoryTooltip/" + skillCategory.categoryName
  local view = {
    tooltipText = ::loc(headerLocId, getSkillCategoryName(skillCategory) + ":")
    skillRows = []
    hasSkillRows = true
    parameterRows = getCategoryParameterRows(skillCategory, unitType, crewData)
    headerItems = null
  }

  local crewSkillPoints = ::g_crew.getCrewSkillPoints(crewData)
  foreach (categorySkill in skillCategory.skillItems)
  {
    if (categorySkill.isVisible(unitType))
      continue
    local skillItem = categorySkill.skillItem
    if (!skillItem)
      continue

    local memberName = ::loc("crew/" + categorySkill.memberName)
    local skillName = ::loc("crew/" + categorySkill.skillName)
    local skillValue = ::g_crew.getSkillValue(crewData.id, categorySkill.memberName, categorySkill.skillName)
    local availValue = ::g_crew.getMaxAvailbleStepValue(skillItem, skillValue, crewSkillPoints)
    view.skillRows.push({
      skillName = ::format("%s (%s)", skillName, memberName)
      totalSteps = ::g_crew.getTotalSteps(skillItem)
      maxSkillCrewLevel = ::g_crew.getSkillMaxCrewLevel(skillItem)
      skillLevel = ::g_crew.getSkillCrewLevel(skillItem, skillValue)
      availableStep = ::g_crew.skillValueToStep(skillItem, availValue)
      skillMaxValue = ::g_crew.getMaxSkillValue(skillItem)
      skillValue = skillValue
    })
  }

  //use header items for legend
  if (view.parameterRows.len())
    view.headerItems <- view.parameterRows[0].valueItems

  return ::handyman.renderCached("gui/crew/crewSkillParametersTooltip", view)
}

function g_crew_skills::getSkillCategoryName(skillCategory)
{
  return ::loc("crewSkillCategory/" + skillCategory.categoryName, skillCategory.categoryName)
}

function g_crew_skills::getCrewPoints(crewData)
{
  return ::getTblValue("skillPoints", crewData, 0)
}

function g_crew_skills::categoryHasNonGunnerSkills(skillCategory)
{
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.memberName != "gunner")
      return true
  return false
}

function g_crew_skills::isAffectedBySpecialization(memberName, skillName)
{
  local skillItem = ::g_crew.getSkillItem(memberName, skillName)
  return ::getTblValue("useSpecializations", skillItem, false)
}

function g_crew_skills::isAffectedByLeadership(memberName, skillName)
{
  local skillItem = ::g_crew.getSkillItem(memberName, skillName)
  return ::getTblValue("useLeadership", skillItem, false)
}

function g_crew_skills::getMinSkillsUnitRepairRank(unitRank)
{
  local repairRanksBlk = ::getTblValue("repair_ranks", ::get_skills_blk())
  if (!repairRanksBlk)
    return -1
  for(local i = 1; ; i++)
  {
    local rankValue = repairRanksBlk["rank" + i]
    if (!rankValue)
      break
    if (rankValue >= unitRank)
      return i
  }
  return -1
}
