local enums = ::require("std/enums.nut")

::g_wrap_dir <- {
  types = []
}

::g_wrap_dir.template <- {
  notifyId = "wrap_down"
  isVertical = true
  isPositive = true
}

enums.addTypes(::g_wrap_dir, {
  UP = {
    notifyId = "wrap_up"
    isVertical = true
    isPositive = false
  }
  DOWN = {
    notifyId = "wrap_down"
    isVertical = true
    isPositive = true
  }
  LEFT = {
    notifyId = "wrap_left"
    isVertical = false
    isPositive = false
  }
  RIGHT = {
    notifyId = "wrap_right"
    isVertical = false
    isPositive = true
  }
})

function g_wrap_dir::getWrapDir(isVertical, isPositive)
{
  if (isVertical)
    return isPositive ? DOWN : UP
  return isPositive ? RIGHT : LEFT
}