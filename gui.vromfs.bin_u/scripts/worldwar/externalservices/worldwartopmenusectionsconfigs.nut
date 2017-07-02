::g_ww_top_menu_left_side_sections <- {
  types = []
  cache = {
    byName = {}
  }

  template = ::g_top_menu_sections.template
  getSectionByName = ::g_top_menu_sections.getSectionByName
}

::g_enum_utils.addTypesByGlobalName("g_ww_top_menu_left_side_sections", [
  {
    name = "ww_menu"
    btnName = "ww_menu"
    getText = function(totalSections = 0) { return ::is_low_width_screen()? null : "#worldWar/menu" }
    getImage = function(totalSections = 0) { return ::is_low_width_screen()? "#ui/gameuiskin#btn_info" : null }
    buttons = [
      [
        ::g_top_menu_buttons.WW_OPERATIONS
        ::g_top_menu_buttons.HANGAR
      ]
    ]
  }
  {
    name = "ww_map_filter"
    minimalWidth = true
    forceHoverWidth = "0.55@scrn_tgt_font"
    getText = function(totalSections = 0) { return ::is_low_width_screen()? null : "#worldwar/mapFilters" }
    getImage = function(totalSections = 0) { return "#ui/gameuiskin#render_army_rad" }
    buttons = [
      [
        ::g_top_menu_buttons.WW_FILTER_RENDER_ZONES
        ::g_top_menu_buttons.WW_FILTER_RENDER_ARROWS
        ::g_top_menu_buttons.WW_FILTER_RENDER_ARROWS_FOR_SELECTED
        ::g_top_menu_buttons.WW_FILTER_RENDER_BATTLES
        ::g_top_menu_buttons.WW_FILTER_RENDER_MAP_PICTURES
        ::g_top_menu_buttons.WW_FILTER_RENDER_DEBUG
      ]
    ]
  }
])