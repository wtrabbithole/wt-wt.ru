local guidParser = require("scripts/guidParser.nut")

local downloadTimeoutSec = 15
local downloadProgressBox = null

/**
 * Starts Customization scene with given unit and optional skin.
 * @param {string} unitId - Unit to show.
 * @param {string|null} [skinId] - Skin to apply. Use null for current skin.
 * @param {boolean} [isForApprove] - Enables UI for skin approvement.
 */
local function showUnitSkin(unitId, skinId = null, isForApprove = false)
{
  local unit = ::getAircraftByName(unitId)
  if (!unit)
    return false

  ::broadcastEvent("ShowroomOpened")
  ::show_aircraft = unit
  ::gui_start_decals()
  if (skinId)
    ::broadcastEvent("SelectUGCSkinForPreview", { unitName = unitId, skinName = skinId, isForApprove = isForApprove })

  return true
}

/**
 * If resource id GUID, then downloads it first.
 * Then starts Customization scene with given unit and skin.
 * @param {string} resource - Resource. Can be GUID.
 * @param {string} resourceType - Resource type.
 */
local function showResource(resource, resourceType)
{
  if (guidParser.isGuid(resource))
  {
    downloadProgressBox = ::scene_msg_box("ugc_resource_requested", null, ::loc("msgbox/please_wait"),
      [["cancel"]], "cancel", { waitAnim = true, delayedButtons = downloadTimeoutSec })
    ::ugc_preview_resource_by_guid(resource, resourceType)
  }
  else
  {
    local unitId = ::g_unlocks.getPlaneBySkinId(resource)
    local skinId  = ::g_unlocks.getSkinNameBySkinId(resource)
    showUnitSkin(unitId, skinId)
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

/**
 * Creates global funcs, which are called from client.
 */
local function registerClientCb()
{
  local rootTable = ::getroottable()
  rootTable["on_ugc_skin_data_loaded"] <- @(unitId, skinGuid, result) onSkinDownloaded(unitId, skinGuid, result)
  rootTable["ugc_start_unit_preview"]  <- @(unitId, skinId, isForApprove) showUnitSkin(unitId, skinId, isForApprove)
  web_rpc.register_handler("ugc_skin_preview", @(params) ugcSkinPreview(params))
}

return {
  registerClientCb = registerClientCb
  showUnitSkin = showUnitSkin
  showResource = showResource
}
