class ::gui_handlers.ProtectionAnalysisHint extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/dmViewer/protectionAnalysisHint.blk"

  cursorObj = null
  hintObj   = null
  lastHintParams = null
  cursorRadius = 0
  emptyResult = ::CHECK_PROT_RES_INEFFECTIVE

  resultConfigs = [
    {
      checkFunc = @(p) p?.result == result
      result = ::CHECK_PROT_RES_NOT_PENETRATED
      color = "badTextColor"
      loc = "protection_analysis/result/not_penetrated"
      infoSrc = [ "max" ]
      params = [ "armor", "ricochetProb" ]
    },
    {
      checkFunc = @(p) p?.result == result && (p?.max?.armor ?? 0) != 0
      result = ::CHECK_PROT_RES_INEFFECTIVE
      color = "badTextColor"
      loc = "protection_analysis/result/not_penetrated"
      infoSrc = [ "max" ]
      params = [ "armor", "ricochetProb" ]
    },
    {
      checkFunc = @(p) p?.result == result && (p?.max?.armor ?? 0) == 0
      result = ::CHECK_PROT_RES_INEFFECTIVE
      color = "minorTextColor"
      loc = "protection_analysis/result/ineffective"
      infoSrc = [ "max" ]
      params = [ "ricochetProb" ]
    },
    {
      checkFunc = @(p) p?.result == result
      result = ::CHECK_PROT_RES_RICOCHETED
      color = "minorTextColor"
      loc = "hitcamera/result/ricochet"
      infoSrc = [ "lower", "upper" ]
      params = [ "ricochetProb" ]
    },
    {
      checkFunc = @(p) p?.result == result
      result = ::CHECK_PROT_RES_POSSIBLE_EFFECTIVE
      color = "cardProgressTextBonusColor"
      loc = "protection_analysis/result/possible_effective"
      infoSrc = [ "lower", "upper" ]
      params = [ "armor", "parts" ]
    },
    {
      checkFunc = @(p) p?.result == result
      result = ::CHECK_PROT_RES_EFFECTIVE
      color = "goodTextColor"
      loc = "protection_analysis/result/effective"
      infoSrc = [ "lower", "upper" ]
      params = [ "armor", "parts" ]
    },
  ]

  getValueByResultCfg = {
    armor = function(params, id, resultCfg) {
      local res = 0.0
      foreach (src in resultCfg.infoSrc)
        res = ::max(res, (params?[src]?[id] ?? 0.0))
      return res
    }
    ricochetProb = function(params, id, resultCfg) {
      local res = 0.0
      foreach (src in resultCfg.infoSrc)
        res = ::max(res, (params?[src]?[id] ?? 0.0))
      return res
    }
    parts = function(params, id, resultCfg) {
      local res = {}
      foreach (src in resultCfg.infoSrc)
        foreach (partId, isShow in (params?[src]?[id] ?? {}))
          res[partId] <- isShow
      return res
    }
  }

  printValueByParam = {
    armor = function(val) {
      if (!val)
        return ""
      return ::loc("protection_analysis/hint/armor") + ::loc("ui/colon") +
        ::colorize("activeTextColor", ::round(val)) + " " + ::loc("measureUnits/mm")
    }
    ricochetProb = function(val) {
      if (val < 0.1)
        return ""
      return ::loc("protection_analysis/hint/ricochetProb") + ::loc("ui/colon") +
        ::colorize("activeTextColor", ::round(val * 100) + ::loc("measureUnits/percent"))
    }
    parts = function(val) {
      if (::u.isEmpty(val))
        return ""
      local prefix = ::loc("ui/bullet") + " "
      local partNames = [ ::loc("protection_analysis/hint/parts/list") + ::loc("ui/colon") ]
      foreach (partId, isShow in val)
        if (isShow)
          partNames.append(prefix + ::loc("dmg_msg_short/" + partId))
      return ::g_string.implode(partNames, "\n")
    }
  }

  function initScreen()
  {
    cursorObj = scene.findObject("target_cursor")
    cursorObj.setUserData(this)

    hintObj = scene.findObject("dmviewer_hint")
    hintObj.setUserData(this)

    cursorRadius = cursorObj.getSize()[0] / 2
  }

  function onEventProtectionAnalysisResult(params)
  {
    update(params)
  }

  function update(params)
  {
    if (::u.isEqual(params, lastHintParams))
      return
    lastHintParams = params

    if (!::check_obj(cursorObj) || !::check_obj(hintObj))
      return

    local isShow = !::u.isEmpty(params)
    hintObj.show(isShow)
    if (!isShow)
      return

    foreach (src in [ "lower", "upper", "max" ])
      if (params?[src])
        params[src].armor <- (params[src]?.penetratedArmor?.generic    ?? 0) +
                             (params[src]?.penetratedArmor?.cumulative ?? 0)

    local resultCfg = ::u.search(resultConfigs, @(c) c.checkFunc(params))
    if (!resultCfg)
      return

    cursorObj["background-color"] = ::get_main_gui_scene().getConstantValue(resultCfg.color)

    local getValue = getValueByResultCfg
    local printValue = printValueByParam
    local title = ::colorize(resultCfg.color, ::loc(resultCfg.loc))
    local desc = ::u.map(resultCfg.params, function(id) {
      local gFunc = getValue?[id]
      local val = gFunc ? gFunc(params, id, resultCfg) : 0
      local pFunc = printValue?[id]
      return pFunc ? pFunc(val) : ""
    })
    desc = ::g_string.implode(desc, "\n")

    hintObj.findObject("dmviewer_title").setValue(title)
    hintObj.findObject("dmviewer_desc").setValue(desc)
  }

  function onTargetingCursorTimer(obj, dt)
  {
    if(!::check_obj(obj))
      return
    local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    obj.left = cursorPos[0] - cursorRadius
    obj.top  = cursorPos[1] - cursorRadius
  }

  function onDMViewerHintTimer(obj, dt)
  {
    ::dmViewer.placeHint(obj)
  }
}

return {
  open = function (scene) {
    if (::check_obj(scene))
      ::handlersManager.loadHandler(::gui_handlers.ProtectionAnalysisHint, { scene = scene })
  }
}
