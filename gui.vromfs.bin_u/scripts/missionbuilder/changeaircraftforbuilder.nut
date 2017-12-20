class ::gui_handlers.changeAircraftForBuilder extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/shop/shopTakeAircraft.blk"
  shopAir = null

  function initScreen()
  {
     createSlotbar(
       {
         showNewSlot = false,
         showEmptySlot = false,
         hasActions = false,
         afterSlotbarSelect = updateButtons
         onSlotDblClick = @(crew) onApply()
       },
       "take-aircraft-slotbar"
     )

     local textObj = scene.findObject("take-aircraft-text")
     textObj.top = "1@titleLogoPlateHeight + 1@frameHeaderHeight"
     textObj.setValue(::loc("mainmenu/missionBuilderNotAvailable"))

     local crew = getCurSlotUnit()
     local airName = ("aircraft" in crew)? crew.aircraft : ""
     local air = getAircraftByName(airName)
     ::show_aircraft = air
     updateButtons()
     initFocusArray()
  }

  function onTakeCancel()
  {
    ::show_aircraft = shopAir
    goBack()
  }

  function onApply()
  {
    if (::isTank(::show_aircraft))
      msgBox("not_available", ::loc("mainmenu/cantTestDrive"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
    else
      ::gui_start_builder()
  }

  function updateButtons()
  {
    scene.findObject("btn_set_air").inactiveColor = ::isTank(::show_aircraft)? "yes" : "no"
  }
}