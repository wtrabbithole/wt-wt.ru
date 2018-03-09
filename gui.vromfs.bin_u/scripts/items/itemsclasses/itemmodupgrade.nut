local BaseItemModClass = ::require("scripts/items/itemsClasses/itemModBase.nut")

class ::items_classes.ModUpgrade extends BaseItemModClass
{
  static iType = itemType.MOD_UPGRADE
  static defaultLocId = "modUpgrade"
  static defaultIcon = "#ui/gameuiskin#itemtype_modifications"
  static typeIcon = "#ui/gameuiskin#itemtype_modifications"

  canBuy = true
  allowBigPicture = false

  level = 0

  getConditionsBlk = @(configBlk) configBlk.modUpgradeParams

  function initConditions(conditionsBlk)
  {
    base.initConditions(conditionsBlk)
    level = conditionsBlk.level || 0
  }

  function getDescriptionIntroArray()
  {
    if (level)
      return [ ::loc("multiplayer/level") + ::loc("ui/colon") + ::colorize("activeTextColor", level) ]
    return null
  }

  function canActivateOnMod(unit, mod)
  {
    if (modsList && !::isInArray(mod.name, modsList))
      return false
    if (countries && !::isInArray(unit.shopCountry, countries))
      return false
    if (rankRange && (unit.rank < rankRange.x || unit.rank > rankRange.y))
      return false
    if (unitTypes && !::isInArray(unit.unitType.lowerName, unitTypes))
      return false
    if (level - 1 != ::get_modification_level(unit.name, mod.name))
      return false
    return true
  }

  function activateOnMod(unit, mod, extSuccessCb = null)
  {
    local uid = uids?[0]
    if (uid == null)
      return false

    local successCb = function() {
      if (extSuccessCb)
        extSuccessCb()
      ::broadcastEvent("ModUpgraded", { unit = unit, mod = mod })
    }

    local blk = ::DataBlock()
    blk.uid = uid
    blk.unit = unit.name
    blk.mod = mod.name

    local item = this
    ::g_tasker.addTask(
      ::char_send_blk("cln_upgrade_modification_item", blk),
      {
        showProgressBox = true
        progressBoxDelayedButtons = 30
      },
      successCb
    )
  }
}