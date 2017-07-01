enum CREWS_READY_STATUS
{
  HAS_ALLOWED              = 0x0001
  HAS_REQUIRED_AND_ALLOWED = 0x0002

  //mask
  READY                    = 0x0003
}

const CHOSEN_EVENT_MISSIONS_SAVE_ID = "events/chosenMissions/"
const CHOSEN_EVENT_MISSIONS_SAVE_KEY = "mission"

class EventRoomCreationContext
{
  mGameMode = null
  onUnitAvailabilityChanged = null

  static options = [
    [::USEROPT_CLUSTER],
    [::USEROPT_RANK],
    [::USEROPT_BIT_COUNTRIES_TEAM_A],
    [::USEROPT_BIT_COUNTRIES_TEAM_B]
  ]

  misListType = ::g_mislist_type.BASE
  fullMissionsList = null
  chosenMissionsList = null

  curBrRange = null
  curCountries = null

  constructor(sourceMGameMode, onUnitAvailabilityChangedCb = null)
  {
    mGameMode = sourceMGameMode
    onUnitAvailabilityChanged = onUnitAvailabilityChangedCb
    curCountries = {}
    initMissionsOnce()
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getOptionsList()
  {
    return options
  }

  _optionsConfig = null
  function getOptionsConfig()
  {
    if (_optionsConfig)
      return _optionsConfig

    _optionsConfig = {
      isEventRoom = true
      brRanges = ::get_tbl_value_by_path_array(["matchmaking", "mmRanges"], mGameMode)
      countries = {}
      onChangeCb = ::Callback(onOptionChange, this)
    }
    foreach(team in ::g_team.getTeams())
      _optionsConfig.countries[team.name] <-
        ::get_tbl_value_by_path_array([team.name, "countries"], mGameMode)

    return _optionsConfig
  }

  function isAllMissionsSelected()
  {
    return !chosenMissionsList.len() || chosenMissionsList.len() == fullMissionsList.len()
  }

  function createRoom()
  {
    local reasonData = getCantCreateReasonData({ isFullText = true })
    if (!reasonData.checkStatus)
      return reasonData.actionFunc(reasonData)

    ::SessionLobby.createEventRoom(mGameMode, getRoomCreateParams())
  }

  function isUnitAllowed(unit)
  {
    if (!::events.isUnitAllowedForEvent(mGameMode, unit))
      return false

    local brRange = getCurBrRange()
    if (brRange)
    {
      local ediff = ::events.getEDiffByEvent(mGameMode)
      local unitMRank = ::get_unit_economic_rank_by_ediff(ediff, unit)
      if (unitMRank < ::getTblValue(0, brRange, 0) || ::getTblValue(1, brRange, ::max_country_rank) < unitMRank)
        return false
    }

    return isCountryAvailable(unit.shopCountry)
  }

  function isCountryAvailable(country)
  {
    foreach(team in ::g_team.getTeams())
      if (::isInArray(country, getCurCountries(team)))
        return true
    return false
  }

  function getCurCrewsReadyStatus()
  {
    local res = 0
    local country = ::get_profile_info().country
    local ediff = ::events.getEDiffByEvent(mGameMode)
    foreach (team in ::g_team.getTeams())
    {
      if (!::isInArray(country, getCurCountries(team)))
       continue

      local teamData = ::events.getTeamData(mGameMode, team.code)
      local requiredCrafts = ::events.getRequiredCrafts(teamData)
      local crews = ::get_crews_list_by_country(country)
      foreach(crew in crews)
      {
        if (::is_crew_locked_by_prev_battle(crew))
          continue
        local unit = ::g_crew.getCrewUnit(crew)
        if (!unit)
          continue

        if (!isUnitAllowed(unit))
          continue
        res = res | CREWS_READY_STATUS.HAS_ALLOWED

        if (requiredCrafts.len() && !::events.isUnitMatchesRule(unit, requiredCrafts, true, ediff))
          continue
        res = res | CREWS_READY_STATUS.HAS_REQUIRED_AND_ALLOWED

        return res
      }
    }
    return res
  }

  //same format result as ::events.getCantJoinReasonData
  function getCantCreateReasonData(params = null)
  {
    params = params ? clone params : {}
    params.isCreationCheck <- true
    local res = ::events.getCantJoinReasonData(mGameMode, null, params)
    if (res.reasonText.len())
      return res

    if (!isCountryAvailable(::get_profile_info().country))
    {
      res.reasonText = ::loc("events/no_selected_country")
    }
    else
    {
      local crewsStatus = getCurCrewsReadyStatus()
      if (!(crewsStatus & CREWS_READY_STATUS.HAS_ALLOWED))
        res.reasonText = ::loc("events/no_allowed_crafts")
      else if (!(crewsStatus & CREWS_READY_STATUS.HAS_REQUIRED_AND_ALLOWED))
        res.reasonText = ::loc("events/no_required_crafts")
    }

    if (res.reasonText.len())
    {
      res.checkStatus = false
      res.activeJoinButton = false
      if (!res.actionFunc)
        res.actionFunc = function (reasonData)
        {
          ::showInfoMsgBox(reasonData.reasonText, "cant_create_event_room")
        }
    }
    return res
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function initMissionsOnce()
  {
    chosenMissionsList = []
    fullMissionsList = []

    local missionsTbl = ::get_tbl_value_by_path_array(["mission_decl", "missions_list"], mGameMode)
    if (!missionsTbl)
      return

    local missionsNames = ::u.keys(missionsTbl)
    fullMissionsList = misListType.getMissionsListByNames(missionsNames)
    fullMissionsList = misListType.sortMissionsByName(fullMissionsList)
    loadChosenMissions()
  }

  function getMissionsSaveId()
  {
    return CHOSEN_EVENT_MISSIONS_SAVE_ID + ::events.getEventEconomicName(mGameMode)
  }

  function loadChosenMissions()
  {
    chosenMissionsList.clear()
    local blk = ::load_local_account_settings(getMissionsSaveId())
    if (!::u.isDataBlock(blk))
      return

    local chosenNames = blk % CHOSEN_EVENT_MISSIONS_SAVE_KEY
    foreach(mission in fullMissionsList)
      if (::isInArray(mission.id, chosenNames))
        chosenMissionsList.append(mission)
  }

  function saveChosenMisssions()
  {
    local names = ::u.map(chosenMissionsList, @(m) m.id)
    ::save_local_account_settings(getMissionsSaveId(), ::array_to_blk(names, CHOSEN_EVENT_MISSIONS_SAVE_KEY))
  }

  function setChosenMissions(missions)
  {
    chosenMissionsList = missions
    saveChosenMisssions()
  }

  function getCurBrRange()
  {
    if (!getOptionsConfig().brRanges)
      return null
    if (!curBrRange)
      setCurBrRange(::get_option(::USEROPT_RANK, getOptionsConfig()).value)
    return curBrRange
  }

  function setCurBrRange(rangeIdx)
  {
    local brRanges = getOptionsConfig().brRanges
    if (rangeIdx in brRanges)
      curBrRange = brRanges[rangeIdx]
  }

  function getCurCountries(team)
  {
    if (team in curCountries)
      return curCountries[team]
    if (team.teamCountriesOption < 0)
      return []
    local curMask = ::get_gui_option(team.teamCountriesOption)
    if (curMask == null)
      curMask = -1
    setCurCountries(team,  curMask)
    return curCountries[team]
  }

  function setCurCountries(team, countriesMask)
  {
    curCountries[team] <- ::get_array_by_bit_value(countriesMask, ::shopCountriesList)
  }

  function onOptionChange(optionId, optionValue, controlValue)
  {
    if (optionId == ::USEROPT_RANK)
      setCurBrRange(controlValue)
    else if (optionId == ::USEROPT_BIT_COUNTRIES_TEAM_A || optionId == ::USEROPT_BIT_COUNTRIES_TEAM_B)
      setCurCountries(::g_team.getTeamByCountriesOption(optionId), optionValue)
    else
      return

    if (onUnitAvailabilityChanged)
      ::get_cur_gui_scene().performDelayed(this, function() { onUnitAvailabilityChanged() })
  }

  function getRoomCreateParams()
  {
    local res = {
      ranks = [1, 5] //matching do nt allow to create session before ranks is set
    }

    foreach(team in ::g_team.getTeams())
      res[team.name] <- {
         countries = getCurCountries(team)
      }

    if (getCurBrRange())
      res.mranks <- getCurBrRange()

    local clusterOpt = ::get_option(::USEROPT_CLUSTER)
    res.cluster <- ::getTblValue(clusterOpt.value, clusterOpt.values, "")

    if (!isAllMissionsSelected())
      res.missions <- ::u.map(chosenMissionsList, @(m) m.id)

    return res
  }
}