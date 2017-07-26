class WwMap
{
  name = ""
  data = null

  constructor(_name, _data)
  {
    data = _data
    name = _name
  }

  function tostring()
  {
    return "WwMap(" + name + ", " + ::toString(data) + ")"
  }

  function getId()
  {
    return name
  }

  function isEqual(map)
  {
    return map != null && map.name == name
  }

  function isVisible()
  {
    return (getOpGroup().hasActiveOperations() || ::is_in_clan()) &&
      (getChapterId() != "" || ::has_feature("worldWarShowTestMaps"))
  }

  function getChapterId()
  {
    return ::getTblValue("operationChapter", data, "")
  }

  function getChapterText()
  {
    local chapterId = getChapterId()
    return ::loc(chapterId != "" ? ("ww_operation_chapter/" + chapterId) : "chapters/test")
  }

  function isDebugChapter()
  {
    return getChapterId() == ""
  }

  function getNameText()
  {
    return ::loc(getNameLocId())
  }

  function getNameLocId()
  {
    return "worldWar/map/" + name
  }

  function getImage()
  {
    local mapImageName = ::getTblValueByPath("info.image", data, null)
    if (::u.isEmpty(mapImageName))
      return ""

    return "@" + mapImageName + "*"
  }

  function getDescription(needShowGroupInfo = true)
  {
    local baseDesc = ::loc("worldWar/map/" + name + "/desc", "")
    if (!needShowGroupInfo)
      return baseDesc

    local txtList = []
    if (getOpGroup().isMyClanParticipate())
      txtList.append(::colorize("userlogColoredText", ::loc("worldwar/yourClanInOperationHere")))
    txtList.append(baseDesc)
    return ::implode(txtList, "\n")
  }

  function getGeoCoordsText()
  {
    local latitude  = ::getTblValue("worldMapLatitude", data, 0.0)
    local longitude = ::getTblValue("worldMapLongitude", data, 0.0)

    local ud = ::loc("measureUnits/deg")
    local um = ::loc("measureUnits/degMinutes")
    local us = ::loc("measureUnits/degSeconds")

    local cfg = [
      { deg = ::fabs(latitude),  hem = latitude  >= 0 ? "N" : "S" }
      { deg = ::fabs(longitude), hem = longitude >= 0 ? "E" : "W" }
    ]

    local coords = []
    foreach (c in cfg)
    {
      local d  = c.deg.tointeger()
      local t = (c.deg - d) * 60
      local m  = t.tointeger()
      local s = (t - m) * 60
      coords.append(::format("%d%s%02d%s%05.2f%s%s", d, ud, m, um, s, us, c.hem))
    }
    return ::implode(coords, ::loc("ui/comma"))
  }

  function getCountryToSideTbl()
  {
    return ::get_tbl_value_by_path_array(["info", "countries"], data, {})
  }

  function getUnitInfoBySide(side)
  {
    return ::getTblValueByPath("info.sides.SIDE_" + side + ".units", data, null)
  }

  _cachedCountriesByTeams = null
  function getCountriesByTeams()
  {
    if (_cachedCountriesByTeams)
      return _cachedCountriesByTeams

    _cachedCountriesByTeams = {}
    local countries = getCountryToSideTbl()
    foreach(c in ::shopCountriesList)
    {
      local side = ::getTblValue(c, countries, ::SIDE_NONE)
      if (side == ::SIDE_NONE)
        continue

      if (!(side in _cachedCountriesByTeams))
        _cachedCountriesByTeams[side] <- []
      _cachedCountriesByTeams[side].append(c)
    }

    return _cachedCountriesByTeams
  }

  function getCountries()
  {
    local res = []
    foreach (cList in getCountriesByTeams())
      res.extend(cList)
    return res
  }

  function canJoinByCountry(country)
  {
    local countriesByTeams = getCountriesByTeams()
    foreach(cList in countriesByTeams)
      if (::isInArray(country, cList))
        return true
    return false
  }

  function getQueue()
  {
    return ::g_ww_global_status.getQueueByMapName(name)
  }

  function getOpGroup()
  {
    return ::g_ww_global_status.getOperationGroupByMapId(name)
  }

  function getPriority()
  {
    local res = getOpGroup().getPriority()
    if (getQueue().isMyClanJoined())
      res = res | WW_MAP_PRIORITY.MY_CLAN_IN_QUEUE
    return res
  }

  function getCountriesViewBySide(side, hasBigCountryIcon = true)
  {
    local countries = getCountryToSideTbl()
    local countryNames = ::u.keys(countries)
    local countryList = ::u.filter(countryNames,
                          (@(countries, side) function(country) {
                            return countries[country] == side
                          })(countries, side)
                        )

    local res = ""
    local iconType = hasBigCountryIcon ? "small_country" : "country_battle"
    foreach (idx, country in countryList)
    {
      local countryIcon = ::get_country_icon(country, hasBigCountryIcon)
      local margin = idx > 0 ? "margin-left:t='@blockInterval'" : ""

      res += ::format("img { iconType:t='%s'; background-image:t='%s'; %s }", iconType, countryIcon, margin)
    }

    return res
  }
}
