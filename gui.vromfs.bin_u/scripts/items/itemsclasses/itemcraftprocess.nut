local ItemExternal = ::require("scripts/items/itemsClasses/itemExternal.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")

class ::items_classes.CraftProcess extends ItemExternal {
  static iType = itemType.CRAFT_PROCESS
  static defaultLocId = "craft_part"
  static typeIcon = "#ui/gameuiskin#item_type_craftpart"

  static itemExpiredLocId = "items/craft_process/finished"
  static descReceipesListWithCurQuantities = false
  static confirmCancelCraftLocId = "msgBox/cancelCraftProcess/confirm"
  static cancelCaptionLocId = "mainmenu/craftCanceled/title"

  canConsume          = @() false
  canAssemble         = @() false
  canConvertToWarbonds= @() false
  hasLink             = @() false

  getMainActionData   = @(...) null
  doMainAction        = @(...) false
  getAltActionName    = @(...) ""
  doAltAction         = @(...) false

  shouldShowAmount    = @(count) count >= 0
  getDescRecipeListHeader = @(...) ::loc("items/craft_process/using") // there is always 1 recipe
  getMarketablePropDesc = @() ""
  getCantUseLocId       = @() "msgBox/cancelCraftProcess/cant"

  function cancelCrafting(cb = null, params = null)
  {
    if (uids.len() > 0)
    {
      local parentItem = params?.parentItem
      local item = this
      local text = ::loc("msgBox/cancelCraftProcess/confirm",
        { itemName = ::colorize("activeTextColor", parentItem ? parentItem.getName() : getName()) })
      ::scene_msg_box("craft_canceled", null, text, [
        [ "yes", @() inventoryClient.cancelDelayedExchange(item.uids[0],
                     @(resultItems) item.onCancelComplete(resultItems)) ],
        [ "no" ]
      ], "yes", { cancel_fn = function() {} })
      return true
    }

    showCantCancelCraftMsgBox()
    return true
  }

  showCantCancelCraftMsgBox = @() ::scene_msg_box("cant_cancel_craft",
    null,
    ::colorize("badTextColor", ::loc(getCantUseLocId())),
    [["ok", @() ::ItemsManager.refreshExtInventory()]],
    "ok")

  function onCancelComplete(resultItems)
  {
    if (!!resultItems?.error)
      return showCantCancelCraftMsgBox()

    ::ItemsManager.markInventoryUpdate()

    local isShowOpening  = @(extItem) extItem?.itemdef?.type == "item"
    local resultItemsShowOpening  = ::u.filter(resultItems, isShowOpening)
    local trophyId = id
    if (resultItemsShowOpening.len())
    {
      local openTrophyWndConfigs = u.map(resultItemsShowOpening, @(extItem) {
        id = trophyId
        item = extItem?.itemdef?.itemdefid
        count = extItem?.quantity ?? 0
      })
      ::gui_start_open_trophy({ [trophyId] = openTrophyWndConfigs,
        rewardTitle = ::loc(cancelCaptionLocId),
        rewardListLocId = getItemsListLocId() })
    }
  }
}
