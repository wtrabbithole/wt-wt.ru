local wwTopMenuButtons = {
  template = {
    category = -1
    value = @() ::g_world_war_render.isCategoryEnabled(category)
    onChangeValueFunc = @(value) ::g_world_war_render.setCategory(category, value)
    isHidden = @(...) !::g_world_war_render.isCategoryVisible(category)
    elementType = TOP_MENU_ELEMENT_TYPE.CHECKBOX
  }

  list = {
    WW_OPERATIONS = {
      text = "#worldWar/menu/selectOperation"
      onClickFunc = @(obj, handler) "goBackToOperations" in handler? handler.goBackToOperations() : null
      elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
    }
    WW_HANGAR = {
      text = "#worldWar/menu/quitToHangar"
      onClickFunc = @(obj, handler) "goBackToHangar" in handler? handler.goBackToHangar() : null
      elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
    }
    WW_FILTER_RENDER_ZONES = {
      category = ::ERC_ZONES
      text = ::loc("worldwar/renderMap/render_zones")
      useImage = "#ui/gameuiskin#render_zones"
    }
    WW_FILTER_RENDER_ARROWS = {
      category = ::ERC_ALL_ARROWS
      text = ::loc("worldwar/renderMap/render_arrows")
      useImage = "#ui/gameuiskin#btn_weapons.svg"
      isHidden = @(...) true
    }
    WW_FILTER_RENDER_ARROWS_FOR_SELECTED = {
      category = ::ERC_ARROWS_FOR_SELECTED_ARMIES
      text = ::loc("worldwar/renderMap/render_arrows_for_selected")
      useImage = "#ui/gameuiskin#render_arrows"
    }
    WW_FILTER_RENDER_BATTLES = {
      category = ::ERC_BATTLES
      text = ::loc("worldwar/renderMap/render_battles")
      useImage = "#ui/gameuiskin#battles_open"
    }
    WW_FILTER_RENDER_MAP_PICTURES = {
      category = ::ERC_MAP_PICTURE
      text = ::loc("worldwar/renderMap/render_map_picture")
      useImage = "#ui/gameuiskin#battles_open"
      isHidden = @(...) true
    }
    WW_FILTER_RENDER_DEBUG = {
      value = @() ::g_world_war.isDebugModeEnabled()
      text = "Debug Mode"
      useImage = "#ui/gameuiskin#battles_closed"
      onChangeValueFunc = @(value) ::g_world_war.setDebugMode(value)
      isHidden = @(...) !::has_feature("worldWarMaster")
    }
  }

  result = {}
}

foreach (name, buttonCfg in wwTopMenuButtons.list)
  wwTopMenuButtons.result[name] <- ::u.tablesCombine(
    buttonCfg,
    wwTopMenuButtons.template,
    @(val1, val2) val1 != null? val1 : val2
  )

::g_enum_utils.addTypesByGlobalName("g_top_menu_buttons", wwTopMenuButtons.result, null, "id")