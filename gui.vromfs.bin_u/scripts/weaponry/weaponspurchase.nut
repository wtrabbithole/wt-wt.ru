local unitActions = require("scripts/unit/unitActions.nut")
local { getModItemName } = require("scripts/weaponry/weaponryVisual.nut")
local { getWeaponByName } = require("scripts/weaponry/weaponryInfo.nut")
local { getModificationByName } = require("scripts/weaponry/modificationInfo.nut")
local { getItemCost,
        getAllModsCost,
        getItemStatusTbl,
        getItemUnlockCost } = require("scripts/weaponry/itemInfo.nut")

::WeaponsPurchase <- class
{
  static PROCESS_TIME_OUT = 60000

  static activePurchaseProcess = []   //cant modify static self
  processStartTime = -1

  unit = null

  silent = false
  open = false
  checkRepair = true

  modItem = null
  modName = ""
  modType = -1

  mainFunc = null
  cost = null

  afterSuccessfullPurchaseCb = null
  onFinishCb = null

  msgLocId = ""
  repairMsgLocId = ""
  msgLocParams = {}

  constructor(_unit, _additionalParams = {})
  {
    if (::u.isString(_unit))
      unit = ::getAircraftByName(_unit)
    else
      unit = _unit

    if (::u.isEmpty(unit))
      return

    if (activePurchaseProcess.len())
      if (::dagor.getCurTime() - activePurchaseProcess[0].processStartTime < PROCESS_TIME_OUT)
        return ::dagor.assertf(false, "Error: trying to use 2 modification purchase processes at once")
      else
        activePurchaseProcess[0].remove()

    activePurchaseProcess.append(this)
    processStartTime = ::dagor.getCurTime()

    silent = _additionalParams?.silent ?? false
    open = _additionalParams?.open ?? false
    afterSuccessfullPurchaseCb = _additionalParams?.afterSuccessfullPurchaseCb ?? function(){}
    onFinishCb = _additionalParams?.onFinishCb

    modItem = ::getTblValue("modItem", _additionalParams)
    if (!::u.isEmpty(modItem))
    {
      modName = modItem.name
      modType = modItem.type
    }

    checkMultiPurchase()
  }

  function remove()
  {
    foreach(idx, process in activePurchaseProcess)
      if (process == this)
        activePurchaseProcess.remove(idx)
    onFinishCb?()
  }

  function getAllModificationsPrice()
  {
    local _modsCost = getAllModsCost(unit, open)
    return ::Cost(_modsCost.wp, open? _modsCost.gold : 0)
  }

  function getPrice()
  {
    if (::u.isEmpty(modItem))
      return getAllModificationsPrice()

    if (::g_weaponry_types.getUpgradeTypeByItem(modItem).canBuy(unit, modItem))
      return getItemCost(unit, modItem)

    return getItemUnlockCost(unit, modItem)
  }

  function checkMultiPurchase()
  {
    local canBuyAmount = 1
    if (!::u.isEmpty(modItem) && modType != weaponsItem.primaryWeapon)
    {
      local statusTbl = getItemStatusTbl(unit, modItem)
      if (!statusTbl.canBuyMore)
      {
        if (statusTbl.showPrice)
          ::g_popups.add("", ::loc("weaponry/enoughAmount"), null, null, null, "enough_amount")
        return remove()
      }

      canBuyAmount = statusTbl.maxAmount - statusTbl.amount
    }

    if (canBuyAmount == 1)
      return execute(canBuyAmount)

    local params = {
      item = modItem
      unit = unit
      buyFunc = ::Callback(function(amount) { execute(amount, false) }, this)
      onExitFunc = ::Callback(function() { remove() }, this)
    }

    ::gui_start_modal_wnd(::gui_handlers.MultiplePurchase, params)
  }

  function fillModItemSpecificParams(amount = 1)
  {
    cost = getPrice()

    if (::u.isEmpty(modItem))
      return fillAllModsParams()

    getCorrectedByAmountCost(amount)

    if (modItem.type == weaponsItem.spare)
      return fillSpareParams(amount)

    if (modItem.type == weaponsItem.weapon)
      return fillWeaponParams(amount)

    return fillModificationParams(amount)
  }

  function canBuyForEagles(_cost)
  {
    if (_cost.isZero())
      return false

    if (_cost.gold > 0)
    {
      if (!::has_feature("SpendGold"))
        return false

      if (!::can_spend_gold_on_unit_with_popup(unit))
        return false
    }

    return true
  }

  function canBuyItem(_cost, afterRefillFunc = null)
  {
    if (_cost.isZero())
      return false

    if (!canBuyForEagles(_cost))
      return false

    if (!::check_balance_msgBox(_cost, afterRefillFunc, silent))
      return false

    return true
  }

//-------------- <BUY ALL MODS> --------------------------------------
  function fillAllModsParams()
  {
    mainFunc = ::Callback(function(amount) { sendPurchaseAllModsRequest(amount) }, this)
    msgLocId = "shop/needMoneyQuestion_all_weapons"
    repairMsgLocId = "msgBox/repair_and_mods_purchase"
    msgLocParams = {
      unitName = ::colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseAllModsRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["unit"] = unit.name
    blk["forceOpen"] = open
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local taskId = ::char_send_blk("cln_buy_all_modification", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::broadcastEvent("ModificationPurchased", {unit = unit})
      ::updateAirAfterSwitchMod(unit, "")

      afterSuccessfullPurchaseCb()
    })(unit, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    remove()
  }

//-------------- </BUY ALL MODS> --------------------------------------

  function execute(amount = 1, removeOnCancel = true)
  {
    fillModItemSpecificParams(amount)

    if (!canBuyItem(cost))
    {
      if (removeOnCancel)
        remove()
      return
    }

    local repairCost = checkRepair? unit.getRepairCost() : ::Cost()
    local price = cost + repairCost
    msgLocParams.cost <- price.getTextAccordingToBalance()

    local performAction = (@(repairCost, mainFunc, amount, removeOnCancel) function() {
      if (repairCost.isZero())
        mainFunc(amount)
      else
        repair(::Callback((@(amount) function() { mainFunc(amount)})(amount), this),
               ::Callback((@(amount, removeOnCancel) function() { execute(amount, removeOnCancel)})(amount, removeOnCancel), this))
    })(repairCost, mainFunc, amount, removeOnCancel)

    if (silent)
      return performAction()

    local cancelAction = (@(removeOnCancel) function() {
      if (removeOnCancel)
        remove()
    })(removeOnCancel)

    local text = ::warningIfGold(
        ::loc(repairCost.isZero()? msgLocId : repairMsgLocId,
        msgLocParams
      ), price)
    local defButton = "yes"
    local buttons = [
      ["yes", performAction ],
      ["no", cancelAction]
    ]
    ::scene_msg_box("mechanic_execute_msg", null, text, buttons, defButton,
      { cancel_fn = cancelAction, baseHandler = this})
  }

//-------------- <BUY SINGLE MOD> --------------------------------------

  function fillModificationParams(amount = 1)
  {
    mainFunc = ::Callback(function(amount)
      { sendPurchaseModificationRequest(amount) }, this)
    msgLocId = open? "shop/needMoneyQuestion_purchaseModificationForGold"
      : "onlineShop/needMoneyQuestion"
    repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      unitName = ::colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseModificationRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["aircraft"] = unit.name
    blk["modification"] = modName
    blk["open"] = open
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local hadUnitModResearch = ::shop_get_researchable_module_name(unit.name)
    local taskId = ::char_send_blk("cln_buy_modification", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, modName, hadUnitModResearch, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::updateAirAfterSwitchMod(unit, modName)

      local newResearch = ::shop_get_researchable_module_name(unit.name)
      if (::u.isEmpty(newResearch) && !::u.isEmpty(hadUnitModResearch))
        ::broadcastEvent("AllModificationsPurchased", {unit = unit})

      ::broadcastEvent("ModificationPurchased", {unit = unit, modName = modName})

      afterSuccessfullPurchaseCb()
    })(unit, modName, hadUnitModResearch, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    remove()
  }

//-------------- </BUY SINGLE MOD> --------------------------------------

//-------------- <BUY WEAPON> --------------------------------------

  function fillWeaponParams(amount = 1)
  {
    mainFunc = ::Callback(function(amount) { sendPurchaseWeaponRequest(amount) }, this)
    checkRepair = false
    msgLocId = "onlineShop/needMoneyQuestion"
    repairMsgLocId = "msgBox/repair_and_single_mod_purchase"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      unitName = ::colorize("userlogColoredText", ::getUnitName(unit))
      cost = cost
    }
  }

  function sendPurchaseWeaponRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["aircraft"] = unit.name
    blk["weapon"] = modName
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local taskId = ::char_send_blk("cln_buy_weapon", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, modName, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::updateAirAfterSwitchMod(unit)
      ::broadcastEvent("WeaponPurchased", {unit = unit, weaponName = modName})
      afterSuccessfullPurchaseCb()
    })(unit, modName, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    remove()
  }

