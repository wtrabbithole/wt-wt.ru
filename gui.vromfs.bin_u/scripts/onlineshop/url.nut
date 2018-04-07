const URL_TAGS_DELIMITER = " "
const URL_TAG_AUTO_LOCALIZE = "auto_local"
const URL_TAG_AUTO_LOGIN = "auto_login"

::g_url <- {}

function g_url::open(baseUrl, forceExternal=false, isAlreadyAuthenticated = false)
{
  if (!::has_feature("AllowExternalLink"))
    return

  if (baseUrl == null || baseUrl == "")
  {
    dagor.debug("Error: tried to open an empty url")
    return
  }

  local url = ::clearBorderSymbols(baseUrl, [URL_TAGS_DELIMITER])
  local urlTags = ::split(baseUrl, URL_TAGS_DELIMITER)
  if (!urlTags.len())
  {
    dagor.debug("Error: tried to open an empty url")
    return
  }
  url = urlTags.remove(urlTags.len() - 1)

  local urlType = ::g_url_type.getByUrl(url)
  if (::isInArray(URL_TAG_AUTO_LOCALIZE, urlTags))
    url = urlType.applyCurLang(url)

  ::dagor.debug("Open url with urlType = " + urlType.typeName + ": " + url)
  ::dagor.debug("Base Url = " + baseUrl)
  if (!isAlreadyAuthenticated
      && urlType.needAutoLogin && ::isInArray(URL_TAG_AUTO_LOGIN, urlTags)
      && canAutoLogin())
  {
    local authUrl = ::get_authenticated_url(url)
    if (!authUrl || authUrl == "")
      ::script_net_assert_once("Faile auth url", "Open url: failed to get authenticated url.")
    else
      url = authUrl
  }

  local hasFeature = urlType.isOnlineShop
                     ? ::has_feature("EmbeddedBrowserOnlineShop")
                     : ::has_feature("EmbeddedBrowser")
  if (!forceExternal && ::use_embedded_browser() && !::steam_is_running() && hasFeature)
  {
    // Embedded browser
    ::open_browser_modal(url)
    ::broadcastEvent("BrowserOpened", { url = url, external = false })
    return
  }

  //shell_launch can be long sync function so call it delayed to avoid broke current call.
  ::get_gui_scene().performDelayed(this, (@(url) function() {
    // External browser
    local response = ::shell_launch(url)
    if (response > 0)
    {
      local errorText = ::get_yu2_error_text(response)
      ::showInfoMsgBox(errorText, "errorMessageBox")
      dagor.debug("shell_launch() have returned " + response + " for URL:" + url)
    }
    ::broadcastEvent("BrowserOpened", { url = url, external = true })
  })(url))
}

function g_url::openByObj(obj, forceExternal=false, isAlreadyAuthenticated = false)
{
  if (!::check_obj(obj) || obj.link == null || obj.link == "")
    return

  local link = (obj.link.slice(0, 1) == "#") ? ::loc(obj.link.slice(1)) : obj.link
  open(link, forceExternal, isAlreadyAuthenticated)
}

function g_url::canAutoLogin()
{
  return !::is_ps4_or_xbox && !::is_vendor_tencent() && ::g_login.isAuthorized()
}

function g_url::validateLink(link)
{
  if (link == null)
    return null

  if (!::u.isString(link))
  {
    ::dagor.debug("CHECK LINK result: " + ::toString(link))
    ::dagor.assertf(false, "CHECK LINK: Link recieved not as text")
    return null
  }

  link = ::clearBorderSymbols(link, [URL_TAGS_DELIMITER])
  local linkStartIdx = ::g_string.lastIndexOf(link, URL_TAGS_DELIMITER)
  if (linkStartIdx < 0)
    linkStartIdx = 0

  if (link.find("://", linkStartIdx) != null)
    return link

  if (link.find("www.", linkStartIdx) != null)
    return link

  local localizedLink = ::loc(link, "")
  if (localizedLink != "")
    return localizedLink

  ::dagor.debug("CHECK LINK: Not found any localization string for link: " + link)
  return null
}

function open_url(baseUrl, forceExternal=false, isAlreadyAuthenticated = false, biqQueryKey = "")
{
  if (!::has_feature("AllowExternalLink"))
    return

  local bigQueryInfoObject = {url = baseUrl}
  if( ! ::u.isEmpty(biqQueryKey))
    bigQueryInfoObject["from"] <- biqQueryKey

  ::add_big_query_record(forceExternal ? "player_opens_external_browser" : "player_opens_browser"
    ::save_to_json(bigQueryInfoObject))

  ::g_url.open(baseUrl, forceExternal, isAlreadyAuthenticated)
}
