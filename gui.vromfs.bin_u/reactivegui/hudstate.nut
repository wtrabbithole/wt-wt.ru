local hudState = persist("hudState", @(){
  unitType = Watched("")
})


::interop.onHudUnitTypeChanged <- function (new_unit_type) {
  hudState.unitType.update(new_unit_type)
}


return hudState
