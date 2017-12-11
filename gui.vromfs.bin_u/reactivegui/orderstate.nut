local state = persist("orderState", @() {
  statusText = Watched("")
  statusTextBottom = Watched("")
  showOrder = Watched(false)
  scoresTable = Watched([])
})


::interop.orderStatusTextUpdate <- function (new_status_text) {
  state.statusText.update(new_status_text)
}


::interop.orderStatusTextBottomUpdate <- function (new_status_text) {
  state.statusTextBottom.update(new_status_text)
}


::interop.orderShowOrderUpdate <- function (new_show_order) {
  state.showOrder.update(new_show_order)
}


::interop.orderScoresTableUpdate <- function (new_scores_table) {
  state.scoresTable.update(new_scores_table)
}


return state
