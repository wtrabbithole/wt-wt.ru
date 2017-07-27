enum MAP_PREVIEW_TYPE {
  MISSION_MAP
  DYNAMIC_SUMMARY
}

//load/unload mission preview depend on visible preview scenes and their modal counter
::g_map_preview <- {
  list = []
  curPreview = null
}

//add or replace (by scene) preview to show.
//obj is scene to check visibility and modal counter (not a obj with tqactical map behavior)
function g_map_preview::setMapPreview(mapObj, missionBlk)
{
  setPreview(MAP_PREVIEW_TYPE.MISSION_MAP, mapObj, missionBlk)
}

function g_map_preview::setSummaryPreview(mapObj, missionBlk, mapName)
{
  setPreview(MAP_PREVIEW_TYPE.DYNAMIC_SUMMARY, mapObj, missionBlk, mapName)
}

function g_map_preview::setPreview(previewType, mapObj, missionBlk, param = null)
{
  if (!::check_obj(mapObj))
    return

  local preview = findPreview(mapObj)
  if (preview)
  {
    preview.blk = missionBlk
    preview.param = param
  }
  else
    preview = createPreview(previewType, missionBlk, mapObj, param)

  refreshCurPreview(preview == curPreview)
}

function g_map_preview::createPreview(previewType, missionBlk, mapObj, param)
{
  local preview = {
    type = previewType
    blk = missionBlk
    obj = mapObj
    param = param

    isInCurGuiScene = function()
    {
      return obj.getScene().isEqual(::get_cur_gui_scene())
    }
  }
  list.append(preview)
  return preview
}

function g_map_preview::findPreview(obj)
{
  return ::u.search(list, (@(obj) function(p) { return ::check_obj(p.obj) && p.obj.isEqual(obj) })(obj))
}

function g_map_preview::hideCurPreview()
{
  if (!curPreview)
    return
  if (::check_obj(curPreview.obj))
    curPreview.obj.show(false)
  ::dynamic_unload_preview()
  curPreview = null
}

function g_map_preview::refreshCurPreview(isForced = false)
{
  validateList()
  local newPreview = ::getTblValue(0, list)
  if (!newPreview || !newPreview.isInCurGuiScene())
  {
    hideCurPreview()
    return
  }

  if (!isForced && newPreview == curPreview)
    return

  hideCurPreview()
  curPreview = newPreview
  curPreview.obj.show(true)
  if (curPreview.type == MAP_PREVIEW_TYPE.MISSION_MAP)
    ::dynamic_load_preview(curPreview.blk)
  else if (curPreview.type == MAP_PREVIEW_TYPE.DYNAMIC_SUMMARY)
    ::dynamic_load_summary(curPreview.param, curPreview.blk)
}

function g_map_preview::validateList()
{
  for(local i = list.len() - 1; i >= 0; i--)
   if (!::check_obj(list[i].obj) || !list[i].blk)
     list.remove(i)


  list.sort(function(a, b)
  {
    local res = (b.isInCurGuiScene() ? 1 : 0) - (a.isInCurGuiScene() ? 1 : 0)
    if (!res)
      res = a.obj.getModalCounter() - b.obj.getModalCounter()
    return res
  })
}

function g_map_preview::onEventActiveHandlersChanged(p) { refreshCurPreview() }

::subscribe_handler(::g_map_preview, ::g_listener_priority.DEFAULT_HANDLER)