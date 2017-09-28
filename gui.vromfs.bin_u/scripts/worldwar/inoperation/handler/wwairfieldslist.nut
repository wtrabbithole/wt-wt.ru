class ::gui_handlers.WwAirfieldsList extends ::BaseGuiHandler
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/worldWar/airfieldObject"
  sceneBlkName = null
  airfieldBlockTplName = "gui/worldWar/worldWarMapArmyItem"

  airfieldIdPrefix = "airfield_"

  side = ::SIDE_NONE

  updateTimer = null
  updateDelay = 1

  function initScreen()
  {
    if (::ww_get_selected_airfield() >= 0)
    {
      updateSelectedAirfield(::ww_get_selected_airfield())
      selectDefaultFormation()
    }
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function getSceneTplView()
  {
    return {
      airfields = getAirfields()
    }
  }

  function isValid()
  {
    return ::checkObj(scene) && ::checkObj(scene.findObject("airfields_list"))
  }

  function getAirfields()
  {
    local selAirfield = ::ww_get_selected_airfield()
    local airfields = []
    local fieldsArray = ::g_world_war.getAirfieldsArrayBySide(side)
    foreach(idx, field in fieldsArray)
    {
      airfields.append({
        id = getAirfieldId(field.index)
        text = (idx+1)
        selected = selAirfield == field.index
      })
    }

    return airfields
  }

  function fillTimer(airfieldIdx, cooldownView)
  {
    local placeObj = scene.findObject("airfield_object")
    if (!::check_obj(placeObj))
      return

    if (updateTimer)
      updateTimer.destroy()

    updateTimer = ::Timer(placeObj, updateDelay,
      (@(placeObj, airfieldIdx, cooldownView) function() {
        onUpdateTimer(placeObj, airfieldIdx, cooldownView)
      })(placeObj, airfieldIdx, cooldownView), this, true)

    onUpdateTimer(placeObj, airfieldIdx, cooldownView)
  }

  function onUpdateTimer(placeObj, airfieldIdx, cooldownView)
  {
    if (!::getTblValue("army", cooldownView))
      return

    local airfield = ::g_world_war.getAirfieldByIndex(airfieldIdx)
    if (!airfield)
      return

    if (cooldownView.army.len() != airfield.getCooldownsWithManageAccess().len())
    {
      updateSelectedAirfield(airfieldIdx)
      return
    }

    foreach (idx, item in cooldownView.army)
    {
      local blockObj = placeObj.findObject(item.getId())
      if (!::check_obj(blockObj))
        return
      local timerObj = blockObj.findObject("arrival_time_text")
      if (!::check_obj(timerObj))
        return

      local timerText = airfield.cooldownFormations[item.getFormationID()].getCooldownText()
      timerObj.setValue(timerText)
    }
  }

  function updateAirfieldFormation(index = -1)
  {
    local blockObj = scene.findObject("free_formations_block")
    if (!::check_obj(blockObj))
      return
    local placeObj = blockObj.findObject("free_formations")
    if (!::check_obj(placeObj))
      return

    if (index < 0)
    {
      blockObj.show(false)
      guiScene.replaceContentFromText(placeObj, "", 0, this)
      return
    }

    local airfield = ::g_world_war.getAirfieldByIndex(index)
    local formationView = {
      army = []
      showArmyGroupText = false
      hasFormationData = true
      reqUnitTypeIcon = true
      addArmySelectCb = true
      checkMyArmy = true
      customCbName = "onChangeFormationValue"
      formationType = "formation"
    }

    foreach (i, formation in [airfield.clanFormation, airfield.allyFormation])
      if (formation)
      {
        local wwFormationView = formation.getView()
        if (wwFormationView && wwFormationView.unitsCount() > 0)
          formationView.army.append(formation.getView())
      }

    local data = ::handyman.renderCached(airfieldBlockTplName, formationView)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)

    blockObj.show(true)
  }

  function hasFormationsForFly(airfield)
  {
    if (!airfield)
      return false

    foreach (formation in [airfield.clanFormation, airfield.allyFormation])
      if (formation)
        if (::WwUnit.unitsCount(formation.getUnits()))
          return true

    return false
  }

  function updateAirfieldCooldownList(index = -1)
  {
    local placeObj = scene.findObject("cooldowns_list")
    if (index < 0)
      guiScene.replaceContentFromText(placeObj, "", 0, this)

    local cooldownView = {
      army = []
      showArmyGroupText = false
      hasFormationData = true
      reqUnitTypeIcon = true
      addArmySelectCb = true
      checkMyArmy = true
      customCbName = "onChangeCooldownValue"
      formationType = "cooldown"
    }

    local airfield = ::g_world_war.getAirfieldByIndex(index)
    local cooldownFormations = airfield.getCooldownsWithManageAccess()
    local itemsView = []
    foreach (i, cooldown in cooldownFormations)
      cooldownView.army.append(cooldown.getView())

    local data = ::handyman.renderCached(airfieldBlockTplName, cooldownView)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
    fillTimer(index, cooldownView)
  }

  function hasArmyOnCooldown(airfield)
  {
    if (!airfield)
      return false

    local cooldownFormations = airfield.getCooldownsWithManageAccess()
    return cooldownFormations.len() > 0
  }

  function updateAirfieldDescription(index = -1)
  {
    local formationTextObj = scene.findObject("free_formations_text")
    if (!::check_obj(formationTextObj))
      return
    local emptyDescTextObj = scene.findObject("empty_formations_text")
    if (!::check_obj(emptyDescTextObj))
      return

    local airfield = ::g_world_war.getAirfieldByIndex(index)
    if (!airfield)
    {
      formationTextObj.show(false)
      emptyDescTextObj.show(false)
      return
    }

    local hasFormationUnits = hasFormationsForFly(airfield)
    formationTextObj.show(hasFormationUnits)
    emptyDescTextObj.show(!hasFormationUnits)
    if (hasArmyOnCooldown(airfield))
      emptyDescTextObj.setValue(::loc("worldwar/state/no_units_to_fly"))
    else
      emptyDescTextObj.setValue(::loc("worldwar/state/airfield_empty"))
  }

  function getAirfieldId(index)
  {
    return airfieldIdPrefix + index
  }

  function selectRadioButtonBlock(rbObj, idx)
  {
    if (::check_obj(rbObj))
      if (rbObj.childrenCount() > idx && idx >= 0)
        if (rbObj.getChild(idx))
          rbObj.getChild(idx).setValue(true)
  }

  function deselectRadioButtonBlocks(rbObj)
  {
    if (::check_obj(rbObj))
      for (local i = 0; i < rbObj.childrenCount(); i++)
        rbObj.getChild(i).setValue(false)
  }

  function onChangeFormationValue(obj)
  {
    deselectRadioButtonBlocks(scene.findObject("cooldowns_list"))
    ::ww_event("MapAirfieldFormationSelected", {
      airfieldIdx = ::ww_get_selected_airfield(),
      formationType = "formation",
      formationId = obj.formationId.tointeger()})
  }

  function onChangeCooldownValue(obj)
  {
    deselectRadioButtonBlocks(scene.findObject("free_formations"))
    ::ww_event("MapAirfieldFormationSelected", {
      airfieldIdx = ::ww_get_selected_airfield(),
      formationType = "cooldown",
      formationId = obj.formationId.tointeger()})
  }

  function onAirfieldClick(obj)
  {
    local index = ::to_integer_safe(obj.id.slice(airfieldIdPrefix.len()), -1)
    local mapObj = ::get_cur_gui_scene()["worldwar_map"]
    ::ww_gui_bhv.worldWarMapControls.selectAirfield.call(
      ::ww_gui_bhv.worldWarMapControls, mapObj, {airfieldIdx = index})
  }

  function selectDefaultFormation()
  {
    local placeObj = scene.findObject("free_formations")
    selectRadioButtonBlock(placeObj, 0)
  }

  function updateSelectedAirfield(selectedAirfield = -1)
  {
    for (local index = 0; index < ::ww_get_airfields_count(); index++)
    {
      local airfieldObj = scene.findObject(getAirfieldId(index))
      if (::checkObj(airfieldObj))
        airfieldObj.selected = selectedAirfield == index? "yes" : "no"
    }
    updateAirfieldFormation(selectedAirfield)
    updateAirfieldCooldownList(selectedAirfield)
    updateAirfieldDescription(selectedAirfield)
    selectDefaultFormation()
  }

  function onEventWWMapAirfieldSelected(params)
  {
    if (!::checkObj(scene))
      return

    updateSelectedAirfield(::ww_get_selected_airfield())
  }

  function onEventWWMapAirfieldCleared(params)
  {
    updateSelectedAirfield()
  }

  function onEventWWLoadOperation(params = {})
  {
    updateSelectedAirfield(::ww_get_selected_airfield())
  }

  function onEventWWMapClearSelectionBySelectedObject(params)
  {
    if (params.objSelected != mapObjectSelect.AIRFIELD)
      updateSelectedAirfield()
  }
}
