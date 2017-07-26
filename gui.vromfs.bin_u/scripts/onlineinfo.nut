const MAX_FETCH_RETRIES = 5

// -------------------------------------------------------
// Online info start
::online_stats <- {
  players_total = 0
  rooms_total = 0
}

::available_countries_info <-
{
  [0] = { //arcade
     country_ussr = 1,
     country_japan = 1,
     country_usa = 1,
     country_germany = 1,
     country_britain = 1
  },
  [1] = { //historical
     country_0 = 1,
     country_ussr = 1,
     country_japan = 1,
     country_usa = 1,
     country_germany = 1,
     country_britain = 1
  },
  [2] = { //realistic
     country_0 = 1,
     country_ussr  = 1,
     country_japan = 1,
     country_usa   = 1,
     country_germany = 1,
     country_britain = 1
  }
}

::last_show_update_popup_time <- -60000
::online_info_server_time_param <- 0
::online_info_server_time_recieved <- 0

::g_script_reloader.registerPersistentData("onlineInfoGlobals", ::getroottable(),
  ["online_stats", "online_info_server_time_param", "online_info_server_time_recieved"])

function get_mode_by_diff(diff)
{
  return ::g_difficulty.getDifficultyByDiffCode(diff).gameTypeName
}

function get_matching_server_time()
{
  return ::online_info_server_time_param + (dagor.getCurTime()/1000 - ::online_info_server_time_recieved)
}

// Online info functions end
// -------------------------------------------------------

// -------------------------------------------------------
// Clusters managment
// -------------------------------------------------------
g_clusters <- {
  clusters_info = []

  function forceUpdateClustersList()
  {
    __clusters_fetching = false
    __update_clusters_list()
  }

  function onClustersLoaded(params)
  {
    dagor.debug("[MM] clusters loaded")
    debugTableData(params)

    local clusters = ::getTblValue("clusters", params)
    if (!::u.isArray(clusters))
      return false

    clusters_info.clear()
    foreach (idx, val in params.clusters)
      clusters_info.push({name = val})
    //TODO: need to update clusters in GUI

    return clusters_info.len() > 0
  }

  function onClustersChanged(params)
  {
    if ("added" in params)
    {
      foreach (cluster in params.added)
      {
        local found = false
        foreach (idx, c in clusters_info)
        {
          if (c.name == cluster)
          {
            found = true
            break
          }
        }
        if (!found)
        {
          clusters_info.push({name = cluster})
          dagor.debug("[MM] cluster added " + cluster)
        }
      }
    }

    if ("removed" in params)
    {
      foreach (cluster in params.removed)
      {
        foreach (idx, c in clusters_info)
        {
          if (c.name == cluster)
          {
            clusters_info.remove(idx)
            break
          }
        }
        dagor.debug("[MM] cluster removed " + cluster)
      }
    }
    dagor.debug("clusters list updated")
    debugTableData(clusters_info)
    //TODO: need to update clusters in GUI
  }

// private
  __clusters_fetching = false
  __fetch_counter = 0

  function __update_clusters_list()
  {
    if (__clusters_fetching)
      return

    __clusters_fetching = true
    __fetch_counter++
    ::fetch_clusters_list(null,
      function(params)
      {
        __clusters_fetching = false

        if (::checkMatchingError(params, false)
            && onClustersLoaded(params))
        {
          __fetch_counter = 0
          return
        }

        //clusters not loaded or broken data
        if (__fetch_counter < MAX_FETCH_RETRIES)
        {
          dagor.debug("fetch cluster error, retry - " + __fetch_counter)
          __update_clusters_list()
        } else
        {
          ::checkMatchingError(params, true)
          if (!::is_dev_version)
            ::gui_start_logout()
        }
      }.bindenv(::g_clusters))
  }

  function onEventSignOut(p)
  {
    clusters_info.clear()
  }

  function onEventScriptsReloaded(p)
  {
    forceUpdateClustersList()
  }

  function onEventMatchingConnect(p)
  {
    forceUpdateClustersList()
  }

  function getClusterLocName(clusterName)
  {
    if (clusterName.find("wthost") != null)
      return clusterName
    return ::loc("cluster/" + clusterName)
  }
}

::subscribe_handler(::g_clusters)

