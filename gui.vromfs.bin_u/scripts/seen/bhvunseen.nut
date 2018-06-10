local u = ::require("std/u.nut")
local seenList = require("scripts/seen/seenList.nut")
local seenListEvents = require("scripts/seen/seenListEvents.nut")
local Callback = ::require("sqStdLibs/helpers/callback.nut").Callback

/*
  behaviour config params:
  listId = uniq seen List Id
  entity = null, uniq entity id, or array of uniq entity ids
             when entityId is null, full list will be used

  when need only listId without entities, you can setValue(listId) without preprocessing
*/

local onSeenListEvent = null //to be able use it in behaviour

local BhvUnseen = class
{
  eventMask    = ::EV_ON_CMD
  valuePID     = ::dagui_propid.add_name_id("value")

  function onAttach(obj)
  {
    if (obj.value)
      setNewConfig(obj, buildConfig(obj.value))
    updateView(obj)
    return ::RETCODE_NOTHING
  }

  static function buildConfig(value)
  {
    local valueTbl = u.isTable(value) ? value : null
    if (u.isString(value))
    {
      valueTbl = ::parse_json(value)
      if (!valueTbl.len())
        valueTbl = value.len() ? { listId = value } : null
    }

    if (!valueTbl?.listId)
      return null

    local entity = valueTbl?.entity
    local list = u.isArray(entity) ? entity
      : u.isString(entity) ? [entity]
      : null
    return {
      seen = seenList.get(valueTbl.listId)
      entitiesList = list
      hasCounter = !list || list.len() > 1
    }
  }

  function setValue(obj, valueTbl)
  {
    setNewConfig(obj, buildConfig(valueTbl))
    updateView(obj)
    return u.isString(valueTbl) || u.isTable(valueTbl)
  }

  function setNewConfig(obj, config)
  {
    obj.setUserData(config) //this is single direct link to config.
                            //So destroy object, or change user data invalidate old subscriptions.
    if (!config)
      return

    local entities = config.entitiesList
    if (entities)
      foreach(entity in entities)
        if (config.seen.isSubList(entity))
        {
          entities = null //when has sublist, need to subscribe for any changes for current seen list
          config.hasCounter = true
          break
        }

    seenListEvents.subscribe(config.seen.id, entities,
      Callback(getOnSeenChangedCb(obj), config))
  }

  function getOnSeenChangedCb(obj)
  {
    local bhvClass = this
    return @() ::check_obj(obj) && bhvClass.updateView(obj)
  }

  function updateView(obj)
  {
    local config = obj.getUserData()
    local count = config ? config.seen.getNewCount(config.entitiesList) : 0
    obj.isActive = count ? "yes" : "no"
    if (count && obj.childrenCount())
    {
      local textObj = obj.getChild(0)
      textObj.isActive = config.hasCounter ? "yes" : "no"
      if (config.hasCounter)
        textObj.setValue(count.tostring())
    }
  }
}

::replace_script_gui_behaviour("bhvUnseen", BhvUnseen)

return {
  configToString = @(config) ::save_to_json(config)
  makeConfig = @(listId, entity = null) { listId = listId, entity = entity }
  makeConfigStr = @(listId, entity = null) entity ? configToString(makeConfig(listId, entity)) : listId
}