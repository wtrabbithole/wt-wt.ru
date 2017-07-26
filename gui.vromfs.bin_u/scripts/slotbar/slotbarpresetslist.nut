class SlotbarPresetsList
{
  maxPresets = 5
  presetIdxPID = ::dagui_propid.add_name_id("presetIdx")

  subscriptions = [
    "SlotbarPresetLoaded"
    "SlotbarPresetsChanged"
  ]

  scene = null
  owner = null
  listIndexByPreset = null

  function constructor(handler)
  {
    owner = handler
    if (!::checkObj(owner.scene))
      return
    scene = owner.scene.findObject("slotbar-presetsPlace")
    if (!::checkObj(scene))
      return

    initMaxPresets()

    local view = {
      presets = array(maxPresets, null)
      itemsCount = maxPresets + 1 // +1 for button "customize presets"
    }
    local blk = ::handyman.renderCached(("gui/slotbar/slotbarPresets"), view)
    scene.getScene().replaceContentFromText(scene, blk, blk.len(), this)
    update()

    ::subscribe_events_from_handler(this, subscriptions)
  }

  function initMaxPresets()
  {
    local width = scene.getSize()[0]
    if (width <= 0)
    {
      scene.getScene().applyPendingChanges(false)
      width = scene.getSize()[0]
      if (width <= 0)
        return
    }

    local itemWidth = ::g_dagui_utils.toPixels(scene.getScene(), "@maxPresetNameItemWidth")
    maxPresets = ::max(1, width / itemWidth - 1)
  }

  function isValid()
  {
    return ::checkObj(scene)
  }

  function getCurCountry()
  {
    local countryData = ::getTblValue(owner.curSlotCountryId, ::crews_list)
    return countryData? countryData.country : ""
  }

  function update()
  {
    local listObj = getListObj()
    if (!listObj)
      return

    listIndexByPreset = {}

    local country = getCurCountry()
    local list = ::slotbarPresets.list(country)
    local curPreset = getCurPresetIdx()
    local curValue = -1
    for(local i = 0; i < maxPresets; i++)
    {
      local presetIdx = (i == maxPresets - 1 && curPreset > i) ? curPreset : i
      local isCurrentPreset = presetIdx == curPreset
      if (isCurrentPreset)
        curValue = i

      local preset = ::getTblValue(presetIdx, list)
      local show = preset != null && (preset.enabled || isCurrentPreset)

      local child = listObj.getChild(i)
      if (!::checkObj(child))
        continue

      child.show(show)
      child.enable(show)
      if (!show)
        continue

      local titleObj = child.findObject("tab_text")
      if (::check_obj(titleObj))
        titleObj.setValue(preset.title)
      child.setIntProp(presetIdxPID, presetIdx)
      listIndexByPreset[preset] <- i
    }

    if (curValue >= 0)
      listObj.setValue(curValue)

    ::broadcastEvent("PresetUpdated")
  }

  function getCurPresetIdx() //current choosen preset
  {
    return ::slotbarPresets.getCurrent(getCurCountry(), 0)
  }

  function getSelPresetIdx() //selected preset in view
  {
    local listObj = getListObj()
    if (!listObj)
      return getCurPresetIdx()

    local value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return getCurPresetIdx()

    local childObj = listObj.getChild(value)
    if (!::check_obj(childObj))
      return getCurPresetIdx()

    return childObj.getIntProp(presetIdxPID, -1)
  }

  function isPresetChanged()
  {
    local idx = getSelPresetIdx()
    return idx != getCurPresetIdx()
  }

  function applySelect()
  {
    if (!::slotbarPresets.canLoad(true, getCurCountry()))
      return update()

    local idx = getSelPresetIdx()
    if (idx < 0)
    {
      update()
      return ::gui_choose_slotbar_preset(owner)
    }

    if (("canPresetChange" in owner) && !owner.canPresetChange())
      return

    ::slotbarPresets.load(idx)
    update()
  }

  function onPresetChange()
  {
    if (::slotbar_oninit || !isPresetChanged())
      return

    checkChangePresetAndDo(applySelect)
  }

  function checkChangePresetAndDo(action)
  {
    ::queues.checkAndStart(
      ::Callback(function()
      {
         if (!("beforeSlotbarChange" in owner))
           return action()

         owner.beforeSlotbarChange(
           ::Callback(action, this),
           ::Callback(update, this)
         )
      }, this),
      ::Callback(update, this),
      "isCanModifyCrew"
    )
  }

  function isValid()
  {
    return ::checkObj(scene)
  }

  function onSlotsChoosePreset(obj)
  {
    checkChangePresetAndDo(function () {
      ::gui_choose_slotbar_preset(this)
    })
  }

  function onWrapUp(obj)   { owner.onWrapUp(obj) }
  function onWrapDown(obj) { owner.onWrapDown(obj) }
  function onBottomGCPanelLeft(obj)  { owner.onBottomGCPanelLeft(obj) }
  function onBottomGCPanelRight(obj) { owner.onBottomGCPanelRight(obj) }

  function onEventSlotbarPresetLoaded(p)
  {
    update()
  }

  function onEventSlotbarPresetsChanged(p)
  {
    update()
  }

  function getListObj()
  {
    if (!::checkObj(scene))
      return null
    local obj = scene.findObject("slotbar-presetsList")
    if (::checkObj(obj))
      return obj
    return null
  }

  function getPresetsButtonObj()
  {
    if (scene == null)
      return null
    local obj = scene.findObject("btn_slotbar_presets")
    if (::checkObj(obj))
      return obj
    return null
  }

  /**
   * Returns list child object if specified preset is in slotbar
   * list or "Presets" button object if preset not found.
   */
  function getListChildByPreset(preset)
  {
    local listObj = getListObj()
    if (listObj == null)
      return null
    local index = ::getTblValue(preset, listIndexByPreset, -1)
    if (index < 0 || listObj.childrenCount() <= index)
      return null
    local childObj = listObj.getChild(index)
    if (::checkObj(childObj))
      return childObj
    return null
  }
}
