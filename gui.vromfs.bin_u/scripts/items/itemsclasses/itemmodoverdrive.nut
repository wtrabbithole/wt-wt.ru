local BaseItemModClass = ::require("scripts/items/itemsClasses/itemModBase.nut")
local callback = ::require("sqStdLibs/helpers/callback.nut")

class ::items_classes.ModOverdrive extends BaseItemModClass
{
  static iType = itemType.MOD_OVERDRIVE
  static defaultLocId = "modOverdrive"
  static defaultIcon = "#ui/gameuiskin#items_orders_revenge"
  static typeIcon = "#ui/gameuiskin#items_orders_revenge"

  canBuy = true
  allowBigPicture = false
  isActiveOverdrive = false

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)

    isActiveOverdrive = slotData?.isActive ?? false
  }

  getConditionsBlk = @(configBlk) configBlk.modOverdriveParams
  canActivate = @() isInventoryItem && !isActive()
  isActive = @(...) isActiveOverdrive

  function getMainActionName(isColored = true, isShort = false)
  {
    if (canActivate())
      return ::loc("item/activate")
    return base.getMainActionName(isColored, isShort)
  }

  function doMainAction(cb, handler, params = null)
  {
    if (canActivate())
      return activate(cb, handler)
    return base.doMainAction(cb, handler, params)
  }

  function activate(cb, handler = null)
  {
    local uid = uids?[0]
    if (uid == null)
      return false

    local blk = ::DataBlock()
    blk.uid = uid
    local item = this
    local taskId = ::char_send_blk("cln_activate_mod_overdrive_item", blk)
    return ::g_tasker.addTask(
      taskId,
      {
        showProgressBox = true
        progressBoxDelayedButtons = 30
      },
      @() cb && cb({ success = true, item = item })
    )
  }
}