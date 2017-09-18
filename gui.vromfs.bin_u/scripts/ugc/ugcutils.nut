function update_unit_skins_list(unitName)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return

  unit.skins.clear()
  unit.skins = ::get_skins_for_unit(unitName)
}

function ugc_skin_preview(params)
{
  local blkHashName = params.hash

  return ugc_preview_resource(blkHashName, "skin", "testName")
}

web_rpc.register_handler("ugc_skin_preview", ugc_skin_preview)
