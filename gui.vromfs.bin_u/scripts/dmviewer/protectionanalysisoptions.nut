local enums = ::require("sqStdlibs/helpers/enums.nut")
local stdMath = require("std/math.nut")

local options = {
  types = []
  cache = {
    bySortId = {}
  }
}

local targetTypeToThreatTypes = {
  [::ES_UNIT_TYPE_AIRCRAFT]   = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
  [::ES_UNIT_TYPE_HELICOPTER] = [ ::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK, ::ES_UNIT_TYPE_HELICOPTER ],
}

local function getThreatEsUnitTypes()
{
  local targetUnit = ::getAircraftByName(::hangar_get_current_unit_name())
  local targetUnitType = targetUnit?.esUnitType ?? ::ES_UNIT_TYPE_INVALID
  local res = targetTypeToThreatTypes?[targetUnitType] ?? [ targetUnitType ]
  return res.filter(@(e) ::g_unit_type.getByEsUnitType(e)?.isAvailable())
}

options.template <- {
  id = "" //used from type name
  sortId = 0
  labelLocId = null
  controlStyle = ""
  shouldInit = false
  shouldSetParams = false
  items  = []
  values = []
  value = null
  defValue = null
  valueWidth = null

  isNeedInit = @() shouldInit
  getLabel = @() labelLocId && ::loc(labelLocId)
  getControlMarkup = function() {
    return ::create_option_combobox(id, [], -1, "onChangeOption", true,
      { controlStyle = controlStyle })
  }
  getInfoRows = @() null

  onChange = function(handler, scene, obj) {
    value = getValFromObj(obj)
    if (afterChangeFunc)
      afterChangeFunc(obj)
    if (shouldSetParams)
      options.setAnalysisParams()
    else
      options.getBySortId(sortId + 1).reinit(handler, scene)
  }

  isVisible = @() true
  getValFromObj = @(obj) ::check_obj(obj) ? values?[obj.getValue()] : null
  afterChangeFunc = null
  reinit = @(handler, scene) null

  update = function(handler, scene) {
    local idx = values.indexof(value) ?? -1
    local markup = ::create_option_combobox(null, items, idx, null, false)
    local obj = scene.findObject(id)
    if (::check_obj(obj))
    {
      obj.getScene().replaceContentFromText(obj, markup, markup.len(), handler)
      onChange(handler, scene, obj)
    }
  }
}

options.addTypes <- function(typesTable)
{
  enums.addTypes(this, typesTable, null, "id")
  types.sort(@(a, b) a.sortId <=> b.sortId)
}

