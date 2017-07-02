return {
  updateStateFn = function (state_var) {
    return function(new_value) {
      state_var.update(new_value)
    }
  }
}
