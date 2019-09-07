const MAX_URL_MISSIONS = 100
const MAX_URL_MISSION_NAME_LENGHT = 24

::g_url_missions <- {
  list = []
  isLoaded = false

  listSavePath = "url_missions_list"
}

function g_url_missions::loadBlk(curMission, callback = null)
{
  ::gui_start_modal_wnd(::gui_handlers.LoadingUrlMissionModal, {curMission = curMission, callback = callback})
}

function g_url_missions::loadOnce()
{
  if (isLoaded)
    return

  local listBlk = ::loadLocalByAccount(listSavePath)
  if (::u.isDataBlock(listBlk))
    foreach(misUrlBlk in listBlk % "mission")
      if (::u.isDataBlock(misUrlBlk))
      {
        list.append(::UrlMission(misUrlBlk))
        if (list.len() >= MAX_URL_MISSIONS)
          break
      }

  isLoaded = true

  fixUrlMissionNames()
}

function g_url_missions::fixUrlMissionNames()
{
  local hasFixedMissionNames = false
  foreach(mission in list)
    if (hasMissionWithSameName(mission, mission.name))
      for (local i = 1; i < MAX_URL_MISSIONS; i++)
      {
        local newName = mission.name
        local namePostFix = "[" + i.tostring() + "]"
        local newNameLen = utf8(newName + namePostFix).charCount()
        local unlimitCharCount = newNameLen - MAX_URL_MISSION_NAME_LENGHT
        if (unlimitCharCount > 0)
          newName = utf8(newName).slice(0, MAX_URL_MISSION_NAME_LENGHT - unlimitCharCount)
        newName += namePostFix
        if (!hasMissionWithSameName(mission, newName))
        {
          mission.name = newName
          hasFixedMissionNames = true
          break
        }
      }

  if (hasFixedMissionNames)
    save()
}

function g_url_missions::save()
{
  if (!isLoaded)
    return

  local saveBlk = ::DataBlock()
  foreach(mission in list)
    saveBlk.mission <- mission.getSaveBlk()
  ::saveLocalByAccount(listSavePath, saveBlk)
}

function g_url_missions::getList()
{
  loadOnce()
  return list
}

function g_url_missions::openCreateUrlMissionWnd()
{
  if (checkCanCreateMission())
    ::handlersManager.loadHandler(::gui_handlers.modifyUrlMissionWnd)
}

function g_url_missions::openModifyUrlMissionWnd(urlMission)
{
  ::handlersManager.loadHandler(::gui_handlers.modifyUrlMissionWnd, { urlMission = urlMission })
}

function g_url_missions::openDeleteUrlMissionConfirmationWnd(urlMission)
{
  local text = ::loc("urlMissions/msgBox/deleteConfirmation" {name = urlMission.name})
  local defButton = "no"
  local buttons = [
      ["yes", (@(urlMission) function() { ::g_url_missions.deleteMission(urlMission) })(urlMission)],
      ["no", function() {}]
    ]
  ::scene_msg_box("delete_url_mission_confirmation", null, text, buttons, defButton)
}

function g_url_missions::hasMissionWithSameName(checkingMission, name)
{
  foreach(mission in getList())
    if (mission != checkingMission && mission.name == name)
      return true

  if (::get_meta_mission_info_by_name(name) != null)
    return true

  return false
}

function g_url_missions::checkDuplicates(name, url, urlMission = null)
{
  local errorMsg = ""
  foreach(mission in getList())
  {
    if (mission == urlMission)
      continue

    if (mission.name == name)
    {
      errorMsg = ::loc("urlMissions/nameExist", mission)
      break
    }
    if (mission.url == url)
    {
      errorMsg = ::loc("urlMissions/urlExist", mission)
      break
    }
  }

  if (errorMsg == "")
    if (::get_meta_mission_info_by_name(name) != null)
      errorMsg = ::loc("urlMissions/nameExist", mission)

  if (errorMsg == "")
    return true

  ::showInfoMsgBox(errorMsg)
  return false
}

function g_url_missions::modifyMission(urlMission, name, url)
{
  if (urlMission.name == name && urlMission.url == url)
    return true

  if (!checkDuplicates(name, url, urlMission))
    return false

  urlMission.name = name
  if (urlMission.url != url)
  {
    urlMission.fullMissionBlk = null
    urlMission.hasErrorByLoading = false
  }
  urlMission.url = url
  save()
  ::broadcastEvent("UrlMissionChanged", { mission = urlMission })
  return true
}

function g_url_missions::deleteMission(urlMission)
{
  local idx = list.find(urlMission)
  if (idx < 0)
    return

  list.remove(idx)
  save()
  ::broadcastEvent("UrlMissionChanged", { mission = urlMission })
}

function g_url_missions::checkCanCreateMission()
{
  loadOnce()
  if (list.len() < MAX_URL_MISSIONS)
    return true
  ::showInfoMsgBox(::loc("urlMissions/tooMuchMissions", { max = MAX_URL_MISSIONS }))
  return false
}

function g_url_missions::createMission(name, url)
{
  if (!checkCanCreateMission())
    return false
  if (!checkDuplicates(name, url))
    return false

  local urlMission = ::UrlMission(name, url)
  list.append(urlMission)
  save()
  ::broadcastEvent("UrlMissionAdded", { mission = urlMission })
  return true
}

function g_url_missions::toggleFavorite(urlMission)
{
  if (!urlMission)
    return
  urlMission.isFavorite = !urlMission.isFavorite
  save()
}

function g_url_missions::setLoadingCompeteState(urlMission, hasErrorByLoading, blk)
{
  if (!urlMission)
    return

  urlMission.fullMissionBlk = hasErrorByLoading ? null : blk
  if (urlMission.hasErrorByLoading != hasErrorByLoading)
  {
    urlMission.hasErrorByLoading = hasErrorByLoading
    save()
  }
  ::broadcastEvent("UrlMissionLoaded", { mission = urlMission })
}

function g_url_missions::findMissionByUrl(url)
{
  loadOnce()
  return ::u.search(list, (@(url) function(m) { return m.url == url })(url))
}

function g_url_missions::findMissionByName(name)
{
  loadOnce()
  return ::u.search(list, (@(name) function(m) { return m.name == name })(name))
}