local sortId = 0
options.addTypes({
  UNKNOWN = {
    sortId = sortId++
    isVisible = @() false
  }
  UNITTYPE = {
    sortId = sortId++
    labelLocId = "mainmenu/threat"
    shouldInit = true
    isVisible = @() getThreatEsUnitTypes().len() > 1

    reinit = function(handler, scene)
    {
      local targetUnit = ::getAircraftByName(::hangar_get_current_unit_name())
      local esUnitTypes = getThreatEsUnitTypes()
      local unitTypes = esUnitTypes.map(@(e)::g_unit_type.getByEsUnitType(e))
      values = esUnitTypes
      items  = ::u.map(unitTypes, @(t) { text = "{0} {1}".subst(t.fontIcon, t.getArmyLocName()) })
      value = value ?? targetUnit?.esUnitType ?? values?[0] ?? ::ES_UNIT_TYPE_INVALID
      update(handler, scene)
    }
  }
  COUNTRY = {
    sortId = sortId++
    controlStyle = "iconType:t='small';"
    isNeedInit = @() !options.UNITTYPE.isVisible()
    getLabel = @() options.UNITTYPE.isVisible() ? null : ::loc("mainmenu/threat")

    reinit = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      local targetUnit = ::getAircraftByName(::hangar_get_current_unit_name())
      local countriesWithUnitType = ::get_countries_by_unit_type(unitType)
      values = ::u.filter(::shopCountriesList, @(c) ::isInArray(c, countriesWithUnitType))
      items  = ::u.map(values, @(c) { text = ::loc(c), image = ::get_country_icon(c) })
      value = value && values.indexof(value) != null ? value
        : values.indexof(targetUnit?.shopCountry) != null ? targetUnit.shopCountry
        : (values?[0] ?? "")
      update(handler, scene)
    }
  }
  RANK = {
    sortId = sortId++

    reinit = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      local country = options.COUNTRY.value
      local targetUnit = ::getAircraftByName(::hangar_get_current_unit_name())
      values = []
      for (local rank = 1; rank <= ::max_country_rank; rank++)
        if (::get_units_count_at_rank(rank, unitType, country, true, false))
          values.append(rank)
      items = ::u.map(values, @(r) {
        text = ::format(::loc("conditions/unitRank/format"), get_roman_numeral(r))
      })
      local preferredRank = value ?? targetUnit?.rank ?? 0
      value = values[::find_nearest(preferredRank, values)]
      update(handler, scene)
    }
  }
  UNIT = {
    sortId = sortId++

    reinit = function(handler, scene)
    {
      local unitType = options.UNITTYPE.value
      local rank = options.RANK.value
      local country = options.COUNTRY.value
      local targetUnit = ::getAircraftByName(::hangar_get_current_unit_name())
      local unitId = ::hangar_get_current_unit_name()
      local ediff = ::get_current_ediff()
      local list = ::get_units_list(@(u) u.isVisibleInShop() &&
        u.esUnitType == unitType && u.rank == rank && u.shopCountry == country)
      list = ::u.map(list, @(u) { unit = u, id = u.name, br = u.getBattleRating(ediff) })
      list.sort(@(a, b) a.br <=> b.br)
      local preferredBR = targetUnit.getBattleRating(ediff)
      local idx = list.findindex(@(v) v.id == unitId) ?? ::find_nearest(preferredBR, ::u.map(list, @(v) v.br))
      values = ::u.map(list, @(v) v.unit)
      items = ::u.map(list, @(v) {
        text  = ::format("[%.1f] %s", v.br, ::getUnitName(v.id))
        image = ::image_for_air(v.unit)
        addDiv = ::g_tooltip_type.UNIT.getMarkup(v.id, { showLocalState = false })
      })
      value = values?[idx]
      update(handler, scene)
    }
  }
  BULLET = {
    sortId = sortId++
    labelLocId = "mainmenu/shell"
    shouldSetParams = true
    visibleTypes = [ WEAPON_TYPE.GUN, WEAPON_TYPE.ROCKET, WEAPON_TYPE.AGM ]

    reinit = function(handler, scene)
    {
      local unit = options.UNIT.value
      values = []
      items = []
      local bulletNamesSet = []

      local curGunIdx = -1
      local groupsCount = ::getBulletsGroupCount(unit)
      local shouldSkipBulletBelts = false

      for (local groupIndex = 0; groupIndex < ::get_last_fake_bullets_index(unit); groupIndex++)
      {
        local gunIdx = ::get_linked_gun_index(groupIndex, groupsCount, false)
        if (gunIdx == curGunIdx)
          continue

        local bulletsList = ::get_bullets_list(unit.name, groupIndex, {
          needCheckUnitPurchase = false, needOnlyAvailable = false, needTexts = true
        })
        if (bulletsList.values.len())
          curGunIdx = gunIdx

        foreach(i, value in bulletsList.values)
        {
          local bulletsSet = ::getBulletsSetData(unit, value)
          local weaponBlkName = bulletsSet?.weaponBlkName
          local isBulletBelt = bulletsSet?.isBulletBelt ?? true

          if (!weaponBlkName)
            continue
          if (visibleTypes.indexof(bulletsSet?.weaponType) == null)
            continue

          if (shouldSkipBulletBelts && isBulletBelt)
            continue
          shouldSkipBulletBelts = shouldSkipBulletBelts || !isBulletBelt

          local searchName = ::getBulletsSearchName(unit, value)
          local useDefaultBullet = searchName != value
          local bulletParameters = ::calculate_tank_bullet_parameters(unit.name,
            (useDefaultBullet && weaponBlkName) || ::getModificationBulletsEffect(searchName),
            useDefaultBullet, false)

          local bulletNames = isBulletBelt ? [] : (bulletsSet?.bulletNames ?? [])
          if (isBulletBelt)
            foreach (params in bulletParameters)
              bulletNames.append(params?.bulletType ?? "")

          local bulletName
          local bulletParams
          local maxPiercing = 0
          foreach (idx, params in bulletParameters)
          {
            local curPiercing = params?.armorPiercing?[0]?[0] ?? 0
            if (maxPiercing < curPiercing)
            {
              bulletName   = bulletNames?[idx]
              bulletParams = params
              maxPiercing  = curPiercing
            }
          }

          local locName = bulletsList.items[i].text
          if(::isInArray(locName, bulletNamesSet))
            continue
          bulletNamesSet.append(locName)

          values.append({
            bulletName = bulletName || ""
            weaponBlkName = weaponBlkName
            bulletParams = bulletParams
          })

          items.append({
            text = bulletsList.items[i]
            addDiv = ::g_tooltip_type.MODIFICATION.getMarkup(unit.name, value,
              { hasPlayerInfo = false })
          })
        }
      }

      value = values?[0]
      update(handler, scene)
    }

    afterChangeFunc = function(obj) {
      options.updateArmorPiercingText(obj)
    }
  }
  DISTANCE = {
    sortId = sortId++
    labelLocId = "distance"
    shouldInit = true
    shouldSetParams = true
    value = 500
    defValue = 500
    minValue = 0
    maxValue = 5000
    step = 100
    valueWidth = "@dmInfoTextWidth"

    getControlMarkup = function() {
      return ::handyman.renderCached("gui/dmViewer/distanceSlider", {
        containerId = "container_" + id
        id = id
        min = minValue
        max = maxValue
        value = defValue
        step = step
        width = "fw"
        btnOnDec = "onButtonDec"
        btnOnInc = "onButtonInc"
        onChangeSliderValue = "onChangeOption"
      })
    }

    getInfoRows = @() [{
      valueId = "armorPiercingText"
      valueWidth = valueWidth
      label = ::loc("bullet_properties/armorPiercing") + ::loc("ui/colon")
    }]

    getValFromObj = @(obj) ::check_obj(obj) ? obj.getValue() : 0

    afterChangeFunc = function(obj) {
      local parentObj = obj.getParent().getParent()
      parentObj.findObject("value_" + id).setValue(value + ::loc("measureUnits/meters_alt"))
      ::enableBtnTable(parentObj, {
        buttonInc = value < maxValue
        buttonDec = value > minValue
      })
      options.updateArmorPiercingText(obj)
    }

    reinit = function(handler, scene) {
      update(handler, scene)
    }

    update = function(handler, scene) {
      local obj = scene.findObject(id)
      if (::check_obj(obj))
        onChange(handler, scene, obj)
    }
  }
})

