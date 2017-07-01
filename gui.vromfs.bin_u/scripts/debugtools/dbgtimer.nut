// Profiler usage:
// console commands:
// "sq.script_profile_start"
// "sq.script_profile_stop"
// And see profile.txt for results.

//for easy debug function timers
//::dbg_timer.start(profile = false) - at function start
//                                   if profile it will start profiler too (finished with the same level pop)
//                                     but it will decrease performance
//::dbg_timer.show(msg)            - in function middle to show top timer diff in dlog (ms)
//::dbg_timer.stop(msg)             - at function end. to show top timer diff in dlog and remove it

::dbg_timer <- {
  timers = []
  profileIdx = -1

  function start(profile = false)
  {
    if (profile && profileIdx < 0)
    {
      profileIdx = timers.len() + 1
      ::console_command("sq.script_profile_start")
    }
    timers.append(::dagor.getCurTime())
  }

  function show(msg = "show")
  {
    if (timers.len())
      dlog("dbg_timer: " + msg + ": " + (::dagor.getCurTime() - timers.top()))
    else
      dlog("dbg_timer: not found timer for " + msg)
  }

  function stop(msg = "stop")
  {
    if (profileIdx >= timers.len())
    {
      ::console_command("sq.script_profile_stop")
      profileIdx = -1
    }
    show(msg)
    if (timers.len())
      timers.pop()
  }
}