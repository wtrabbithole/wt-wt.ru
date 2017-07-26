class ::gui_handlers.CrewBuyPointsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptyFrame.blk"
  sceneTplName = "gui/crew/crewBuyPoints"
  buyPointsPacks = null
  crew = null

  function initScreen()
  {
    buyPointsPacks = createBuyPointsPacks()
    scene.findObject("wnd_title").setValue(::loc("mainmenu/btnBuySkillPoints")+::loc("ui/colon"))

    local rootObj = scene.findObject("wnd_frame")
    rootObj["class"] = "wnd"
    loadSceneTpl()
  }

  function loadSceneTpl()
  {
    local rows = []
    local price = getBasePrice()
    foreach(idx, pack in buyPointsPacks)
    {
      local skills = pack.skills || 1
      local bonusDiscount = price ? floor(100.5 - 100.0 * pack.cost / skills / price) : 0
      local bonusText = bonusDiscount ? format(::loc("charServer/entitlement/discount"), bonusDiscount) : ""

      rows.append({
        id = getRowId(idx)
        rowIdx = idx
        even = idx % 2 == 0
        skills = ::get_crew_sp_text(skills)
        bonusText = bonusText
        cost = ::getPriceText(0, pack.cost)
      })
    }

    local view = { rows = rows }
    local data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(scene.findObject("wnd_content"), data, data.len(), this)

    updateRows()
  }

  function updateRows()
  {
    local tblObj = scene.findObject("buy_table")
    foreach(idx, pack in buyPointsPacks)
      ::showDiscount(tblObj.findObject("buy_discount_" + idx),
                     "skills", ::crews_list[crew.idCountry].country, pack.name)
  }

  function getRowId(i)
  {
    return "buy_row" + i
  }

  function getBasePrice()
  {
    foreach(idx, pack in buyPointsPacks)
      if (pack.cost)
        return pack.cost.tofloat() / (pack.skills || 1)
    return 0
  }

  function onButtonRowApply(obj)
  {
    if (!checkObj(obj) || obj.id != "buttonRowApply")
    {
      local tblObj = scene.findObject("buy_table")
      if (!::checkObj(tblObj))
        return
      local idx = tblObj.getValue()
      local rowObj = tblObj.getChild(idx)
      if (!::checkObj(rowObj))
        return
      obj = rowObj.findObject("buttonRowApply")
    }

    if (::checkObj(obj))
      doBuyPoints(obj)
  }

  function doBuyPoints(obj)
  {
    local row = ::g_crew.getButtonRow(obj, scene, scene.findObject("buy_table"))
    if (!(row in buyPointsPacks) || progressBox)
      return

    local pack = buyPointsPacks[row]
    local locParams = {
      amount = ::getCrewSpText(pack.skills)
      cost = ::getPriceText(0, pack.cost)
    }
    local msgText = ::loc("shop/needMoneyQuestion_buySkillPoints", locParams)
    msgBox("purchase_ask", msgText,
      [["yes", (@(pack) function() {
          if (!::old_check_balance_msgBox(0, pack.cost))
            return

          taskId = shop_purchase_skillpoints(crew.id, pack.name)
          if (taskId < 0)
            return

          ::set_char_cb(this, slotOpCb)
          showTaskProgressBox()
          afterSlotOp = function() {
            ::broadcastEvent("CrewSkillsChanged", { crew = crew })

            if (!::checkObj(scene))
              return

            goBack()
          }
        })(pack)
      ], ["no", function(){}]], "yes", { cancel_fn = function(){}})
  }

  function createBuyPointsPacks()
  {
    local blk = ::get_warpoints_blk()
    if (!blk.crewSkillPointsCost)
      return []

    local country = ::crews_list[crew.idCountry].country
    local result = []
    foreach(block in blk.crewSkillPointsCost)
    {
      local blkName = block.getBlockName()
      result.append({
        name = blkName
        cost = ::wp_get_skill_points_cost_gold(blkName, country)
        skills = block.crewExp || 1
      })
    }
    return result
  }
}
