::g_qi_view_utils <- {}

function g_qi_view_utils::createViewByCountries(nestObj, queue, event)
{
  local headerColumns = [{ text = "#sm_era"}]
  local view = {
    rows = [
      {
        rowParam = "queueTableIconRow"
        columns = headerColumns
      }
      {
        rowParam = "queueTableTitleRow"
        columns = [{ text = "#multiplayer/playersInQueue" }]
      }
    ]
  }

  //fillheader
  foreach(i, countryName in ::shopCountriesList)
    headerColumns.append({
      image = ::get_country_icon(countryName, false, !::events.isCountryAvailable(event, countryName))
    })

  //fillrank rows
  local myCountry = ::queues.getQueueCountry(queue)
  local myRank = ::queues.getMyRankInQueue(queue)
  local countriesSets = ::events.getAllCountriesSets(event)
  local canMeetCountries = {}
  foreach(cSet in countriesSets)
    if (myCountry in cSet.allCountries)
      canMeetCountries = ::u.tablesCombine(canMeetCountries, cSet.allCountries, function(a, b) { return true })

  for(local rank = 1; rank <= ::max_country_rank; ++rank)
  {
    local row = {
      rowParam = "queueTableRow"
      columns = [{ text = ::getUnitRankName(rank) }]
      isEven = rank % 2 == 0
    }

    foreach(i, country in ::shopCountriesList)
      row.columns.append({
        id = country + "_" + rank
        text = ::events.isCountryAvailable(event, country) ? "0" : "-"
        overlayTextColor = (country == myCountry && rank == myRank) ? "mainPlayer"
                         : country in canMeetCountries ? null
                         : "minor"
      })

    view.rows.append(row)
  }

  local markup = ::handyman.renderCached("gui/queue/queueTableByCountries", view)
  nestObj.getScene().replaceContentFromText(nestObj, markup, markup.len(), this)
}

function g_qi_view_utils::updateViewByCountries(nestObj, queue, curCluster)
{
  local queueStats = queue && queue.queueStats
  if (!queueStats)
    return

  local event = ::queues.getQueueEvent(queue)
  local countriesQueueTable = queueStats.getCountriesQueueTable(curCluster)
  local countryOption = ::get_option(::USEROPT_COUNTRY)
  foreach(countryName in countryOption.values)
  {
    if (!::events.isCountryAvailable(event, countryName))
      continue

    local ranksQueueTable = ::getTblValue(countryName, countriesQueueTable)
    for(local rank = 1; rank <= ::max_country_rank; ++rank)
    {
      local tdTextObj = nestObj.findObject(countryName + "_" + rank)
      if (!::checkObj(tdTextObj))
        continue
      local val = ::getTblValue(rank.tostring(), ranksQueueTable, 0)
      tdTextObj.setValue(val.tostring())
    }
  }
}

//update text and icon of queue each second until all queues finish.
function g_qi_view_utils::updateShortQueueInfo(timerObj, textObj, iconObj)
{
  if (!::check_obj(timerObj))
    return
  ::secondsUpdater(timerObj, (@(textObj, iconObj) function(obj, p) {
    local queue = ::queues.findQueue({}) //first active queue
    if (::check_obj(textObj))
    {
      local msg = ""
      if (queue)
      {
        msg = ::loc("yn1/wait_for_session")
        local waitTime = queue ? ::queues.getQueueActiveTime(queue).tointeger() : 0
        if (waitTime > 0)
          msg += ::loc("ui/colon") + ::secondsToString(waitTime, false)
      }
      textObj.setValue(msg)
    }
    if (::check_obj(iconObj))
      iconObj.show(!!queue)
    return !queue
  })(textObj, iconObj))
}