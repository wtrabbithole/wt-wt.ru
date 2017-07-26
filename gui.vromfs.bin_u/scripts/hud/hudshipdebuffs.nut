::g_hud_ship_debuffs <- {
  scene    = null
  guiScene = null


  stateNameToViewName = {
    transmissionBroken = "bad"
    transmissionDamaged = "damaged"
    engineBroken = "bad"
    engineDamaged = "damaged"
    ruddersBroken = "bad"
    ruddersDamaged = "damaged"
    torpedoBroken = "bad"
    torpedoDamaged = "damaged"
    artilleryBroken = "bad"
    artilleryDamaged = "damaged"
  }

  function init(_nest)
  {
    if (!::has_feature("ShipDetailedDamageIndicator"))
      return

    scene = _nest.findObject("ship_debuffs")

    if (!scene && !::checkObj(scene))
      return

    guiScene = scene.getScene()
    local blk = ::handyman.renderCached("gui/hud/HudShipDebuffs", {})
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)

    ::g_hud_event_manager.subscribe("ShipDebuffs:Fire",
      function (debuffs_data) {
        scene.findObject("fire_status").show(debuffs_data.burns)
      }, this)

    ::g_hud_event_manager.subscribe("ShipDebuffs:Transmission",
      function (debuffs_data) {
        updateDebuffState(debuffs_data, scene.findObject("transmission_state"))
      }, this)

    ::g_hud_event_manager.subscribe("ShipDebuffs:Engine",
      function (debuffs_data) {
        updateDebuffState(debuffs_data, scene.findObject("engine_state"))
      }, this)

    ::g_hud_event_manager.subscribe("ShipDebuffs:SteeringGear",
      function (debuffs_data) {
        updateDebuffState(debuffs_data, scene.findObject("steering_gear_state"))
      }, this)

    ::g_hud_event_manager.subscribe("ShipDebuffs:Torpedo",
      function (debuffs_data) {
        updateDebuffState(debuffs_data, scene.findObject("torpedo_state"))
      }, this)

    ::g_hud_event_manager.subscribe("ShipDebuffs:ArtilleryWeapon",
      function (debuffs_data) {
        updateDebuffState(debuffs_data, scene.findObject("artillery_weapon_state"))
      }, this)

    ::g_hud_event_manager.subscribe("ShipDebuffs:Buoyancy", updateBuoyancy, this)

    ::hud_request_hud_ship_debuffs_state()
  }

  function reinit()
  {
    ::hud_request_hud_ship_debuffs_state()
  }

  function updateDebuffState(debuffs_data, obj)
  {
    foreach (debuff, on in debuffs_data)
      if (on)
      {
        obj.state = getStateViewName(debuff)
        return
      }
    obj.state = "ok"
  }

  function getStateViewName(stateName)
  {
    return ::getTblValue(stateName, stateNameToViewName, "bad")
  }

  function updateBuoyancy(debuffs_data)
  {
    local obj = scene.findObject("buoyancy_indicator_text")
    if (!::checkObj(obj))
      return
    obj.setValue(debuffs_data.Buoyancy.tostring() + "%")
  }

  function isValid()
  {
    return ::checkObj(scene)
  }
}
