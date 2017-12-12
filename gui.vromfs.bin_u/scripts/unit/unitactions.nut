local function repairRequest(unit, onSuccessCb = null)
{
  local blk = ::DataBlock()
  blk.setStr("name", unit.name)

  local taskId = ::char_send_blk("cln_prepare_aircraft", blk)

  local progBox = { showProgressBox = true }
  local onTaskSuccess = function() {
    ::broadcastEvent("UnitRepaired", {unit = unit})
    if (onSuccessCb)
      onSuccessCb()
  }

  ::g_tasker.addTask(taskId, progBox, onTaskSuccess)
}

local function repair(unit, onSuccessCb = null)
{
  if (!unit)
    return
  local price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  if (::check_balance_msgBox(price))
    repairRequest(unit, onSuccessCb)
}

local function repairWithMsgBox(unit, onSuccessCb = null)
{
  if (!unit)
    return
  local price = unit.getRepairCost()
  if (price.isZero())
    return onSuccessCb && onSuccessCb()

  local msgText = ::loc("msgbox/question_repair", { unitName = ::loc(::getUnitName(unit)), cost = price.tostring() })
  ::scene_msg_box("question_quit_game", null, msgText,
  [
    ["yes", function() { repair(unit, onSuccessCb) }],
    ["no", function() {} ]
  ], "no", { cancel_fn = function() {}})
}

return {
  repair = repair
  repairWithMsgBox = repairWithMsgBox
}