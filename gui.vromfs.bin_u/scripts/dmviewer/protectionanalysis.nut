local protectionAnalysisOptions = ::require("scripts/dmViewer/protectionAnalysisOptions.nut")
local protectionAnalysisHint = ::require("scripts/dmViewer/protectionAnalysisHint.nut")

class ::gui_handlers.ProtectionAnalysis extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.BASE
  sceneBlkName = "gui/dmViewer/protectionAnalysis.blk"
  sceneTplName = "gui/options/verticalOptions"

  protectionAnalysisMode = ::DM_VIEWER_PROTECTION
  hintHandler = null
  unit = null

  getSceneTplContainerObj = @() scene.findObject("options_container")
  function getSceneTplView()
  {
    local view = { rows = [] }
    foreach (o in protectionAnalysisOptions.types)
      if (o.isVisible())
        view.rows.append({
          id = o.id
          name = o.getLabel()
          option = o.getControlMarkup()
          infoRows = o.getInfoRows()
          valueWidth = o.valueWidth
        })
    return view
  }

  function initScreen()
  {
    initHandlerSceneTpl()

    unit = ::getAircraftByName(::hangar_get_current_unit_name())
    if (!unit)
      return goBack()

    ::enableHangarControls(true)
    ::dmViewer.init(this)
    ::hangar_focus_model(true)
    guiScene.performDelayed(this, @() ::hangar_set_dm_viewer_mode(protectionAnalysisMode))
    setSceneTitle(::loc("mainmenu/btnProtectionAnalysis") + " " +
      ::loc("ui/mdash") + " " + ::getUnitName(unit.name))

    onUpdateActionsHint()

    guiScene.setUpdatesEnabled(false, false)
    protectionAnalysisOptions.init(this, scene)
    guiScene.setUpdatesEnabled(true, true)

    ::g_hud_hitcamera.init(scene.findObject("dmviewer_hitcamera"))

    hintHandler = protectionAnalysisHint.open(scene.findObject("hint_scene"))
    registerSubHandler(hintHandler)
    initFocusArray()
  }

  function onChangeOption(obj)
  {
    if (!::check_obj(obj))
      return
    protectionAnalysisOptions.get(obj.id).onChange(this, scene, obj)
  }

  onButtonInc = @(obj) onProgressButton(obj, true)
  onButtonDec = @(obj) onProgressButton(obj, false)
  onDistanceInc = @(obj) onButtonInc(scene.findObject("buttonInc"))
  onDistanceDec = @(obj) onButtonDec(scene.findObject("buttonDec"))

  getMainFocusObj   = @() "options_container"

  function onProgressButton(obj, isIncrement)
  {
    if (!::check_obj(obj))
      return
    local optionId = ::g_string.cutPrefix(obj.getParent().id, "container_", "")
    local option = protectionAnalysisOptions.get(optionId)
    local value = option.value + (isIncrement ? option.step : - option.step)
    scene.findObject(option.id).setValue(value)
  }

  function onWeaponsInfo(obj)
  {
    ::open_weapons_for_unit(unit, { needHideSlotbar = true })
  }

  function goBack()
  {
    ::hangar_focus_model(false)
    ::hangar_set_dm_viewer_mode(::DM_VIEWER_NONE)
    base.goBack()
  }

  function onUpdateActionsHint()
  {
    local showHints = ::has_feature("HangarHitcamera")
    local hObj = showSceneBtn("analysis_hint", showHints)
    if (!showHints || !::check_obj(hObj))
      return

    local hasKeyboard = ::is_platform_pc
    local hasGamepad = ::show_console_buttons
    local shortcuts = []
    //hint for simulate shot
    local showHint = ::has_feature("HangarHitcamera")
    local bObj = showSceneBtn("analysis_hint_shot", showHint)
    if (showHint && ::check_obj(bObj))
    {
      if (hasGamepad)
        shortcuts.append(::loc("xinp/R2"))
      if (hasKeyboard)
        shortcuts.append(::loc("key/LMB"))
      bObj.findObject("push_to_shot").setValue(::g_string.implode(shortcuts, ::loc("ui/comma")))
    }
  }
}

return {
  canOpen = function() {
    return ::has_feature("DmViewerProtectionAnalysis")
      && ::isInMenu()
      && !::SessionLobby.hasSessionInLobby()
      && ::getAircraftByName(::hangar_get_current_unit_name())?.unitType.canShowProtectionAnalysis() == true
  }

  open = function () {
    if (!canOpen())
        return
    ::handlersManager.loadHandler(::gui_handlers.ProtectionAnalysis)
  }
}
