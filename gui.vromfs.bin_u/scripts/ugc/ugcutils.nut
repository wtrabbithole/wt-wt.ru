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
  if (!::has_feature("EnableUgcSkins"))
  {
    return "not_allowed"
  }

  if (!::g_login.isLoggedIn())
  {
  return "not_logged_in"
  }

  if (!::is_in_hangar())
  {
    return "not_in_hangar"
  }

  if (!hangar_is_loaded())
  {
    return "hangar_not_ready"
  }

  local blkHashName = params.hash
  local name = params?.name ?? "testName"
  local shouldPreviewForApprove = params?.previewForApprove ?? false
  local res = shouldPreviewForApprove ? ugc_preview_resource_for_approve(blkHashName, "skin", name) :
                                        ugc_preview_resource(blkHashName, "skin", name)

  return res.result
}

function ugc_start_unit_preview(unitName, skinName, isForApprove)
{
  local unit = ::getAircraftByName(unitName)
  if (unit)
  {
    ::show_aircraft = unit
    gui_start_decals()
    broadcastEvent("SelectUGCSkinForPreview", {unitName = unitName, skinName = skinName, isForApprove = isForApprove})
  }
}

web_rpc.register_handler("ugc_skin_preview", ugc_skin_preview)
