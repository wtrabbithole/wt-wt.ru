::FACEBOOK_POST_WALL_MESSAGE <- false

::ps4_activityFeed_requestsTable <- {
  player = "$USER_NAME_OR_ID",
  count = "$STORY_COUNT",
  onlineUserId = "$ONLINE_ID",
  productName = "$PRODUCT_NAME",
  titleName = "$TITLE_NAME",
  fiveStarValue = "$FIVE_STAR_VALUE",
  sourceCount = "$SOURCE_COUNT"
}

function prepareMessageForWallPostAndSend(config, customFeedParams = {}, reciever = bit_activity.NONE)
{
  local copy_config = clone config
  local copy_customFeedParams = clone customFeedParams
  if (reciever & bit_activity.PS4_ACTIVITY_FEED)
    ::ps4PostActivityFeed(copy_config, copy_customFeedParams)
  if (reciever & bit_activity.FACEBOOK)
    ::facebookPostActivityFeed(copy_config, copy_customFeedParams)
}

function getRandomActivityFeedImageUrl(customConfig)
{
  local guiBlk = ::configs.GUI.get()

  if (guiBlk.blockCount() == 0 || !guiBlk.activity_feed_image_url)
  {
    ::dagor.debug("failed to load block activity_feed_image_url, reason: guiBlk len = " + guiBlk.blockCount() + ", guiBlk.activity_feed_image_url - " + guiBlk.activity_feed_image_url)
    return
  }

  local mainLinkPart = guiBlk.activity_feed_image_url.mainPart
  local fileExtension = guiBlk.activity_feed_image_url.fileExtension
  local bigLogoEnd = guiBlk.activity_feed_image_url.bigLogoEnd || ""

  if (!mainLinkPart || !fileExtension)
  {
    ::dagor.debug("getRandomActivityFeedImageUrl: Not found mainPart - " + mainLinkPart + ", fileExtension - " + fileExtension)
    debugTableData(guiBlk.activity_feed_image_url)
    return
  }

  local country = ::getTblValue("country", customConfig, "")
  local unitName = ::getTblValue("unitNameId", customConfig, "")
  local searchedBlock = null
  local urlEndPart = ""
  local failText = "Not found block 'other'"

  if (country != "" && unitName != "")
  {
    local unit = ::getAircraftByName(unitName)
    local unitType = ::get_es_unit_type(unit)
    local unitTypeText = ::getUnitTypeText(unitType)

    local path = "activity_feed_image_url/" + country + "/" + unitTypeText
    searchedBlock = ::get_blk_value_by_path(guiBlk, path)
    if (!u.isDataBlock(searchedBlock))
    {
      local message = "getRandomActivityFeedImageUrl: Not found block " + path
      ::dagor.debug(message)
      ::script_net_assert_once("bad activity feed", message)
      return
    }

    local rndItemNum = ::math.rnd() % searchedBlock.paramCount()
    urlEndPart = searchedBlock.getParamValue(rndItemNum)
  }
  else
  {
    searchedBlock = guiBlk.activity_feed_image_url.other
    local customParam = ::getTblValue("blkParamName", customConfig, "")
    if (customParam == "")
    {
      ::dagor.debug("getRandomActivityFeedImageUrl: Not fount blkParamName")
      debugTableData(customConfig)
      return
    }

    if (!searchedBlock[customParam])
    {
      ::dagor.debug("getRandomActivityFeedImageUrl: Not fount customParam")
      debugTableData(searchedBlock)
      return
    }

    urlEndPart = searchedBlock[customParam]
    local suffix = ::getTblValue("imgSuffix", customConfig, "")
    if (!u.isEmpty(suffix))
      urlEndPart = urlEndPart + "_" + suffix
  }

  if (!searchedBlock)
  {
    ::dagor.debug(failText)
    debugTableData(guiBlk.activity_feed_image_url)
    return
  }

  local returnConfig = {
                          mainUrl = mainLinkPart + urlEndPart,
                          bigLogoEnd = bigLogoEnd,
                          fileExtension = fileExtension
                       }
  return returnConfig
}

