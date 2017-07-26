::g_tooltip <- {
  openedTooltipObjs = []
  inited = false
}

function g_tooltip::getIdUnlock(unlockId, params = null)
{
  return ::g_tooltip_type.UNLOCK.getTooltipId(unlockId, params)
}

function g_tooltip::getIdItem(itemName)
{
  return ::g_tooltip_type.ITEM.getTooltipId(itemName)
}

function g_tooltip::getIdInventoryItem(itemUid)
{
  return ::g_tooltip_type.INVENTORY.getTooltipId(itemUid)
}

//only trophy content without trophy info. for hidden trophy items content.
function g_tooltip::getIdSubtrophy(itemName)
{
  return ::g_tooltip_type.SUBTROPHY.getTooltipId(itemName)
}

function g_tooltip::getIdUnit(unitName, params = null)
{
  return ::g_tooltip_type.UNIT.getTooltipId(unitName, params)
}

function g_tooltip::getIdModification(unitName, modName, params = null)
{
  return ::g_tooltip_type.MODIFICATION.getTooltipId(unitName, modName, params)
}

function g_tooltip::getIdSpare(unitName)
{
  return ::g_tooltip_type.SPARE.getTooltipId(unitName)
}

function g_tooltip::getIdCrewSkillCategory(categoryName, unitTypeName)
{
  return ::g_tooltip_type.SKILL_CATEGORY.getTooltipId(categoryName, unitTypeName)
}

//specTypeCode == -1  -> current crew specialization
function g_tooltip::getIdCrewSpecialization(crewId, unitName, specTypeCode = -1)
{
  return ::g_tooltip_type.CREW_SPECIALIZATION.getTooltipId(crewId, unitName, specTypeCode)
}

function g_tooltip::getIdBuyCrewSpec(crewId, unitName, specTypeCode = -1)
{
  return ::g_tooltip_type.BUY_CREW_SPEC.getTooltipId(crewId, unitName, specTypeCode)
}

function g_tooltip::getIdDecorator(decoratorId, unlockedItemType)
{
  return ::g_tooltip_type.DECORATION.getTooltipId(decoratorId, unlockedItemType)
}

function g_tooltip::open(obj, handler)
{
  ::g_tooltip.removeInvalidObjs(::g_tooltip.openedTooltipObjs)

  if (!::handlersManager.isHandlerValid(handler) || !::checkObj(obj))
    return
  local tooltipId = ::getTooltipObjId(obj)
  if (!tooltipId)
    return
  local params = ::parse_json(tooltipId)
  if (type(params) != "table" || !("ttype" in params) || !("id" in params))
    return

  local tooltipType = ::g_tooltip_type.getTypeByName(params.ttype)
  local id = params.id

  local isSucceed = fill(obj, handler, tooltipType, id, params)

  if (!::checkObj(obj))
    return

  obj["class"] = isSucceed ? "" : "empty"

  if (isSucceed)
    register(obj, handler, tooltipType, id, params)
}

function g_tooltip::register(obj, handler, tooltipType, id, params)
{
  local data = {
    obj         = obj
    handler     = handler
    tooltipType = tooltipType
    id          = id
    params      = params
    isValid     = function() { return ::checkObj(obj) && obj.isVisible() }
  }

  foreach (key, value in tooltipType)
    if (::u.isFunction(value) && ::g_string.startsWith(key, "onEvent"))
    {
      local eventName = key.slice("onEvent".len())
      ::add_event_listener(eventName, (@(eventName) function(eventParams) {
        tooltipType["onEvent" + eventName](eventParams, obj, handler, id, params)
      })(eventName), data)
    }

  openedTooltipObjs.push(data)
}

function g_tooltip::fill(obj, handler, tooltipType, id, params)
{
  local isSucceed = true
  if (tooltipType.isCustomTooltipFill)
    isSucceed = tooltipType.fillTooltip(obj, handler, id, params)
  else
  {
    local content = tooltipType.getTooltipContent(id, params)
    if (content.len())
      obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
    else
      isSucceed = false
  }
  return isSucceed
}

function g_tooltip::close(obj)
{
  local tooltipId = ::checkObj(obj) ? ::getTooltipObjId(obj) : null
  ::g_tooltip.removeInvalidObjs(::g_tooltip.openedTooltipObjs, tooltipId)

  if (!::checkObj(obj) || !obj.childrenCount())
    return
  local guiScene = obj.getScene()
  obj.show(false)

  guiScene.performDelayed(this, (@(obj, guiScene) function() {
    if (!::checkObj(obj) || !obj.childrenCount())
      return

    //for debug and catch rare bug
    local dbg_event = obj.on_tooltip_open
    if (!dbg_event)
      return

    if (!(dbg_event in this))
    {
      local metric = "errors.brokenTooltip." + ::toString(this) + ";" + dbg_event
      dagor.debug("Error: " + metric + ";" + ::toString(obj))
      statsd_counter(metric)
      guiScene.replaceContentFromText(obj, "", 0, null) //after it tooltip dosnt open again
      return
    }

    guiScene.replaceContentFromText(obj, "", 0, this)
  })(obj, guiScene))
}

function g_tooltip::init()
{
  if (inited)
    return
  inited = true
  ::add_event_listener("ChangedCursorVisibility", onEventChangedCursorVisibility, this)
}

function g_tooltip::onEventChangedCursorVisibility(params)
{
  // Proceed if cursor is hidden now.
  if (params.newValue)
    return

  removeAll()
}

function g_tooltip::removeInvalidObjs(objs, tooltipId = null)
{
  for (local i = objs.len() - 1; i >= 0; --i)
  {
    local obj = objs[i].obj
    if (!objs[i].isValid() || tooltipId && ::getTooltipObjId(obj) == tooltipId)
      objs.remove(i)
  }
}

function g_tooltip::removeAll()
{
  removeInvalidObjs(openedTooltipObjs)

  while (openedTooltipObjs.len())
  {
    local tooltipData = openedTooltipObjs.remove(0)
    close.call(tooltipData.handler, tooltipData.obj)
  }
  openedTooltipObjs.clear()
}

::g_tooltip.init()
