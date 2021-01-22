local { getBulletsListHeader } = require("scripts/weaponry/weaponryVisual.nut")
local { getModificationByName } = require("scripts/weaponry/modificationInfo.nut")
local { getBulletsSetData,
        setUnitLastBullets,
        getOptionsBulletsList } = require("scripts/weaponry/bulletsInfo.nut")
local { AMMO,
        getAmmoAmount,
        isAmmoFree } = require("scripts/weaponry/ammoInfo.nut")

::BulletGroup <- class
{
  unit = null
  groupIndex = -1
  selectedName = ""   //selected bullet name
  bullets = null  //bullets list for this group
  bulletsCount = -1
  maxBulletsCount = -1
  gunInfo = null
  guns = 1
  active = false
  canChangeActivity = false
  isForcedAvailable = false

  option = null //bullet option. initialize only on request because generate descriptions
  selectedBullet = null //selected bullet from modifications list

  constructor(_unit, _groupIndex, _gunInfo, params)
  {
    unit = _unit
    groupIndex = _groupIndex
    gunInfo = _gunInfo
    guns = ::getTblValue("guns", gunInfo) || 1
    active = params?.isActive ?? active
    canChangeActivity = params?.canChangeActivity ?? canChangeActivity
    isForcedAvailable = params?.isForcedAvailable ?? isForcedAvailable

    bullets = getOptionsBulletsList(unit, groupIndex, false, isForcedAvailable)
    selectedName = ::getTblValue(bullets.value, bullets.values, "")

    if (::get_last_bullets(unit.name, groupIndex) != selectedName)
      setUnitLastBullets(unit, groupIndex, selectedName)

    local count = ::get_unit_option(unit.name, ::USEROPT_BULLET_COUNT0 + groupIndex)
    if (count != null)
      bulletsCount = (count / guns).tointeger()
    updateCounts()
  }

  function canChangeBulletsCount()
  {
    return gunInfo != null
  }

  function getGunIdx()
  {
    return getTblValue("gunIdx", gunInfo, 0)
  }

  function setBullet(bulletName)
  {
    if (selectedName == bulletName)
      return false

    local bulletIdx = bullets.values.indexof(bulletName)
    if (bulletIdx == null)
      return false

    selectedName = bulletName
    selectedBullet = null
    setUnitLastBullets(unit, groupIndex, selectedName)
    if (option)
      option.value = bulletIdx

    updateCounts()

    return true
  }

  //return is new bullet not from list
  function setBulletNotFromList(bList)
  {
    if (!::isInArray(selectedName, bList))
      return true

    foreach(idx, value in bullets.values)
    {
      if (!bullets.items[idx].enabled)
        continue
      if (::isInArray(value, bList))
        continue
      if (setBullet(value))
        return true
    }
    return false
  }

  function getBulletNameByIdx(idx)
  {
    return ::getTblValue(idx, bullets.values)
  }

  function setBulletsCount(count)
  {
    if (bulletsCount == count)
      return

    bulletsCount = count
    ::set_unit_option(unit.name, ::USEROPT_BULLET_COUNT0 + groupIndex, (count * guns).tointeger())
  }

  //return bullets changed
  function updateCounts()
  {
    if (!gunInfo)
      return false

    maxBulletsCount = gunInfo.total
    if (!isAmmoFree(unit, selectedName, AMMO.PRIMARY))
    {
      local boughtCount = (getAmmoAmount(unit, selectedName, AMMO.PRIMARY) / guns).tointeger()
      maxBulletsCount = isForcedAvailable? gunInfo.total : ::min(boughtCount, gunInfo.total)

      local bulletsSet = getBulletsSetData(unit, selectedName)
      local maxToRespawn = ::getTblValue("maxToRespawn", bulletsSet, 0)
      if (maxToRespawn > 0)
        maxBulletsCount = ::min(maxBulletsCount, maxToRespawn)
    }

    if (bulletsCount < 0 || bulletsCount <= maxBulletsCount)
      return false

    setBulletsCount(maxBulletsCount)
    return true
  }

  function getGunMaxBullets()
  {
    return ::getTblValue("total", gunInfo, 0)
  }

  function getOption()
  {
    if (!option)
    {
      ::aircraft_for_weapons = unit.name
      option = ::get_option(::USEROPT_BULLETS0 + groupIndex)
    }
    return option
  }

  function _tostring()
  {
    return ::format("BulletGroup( unit = %s, idx = %d, active = %s, selected = %s )",
                    unit.name, groupIndex, active.tostring(), selectedName)
  }

  function getHeader()
  {
    if (!bullets || !unit)
      return ""
    return getBulletsListHeader(unit, bullets)
  }

  function getBulletNameForCode(bulName) {
    local mod = getModByBulletName(bulName)
    return "isDefaultForGroup" in mod? "" : mod.name
  }

  function getModByBulletName(bulName)
  {
    local mod = getModificationByName(unit, bulName)
    if (!mod) //default
      mod = { name = bulName, isDefaultForGroup = groupIndex, type = weaponsItem.modification }
    return mod
  }

  _bulletsModsList = null
  function getBulletsModsList()
  {
    if (!_bulletsModsList)
    {
      _bulletsModsList = []
      foreach(bulName in bullets.values)
        _bulletsModsList.append(getModByBulletName(bulName))
    }
    return _bulletsModsList
  }

  function getSelBullet()
  {
    if (!selectedBullet)
      selectedBullet = getModByBulletName(selectedName)
    return selectedBullet
  }

  function shouldHideBullet()
  {
    return gunInfo?.forcedMaxBulletsInRespawn ?? false
  }
}
