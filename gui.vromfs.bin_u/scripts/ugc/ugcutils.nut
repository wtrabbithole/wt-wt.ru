function update_unit_skins_list(unitName)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return

  ::on_dl_content_skins_invalidate()
  unit.skins.clear()
  unit.skins = ::get_skins_for_unit(unitName)
}

function ugc_skin_preview(params)
{
  if (!::is_in_hangar())
  {
    return "not_in_hangar"
  }

  local blkHashName = params.hash
  local name = params?.name ?? "testName"
  local res = ugc_preview_resource(blkHashName, "skin", name)

  return res.result
}

function ugc_start_unit_preview(unitName, skinName)
{
  local unit = ::getAircraftByName(unitName)
  if (unit)
  {
    ::show_aircraft = unit
    gui_start_decals()
    broadcastEvent("SelectUGCSkinForPreview", {skinName = skinName})
  }
}

web_rpc.register_handler("ugc_skin_preview", ugc_skin_preview)
