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
  local res = ugc_preview_resource(blkHashName, "skin", "testName")

  return res.result
}

function ugc_start_unit_preview(unitName, skinName)
{
  local unit = ::getAircraftByName(unitName)
  if (unit)
  {
    ::show_aircraft = unit
    gui_start_decals()
    local handler = ::handlersManager.getActiveBaseHandler()
    if (handler && (handler instanceof ::gui_handlers.DecalMenuHandler))
      handler.applySkin(skinName, true)
  }
}

web_rpc.register_handler("ugc_skin_preview", ugc_skin_preview)
