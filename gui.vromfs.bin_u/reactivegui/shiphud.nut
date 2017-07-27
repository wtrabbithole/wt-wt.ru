local shipStateModule = require("shipStateModule.nut")


return {
  vplace = VALIGN_BOTTOM
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  margin = [sh(5), sh(1)] //keep gap for counters
  gap = sh(1)
  children = [
    shipStateModule
  ]
}
