local { getTooltipType, UNLOCK, ITEM, INVENTORY, SUBTROPHY, UNIT,
  CREW_SPECIALIZATION, BUY_CREW_SPEC, DECORATION
} = require("genericTooltipTypes.nut")

local openedTooltipObjs = []
local function removeInvalidTooltipObjs() {
  openedTooltipObjs = openedTooltipObjs.filter(@(t) t.isValid())
}

::g_tooltip <- {
  inited = false

//!!TODO: remove this functions from this module
  getIdUnlock = @(unlockId, params = null)
    UNLOCK.getTooltipId(unlockId, params)
  getIdItem = @(itemName, params = null)
    ITEM.getTooltipId(itemName, params)
  getIdInventoryItem = @(itemUid)
    INVENTORY.getTooltipId(itemUid)
//only trophy content without trophy info. for hidden trophy items content.
  getIdSubtrophy = @(itemName)
    SUBTROPHY.getTooltipId(itemName)
  getIdUnit = @(unitName, params = null)
    UNIT.getTooltipId(unitName, params)
//specTypeCode == -1  -> current crew specialization
  getIdCrewSpecialization = @(crewId, unitName, specTypeCode = -1)
    CREW_SPECIALIZATION.getTooltipId(crewId, unitName, specTypeCode)
  getIdBuyCrewSpec = @(crewId, unitName, specTypeCode = -1)
    BUY_CREW_SPEC.getTooltipId(crewId, unitName, specTypeCode)
  getIdDecorator = @(decoratorId, unlockedItemType, params = null)
    DECORATION.getTooltipId(decoratorId, unlockedItemType, params)
}

local function fillTooltip(obj, handler, tooltipType, id, params) {
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

g_tooltip.open <- function open(obj, handler)
{
  removeInvalidTooltipObjs()
  if (!::check_obj(obj))
    return
  obj["class"] = "empty"

  if (!::handlersManager.isHandlerValid(handler))
    return
  local tooltipId = ::getTooltipObjId(obj)
  if (!tooltipId || tooltipId == "")
    return
  local params = ::parse_json(tooltipId)
  if (type(params) != "table" || !("ttype" in params) || !("id" in params))
    return

  local tooltipType = getTooltipType(params.ttype)
  local id = params.id

  local isSucceed = fillTooltip(obj, handler, tooltipType, id, params)

  if (!isSucceed || !::check_obj(obj))
    return

  obj["class"] = ""
  register(obj, handler, tooltipType, id, params)
}

g_tooltip.register <- function register(obj, handler, tooltipType, id, params)
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

  openedTooltipObjs.append(data)
}

g_tooltip.close <- function close(obj) //!!FIXME: this function can be called with wrong context. Only for replace content in correct handler
{
  local tIdx = !obj.isValid() ? null
    : openedTooltipObjs.findindex(@(v) v.obj.isValid() && v.obj.isEqual(obj))
  if (tIdx != null) {
    openedTooltipObjs[tIdx].tooltipType.onClose(obj)
    openedTooltipObjs.remove(tIdx)
  }

  if (!::checkObj(obj) || !obj.childrenCount())
    return
  local guiScene = obj.getScene()
  obj.show(false)

  guiScene.performDelayed(this, function() {
    if (!::checkObj(obj) || !obj.childrenCount())
      return

    //for debug and catch rare bug
    local dbg_event = obj?.on_tooltip_open
    if (!dbg_event)
      return

    if (!(dbg_event in this))
    {
      guiScene.replaceContentFromText(obj, "", 0, null) //after it tooltip dosnt open again
      return
    }

    guiScene.replaceContentFromText(obj, "", 0, this)
  })
}

g_tooltip.init <- function init()
{
  if (inited)
    return
  inited = true
  ::add_event_listener("ChangedCursorVisibility", onEventChangedCursorVisibility, this)
}

g_tooltip.onEventChangedCursorVisibility <- function onEventChangedCursorVisibility(params)
{
  // Proceed if cursor is hidden now.
  if (params.isVisible)
    return

  removeAll()
}

g_tooltip.removeAll <- function removeAll()
{
  removeInvalidTooltipObjs()

  while (openedTooltipObjs.len())
  {
    local tooltipData = openedTooltipObjs.remove(0)
    close.call(tooltipData.handler, tooltipData.obj)
  }
  openedTooltipObjs.clear()
}

::g_tooltip.init()

return {
  fillTooltip
}