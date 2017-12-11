function gui_modal_rank_versus_info(unit)
{
  ::gui_start_modal_wnd(::gui_handlers.RankVersusInfo, { unit = unit })
}

class ::gui_handlers.RankVersusInfo extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/airInfo/rankVersusInfo.blk"

  unit = null
  unitTooltipParams = null
  allUnitTypes = false
  allUnitTypesSaveName = "allUnitTypes"
  gameModes = null
  selectedGameMode = null

  function initScreen()
  {
    if (!unit)
      return goBack()

    unitTooltipParams = { ratingCountry = unit.shopCountry }

    allUnitTypes = ::loadLocalByAccount(allUnitTypesSaveName, allUnitTypes)

    scene.findObject("all_units_types").setValue(allUnitTypes)

    local unitType = ::get_es_unit_type(unit)
    gameModes = ::game_mode_manager.getGameModes(unitType, function (gameMode) {
      return !gameMode.forClan
    })
    fillModeListBox(gameModes)

    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    local index = ::max(::find_in_array(gameModes, currentGameMode), 0)
    setModesListValue(index)
  }

  function getUnitsData()
  {
    local maxRankDiff = 3 //!!FIX ME: need to get this value from matchng
    local res = {}
    local rating = {}
    foreach(country in ::shopCountriesList)
    {
      res[country] <- {}
      rating[country] <- getUnitEconomicRank(unit)
    }
    unitTooltipParams.economicRankCompare <- rating

    local unitType = ::get_es_unit_type(unit)
    local country = unit.shopCountry
    foreach(u in ::all_units)
    {
      if (!u.isInShop)
        continue
      local uCountry = u.shopCountry
      if (!(uCountry in res))
      {
        ::dagor.assertf(false, "Error: Unit " + u.name + " have country not exist in shop: '" + uCountry + "'")
        continue
      }

      if (!allUnitTypes && unitType != ::get_es_unit_type(u))
        continue

      local rank = getUnitEconomicRank(u)
      if (fabs(rank.tofloat() - rating[uCountry]) > maxRankDiff)
        continue

      local role = ::get_unit_basic_role(u)
      if (role in res[uCountry])
        res[uCountry][role].append(u)
      else
        res[uCountry][role] <- [u]
    }

    foreach(cName, cList in res)
      foreach(unitList in cList)
      {
        local cRating = rating[cName].tofloat()
        unitList.sort((@(country, cRating) function(a, b) {
          local ratingA = getUnitEconomicRank(a)
          local ratingB = getUnitEconomicRank(b)
          local diffA = fabs(cRating - ratingA)
          local diffB = fabs(cRating - ratingB)
          if (diffA > diffB) return 1
            else if (diffA < diffB) return -1
          if (ratingA > ratingB) return 1
            else if (ratingA < ratingB) return -1
          if (a.rank != b.rank)
            return (a.rank > b.rank) ? 1 : -1
          return 0
        })(country, cRating).bindenv(this))
      }
    return res
  }

  function fillUnitSlot()
  {
    local unitObj = scene.findObject("unit_place")
    local data = ::build_aircraft_item(unit.name, unit, {
      status = "owned"
      showBR = ::has_feature("SlotbarShowBattleRating")
      getEdiffFunc = getCurrentEdiff.bindenv(this)
    })
    guiScene.replaceContentFromText(unitObj, data, data.len(), this)
    ::fill_unit_item_timers(unitObj.findObject(unit.name), unit)
  }

  function fillRanks()
  {
    local unitType = ::get_es_unit_type(unit)

    local rolesOrder = []
    if (unitType in ::basic_unit_roles)
      rolesOrder.extend(::basic_unit_roles[unitType])
    foreach(ut, roles in ::basic_unit_roles)
      if (ut != unitType)
        rolesOrder.extend(roles)

    local view = {
      total = ::shopCountriesList.len()
      countries = []
    }

    local units = getUnitsData()
    foreach(country in ::shopCountriesList)
    {
      local countryData = {
        countryIcon = ::get_country_icon(country)
        types = []
      }

      foreach(role in rolesOrder)
        if (role in units[country])
        {
          local typeData = {
            typeName = ::get_role_text(role)
            units = []
          }
          foreach(u in units[country][role])
            typeData.units.append({
              ico = ::getUnitClassIco(u)
              type = ::get_unit_role(u)
              tooltipId = ::g_tooltip.getIdUnit(u.name, unitTooltipParams)
              text = ::getUnitName(u, true)
            })
          countryData.types.append(typeData)
        }

      view.countries.append(countryData)
    }

    local data = ::handyman.renderCached(("gui/airInfo/countriesAirsList"), view)
    local infoObj = scene.findObject("info_block")
    guiScene.replaceContentFromText(infoObj, data, data.len(), this)
  }

  function fillModeListBox(gameModes)
  {
    local modesList = getObj("modes_list")
    if (!::checkObj(modesList))
      return
    local currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    local view = { tabs = [] }
    foreach (gameModeIndex, gameMode in gameModes)
      view.tabs.append({
        tabName = gameMode.text
        selected = gameMode.id == currentGameModeId
        navImagesText = ::get_navigation_images_text(gameModeIndex, gameModes.len())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(modesList, data, data.len(), this)
  }

  function setModesListValue(value)
  {
    local modesList = getObj("modes_list")
    if (!::checkObj(modesList))
      return
    modesList.setValue(value)
    onModeChange(modesList)
  }

  function getUnitEconomicRank(unit)
  {
    return ::game_mode_manager.getUnitEconomicRankByGameMode(selectedGameMode, unit)
  }

  function getCurrentEdiff()
  {
    local ediff = selectedGameMode ? selectedGameMode.ediff : -1
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onModeChange(obj)
  {
    local value = ::clamp(obj.getValue(), 0, gameModes.len())
    selectedGameMode = gameModes[value]
    fillUnitSlot()
    fillRanks()
  }

  function onAllUnitsTypes(obj)
  {
    local value = obj.getValue()
    if (value == allUnitTypes)
      return
    allUnitTypes = value
    ::saveLocalByAccount(allUnitTypesSaveName, allUnitTypes)
    fillRanks()
  }
}
