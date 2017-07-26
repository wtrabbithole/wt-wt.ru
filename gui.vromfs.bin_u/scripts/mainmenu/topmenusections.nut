::g_top_menu_sections <- {
  template = {
    name = "unknown"
    type = null
    onClick = "onDropDown"
    hoverMenuPos = "0"
    getText = function(totalSections = 0) { return null }
    getImage = function(totalSections = 0) { return null }
    getWinkImage = function() { return null }
    btnName = null
    buttons = null
    mergeIndex = -1
    minimalWidth = false
    haveTmDiscount = false

    getTopMenuButtonDivId = function() { return "topmenu_" + name }
    getTopMenuDiscountId = function() { return getTopMenuButtonDivId() + "_discount" }
  }
}

function g_top_menu_sections::isSeparateTab(section, totalSections)
{
  return section? section.mergeIndex < totalSections : true
}

function g_top_menu_sections::getSectionsOrder(sectionsStructure, maxSectionsCount)
{
  local sections = []
  foreach (idx, section in sectionsStructure.types)
  {
    if (!isSeparateTab(section, maxSectionsCount))
      continue

    local result = clone section
    result.buttons = _proceedButtonsArray(section.buttons, maxSectionsCount, sectionsStructure)
    sections.append(result)
  }

  foreach (section in sections)
    clearEmptyColumns(section.buttons)

  return sections
}

function g_top_menu_sections::_proceedButtonsArray(itemsArray, maxSectionsCount, sectionsStructure)
{
  local result = []
  foreach (idx, column in itemsArray)
  {
    result.append([])
    foreach (item in column)
    {
      if (::u.isTable(item))
      {
        result[result.len() - 1].append(item)
        continue
      }

      local newSection = sectionsStructure.getSectionByName(item)
      if (isSeparateTab(newSection, maxSectionsCount))
        continue

      local newSectionResult = _proceedButtonsArray(newSection.buttons, maxSectionsCount, sectionsStructure)
      foreach (column in newSectionResult)
        if (column)
          result[result.len() - 1].extend(column)
    }
  }
  return result
}

function g_top_menu_sections::clearEmptyColumns(itemsArray)
{
  for (local i = itemsArray.len()-1; i >= 0; i--)
  {
    if (::u.isEmpty(itemsArray[i]))
      itemsArray.remove(i)
    else if (::u.isArray(itemsArray[i]))
      clearEmptyColumns(itemsArray[i])
  }
}

function g_top_menu_sections::getSectionByName(name)
{
  return ::g_enum_utils.getCachedType("name", name, cache.byName, this, {})
}
