local guidParser = require("scripts/guidParser.nut")

local downloadTimeoutSec = 15
local downloadProgressBox = null

local waitingItemDefId = null

/**
 * Starts Customization scene with given unit and optional skin.
 * @param {string} unitId - Unit to show.
 * @param {string|null} [skinId] - Skin to apply. Use null for default skin.
 * @param {boolean} [isForApprove] - Enables UI for skin approvement.
 */
local function showUnitSkin(unitId, skinId = null, isForApprove = false)
{
  if (!::ItemsManager.canPreviewItems())
    return

  local unit = ::getAircraftByName(unitId)
  if (!unit)
    return false

  local unitPreviewSkin = unit.getPreviewSkinId()
  skinId = skinId || unitPreviewSkin

  ::broadcastEvent("BeforeStartShowroom")
  ::show_aircraft = unit
  local startFunc = function() {
    ::gui_start_decals({
      previewMode = skinId == unitPreviewSkin ? PREVIEW_MODE.UNIT : PREVIEW_MODE.SKIN
      previewParams = {
        unitName = unitId
        skinName = skinId
        isForApprove = isForApprove
      }
    })
  }
  startFunc()
  ::handlersManager.setLastBaseHandlerStartFunc(startFunc)

  return true
}

/**
 * Starts Customization scene with some conpatible unit and given decorator.
 * @param {string|null} unitId - Unit to show. Use null to auto select some compatible unit.
 * @param {string} resource - Resource.
 * @param {string} resourceType - Resource type.
 */
local function showUnitDecorator(unitId, resource, resourceType)
{
  if (!::ItemsManager.canPreviewItems())
    return

  local decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
  if (decoratorType == ::g_decorator_type.UNKNOWN)
    return false

  local decorator = ::g_decorator.getDecorator(resource, decoratorType)
  if (!decorator)
    return false

  local hangarUnit = ::get_player_cur_unit()

  local unit = null
  if (unitId)
  {
    unit = ::getAircraftByName(unitId)
    if (! decoratorType.isAvailable(unit))
      return false
  }
  else
  {
    unit = hangarUnit
    if (! decoratorType.isAvailable(unit))
      unit = ::getAircraftByName(::getReserveAircraftName({
        country = ::get_profile_country_sq()
        unitType = ::ES_UNIT_TYPE_TANK
        ignoreSlotbarCheck = true
      }))
    if (! decoratorType.isAvailable(unit))
      unit = ::getAircraftByName(::getReserveAircraftName({
        country = "country_usa"
        unitType = ::ES_UNIT_TYPE_TANK
        ignoreSlotbarCheck = true
      }))
    if (! decoratorType.isAvailable(unit))
      return false
  }

  ::broadcastEvent("BeforeStartShowroom")
  ::show_aircraft = unit
  local startFunc = function() {
    ::gui_start_decals({
      previewMode = PREVIEW_MODE.DECORATOR
      initialUnitId = hangarUnit?.name
      previewParams = {
        unitName = unit.name
        decorator = decorator
      }
    })
  }
  startFunc()
  ::handlersManager.setLastBaseHandlerStartFunc(startFunc)

  return true
}

/**
 * If resource id GUID, then downloads it first.
 * Then starts Customization scene with given resource preview.
 * @param {string} resource - Resource. Can be GUID.
 * @param {string} resourceType - Resource type.
 */
local function showResource(resource, resourceType)
{
  if (!::ItemsManager.canPreviewItems())
    return

  if (guidParser.isGuid(resource))
  {
    downloadProgressBox = ::scene_msg_box("ugc_resource_requested", null, ::loc("msgbox/please_wait"),
      [["cancel"]], "cancel", { waitAnim = true, delayedButtons = downloadTimeoutSec })
    ::ugc_preview_resource_by_guid(resource, resourceType)
  }
  else
  {
    if (resourceType == "skin")
    {
      local unitId = ::g_unlocks.getPlaneBySkinId(resource)
      local skinId  = ::g_unlocks.getSkinNameBySkinId(resource)
      showUnitSkin(unitId, skinId)
    }
    else if (resourceType == "decal" || resourceType == "attachable")
    {
      showUnitDecorator(null, resource, resourceType)
    }
  }
}

local function ugcSkinPreview(params)
{
  if (!::has_feature("EnableUgcSkins"))
    return "not_allowed"
  if (!::g_login.isLoggedIn())
    return "not_logged_in"
  if (!::is_in_hangar())
    return "not_in_hangar"
  if (!hangar_is_loaded())
    return "hangar_not_ready"
  if (!::ItemsManager.canPreviewItems())
    return "temporarily_forbidden"

  local blkHashName = params.hash
  local name = params?.name ?? "testName"
  local shouldPreviewForApprove = params?.previewForApprove ?? false
  local res = shouldPreviewForApprove ? ::ugc_preview_resource_for_approve(blkHashName, "skin", name)
                                      : ::ugc_preview_resource(blkHashName, "skin", name)
  return res.result
}

local function onSkinDownloaded(unitId, skinId, result)
{
  if (downloadProgressBox)
    ::destroyMsgBox(downloadProgressBox)
  if (result)
    showUnitSkin(unitId, skinId)
}

local function marketViewItem(params)
{
  if (::to_integer_safe(params?.appId, 0, false) != ::WT_APPID)
    return
  local assets = ::u.filter(params?.assetClass ?? [], @(asset) asset?.name == "__itemdefid")
  if (!assets.len())
    return
  local itemDefId = ::to_integer_safe(assets?[0]?.value)
  local item = ::ItemsManager.findItemById(itemDefId)
  if (!item)
  {
    waitingItemDefId = itemDefId
    return
  }
  waitingItemDefId = null
  if (item.canPreview() && ::ItemsManager.canPreviewItems())
    item.doPreview()
}

local function onEventItemsShopUpdate(params)
{
  if (waitingItemDefId == null)
    return
  local item = ::ItemsManager.findItemById(waitingItemDefId)
  if (!item)
    return
  waitingItemDefId = null
  if (item.canPreview() && ::ItemsManager.canPreviewItems())
    item.doPreview()
}


/**
 * Creates global funcs, which are called from client.
 */
local rootTable = ::getroottable()
rootTable["on_ugc_skin_data_loaded"] <- @(unitId, skinGuid, result) onSkinDownloaded(unitId, skinGuid, result)
rootTable["ugc_start_unit_preview"]  <- @(unitId, skinId, isForApprove) showUnitSkin(unitId, skinId, isForApprove)
web_rpc.register_handler("ugc_skin_preview", @(params) ugcSkinPreview(params))
web_rpc.register_handler("market_view_item", @(params) marketViewItem(params))
::subscribe_events({
  ItemsShopUpdate = @(p) onEventItemsShopUpdate(p)
})

return {
  showUnitSkin = showUnitSkin
  showResource = showResource
}
