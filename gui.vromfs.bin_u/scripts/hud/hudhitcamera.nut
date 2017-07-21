function on_hit_camera_event(mode, result = ::DM_HIT_RESULT_NONE, info = {}) // called from client
{
  ::g_hud_hitcamera.onHitCameraEvent(mode, result, info)

  if (::g_hud_hitcamera.isKillingHitResult(result))
    ::g_hud_event_manager.onHudEvent("HitcamTargetKilled", info)
}

function get_hit_camera_aabb() // called from client
{
  return ::g_hud_hitcamera.getAABB()
}

::g_hud_hitcamera <- {
  scene     = null
  titleObj  = null
  infoObj   = null

  isEnabled = true

  isVisible = false
  hitResult = ::DM_HIT_RESULT_NONE
  unitId = -1
  unitVersion = -1
  unitType = ::ES_UNIT_TYPE_INVALID

  camInfo   = {}
  unitsInfo = {}

  debuffTemplates = {
    [::ES_UNIT_TYPE_SHIP] = "gui/hud/hudEnemyDebuffsShip.blk",
  }
  debuffsListsByUnitType = {}
  trackedPartNamesByUnitType = {}

  styles = {
    [::DM_HIT_RESULT_NONE]      = "none",
    [::DM_HIT_RESULT_RICOSHET]  = "ricochet",
    [::DM_HIT_RESULT_BOUNCE]    = "bounce",
    [::DM_HIT_RESULT_HIT]       = "hit",
    [::DM_HIT_RESULT_BURN]      = "burn",
    [::DM_HIT_RESULT_CRITICAL]  = "critical",
    [::DM_HIT_RESULT_KILL]      = "kill",
    [::DM_HIT_RESULT_METAPART]  = "hull",
    [::DM_HIT_RESULT_AMMO]      = "ammo",
    [::DM_HIT_RESULT_FUEL]      = "fuel",
    [::DM_HIT_RESULT_CREW]      = "crew",
    [::DM_HIT_RESULT_TORPEDO]   = "torpedo",
  }
}

function g_hud_hitcamera::init(_nest)
{
  if (!::checkObj(_nest))
    return

  if (::checkObj(scene) && scene.isEqual(_nest))
    return

  scene = _nest
  titleObj = scene.findObject("title")
  infoObj  = scene.findObject("info")

  foreach (unitType, fn in debuffTemplates)
  {
    debuffsListsByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTypesArrayByUnitType(unitType)
    trackedPartNamesByUnitType[unitType] <- ::g_hud_enemy_debuffs.getTrackedPartNamesByUnitType(unitType)
  }

  ::g_hud_event_manager.subscribe("EnemyPartDamage", function (params) {
      onEnemyPartDamage(params)
    }, this)

  reset()
  reinit()
}

function g_hud_hitcamera::reinit()
{
  isEnabled = ::get_option_xray_kill()
  update()
}

function g_hud_hitcamera::reset()
{
  isVisible = false
  hitResult = ::DM_HIT_RESULT_NONE
  unitId = -1
  unitVersion = -1
  unitType = ::ES_UNIT_TYPE_INVALID

  camInfo   = {}
  unitsInfo = {}
}

function g_hud_hitcamera::update()
{
  if (!::checkObj(scene))
    return

  scene.show(isVisible)
  if (!isVisible)
    return

  if (::check_obj(titleObj))
  {
    local style = ::getTblValue(hitResult, styles, "none")
    titleObj.show(hitResult != ::DM_HIT_RESULT_NONE)
    titleObj.setValue(::loc("hitcamera/result/" + style))
    scene.result = style
  }
}

function g_hud_hitcamera::getAABB()
{
  return ::get_dagui_obj_aabb(scene)
}

function g_hud_hitcamera::isKillingHitResult(result)
{
  return result >= ::DM_HIT_RESULT_KILL
}

