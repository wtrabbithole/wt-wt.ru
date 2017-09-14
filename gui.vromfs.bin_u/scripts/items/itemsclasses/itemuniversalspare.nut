class ::items_classes.UniversalSpare extends ::BaseItem
{
  static iType = itemType.UNIVERSAL_SPARE
  static defaultLocId = "universalSpare"
  static defaultIcon = "#ui/gameuiskin#item_uni_spare"
  static typeIcon = "#ui/gameuiskin#item_type_uni_spare"

  canBuy = true
  allowBigPicture = false

  countries = null
  numSpares = 0
  minRank = 0
  maxRank = 0
  unitTypes = null

  constructor(blk, invBlk = null, slotData = null)
  {
    local paramsBlk = blk.universalSpareParams
    if (!::u.isDataBlock(paramsBlk))
      return
    base.constructor(blk, invBlk, slotData)
    countries = paramsBlk % "country"
    unitTypes = paramsBlk % "unitType"
    numSpares = paramsBlk.numSpares || 1
    minRank = paramsBlk.minRank || 1
    maxRank = paramsBlk.maxRank || ::max_country_rank
  }

  function getDescription()
  {
    local textParts = []
    textParts.push(::loc("items/universalSpare/description/uponActivation"))
    if (numSpares > 1)
      textParts.push(::loc("items/universalSpare/numSpares") + ::loc("ui/colon") + ::colorize("activeTextColor", numSpares))
    if (countries.len() > 0)
    {
      local locCountries = ::u.map(countries, @ (country) ::loc("unlockTag/" + country))
      textParts.push(::loc("trophy/unlockables_names/country") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locCountries, ", ")))
    }
    if (unitTypes.len() > 0)
    {
      local locUnitTypes = ::u.map(unitTypes, @ (unitType) ::loc("mainmenu/type_" + unitType))
      textParts.push(::loc("mainmenu/btnUnits") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locUnitTypes, ", ")))
    }
    textParts.push(::loc("sm_rank") + ::loc("ui/colon") + ::colorize("activeTextColor", getRankText()))
    textParts.push(::colorize("fadedTextColor", ::loc("items/universalSpare/description")))
    return ::g_string.implode (textParts, "\n")
  }

  function getRankText()
  {
    return ::getUnitRankName(minRank) + ((minRank != maxRank) ? "-" + ::getUnitRankName(maxRank) : "")
  }

  function getName(colored = true)
  {
    return base.getName(colored) + " " + getRankText()
  }

  function canActivateOnUnit(unit)
  {
    if (countries.len() && !::isInArray(unit.shopCountry, countries))
      return false
    if (unit.rank < minRank || unit.rank > maxRank)
      return false
    if (unitTypes.len() && !::isInArray(unit.unitType.tag, unitTypes))
      return false
    return true
  }

  function activateOnUnit(unit, count, extSuccessCb = null)
  {
    if (!canActivateOnUnit(unit)
      || !isInventoryItem || !uids.len()
      || count <= 0 || count > getAmount())
      return false

    local successCb = function() {
      if (extSuccessCb)
        extSuccessCb()
      ::broadcastEvent("UniversalSpareActivated")
    }

    local blk = ::DataBlock()
    blk.uid = uids[0]
    blk.unit = unit.name
    blk.useItemsCount = count
    local taskId = ::char_send_blk("cln_apply_spare_item", blk)
    return ::g_tasker.addTask(taskId, { showProgressBox = true }, successCb)
  }

  function getIcon(addItemName = true)
  {
    local res = ::LayersIcon.genDataFromLayer(_getBaseIconCfg())
    res += ::LayersIcon.genDataFromLayer(_getFlagLayer())
    res += ::LayersIcon.genDataFromLayer(_getuUnitTypesLayer())
    res += ::LayersIcon.getTextDataFromLayer(_getRankLayer())
    return res
  }

  function _getBaseIconCfg()
  {
    local layerId = "universal_spare_base"
    return ::LayersIcon.findLayerCfg(layerId)
  }

  function _getuUnitTypesLayer()
  {
    if (unitTypes.len() != 1)
      return ::LayersIcon.findLayerCfg("universal_spare_all")
    return ::LayersIcon.findLayerCfg("universal_spare_" + unitTypes[0])
  }

  function _getRankLayer()
  {
    local textLayerStyle = "universal_spare_rank_text"
    local layerCfg = ::LayersIcon.findLayerCfg(textLayerStyle)
    if (!layerCfg)
      return null
    layerCfg.text <- getRankText()
    return layerCfg
  }

  function _getFlagLayer()
  {
    if (countries.len() != 1)
      return null
    local flagLayerStyle = "universal_spare_flag"
    local layerCfg = ::LayersIcon.findLayerCfg(flagLayerStyle)
    if (!layerCfg)
      return null
    layerCfg.img <- ::get_country_icon(countries[0])
    return layerCfg
  }
}
