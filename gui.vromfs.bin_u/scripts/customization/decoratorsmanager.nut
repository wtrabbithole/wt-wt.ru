local skinLocations = ::require("scripts/customization/skinLocations.nut")

const DEFAULT_SKIN_NAME = "default"

//code callback
function on_dl_content_skins_invalidate()
{
  ::g_decorator.clearCache()
}

::g_decorator <- {
  cache = {}
  previewedUgcSkinId = ""
  approversUnitToPreviewUgcResource = null
}

function g_decorator::clearCache()
{
  ::g_decorator.cache.clear()
  ::g_decorator.clearUgcPreviewParams()
}

function g_decorator::clearUgcPreviewParams()
{
  ::g_decorator.previewedUgcSkinId = ""
  ::g_decorator.approversUnitToPreviewUgcResource = null
}

function g_decorator::getCachedDataByType(decType)
{
  local id = "proceedData_" + decType.name
  if (id in ::g_decorator.cache)
    return ::g_decorator.cache[id]

  local data = ::g_decorator.splitDecoratorData(decType)
  ::g_decorator.cache[id] <- data
  return data
}

function g_decorator::getCachedDecoratorsDataByType(decType)
{
  local data = ::g_decorator.getCachedDataByType(decType)
  return data.decorators
}

function g_decorator::getCachedOrderByType(decType)
{
  local data = ::g_decorator.getCachedDataByType(decType)
  return data.categories
}

function g_decorator::getCachedDecoratorsListByType(decType)
{
  local data = ::g_decorator.getCachedDataByType(decType)
  return data.decoratorsList
}

function g_decorator::getDecorator(searchId, decType)
{
  if (::u.isEmpty(searchId))
    return null

  local res = decType.getSpecialDecorator(searchId)
  if (res)
    return res

  local res = ::getTblValue(searchId, ::g_decorator.getCachedDecoratorsListByType(decType))
  if (!res)
    ::dagor.debug("Decorators Manager: " + searchId + " was not found in old cache, try update cache")
  return res
}

function g_decorator::getCachedDecoratorByUnlockId(unlockId, decType)
{
  if (::u.isEmpty(unlockId))
    return null

  local path = "decoratorByUnlockId"
  if (!(path in ::g_decorator.cache))
    ::g_decorator.cache[path] <- {}

  if (unlockId in ::g_decorator.cache[path])
    return getDecorator(::g_decorator.cache[path][unlockId], decType)

  local foundDecorator = ::u.search(::g_decorator.getCachedDecoratorsListByType(decType),
      (@(unlockId) function(d) {
        return d.unlockId == unlockId
      })(unlockId))

  if (foundDecorator == null)
    return null

  ::g_decorator.cache[path][unlockId] <- foundDecorator.id
  return foundDecorator
}

function g_decorator::splitDecoratorData(decType)
{
  local result = {
    decorators = {}
    categories = []
    decoratorsList = {}
    fullBlk = null
  }

  local blk = decType.getBlk()
  result.fullBlk = blk
  if (::u.isEmpty(blk))
    return result

  local prevCategory = ""
  for (local c = 0; c < blk.blockCount(); c++)
  {
    local dblk = blk.getBlock(c)
    local category = dblk.category || prevCategory

    if (!(category in result.decorators))
    {
      result.categories.append(category)
      result.decorators[category] <- []
    }

    local decorator = ::Decorator(dblk, decType)
    decorator.category = category
    decorator.catIndex = result.decorators[category].len()

    result.decoratorsList[decorator.id] <- decorator
    if (decorator.isVisible() || decorator.isForceVisible())
      result.decorators[category].append(decorator)
  }

  foreach (category, decoratorsList in result.decorators)
    if (!decoratorsList.len())
    {
      result.categories.remove(::find_in_array(result.categories, category))
      delete result.decorators[category]
    }

  return result
}

function g_decorator::getSkinSaveId(unitName)
{
  return "skins/" + unitName
}

function g_decorator::isAutoSkinAvailable(unitName)
{
  return ::g_unit_type.getByUnitName(unitName).isSkinAutoSelectAvailable()
}

function g_decorator::getLastSkin(unitName)
{
  if (!isAutoSkinAvailable(unitName))
    return ::hangar_get_last_skin(unitName)
  return ::load_local_account_settings(getSkinSaveId(unitName))
}

function g_decorator::getRealSkin(unitName)
{
  local res = getLastSkin(unitName)
  return res || getAutoSkin(unitName)
}

function g_decorator::setLastSkin(unitName, skinName)
{
  if (!isAutoSkinAvailable(unitName))
    return skinName && ::hangar_set_last_skin(unitName, skinName)

  ::save_local_account_settings(getSkinSaveId(unitName), skinName)
  ::hangar_set_last_skin(unitName, skinName || getAutoSkin(unitName))
}

