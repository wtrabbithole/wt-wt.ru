::g_crew_skills <- {
  DEFAULT_MAX_SKILL_LEVEL = 50

  skillCategories = []
  skillCategoryByName = {}
  skillsLoaded = false
  maxSkillValueByMemberAndSkill = {}
  skillParameterInfo = {} //skillName = { measureType = <string>, sortOrder = <int> }
}

g_crew_skills.updateSkills <- function updateSkills()
{
  if (!skillsLoaded)
  {
    skillsLoaded = true
    loadSkills()
  }
}

g_crew_skills.getSkillCategories <- function getSkillCategories()
{
  updateSkills()
  return skillCategories
}

g_crew_skills.getSkillCategoryByName <- function getSkillCategoryByName(categoryName)
{
  updateSkills()
  return ::getTblValue(categoryName, skillCategoryByName, null)
}

g_crew_skills.getSkillParameterInfo <- function getSkillParameterInfo(parameterName)
{
  updateSkills()
  return ::getTblValue(parameterName, skillParameterInfo)
}

g_crew_skills.getMeasureTypeBySkillParameterName <- function getMeasureTypeBySkillParameterName(parameterName)
{
  return ::getTblValue("measureType", getSkillParameterInfo(parameterName), ::g_measure_type.UNKNOWN)
}

g_crew_skills.getSortOrderBySkillParameterName <- function getSortOrderBySkillParameterName(parameterName)
{
  return ::getTblValue("sortOrder", getSkillParameterInfo(parameterName), 0)
}

g_crew_skills.loadSkills <- function loadSkills()
{
  ::load_crew_skills_once()
  local skillsBlk = ::get_skills_blk()
  skillCategories.clear()
  skillCategoryByName.clear()
  maxSkillValueByMemberAndSkill.clear()
  local calcBlk = skillsBlk?.crew_skills_calc
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
      local maxSkillValue = ::getTblValue("max_skill_level", skillBlk, DEFAULT_MAX_SKILL_LEVEL)
      maxSkillValueByMemberAndSkill[memberName][skillName] <- maxSkillValue

      // Skill category
      local categoryName = skillBlk?.skill_category
      if (categoryName == null)
        continue

      local skillCategory = skillCategoryByName?[categoryName]
      if (skillCategory == null)
        skillCategory = createCategory(categoryName)

      local categorySkill = {
        memberName = memberName
        skillName = skillName
        skillItem = skillItem
        isVisible = function(crewUnitType) { return skillItem.isVisible(crewUnitType) }
      }
      skillCategory.crewUnitTypeMask = skillCategory.crewUnitTypeMask | skillItem.crewUnitTypeMask
      skillCategory.skillItems.append(categorySkill)
    }
  }

  skillParameterInfo.clear()
  local typesBlk = skillsBlk?.measure_type_by_skill_parameter
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

g_crew_skills.createCategory <- function createCategory(categoryName)
{
  local category = {
    categoryName = categoryName
    skillItems = []
    crewUnitTypeMask = 0
  }
  skillCategories.append(category)
  skillCategoryByName[categoryName] <- category
  return category
}

g_crew_skills.getSkillCategoryValue <- function getSkillCategoryValue(crewData, skillCategory, crewUnitType)
{
  local skillValue = 0
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.isVisible(crewUnitType))
      skillValue += getCrewSkillValue(crewData, skillItem.memberName, skillItem.skillName)
  return skillValue
}

g_crew_skills.getSkillCategoryCrewLevel <- function getSkillCategoryCrewLevel(crewData, skillCategory, crewUnitType)
{
  local res = 0
  foreach (categorySkill in skillCategory.skillItems)
  {
    if (!categorySkill.isVisible(crewUnitType))
      continue

    local value = getCrewSkillValue(crewData, categorySkill.memberName, categorySkill.skillName)
    res += ::g_crew.getSkillCrewLevel(categorySkill.skillItem, value)
  }
  return res
}

g_crew_skills.getSkillCategoryMaxValue <- function getSkillCategoryMaxValue(skillCategory, crewUnitType)
{
  local skillValue = 0
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.isVisible(crewUnitType))
      skillValue += getMaxSkillValue(skillItem.memberName, skillItem.skillName)
  return skillValue
}

g_crew_skills.getSkillCategoryMaxCrewLevel <- function getSkillCategoryMaxCrewLevel(skillCategory, crewUnitType)
{
  local crewLevel = 0
  foreach (categorySkill in skillCategory.skillItems)
    if (categorySkill.isVisible(crewUnitType))
      crewLevel += ::g_crew.getSkillMaxCrewLevel(categorySkill.skillItem)
  return crewLevel
}

