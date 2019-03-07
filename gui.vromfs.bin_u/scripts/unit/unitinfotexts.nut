local function getUnitTooltipImage(unit)
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

local function getFullUnitRoleText(unit)
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

local function getChanceToMeetText(battleRating1, battleRating2)
{
  local brDiff = fabs(battleRating1.tofloat() - battleRating2.tofloat())
  local brData = null
  foreach(data in ::chances_text)
    if (!brData
        || (data.brDiff <= brDiff && data.brDiff > brData.brDiff))
      brData = data
  return brData? format("<color=%s>%s</color>", brData.color, ::loc(brData.text)) : ""
}

local function getShipHullMaterialText(unitId)
{
  local blk = ::get_wpcost_blk()?[unitId ?? ""]?.Shop
  local material     = blk?.hullMaterialClass ?? ""
  local thicknessMin = blk?.hullMaterialThickness?.x ?? 0.0
  local thicknessMax = blk?.hullMaterialThickness?.y ?? 0.0
  if (!thicknessMin || !thicknessMax || material == "")
    return ""
  local materialText = ::loc("armor_class/" + material + "/short", ::loc("armor_class/" + material))
  local thicknessText = thicknessMin == thicknessMax ? ("" + ::round(thicknessMax)) :
    (::round(thicknessMin) + ::loc("ui/mdash") + ::round(thicknessMax))
  return materialText + ::loc("ui/comma") + thicknessText + " " + ::loc("measureUnits/mm")
}

return {
  getUnitTooltipImage = getUnitTooltipImage
  getFullUnitRoleText = getFullUnitRoleText
  getChanceToMeetText = getChanceToMeetText
  getShipHullMaterialText = getShipHullMaterialText
}