function g_decorator::setCurSkinToHangar(unitName)
{
  if (isAutoSkinAvailable(unitName))
    ::hangar_set_last_skin(unitName, getRealSkin(unitName))
}

//default skin will return when no one skin match location
function g_decorator::getAutoSkin(unitName, isLockedAllowed = false)
{
  local list = getBestSkinsList(unitName, isLockedAllowed)
  if (!list.len())
    return DEFAULT_SKIN_NAME
  return list[list.len() - 1 - (::SessionLobby.roomId % list.len())] //use last skin when no in session
}

function g_decorator::getBestSkinsList(unitName, isLockedAllowed)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return DEFAULT_SKIN_NAME

  local misBlk = ::is_in_flight() ? ::get_current_mission_info_cached()
    : ::get_mission_meta_info(unit.testFlight)
  local level = misBlk?.level
  if (!level)
    return DEFAULT_SKIN_NAME

  local skinsList = []
  foreach(skin in unit.getSkins())
  {
    if (skin.name == "")
      continue
    if (isLockedAllowed)
    {
      skinsList.append(skin.name)
      continue
    }
    local decorator = ::g_decorator.getDecorator(unitName + "/"+ skin.name, ::g_decorator_type.SKINS)
    if (decorator && decorator.isUnlocked())
      skinsList.append(skin.name)
  }
  return skinLocations.getBestSkinsList(skinsList, level)
}

function g_decorator::addSkinItemToOption(option, locName, value, decorator, shouldSetFirst = false)
{
  local idx = shouldSetFirst ? 0 : option.items.len()
  option.items.insert(idx, locName)
  option.values.insert(idx, value)
  option.decorators.insert(idx, decorator)
  option.access.insert(idx, {
    isOwn = true
    unlockId  = ""
    canBuy    = false
    price     = ::zero_money
    isVisible = true
  })
  return option.access[idx]
}

function g_decorator::getSkinsOption(unitName, showLocked=false, needAutoSkin = true)
{
  local descr = {
    items = []
    values = []
    access = []
    decorators = []
    value = 0
  }

  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return descr

  local skins = unit.getSkins()
  for (local skinNo = 0; skinNo < skins.len(); skinNo++)
  {
    local skin = skins[skinNo]
    local isDefault = skin.name.len() == 0
    local skinName = isDefault ? DEFAULT_SKIN_NAME : skin.name // skin ID (default skin stored in profile with name 'default')

    local skinBlockName = unitName + "/"+ skinName

    local isPreviewedUgcSkin = ::has_feature("EnableUgcSkins") && skinBlockName == previewedUgcSkinId
    local decorator = ::g_decorator.getDecorator(skinBlockName, ::g_decorator_type.SKINS)
    if (!decorator)
    {
      if (isPreviewedUgcSkin)
        decorator = ::Decorator(skinBlockName, ::g_decorator_type.SKINS);
      else
        continue
    }

    local isUnlocked = decorator.isUnlocked()
    local isOwn = isDefault || isUnlocked

    if (!isOwn && !showLocked)
      continue

    local forceVisible = isPreviewedUgcSkin

    if (!decorator.isVisible() && !forceVisible)
      continue

    local cost = decorator.getCost()
    local hasPrice = !cost.isZero()
    local isVisible = isDefault || isOwn || hasPrice || ::is_unlock_visible(decorator.unlockBlk)|| forceVisible
    if (!isVisible && !::is_dev_version)
      continue

    local access = addSkinItemToOption(descr, decorator.getName(), skinName, decorator)
    access.isOwn = isOwn
    access.unlockId  = !isOwn && decorator.unlockBlk ? decorator.unlockId : ""
    access.canBuy    = decorator.canBuyUnlock(unit)
    access.price     = cost
    access.isVisible = isVisible
  }

  if (needAutoSkin && isAutoSkinAvailable(unitName))
  {
    local autoSkin = getAutoSkin(unitName)
    local decorator = ::g_decorator.getDecorator(unitName + "/"+ autoSkin, ::g_decorator_type.SKINS)
    local locName = ::loc("skins/auto", { skin = decorator ? decorator.getName() : "" })
    addSkinItemToOption(descr, locName, null, decorator, true)
  }

  local curSkin = getLastSkin(unit.name)
  descr.value = ::find_in_array(descr.values, curSkin, 0)

  return descr
}

function g_decorator::onEventSignOut(p)
{
  ::g_decorator.clearCache()
}

function g_decorator::onEventLoginComplete(p)
{
  ::g_decorator.clearCache()
}

::subscribe_handler(::g_decorator, ::g_listener_priority.CONFIG_VALIDATION)
