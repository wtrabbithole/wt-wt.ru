class ::gui_handlers.WwOperationDescriptionCustomHandler extends ::gui_handlers.WwMapDescription
{
  unitStringTpl = "gui/commonParts/shortUnitString"
  sceneTplTeamStrenght = "gui/worldWar/wwOperationDescriptionSideStrenght"
  sceneTplTeamArmyGroups = "gui/worldWar/wwOperationDescriptionSideArmyGroups"

  wwMap = null

  function setDescItem(newDescItem)
  {
    if (!(newDescItem instanceof ::WwOperation))
      return

    base.setDescItem(newDescItem)
  }

  function updateView()
  {
    local isVisible = isVisible()
    updateVisibilities(isVisible)
    if (!isVisible)
      return

    updateDescription()

    wwMap = descItem.getMap()
    if (::u.isEmpty(wwMap))
      return

    updateStatus()
    updateTeamsInfo()
    updateMap()
  }

  function updateDescription()
  {
    local desctObj = scene.findObject("item_desc")
    if (::checkObj(desctObj))
      desctObj.setValue(descItem.getDescription(false))
  }

  function updateMap()
  {
    local taskId = ::ww_preview_operation(descItem.id)
    if (taskId < 0)
    {
      ::ww_stop_preview()
      return
    }

    ::g_world_war_render.setPreviewCategories()

    local taskCallback = ::Callback(function() {
      updateStatus()
      updateTeamsInfo()
    }, this)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, taskCallback)

    local mapNestObj = scene.findObject("map_nest_obj")
    if (!::checkObj(mapNestObj))
      return

    local descObj = scene.findObject("item_desc")
    local itemDescHeight = ::checkObj(descObj) ? descObj.getSize()[1] : 0
    local startDataObj = scene.findObject("operation_start_date")
    local statusTextHeight = ::checkObj(startDataObj) ? 2*startDataObj.getSize()[1] : 0

    local maxHeight = guiScene.calcString("ph-2@blockInterval", mapNestObj) - itemDescHeight - statusTextHeight
    local minSize = maxHeight
    local top = guiScene.calcString("2@blockInterval", mapNestObj) + itemDescHeight
    foreach(side in ::g_world_war.getCommonSidesOrder())
    {
      local sideStrenghtObj = scene.findObject("strenght_" + ::ww_side_val_to_name(side))
      if (::checkObj(sideStrenghtObj))
      {
        local curWidth = ::g_dagui_utils.toPixels(
          guiScene,
          "pw-2*(" + sideStrenghtObj.getSize()[0] + "+1@blockInterval+2@framePadding)",
          mapNestObj
        )

        minSize = ::min(minSize, curWidth)
      }
    }

    mapNestObj.width = minSize
    mapNestObj.pos = "50%pw-50%w, 0.5*(" + maxHeight + "-" + minSize + ")+" + top
  }

  function updateStatus()
  {
    local startDateObj = scene.findObject("operation_start_date")
    if (::checkObj(startDateObj))
      startDateObj.setValue(
        ::loc("worldwar/operation/started", { date = descItem.getStartDateTxt() })
      )

    local activeBattlesCountObj = scene.findObject("operation_active_battles_count")
    if (::checkObj(activeBattlesCountObj))
    {
      local battlesCount = ::g_world_war.getBattles(
        function(wwBattle) {
          return wwBattle.isActive()
        },
        true
      ).len()

      activeBattlesCountObj.setValue(
        battlesCount > 0
          ? ::loc("worldwar/operation/activeBattlesCount", { count = battlesCount } )
          : ::loc("worldwar/operation/noActiveBattles")
      )
    }

    local isClanParticipateObj = scene.findObject("is_clan_participate_text")
    if (::checkObj(isClanParticipateObj))
    {
      local isMyClanParticipateText = ""
      if (descItem.isMyClanParticipate())
        foreach(idx, side in ::g_world_war.getCommonSidesOrder())
          if (descItem.isMyClanSide(side))
          {
            isMyClanParticipateText = ::loc("worldwar/operation/isClanParticipate")
            isClanParticipateObj["text-align"] = (idx == 0 ? "left" : "right")
            break
          }

      isClanParticipateObj.setValue(isMyClanParticipateText)
    }
    ::g_world_war.getConfigurableValues()
  }

  function updateTeamsInfo()
  {
    local unitInfoHeight = 0

    foreach(side in ::g_world_war.getCommonSidesOrder())
    {
      local sideName = ::ww_side_val_to_name(side)
      local isInvert = side == ::SIDE_2

      local unitListObjPlace = scene.findObject("team_" + sideName + "_unit_info")
      local armySideStrenghtViewData = getUnitsListViewBySide(side, isInvert)
      local unitListBlk = ::handyman.renderCached(sceneTplTeamStrenght, armySideStrenghtViewData)
      guiScene.replaceContentFromText(unitListObjPlace, unitListBlk, unitListBlk.len(), this)

      local armyGroupObjPlace = scene.findObject("team_" + sideName + "_army_group_info")
      local armyGroupViewData = getClanListViewDataBySide(side, isInvert, armyGroupObjPlace)
      local armyGroupsBlk = ::handyman.renderCached(sceneTplTeamArmyGroups, armyGroupViewData)
      guiScene.replaceContentFromText(armyGroupObjPlace, armyGroupsBlk, armyGroupsBlk.len(), this)

      local countryesObjPlace = scene.findObject("team_" + sideName + "_countryes_info")
      local countryesMarkUpData = wwMap.getCountriesViewBySide(side)
      guiScene.replaceContentFromText(countryesObjPlace, countryesMarkUpData, countryesMarkUpData.len(), this)
    }
  }

  function getUnitsListViewBySide(side, isInvert)
  {
    local unitsList = wwMap.getUnitInfoBySide(side)
    if (::u.isEmpty(unitsList))
      return ""

    local wwUnitsList = ::WwUnit.loadUnitsFromNameCountTbl(unitsList)
    local collectedWwUnits = ::u.values(::g_world_war.collectUnitsData(wwUnitsList))
    collectedWwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)

    local unitsString = ::u.map(
      collectedWwUnits,
      function(wwUnit) {
        return {
          unitIcon = wwUnit.getWwUnitClassIco()
          unitName = wwUnit.getUnitStrengthGroupTypeText()
          shopItemType = wwUnit.getUnitRole()
          sideUnitCount = wwUnit.count
        }
      }
    )

    if (unitsString.len() > 0)
      unitsString.top().isLastElement <- true

    return {
      sideName = ::ww_side_val_to_name(side)
      unitString = unitsString
      invert = isInvert
    }
  }

  function getClanListViewDataBySide(side, isInvert, parentObj)
  {
    local viewData = {
        columns = [],
        isInvert = isInvert
        isSingleColumn = false
      }

    local armyGroups = descItem.getArmyGroupsBySide(side)
    local clansPerColumn = ::g_dagui_utils.countSizeInItems(parentObj, 1, "@leaderboardTrHeight",
      0, 0, 0, "2@wwWindowListBackgroundPadding").itemsCountY

    local armyGroupNames = null
    for(local i = 0; i < armyGroups.len(); i++)
    {
      if (i % clansPerColumn == 0)
      {
        armyGroupNames = []
        viewData.columns.append({ armyGroupNames = armyGroupNames })
      }

      if ("name" in armyGroups[i])
        armyGroupNames.append({ name = armyGroups[i].name })
    }

    if (isInvert)
      viewData.columns.reverse()

    viewData.isSingleColumn = viewData.columns.len() == 1

    return viewData
  }
}
