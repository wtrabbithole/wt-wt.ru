// Priority for separation on buttons.
enum topMenuLeftSideMergeIndex {
  MENU
  PVP
  COMMUNITY
}

::g_top_menu_left_side_sections <- {
  types = []
  cache = {
    byName = {}
  }

  template = ::g_top_menu_sections.template
  getSectionByName = ::g_top_menu_sections.getSectionByName
}

/*
Columns are each array in buttons array.
Params - can be whole section ('help', 'pve') or single button.
*/
::g_enum_utils.addTypesByGlobalName("g_top_menu_left_side_sections", [
  {
    name = "menu"
    btnName = "start"
    getText = function(totalSections = 0) { return totalSections == 1? "#topmenu/menu" : null }
    mergeIndex = topMenuLeftSideMergeIndex.MENU
    getImage = function(totalSections = 0) { return totalSections == 1? null : "#ui/gameuiskin#slot_modifications" }
    buttons = [
      [
        "pvp"
      ],
      [
        ::g_top_menu_buttons.OPTIONS
        ::g_top_menu_buttons.CONTROLS
        ::g_top_menu_buttons.ENCYCLOPEDIA
        "community"
        ::g_top_menu_buttons.CREDITS
        ::g_top_menu_buttons.EXIT
        ::g_top_menu_buttons.DEBUG_UNLOCK
      ]
    ]
  },
  {
    name = "pvp"
    getText = function(totalSections = 0) { return "#topmenu/battle" }
    mergeIndex = topMenuLeftSideMergeIndex.PVP
    buttons = [
      [
        ::g_top_menu_buttons.SKIRMISH
        ::g_top_menu_buttons.WORLDWAR
        ::g_top_menu_buttons.LINE_SEPARATOR
        ::g_top_menu_buttons.USER_MISSION
        ::g_top_menu_buttons.TUTORIAL
        ::g_top_menu_buttons.SINGLE_MISSION
        ::g_top_menu_buttons.DYNAMIC
        ::g_top_menu_buttons.CAMPAIGN
        ::g_top_menu_buttons.BENCHMARK
      ]
    ]
  },
  {
    name = "community"
    getText = function(totalSections = 0) { return "#topmenu/community" }
    mergeIndex = topMenuLeftSideMergeIndex.COMMUNITY
    buttons = [
      [
        ::g_top_menu_buttons.LEADERBOARDS
        ::g_top_menu_buttons.CLANS
        ::g_top_menu_buttons.REPLAY
        ::g_top_menu_buttons.VIRAL_AQUISITION
        ::g_top_menu_buttons.TSS
        ::g_top_menu_buttons.STREAMS_AND_REPLAYS
      ]
    ]
  }
])
