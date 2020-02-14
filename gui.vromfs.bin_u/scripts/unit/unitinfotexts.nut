local basicUnitRoles = {
  [::ES_UNIT_TYPE_AIRCRAFT] = ["fighter", "assault", "bomber"],
  [::ES_UNIT_TYPE_TANK] = ["tank", "light_tank", "medium_tank", "heavy_tank", "tank_destroyer", "spaa", "lbv", "mbv", "hbv"],
  [::ES_UNIT_TYPE_SHIP] = ["ship", "boat", "heavy_boat", "barge", "destroyer", "light_cruiser",
    "cruiser", "battlecruiser", "battleship", "submarine"],
  [::ES_UNIT_TYPE_HELICOPTER] = ["attack_helicopter", "utility_helicopter"],
}

local unitRoleFontIcons = {
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
  lbv                      = ::loc("icon/unitclass/light_tank")
  mbv                      = ::loc("icon/unitclass/medium_tank")
  hbv                      = ::loc("icon/unitclass/heavy_tank")
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

local unitRoleByTag = {
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
  //battle vehicles:
  type_lbv              = "lbv",
  type_mbv              = "mbv",
  type_hbv              = "hbv",
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

local unitRoleByName = {}

local function getUnitRole(unitData) { //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
  local unit = unitData
  if (typeof(unitData) == "string")
    unit = ::getAircraftByName(unitData);

  if (!unit)
    return ""; //not found

  local role = unitRoleByName?[unit.name] ?? ""
  if (role == "")
  {
    foreach(tag in unit.tags)
      if (tag in unitRoleByTag)
      {
        role = unitRoleByTag[tag]
        break
      }
    unitRoleByName[unit.name] <- role
  }

  return role
}

local haveUnitRole = @(unit, role) ::isInArray($"type_{role}", unit.tags)

local function getUnitBasicRole(unit) {
  local unitType = ::get_es_unit_type(unit)
  local basicRoles = basicUnitRoles?[unitType]
  if (!basicRoles || !basicRoles.len())
    return ""

  foreach(role in basicRoles)
    if (haveUnitRole(unit, role))
      return role
  return basicRoles[0]
}

local getRoleText = @(role) ::loc("mainmenu/type_" + role)

/*
  typeof @source == Unit     -> @source is unit
  typeof @source == "string" -> @source is role id
*/
local function getUnitRoleIcon(source) {
  local role = ::u.isString(source) ? source
    : getUnitBasicRole(source)
  return unitRoleFontIcons?[role] ?? ""
}

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
    return getRoleText("submarine")

  local basicRoles = basicUnitRoles?[::get_es_unit_type(unit)] ?? []
  local textsList = []
  foreach(tag in unit.tags)
    if (tag.len()>5 && tag.slice(0, 5)=="type_" && !::isInArray(tag.slice(5), basicRoles))
      textsList.append(::loc($"mainmenu/{tag}"))

  if (textsList.len())
    return ::g_string.implode(textsList, ::loc("mainmenu/unit_type_separator"))

  foreach (t in basicRoles)
    if (::isInArray("type_" + t, unit.tags))
      return getRoleText(t)
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

local function getShipMaterialTexts(unitId)
{
  local res = {}
  local blk = ::get_wpcost_blk()?[unitId ?? ""]?.Shop
  local parts = [ "hull", "superstructure" ]
  foreach (part in parts)
  {
    local material  = blk?[part + "Material"]  ?? ""
    local thickness = blk?[part + "Thickness"] ?? 0.0
    if (thickness && material)
    {
      res[part + "Label"] <- ::loc("info/ship/part/" + part)
      res[part + "Value"] <- ::loc("armor_class/" + material + "/short", ::loc("armor_class/" + material)) +
        ::loc("ui/comma") + ::round(thickness) + " " + ::loc("measureUnits/mm")
    }
  }
  if (res?.superstructureValue && res?.superstructureValue == res?.hullValue)
  {
    res.hullLabel += " " + ::loc("clan/rankReqInfoCondType_and") + " " +
      ::g_string.utf8ToLower(res.superstructureLabel)
    res.rawdelete("superstructureLabel")
    res.rawdelete("superstructureValue")
  }
  return res
}

return {
  getUnitRole = getUnitRole
  getUnitBasicRole = getUnitBasicRole
  getRoleText = getRoleText
  getUnitRoleIcon = getUnitRoleIcon
  getUnitTooltipImage = getUnitTooltipImage
  getFullUnitRoleText = getFullUnitRoleText
  getChanceToMeetText = getChanceToMeetText
  getShipMaterialTexts = getShipMaterialTexts
}
