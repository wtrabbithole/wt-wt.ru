function exportUnitInfo(params)
{
    UnitInfoExporter(params["langs"], params["path"])
    return "ok"
}

const COUNTRY_GROUP = "country"
const ARMY_GROUP = "army"
const RANK_GROUP = "rank"
const COMMON_PARAMS_GROUP = "common"
const BASE_GROUP = "base"
const EXTENDED_GROUP = "extended"


web_rpc.register_handler("exportUnitInfo", exportUnitInfo)

class UnitInfoExporter
{
  static EXPORT_TIME_OUT = 20000
  static activeUnitInfoExporters = []
  lastActiveTime = -1

  path = "export"
  langsList = null

  langBeforeExport = ""
  curLang = ""

  isToStringForDebug = true

  fullBlk = null
  unitsList = null

  constructor(genLangsList = ["English", "Russian"], genPath = "export") //null - export all langs
  {
    if (!isReadyStartExporter())
      return

    activeUnitInfoExporters.append(this)
    updateActive()

    ::subscribe_handler(this)

    langBeforeExport = ::get_current_language()
    if (::u.isArray(genLangsList))
      langsList = clone genLangsList
    else if (::u.isString(genLangsList))
      langsList = [genLangsList]
    else
      langsList = ::u.map(::g_language.getGameLocalizationInfo(), function(lang) { return lang.id })

    path = genPath

    ::get_main_gui_scene().performDelayed(this, nextLangExport)  //delay to show exporter logs
  }

  function _tostring()
  {
    return format("Exporter(%s, '%s')", ::toString(langsList), path)
  }

  function isReadyStartExporter()
  {
    if (!activeUnitInfoExporters.len())
      return true

    if (activeUnitInfoExporters[0].isStuck())
    {
      activeUnitInfoExporters[0].remove()
      return true
    }

    dlog("Exporter: Error: Previous exporter not finish process")
    return false
  }

  function isValid()
  {
    foreach(idx, exporter in activeUnitInfoExporters)
      if (exporter == this)
        return true
    return false
  }

  function isStuck()
  {
    return ::dagor.getCurTime() - lastActiveTime < EXPORT_TIME_OUT
  }

  function updateActive()
  {
    lastActiveTime = ::dagor.getCurTime()
  }

  function remove()
  {
    foreach(idx, exporter in activeUnitInfoExporters)
      if (exporter == this)
        activeUnitInfoExporters.remove(idx)

    ::g_language.setGameLocalization(langBeforeExport, false, false)
  }

  /******************************************************************************/
  /********************************EXPORT PROCESS********************************/
  /******************************************************************************/

  function nextLangExport()
  {
    if (!langsList.len())
    {
      remove()
      dlog("Exporter: DONE.")
      return
    }

    curLang = langsList.pop()
    ::g_language.setGameLocalization(curLang, false, false)

    dlog("Exporter: gen all units info to " + getFullPath())
    ::get_main_gui_scene().performDelayed(this, startExport) //delay to show exporter logs
  }

  function getFullPath()
  {
    local relPath = ::u.isEmpty(path) ? "" : (path + "/")
    return ::format("%sunitInfo%s.blk", relPath, curLang)
  }

  function startExport()
  {
    fullBlk = ::DataBlock()
    exportArmy(fullBlk)
    exportCountry(fullBlk)
    exportRank(fullBlk)
    exportCommonParams(fullBlk)

    fullBlk[BASE_GROUP] = ::DataBlock()
    fullBlk[EXTENDED_GROUP] = ::DataBlock()

    unitsList = ::u.values(::all_units)

    updateActive()

    processUnits()
  }

  function finishExport(fullBlk)
  {
    fullBlk.saveToTextFile(getFullPath())
    ::get_main_gui_scene().performDelayed(this, nextLangExport) //delay to show exporter logs
  }

  function exportArmy(fullBlk)
  {
    fullBlk[ARMY_GROUP] = ::DataBlock()

    foreach(army in ::g_unit_type.types)
    {
      if(army.isAvailable())
      {
        fullBlk[ARMY_GROUP][army.armyId] = army.getArmyLocName()
      }
    }
  }

  function exportCountry(fullBlk)
  {
    fullBlk[COUNTRY_GROUP] = ::DataBlock()

    foreach(country in ::shopCountriesList)
    {
      fullBlk[COUNTRY_GROUP][country] = ::loc(country)
    }
  }

  function exportRank(fullBlk)
  {
    fullBlk[RANK_GROUP] = ::DataBlock()
    fullBlk[RANK_GROUP].header = ::loc("shop/age")
    fullBlk[RANK_GROUP].texts = ::DataBlock()

    for(local rank = 1; rank <= ::max_country_rank; rank++)
    {
      fullBlk[RANK_GROUP]["texts"][rank.tostring()] = ::getUnitRankName(rank)
    }
  }

  function exportCommonParams(fullBlk)
  {
    fullBlk[COMMON_PARAMS_GROUP] = ::DataBlock()

    foreach(infoType in ::g_unit_info_type.types)
    {
      fullBlk[COMMON_PARAMS_GROUP][infoType.id] = infoType.exportCommonToDataBlock()
    }
  }

  function onEventUnitModsRecount(params)
  {
    processUnits()
  }

  function processUnits()
  {
    while (unitsList.len())
    {
        if(!exportCurUnit(fullBlk, unitsList[unitsList.len() - 1]))
          return
        unitsList.pop()
    }
    finishExport(fullBlk)
  }

  function exportCurUnit(fullBlk, curUnit)
  {
    if(!curUnit.isInShop || ::get_es_unit_type(curUnit) >= ::ES_UNIT_TYPE_TOTAL_RELEASED)
      return true

    if(!("modificators" in curUnit))
    {
      if(isTank(curUnit))
        return check_unit_mods_update(curUnit)
    }
    local groupId = ::getTblValue("showOnlyWhenBought", curUnit, false)? EXTENDED_GROUP : BASE_GROUP

    local armyId = curUnit.unitType.armyId
    local countryId = curUnit.shopCountry
    local rankId = curUnit.rank.tostring()

    local unitBlk = ::DataBlock()

    foreach(infoType in ::g_unit_info_type.types)
    {
      local blk = infoType.exportToDataBlock(curUnit)
      if(blk.hide)
        continue
      unitBlk[infoType.id] = blk
    }

    local targetBlk = fullBlk.addBlock(groupId).addBlock(armyId).addBlock(countryId).addBlock(rankId)
    targetBlk[curUnit.name] = unitBlk
    return true
  }
}