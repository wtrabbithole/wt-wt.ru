const URL_TAGS_DELIMITER = " "
const URL_TAG_AUTO_LOCALIZE = "auto_local"
const URL_TAG_AUTO_LOGIN = "auto_login"
const URL_TAG_SSO_SERVICE = "sso_service="
const URL_TAG_NO_ENCODING = "no_encoding"

const AUTH_ERROR_LOG_COLLECTION = "log"

::g_url <- {}

g_url.open <- function open(baseUrl, forceExternal=false, isAlreadyAuthenticated = false)
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

  local shouldLogin = ::isInArray(URL_TAG_AUTO_LOGIN, urlTags)
  if (!isAlreadyAuthenticated && urlType.needAutoLogin && shouldLogin && canAutoLogin())
  {
    local shouldEncode = !::isInArray(URL_TAG_NO_ENCODING, urlTags)
    if (shouldEncode)
      url = ::encode_base64(url)

    local ssoServiceTag = urlTags.filter(@(v) v.find(URL_TAG_SSO_SERVICE) == 0);
    local ssoService = ssoServiceTag.len() != 0 ? ssoServiceTag.pop().slice(URL_TAG_SSO_SERVICE.len()) : null
    local authData = (ssoService != null) ? ::get_authenticated_url_sso(url, ssoService) : ::get_authenticated_url_table(url)

    if (authData.yuplayResult == ::YU2_OK)
      url = authData.url + (shouldEncode ? "&ret_enc=1" : "") //This parameter is needed for coded complex links.
    else if (authData.yuplayResult == ::YU2_WRONG_LOGIN)
    {
      ::send_error_log("Authorize url: failed to get authenticated url with error ::YU2_WRONG_LOGIN",
        false, AUTH_ERROR_LOG_COLLECTION)
      ::gui_start_logout()
      return
    }
    else
      ::send_error_log("Authorize url: failed to get authenticated url with error " + authData.yuplayResult,
        false, AUTH_ERROR_LOG_COLLECTION)
  }

  local hasFeature = urlType.isOnlineShop
                     ? ::has_feature("EmbeddedBrowserOnlineShop")
                     : ::has_feature("EmbeddedBrowser")
  if (!forceExternal && ::use_embedded_browser() && !::steam_is_running() && hasFeature)
  {
    // Embedded browser
    ::open_browser_modal(url, urlTags)
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

g_url.openByObj <- function openByObj(obj, forceExternal=false, isAlreadyAuthenticated = false)
{
  if (!::check_obj(obj) || obj?.link == null || obj.link == "")
    return

  local link = (obj.link.slice(0, 1) == "#") ? ::loc(obj.link.slice(1)) : obj.link
  open(link, forceExternal, isAlreadyAuthenticated)
}

g_url.canAutoLogin <- function canAutoLogin()
{
  return !::is_ps4_or_xbox && !::is_vendor_tencent() && ::g_login.isAuthorized()
}

g_url.validateLink <- function validateLink(link)
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

::open_url <- function open_url(baseUrl, forceExternal=false, isAlreadyAuthenticated = false, biqQueryKey = "")
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