// -------------------------------------------------------
// Matching game modes managment
// -------------------------------------------------------
g_matching_game_modes <- {
  __gameModes = {} // game-mode unique id -> mode info

  __fetching = false
  __fetch_counter = 0

  function forceUpdateGameModes()
  {
    __fetching = false
    __fetch_counter = 0
    fetchGameModes()
  }

  function fetchGameModes()
  {
    if (__fetching)
      return

    __gameModes.clear()
    __fetching = true
    __fetch_counter++
    ::fetch_game_modes_digest(null,
      function (result)
      {
        __fetching = false

        local canRetry = __fetch_counter < MAX_FETCH_RETRIES
        if (::checkMatchingError(result, !canRetry))
        {
          __loadGameModesFromList(::getTblValue("modes", result, []))
          __fetch_counter = 0
          return
        }

        if (!canRetry)
        {
          if (!::is_dev_version)
            ::gui_start_logout()
        }
        else
        {
          dagor.debug("fetch gamemodes error, retry - " + __fetch_counter)
          fetchGameModes()
        }
      }.bindenv(::g_matching_game_modes)
    )
  }

  function getModeById(gameModeId)
  {
    return getTblValue(gameModeId, __gameModes, null)
  }

  function  onGameModesChangedNotify(added_list, removed_list, changed_list)
  {
    local needNotify = false
    local needToFetchGmList = []

    if (removed_list)
    {
      foreach (modeInfo in removed_list)
      {
        local gameModeId = ::getTblValue("gameModeId", modeInfo, -1)
        dagor.debug(format("matching game mode removed '%s' [%d]",
                            ::getTblValue("name", modeInfo, ""), gameModeId))
        __removeGameMode(gameModeId)
        needNotify = true
      }
    }

    if (added_list)
    {
      foreach (modeInfo in added_list)
      {
        local gameModeId = ::getTblValue("gameModeId", modeInfo, -1)
        dagor.debug(format("matching game mode added '%s' [%d]",
                            ::getTblValue("name", modeInfo, ""), gameModeId))
        needToFetchGmList.push(gameModeId)
      }
    }

    if (changed_list)
    {
      foreach (modeInfo in changed_list)
      {
        local gameModeId = ::getTblValue("gameModeId", modeInfo)
        if (gameModeId == null)
          continue

        local name     = ::getTblValue("name", modeInfo, "")
        local disabled = ::getTblValue("disabled", modeInfo)
        local visible  = ::getTblValue("visible", modeInfo)
        local active   = ::getTblValue("active", modeInfo)

         // when flags no set or not gamemode exist need refresh full mode-info
        if (disabled == null || visible == null || active == null
            || !(gameModeId in __gameModes))
        {
          needToFetchGmList.push(gameModeId)
          continue
        }

        needNotify = true
        dagor.debug(format("matching game mode %s '%s' [%d]",
                            disabled ? "disabled" : "enabled"
                            name, gameModeId))

        if (disabled && !visible && !active)
          __removeGameMode(gameModeId)
        else
        {
          local fullModeInfo = __gameModes[gameModeId]
          fullModeInfo.disabled = disabled
          fullModeInfo.visible = visible
        }
      }
    }

    if (needToFetchGmList.len() > 0)
      __loadGameModesFromList(needToFetchGmList)

    if (needNotify)
      __notifyGmChanged()
  }

// private section
  function __notifyGmChanged()
  {
    local gameEventsOldFormat = {}
    foreach (gm_id, modeInfo in __gameModes)
    {
      if (::events.isCustomGameMode(modeInfo))
        continue
      if ("team" in modeInfo && !("teamA" in modeInfo) && !("teamB" in modeInfo))
        modeInfo.teamA <- modeInfo.team
      gameEventsOldFormat[modeInfo.name] <- modeInfo
    }
    ::events.updateEventsData(gameEventsOldFormat)
  }

  function __removeGameMode(game_mode_id)
  {
    if (game_mode_id in __gameModes)
      delete __gameModes[game_mode_id]
  }

  function __onGameModesUpdated(modes_list)
  {
    foreach (modeInfo in modes_list)
    {
      dagor.debug(format("matching game mode fetched '%s' [%d]",
                         modeInfo.name, modeInfo.gameModeId))
      __gameModes[modeInfo.gameModeId] <- modeInfo
    }
    __notifyGmChanged();
  }

  function __loadGameModesFromList(gm_list)
  {
    ::fetch_game_modes_info({byId = gm_list},
      function (result)
      {
        if (!::checkMatchingError(result))
          return
        ::g_matching_game_modes.__onGameModesUpdated(result.modes)
      })
  }

  function onEventSignOut(p)
  {
    __gameModes.clear()
    __fetching = false
    __fetch_counter = 0
  }

  function onEventScriptsReloaded(p)
  {
    forceUpdateGameModes()
  }

  //no need to request gameModes before configs inited
  function onEventLoginComplete(p)
  {
    forceUpdateGameModes()
  }

  function getGameModeData(gameModeId)
  {
    return ::getTblValue(gameModeId, __gameModes)
  }

  function getGameModesByEconomicName(economicName)
  {
    return ::u.filter(__gameModes,
      (@(economicName) function(g) { return ::events.getEventEconomicName(g) == economicName })(economicName))
  }

  function requestGameModeById(gameModeId, cb = null)
  {
    local cachedGameMode = getGameModeData(gameModeId)
    if (cachedGameMode)
    {
      if (cb)
        cb(cachedGameMode)
      return
    }

    ::fetch_game_modes_info({byId = [gameModeId]},
      (@(gameModeId, cb, __gameModes) function (result) {
        if (::checkMatchingError(result, false))
          ::g_matching_game_modes.__onGameModesUpdated(result.modes)
        if (cb)
          cb(::getTblValue(gameModeId, __gameModes, null))
      })(gameModeId, cb, __gameModes))
  }

  function getGameModeIdsByEconomicName(economicName)
  {
    local res = []
    foreach(id, gm in __gameModes)
      if (::events.getEventEconomicName(gm) == economicName)
        res.append(id)
    return res
  }
}

::subscribe_handler(::g_matching_game_modes)