//-------------- </BUY WEAPON> --------------------------------------

//-------------- <BUY SPARE> --------------------------------------

  function fillSpareParams(amount = 1)
  {
    mainFunc = ::Callback(function(amount) { sendPurchaseSpareRequest(amount) }, this)
    checkRepair = false
    msgLocId = "onlineShop/needMoneyQuestion"
    msgLocParams = {
      purchase = getItemTextWithAmount(amount)
      cost = cost
    }
  }

  function sendPurchaseSpareRequest(amount = 1)
  {
    local blk = ::DataBlock()
    blk["aircraft"] =  unit.name
    blk["count"] = amount
    blk["cost"] = cost.wp
    blk["costGold"] = cost.gold

    local taskId = ::char_send_blk("cln_buy_spare_aircrafts", blk)
    local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
    local afterOpFunc = (@(unit, afterSuccessfullPurchaseCb) function() {
      ::update_gamercards()
      ::broadcastEvent("SparePurchased", {unit = unit})
      afterSuccessfullPurchaseCb()
    })(unit, afterSuccessfullPurchaseCb)

    ::g_tasker.addTask(taskId, taskOptions, afterOpFunc)
    remove()
  }

//-------------- </BUY SPARE> --------------------------------------

//-------------- <REPAIR> --------------------------------------

  function repair(afterSuccessFunc = null, afterBalanceRefillFunc = null)
  {
    local repairCost = unit.getRepairCost()
    if (!canBuyItem(repairCost, afterBalanceRefillFunc))
    {
      remove()
      return false
    }

    unitActions.repair(unit, afterSuccessFunc)
    return true
  }

//-------------- </REPAIR> --------------------------------------

  function getItemByName(itemName, itemType)
  {
    if (itemName == "")
      return null

    if (itemType == weaponsItem.weapon)
    {
      local item = getWeaponByName(unit, itemName)
      if (!::u.isEmpty(item))
        return item
    }

    local item = getModificationByName(unit, itemName)
    if (!::u.isEmpty(item))
      return item

    return ::getTblValue(itemName, unit)
  }

  function getCorrectedByAmountCost(amount = 1)
  {
    return cost.multiply(amount)
  }

  function getItemTextWithAmount(amount)
  {
    local text = getModItemName(unit, modItem, false)
    if (amount > 1)
      text += " " + ::colorize("activeTextColor", ::format(::loc("weapons/counter/right/short"), amount))

    return ::colorize("userlogColoredText", text)
  }
}
