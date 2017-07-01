class gui_bhv.ActivateSelect extends gui_bhv.posNavigator
{
  valuePID = ::dagui_propid.add_name_id("value")  //values by bits   chosen:yes;
  selectedPID = ::dagui_propid.add_name_id("_selected")    //only 1     selected:yes;
  activateByMClick = true

  function setValue(obj, value)
  {
    if (chooseItem(obj, value))
      setSelectedValue(obj, value)
  }

  function getSelectedValue(obj)
  {
    return obj.getIntProp(selectedPID, -1)
  }

  function setSelectedValue(obj, value)
  {
    selectItem(obj, value, false)
  }

  function onSelectAction(obj)
  {
  }

  function chooseItem(obj, idx, needSound = true)
  {
    local idxObj = getChildObj(obj, idx)
    if (!idxObj)
      return false

    local needNotify = false
    local prevIdx = getValue(obj)
    if (prevIdx!=idx)
    {
      needNotify = true
      local prevObj = getChildObj(obj, prevIdx)
      if (prevObj)
        prevObj["chosen"] = "no"
    }

    obj.setIntProp(valuePID, idx)
    idxObj["chosen"] = "yes"

    if (needSound && needNotify)
      ::play_gui_sound("choose")
    if (needNotify)
      obj.sendNotify("select")
    return true
  }

  function activateAction(obj)
  {
    local selected = getSelectedValue(obj)
    if (selected < 0)
      return

    chooseItem(obj, selected)
  }
}