//!!FIX ME: replace by real threads after fix crash of datablock in sq thread
enum PT_STEP_STATUS {
  NEXT_STEP = 0  //default status
  SKIP_DELAY //for steps which do nothing no need to delay
  SUSPEND
}

function start_pseudo_thread(actionsList, step = 0, guiScene = null)
{
  if (!guiScene)
    guiScene = ::get_main_gui_scene()
  guiScene.performDelayed(::getroottable(), (@(actionsList, step) function() {
    local curStep = step
    while(curStep in actionsList)
    {
      local stepStatus = actionsList[curStep]()
      if (stepStatus != PT_STEP_STATUS.SUSPEND)
        curStep++

      if (stepStatus == PT_STEP_STATUS.SKIP_DELAY)
        continue

      if (curStep in actionsList)
        ::start_pseudo_thread(actionsList, curStep)
      break
    }
  })(actionsList, step))
}