options.init <- function(handler, scene) {
  foreach (o in options.types)
    o.value = o.defValue
  foreach (o in options.types)
    if (o.isNeedInit())
      o.reinit(handler, scene)
}

options.setAnalysisParams <- function() {
  local bullet   = options.BULLET.value
  local distance = options.DISTANCE.value
  ::set_protection_checker_params(bullet?.weaponBlkName ?? "", bullet?.bulletName ?? "", distance)
}

options.get <- @(id) this?[id] ?? UNKNOWN

options.getBySortId <- function(idx) {
  return enums.getCachedType("sortId", idx, cache.bySortId, this, UNKNOWN)
}

options.updateArmorPiercingText <- function(obj) {
  local descObj = obj.getParent().getParent().getParent().findObject("armorPiercingText")
  if (!::check_obj(descObj))
    return
  local desc = ::loc("ui/mdash")

  local bullet   = options.BULLET.value
  local distance = options.DISTANCE.value

  if (bullet?.bulletParams?.armorPiercing)
  {
    local pMin
    local pMax

    for (local i = 0; i < bullet.bulletParams.armorPiercing.len(); i++)
    {
      local v = {
        armor = bullet.bulletParams.armorPiercing[i]?[0] ?? 0,
        dist  = bullet.bulletParams.armorPiercingDist[i],
      }
      if (!pMin)
        pMin = { armor = v.armor, dist = 0 }
      if (!pMax)
        pMax = pMin
      if (v.dist <= distance)
        pMin = v
      pMax = v
      if (v.dist >= distance)
        break
    }
    if (pMax && pMax.dist < distance)
      pMax.dist = distance

    if (pMin && pMax)
    {
      local armor = stdMath.lerp(pMin.dist, pMax.dist, pMin.armor, pMax.armor, distance)
      desc = stdMath.round(armor).tointeger() + " " + ::loc("measureUnits/mm")
    }
  }

  descObj.setValue(desc)
}

return options
