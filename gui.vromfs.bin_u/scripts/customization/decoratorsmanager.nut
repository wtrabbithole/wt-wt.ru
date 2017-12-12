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

function g_decorator::getSkinsOption(unitName, showLocked=false)
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

  if (unit.skins.len() == 0)
    unit.skins = get_skins_for_unit(unitName) //always returns at least one entry

  for (local skinNo = 0; skinNo < unit.skins.len(); skinNo++)
  {
    local skin = unit.skins[skinNo]
    local isDefault = skin.name.len() == 0
    local skinName = isDefault ? "default" : skin.name

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

    descr.decorators.append(decorator)
    descr.items.append(decorator.getName())
    descr.values.append(skinName) // skin ID (default skin stored in profile with name 'default')
    descr.access.append({
      isOwn = isOwn
      unlockId  = !isOwn && decorator.unlockBlk ? decorator.unlockId : ""
      canBuy    = decorator.canBuyUnlock(unit)
      price     = cost
      isVisible = isVisible
    })
  }

  local curSkin = ::hangar_get_last_skin(unit.name)
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
