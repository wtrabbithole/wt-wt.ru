function gui_start_aircraft_info(airName=null)
{
  airName = airName || ::show_aircraft.name
  ::gui_start_modal_wnd(::gui_handlers.showAircraftInfo, {airName = airName})
}

class ::gui_handlers.showAircraftInfo extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/infoBoxWindow.blk"
  airName = ""

  function initScreen()
  {
    local hObj = scene.findObject("message_box_header")
    hObj.setValue(::getUnitName(airName, false))

    local bObj = scene.findObject("message_box_body")
    bObj.setValue(::loc("encyclopedia/" + airName + "/desc", ::loc("encyclopedia/no_unit_description")))

    local btnLinkObj = scene.findObject("wiki_link")
    if (::checkObj(btnLinkObj))
      btnLinkObj.show(::has_feature("AllowExternalLink") && !::is_vendor_tencent())
  }

  function onWiki()
  {
    ::open_url(::format(::loc("url/wiki_objects"), airName), false, false, "unit_info_box")
  }
}
