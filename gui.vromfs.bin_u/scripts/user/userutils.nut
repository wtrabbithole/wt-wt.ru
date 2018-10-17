local crossplayModule = require("scripts/social/crossplay.nut")

::g_user_utils <- {}

function g_user_utils::getMyStateData()
{
  local profileInfo = ::get_profile_info()
  local myData = {
    name = profileInfo.name,
    clanTag = profileInfo.clanTag,
    pilotIcon = profileInfo.icon,
    rank = 0,
    country = profileInfo.country,
    crewAirs = null,
    selAirs = ::getSelAirsTable(),
    selSlots = getSelSlotsTable(),
    brokenAirs = null,
    cyberCafeId = ::get_cyber_cafe_id()
    unallowedEventsENames = ::events.getUnallowedEventEconomicNames(),
    crossplay = crossplayModule.isCrossPlayEnabled()
  }

  local airs = getMyCrewAirsState(profileInfo)
  myData.crewAirs = airs.crewAirs
  myData.brokenAirs = airs.brokenAirs
  if (airs.rank > myData.rank)
    myData.rank = airs.rank

  local checkPacks = ["pkg_main"]
  local missed = []
  foreach(pack in checkPacks)
    if (!::have_package(pack))
      missed.append(pack)
  if (missed.len())
    myData.missedPkg <- missed

  return myData
}

function g_user_utils::getMyCrewAirsState(profileInfo = null)
{
  if (profileInfo == null)
    profileInfo = ::get_profile_info()

  local res = {
                crewAirs = {}
                brokenAirs = []
                rank = 0
              }
  foreach(c in ::g_crews_list.get())
  {
    if (!("crews" in c))
      continue

    res.crewAirs[c.country] <- []
    foreach(crew in c.crews)
      if (("aircraft" in crew) && crew.aircraft!="")
      {
        local air = getAircraftByName(crew.aircraft)
        if (air)
        {
          res.crewAirs[c.country].append(crew.aircraft)
          if (c.country == profileInfo.country && res.rank < air.rank)
            res.rank = air.rank
          if (::wp_get_repair_cost(crew.aircraft))
            res.brokenAirs.append(crew.aircraft)
        }
      }
  }

  return res
}

function g_user_utils::checkAutoShowSteamEmailRegistration()
{
  if (!::steam_is_running() || !::check_account_tag("steamlogin"))
    return

  if (::g_language.getLanguageName() != "Japanese")
  {
    if (::loadLocalByAccount("SteamEmailRegistrationShowed", false))
      return

    ::saveLocalByAccount("SteamEmailRegistrationShowed", true)
  }

  local config = {
    name = ::loc("mainmenu/SteamEmailRegistration")
    desc = ::loc("mainmenu/SteamEmailRegistration/desc")
    popupImage = "ui/images/invite_big.jpg?P1"
    onOkFunc = function() { ::g_user_utils.launchSteamEmailRegistration() }
    okBtnText = "msgbox/btn_bind"
  }
  showUnlockWnd(config)
}

function g_user_utils::launchSteamEmailRegistration()
{
  local token = ::get_steam_link_token()
  if (token == "")
    return ::dagor.debug("Steam Email Registration: empty token")

  ::open_url(::loc("url/steam_bind_url",
      { token = token,
        langAbbreviation = ::g_language.getShortName()
      }), false, false, "profile_page")
}

function g_user_utils::checkAutoShowPS4EmailRegistration()
{
  if (!::is_platform_ps4 || !::check_account_tag("psnlogin"))
    return

  if (::loadLocalByAccount("PS4EmailRegistrationShowed", false))
    return

  ::saveLocalByAccount("PS4EmailRegistrationShowed", true)

  local config = {
    name = ::loc("mainmenu/PS4EmailRegistration")
    desc = ::loc("mainmenu/PS4EmailRegistration/desc")
    popupImage = "ui/images/invite_big.jpg?P1"
    onOkFunc = function() { ::g_user_utils.launchPS4EmailRegistration() }
    okBtnText = "msgbox/btn_bind"
  }
  showUnlockWnd(config)
}

function g_user_utils::launchPS4EmailRegistration()
{
  ::ps4_open_url_logged_in(::loc("url/ps4_bind_url"), ::loc("url/ps4_bind_redirect"))
}
