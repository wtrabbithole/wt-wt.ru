local hudState = persist("hudState", @(){
  unitType = Watched("")
  cursorVisible = Watched("false")
})


::interop.onHudUnitTypeChanged <- function (new_unit_type) {
  hudState.unitType.update(new_unit_type)
}


::interop.cursorVisibilityUpdate <- function (new_value) {
  hudState.cursorVisible.update(new_value)
}


return hudState