g_crew_skills.getCrewSkillValue <- function getCrewSkillValue(crewData, memberName, skillName)
{
  local unitCrewData = ::g_unit_crew_cache.getUnitCrewDataById(crewData.id)
  local memberData = ::getTblValue(memberName, unitCrewData, null)
  return ::getTblValue(skillName, memberData, 0)
}

g_crew_skills.getMaxSkillValue <- function getMaxSkillValue(memberName, skillName)
{
  updateSkills()
  local maxSkillValueBySkill = ::getTblValue(memberName, maxSkillValueByMemberAndSkill, null)
  return ::getTblValue(skillName, maxSkillValueBySkill, 0)
}

/** @see slotInfoPanel.nut */
g_crew_skills.getSkillCategoryView <- function getSkillCategoryView(crewData, unit)
{
  local unitType = unit?.unitType ?? g_unit_type.INVALID
  local crewUnitType = unitType.crewUnitType
  local unitTypeName = unitType.name
  local view = []
  foreach (skillCategory in getSkillCategories())
  {
    local isSupported = (skillCategory.crewUnitTypeMask & (1 << crewUnitType)) != 0
      && (unit.gunnersCount > 0 || categoryHasNonGunnerSkills(skillCategory))
    if (!isSupported)
      continue
    view.append({
      categoryName = getSkillCategoryName(skillCategory)
      categoryTooltip = ::g_tooltip.getIdCrewSkillCategory(skillCategory.categoryName, unitTypeName)
      categoryValue = getSkillCategoryCrewLevel(crewData, skillCategory, crewUnitType)
      categoryMaxValue = getSkillCategoryMaxCrewLevel(skillCategory, crewUnitType)
    })
  }
  return view
}

g_crew_skills.getCategoryParameterRows <- function getCategoryParameterRows(skillCategory, crewUnitType, crew)
{
  local difficulty = ::get_current_shop_difficulty()
  return ::g_crew_skill_parameters.getSkillListParameterRowsView(crew, difficulty, skillCategory.skillItems, crewUnitType)
}

g_crew_skills.getSkillCategoryTooltipContent <- function getSkillCategoryTooltipContent(skillCategory, crewUnitType, crewData)
{
  local headerLocId = "crewSkillCategoryTooltip/" + skillCategory.categoryName
  local view = {
    tooltipText = ::loc(headerLocId, getSkillCategoryName(skillCategory) + ":")
    skillRows = []
    hasSkillRows = true
    parameterRows = getCategoryParameterRows(skillCategory, crewUnitType, crewData)
    headerItems = null
  }

  local crewSkillPoints = ::g_crew.getCrewSkillPoints(crewData)
  foreach (categorySkill in skillCategory.skillItems)
  {
    if (categorySkill.isVisible(crewUnitType))
      continue
    local skillItem = categorySkill.skillItem
    if (!skillItem)
      continue

    local memberName = ::loc("crew/" + categorySkill.memberName)
    local skillName = ::loc("crew/" + categorySkill.skillName)
    local skillValue = ::g_crew.getSkillValue(crewData.id, categorySkill.memberName, categorySkill.skillName)
    local availValue = ::g_crew.getMaxAvailbleStepValue(skillItem, skillValue, crewSkillPoints)
    view.skillRows.append({
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

g_crew_skills.getSkillCategoryName <- function getSkillCategoryName(skillCategory)
{
  return ::loc("crewSkillCategory/" + skillCategory.categoryName, skillCategory.categoryName)
}

g_crew_skills.getCrewPoints <- function getCrewPoints(crewData)
{
  return ::getTblValue("skillPoints", crewData, 0)
}

g_crew_skills.categoryHasNonGunnerSkills <- function categoryHasNonGunnerSkills(skillCategory)
{
  foreach (skillItem in skillCategory.skillItems)
    if (skillItem.memberName != "gunner")
      return true
  return false
}

g_crew_skills.isAffectedBySpecialization <- function isAffectedBySpecialization(memberName, skillName)
{
  local skillItem = ::g_crew.getSkillItem(memberName, skillName)
  return ::getTblValue("useSpecializations", skillItem, false)
}

g_crew_skills.isAffectedByLeadership <- function isAffectedByLeadership(memberName, skillName)
{
  local skillItem = ::g_crew.getSkillItem(memberName, skillName)
  return ::getTblValue("useLeadership", skillItem, false)
}

g_crew_skills.getMinSkillsUnitRepairRank <- function getMinSkillsUnitRepairRank(unitRank)
{
  local repairRanksBlk = ::getTblValue("repair_ranks", ::get_skills_blk())
  if (!repairRanksBlk)
    return -1
  for(local i = 1; ; i++)
  {
    local rankValue = repairRanksBlk?["rank" + i]
    if (!rankValue)
      break
    if (rankValue >= unitRank)
      return i
  }
  return -1
}
