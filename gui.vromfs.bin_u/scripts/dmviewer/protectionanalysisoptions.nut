local enums = ::require("std/enums.nut")

local options = {
  types = []
  cache = {
    bySortId = {}
  }
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
  valueWidth = null

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
    local idx = values.find(value) ?? -1
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
  COUNTRY = {
    sortId = sortId++
    labelLocId = "mainmenu/threat"
    controlStyle = "iconType:t='small';"
    shouldInit = true

    reinit = function(handler, scene)
    {
      local countriesWithTanks = ::get_countries_by_unit_type(::ES_UNIT_TYPE_TANK)
      values = ::u.filter(::shopCountriesList, @(c) ::isInArray(c, countriesWithTanks))
      items  = ::u.map(values, @(c) { text = ::loc(c), image = ::get_country_icon(c) })
      value = ::getAircraftByName(::hangar_get_current_unit_name())?.shopCountry ?? values?[0]
      update(handler, scene)
    }
  }
  RANK = {
    sortId = sortId++

    reinit = function(handler, scene)
    {
      local country = options.COUNTRY.value
      values = []
      for (local rank = 1; rank <= ::max_country_rank; rank++)
        if (::get_units_count_at_rank(rank, ::ES_UNIT_TYPE_TANK, country, true, false))
          values.append(rank)
      items = ::u.map(values, @(r) {
        text = ::format(::loc("conditions/unitRank/format"), get_roman_numeral(r))
      })
      local preferredRank = ::getAircraftByName(::hangar_get_current_unit_name())?.rank ?? 0
      value = values[::find_nearest(preferredRank, values)]
      update(handler, scene)
    }
  }
  UNIT = {
    sortId = sortId++

    reinit = function(handler, scene)
    {
      local rank = options.RANK.value
      local country = options.COUNTRY.value
      local unitId = ::hangar_get_current_unit_name()
      local ediff = ::get_current_ediff()
      local list = ::get_units_list(@(u) u.isVisibleInShop() &&
        u.esUnitType == ::ES_UNIT_TYPE_TANK && u.rank == rank && u.shopCountry == country)
      list = ::u.map(list, @(u) { unit = u, id = u.name, br = u.getBattleRating(ediff) })
      list.sort(@(a, b) a.br <=> b.br)
      local preferredBR = ::getAircraftByName(::hangar_get_current_unit_name()).getBattleRating(ediff)
      local idx = ::u.searchIndex(list, @(v) v.id == unitId)
      if (idx == -1)
        idx = ::find_nearest(preferredBR, ::u.map(list, @(v) v.br))
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
    visibleTypes = [ WEAPON_TYPE.GUN, WEAPON_TYPE.ROCKET ]

    reinit = function(handler, scene)
    {
      local unit = options.UNIT.value
      values = []
      items = []

      local curGunIdx = -1
      local groupsCount = ::getBulletsGroupCount(unit)
      local shouldSkipBulletBelts = false

      for (local groupIndex = 0; groupIndex < ::get_last_fake_bullets_index(unit); groupIndex++)
      {
        local gunIdx = ::get_linked_gun_index(groupIndex, groupsCount)
        if (gunIdx == curGunIdx)
          continue

        local bulletsList = ::get_bullets_list(unit.name, groupIndex, false, false, false, true)
        if (bulletsList.values.len())
          curGunIdx = gunIdx

        foreach(i, value in bulletsList.values)
        {
          local bulletsSet = ::getBulletsSetData(unit, value)
          local weaponBlkName = bulletsSet?.weaponBlkName
          local isBulletBelt = bulletsSet?.isBulletBelt ?? true

          if (!weaponBlkName)
            continue
          if (visibleTypes.find(bulletsSet?.weaponType) == null)
            continue

          if (shouldSkipBulletBelts && isBulletBelt)
            continue
          shouldSkipBulletBelts = shouldSkipBulletBelts || !isBulletBelt

          local searchName = ::getBulletsSearchName(unit, value)
          local useDefaultBullet = searchName != value
          local bulletParameters = ::calculate_tank_bullet_parameters(unit.name,
            useDefaultBullet && weaponBlkName || ::getModificationBulletsEffect(searchName),
            useDefaultBullet)

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
        value = value
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
    if (o.shouldInit)
      o.reinit(handler, scene)
}

options.setAnalysisParams <- function() {
  local bullet   = options.BULLET.value
  local distance = options.DISTANCE.value
  ::set_protection_checker_params(bullet?.weaponBlkName ?? "", bullet?.bulletName ?? "", distance)
}

options.get <- @(id) this?[id] ?? UNKNOWN

options.getBySortId <- function(sortId) {
  return enums.getCachedType("sortId", sortId, cache.bySortId, this, UNKNOWN)
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
      local armor = ::lerp(pMin.dist, pMax.dist, pMin.armor, pMax.armor, distance)
      desc = armor.tointeger() + " " + ::loc("measureUnits/mm")
    }
  }

  descObj.setValue(desc)
}

return options