function g_hud_hitcamera::onHitCameraEvent(mode, result, info)
{
  local _isVisible   = isEnabled && mode == ::HIT_CAMERA_START
  local _unitId      = ::getTblValue("unitId", info, unitId)
  local _unitVersion = ::getTblValue("unitVersion", info, unitVersion)
  local _unitType    = ::getTblValue("unitType", info, unitType)

  local isToggleOn = !isVisible && _isVisible
  local needResetUnitType = isToggleOn && _unitType != unitType
  local needResetUnitInfo = isToggleOn && (!needResetUnitType || _unitId != unitId || _unitVersion != unitVersion)

  isVisible     = _isVisible
  hitResult   = result
  unitId      = _unitId
  unitVersion = _unitVersion
  unitType    = _unitType
  camInfo     = info

  if (needResetUnitType && ::check_obj(infoObj))
  {
    local guiScene = infoObj.getScene()
    local markupFilename = ::getTblValue(unitType, debuffTemplates)
    if (markupFilename)
      guiScene.replaceContent(infoObj, markupFilename, this)
    else
      guiScene.replaceContentFromText(infoObj, "", 0, this)
  }

  if (needResetUnitType || needResetUnitInfo)
  {
    local unitInfo = getTargetInfo(unitId, unitVersion, unitType, isKillingHitResult(hitResult))

    foreach (item in ::getTblValue(unitType, debuffsListsByUnitType, []))
    {
      local labelText = item.getLabel(camInfo, unitInfo)

      local iconObj = scene.findObject(item.id)
      if (::check_obj(iconObj))
        iconObj.show(labelText != "")

      local labelObj = scene.findObject(item.id + "_label")
      if (::check_obj(labelObj))
        labelObj.setValue(labelText)
    }
  }

  update()
}

function g_hud_hitcamera::getTargetInfo(unitId, unitVersion, unitType, isUnitKilled)
{
  if (!(unitId in unitsInfo) || unitsInfo[unitId].unitVersion != unitVersion)
    unitsInfo[unitId] <- {
      unitId = unitId
      unitVersion = unitVersion
      unitType = unitType
      parts = {}
      trackedPartNames = ::getTblValue(unitType, trackedPartNamesByUnitType, [])
      isKilled = isUnitKilled
      time = 0
    }

  local info = unitsInfo[unitId]
  info.time = ::get_usefull_total_time()
  if (isUnitKilled && !info.isKilled)
  {
    info.isKilled = isUnitKilled
    info.parts = {}
  }

  return info
}

function g_hud_hitcamera::onEnemyPartDamage(data)
{
  if (!isEnabled)
    return

  local unitInfo = getTargetInfo(
    ::getTblValue("unitId", data, -1),
    ::getTblValue("unitVersion", data, -1),
    ::getTblValue("unitType", data, ::ES_UNIT_TYPE_INVALID),
    ::getTblValue("unitKilled", data, false)
    )

  local partName = null
  local partDmName = null
  local isPartKilled = ::getTblValue("partKilled", data, false)

  if (!unitInfo.isKilled)
  {
    partName = ::getTblValue("partName", data)
    if (!partName || !::isInArray(partName, unitInfo.trackedPartNames))
      return

    local parts = unitInfo.parts
    if (!(partName in parts))
      parts[partName] <- { dmParts = {} }

    partDmName = ::getTblValue("partDmName", data)
    if (!(partDmName in parts[partName].dmParts))
      parts[partName].dmParts[partDmName] <- { partKilled = isPartKilled }
    local dmPart = parts[partName].dmParts[partDmName]

    isPartKilled = isPartKilled ||  dmPart.partKilled
    dmPart.partKilled = isPartKilled

    foreach (k, v in data)
      dmPart[k] <- v

    local isPartDead   = ::getTblValue("partDead", dmPart, false)
    local partHpCur  = ::getTblValue("partHpCur", dmPart, 1.0)
    dmPart._hp <- (isPartKilled || isPartDead) ? 0.0 : partHpCur
  }

  if (isVisible && unitInfo.unitId == unitId)
  {
    foreach (item in ::getTblValue(unitInfo.unitType, debuffsListsByUnitType, []))
    {
      if (item.isUpdateOnKnownPartKillsOnly &&
        (!isPartKilled && !unitInfo.isKilled || !::isInArray(partName, item.parts)))
        continue

      local labelText = item.getLabel(camInfo, unitInfo, partName, data)

      local iconObj = scene.findObject(item.id)
      if (::check_obj(iconObj))
        iconObj.show(labelText != "")

      local labelObj = scene.findObject(item.id + "_label")
      if (::check_obj(labelObj))
        labelObj.setValue(labelText)
    }
  }
}

function g_hud_hitcamera::onEventLoadingStateChange(params)
{
  if (!::is_in_flight())
    reset()
}

::subscribe_handler(::g_hud_hitcamera, ::g_listener_priority.DEFAULT_HANDLER)