//---------------- <Facebook> --------------------------
function facebookPostActivityFeed(config, customFeedParams)
{
  if (!::has_feature("FacebookWallPost"))
    return

  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      customFeedParams[name] <- ::loc(customFeedParams[name])

  ::FACEBOOK_POST_WALL_MESSAGE = false
  local locId = ::getTblValue("locId", config, "")
  if (locId == "")
  {
    ::dagor.debug("facebookPostActivityFeed, Not found locId in config")
    ::debugTableData(config)
    return
  }

  customFeedParams.player <- ::my_user_name
  local message = ::loc("activityFeed/" + locId, customFeedParams)
  local link = ::getTblValue("link", customFeedParams, "")
  local backgroundPost = ::getTblValue("backgroundPost", config, false)
  ::make_facebook_login_and_do((@(link, message, backgroundPost) function() {
                 if (!backgroundPost)
                  ::scene_msg_box("facebook_login", null, ::loc("facebook/uploading"), null, null)
                 ::facebook_post_link(link, message)
               })(link, message, backgroundPost), this)
}
//------------------ </Facebook> --------------------------------

//----------------- <PlayStation> -------------------------------
function ps4PostActivityFeed(config, customFeedParams)
{
  if (!::is_platform_ps4 || !::has_feature("ActivityFeedPs4"))
    return

  local locId = ::getTblValue("locId", config, "")
  if (locId == "" && u.isEmpty(customFeedParams?.captions))
  {
    ::dagor.debug("ps4PostActivityFeed, Not found locId in config")
    ::debugTableData(config)
    return
  }

  local localizedKeyWords = {}
  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      localizedKeyWords[name] <- ::get_localized_text_with_abbreviation(customFeedParams[name])

  local activityFeed_config = ::combine_tables(::ps4_activityFeed_requestsTable, customFeedParams)

  local getFilledFeedTextByLang = (@(activityFeed_config, localizedKeyWords) function(locId) {
    local captions = {}
    local localizedTable = ::get_localized_text_with_abbreviation(locId)

    foreach(lang, string in localizedTable)
    {
      local localizationTable = {}
      foreach(name, value in activityFeed_config)
        localizationTable[name] <- ::get_tbl_value_by_path_array([name, lang], localizedKeyWords, value)

      captions[lang] <- ::replaceParamsInLocalizedText(string, localizationTable)
    }

    return captions
  })(activityFeed_config, localizedKeyWords)

  local blk = ::DataBlock()
  blk.apiGroup = "activityFeed"
  blk.method = ::HTTP_METHOD_POST
  blk.path = "/v1/users/me/feed"

  local imageUrlsConfig = ::getRandomActivityFeedImageUrl(customFeedParams)
  local url = imageUrlsConfig?.mainUrl || ""
  local big = imageUrlsConfig?.bigLogoEnd || ""
  local ext = imageUrlsConfig?.fileExtension || ""

  local largeImage = customFeedParams?.images?.large || (!u.isEmpty(url) ? url + big + ext : "")
  local smallImage = customFeedParams?.images?.small || (!u.isEmpty(url) ? url + ext : "")

  local body = {
    captions = customFeedParams.captions || getFilledFeedTextByLang("activityFeed/" + locId)
    condensedCaptions = customFeedParams.condensedCaptions || getFilledFeedTextByLang("activityFeed/" + locId + "/condensed")
    storyType = "IN_GAME_POST"
    subType = config?.subType || 0
    targets = [{accountId=::ps4_get_account_id(), type="ONLINE_ID"}]
  }
  if (!u.isEmpty(largeImage))
    body.targets.append({meta=largeImage, type="LARGE_IMAGE_URL"})
  if (!u.isEmpty(smallImage))
    body.targets.append({meta=smallImage, type="SMALL_IMAGE_URL", aspectRatio="2.08:1"})

  blk.request = ::save_to_json(body)

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    dagor.debug("Error: "+ret.error);
    dagor.debug("Error text: "+ret.errorStr);
  }
  else if ("response" in ret)
  {
    dagor.debug("Response: "+ret.response);
  }
}
//----------------------- </PlayStation> --------------------------
