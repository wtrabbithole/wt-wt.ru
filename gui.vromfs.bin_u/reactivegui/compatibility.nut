//1.69.2.X
::apply_compatibilities({
  perform_cross_call = function (...) { return null }
})


//1.69.4.X
::apply_compatibilities({
  get_mission_time = function () { return 0 }
  get_time_speed = function () { return 1.0 }
  set_time_speed = function (...) {}
  is_game_paused = function () { return false }
})
