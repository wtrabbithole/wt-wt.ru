::uploadLimit <- 3
::on_screenshot_saved <- null
::after_facebook_login <- null
::no_dump_facebook_friends <- {}
::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS <- 200
::PS4_UPDATE_TIMER_LIMIT <- 300000
::last_update_ps4_friends <- -::PS4_UPDATE_TIMER_LIMIT
::FACEBOOK_POST_WALL_MESSAGE <- false

::g_script_reloader.registerPersistentData("SocialGlobals", ::getroottable(), ["no_dump_facebook_friends"])

::ps4_activityFeed_requestsTable <- {
  player = "$USER_NAME_OR_ID",
  count = "$STORY_COUNT",
  onlineUserId = "$ONLINE_ID",
  productName = "$PRODUCT_NAME",
  titleName = "$TITLE_NAME",
  fiveStarValue = "$FIVE_STAR_VALUE",
  sourceCount = "$SOURCE_COUNT"
}

function make_screenshot_and_do(func, handler)
{
  on_screenshot_saved = (@(func, handler) function(saved_screenshot_filename) {
      if(handler)
      {
        ::fill_gamer_card(::get_profile_info(), true, "gc_", ::getLastGamercardScene())
        func.call(handler, saved_screenshot_filename)
      }
      on_screenshot_saved = null
    })(func, handler)
  ::fill_gamer_card({gold = ""}, true, "gc_", ::getLastGamercardScene())
  ::make_screenshot()
}

function make_facebook_login_and_do(func, handler)
{
  after_facebook_login = (@(func, handler) function() {
        if(handler && func)
          func.call(handler)
        after_facebook_login = null
      })(func, handler)
  if(!::facebook_is_logged_in())
    ::start_facebook_login()
  else
    after_facebook_login()
}

function on_facebook_link_finished(result)
{
  ::on_facebook_destroy_waitbox()
  if (result == "")
    ::showInfoMsgBox(::loc("facebook/postFail"), "facebook_post_fail")

  return
}

function start_facebook_upload_screenshot(path)
{
  if (path == "")
    return
  dagor.debug("UPLOAD: " + path)
  local cdb = ::get_local_custom_settings_blk();

  if (cdb.facebook == null)
    cdb.facebook = ::DataBlock()
  if (cdb.facebook.uploads == null)
    cdb.facebook.uploads = ::DataBlock()

  local ltm = ::get_local_time();
  local curDate = ltm.year +"/"+ ltm.month +"/"+ ltm.day;
  local postDate = (cdb.facebook.uploads.postDate != null)? cdb.facebook.uploads.postDate : "";
  local uploads = cdb.facebook.uploads % "path";

  if (curDate == postDate)
  {
    if (uploads.len() >= uploadLimit)
    {
      local msgText = format(::loc("facebook/error_upload_limit"), uploadLimit);
      ::showInfoMsgBox(msgText, "facebook_upload_limit")
      return;
    }
    else
      foreach (p in uploads)
        if (path == p)
        {
          ::showInfoMsgBox(::loc("facebook/error_upload_once"), "facebook_upload")
          return;
        }
  }
  else
    cdb.facebook.removeBlock("uploads");

  ::scene_msg_box("facebook_login", null, ::loc("facebook/uploading"),
    [["cancel", function() {}]], "cancel", {cancel_fn = function() {}, waitAnim=true, delayedButtons = 10})
  ::facebook_upload_screenshot(path)
}

function on_facebook_upload_finished(path)
{
  on_facebook_destroy_waitbox()
  if (path == "")
    return

  local cdb = ::get_local_custom_settings_blk();
  if (cdb.facebook == null)
    cdb.facebook = ::DataBlock()
  if (cdb.facebook.uploads == null)
    cdb.facebook.uploads = ::DataBlock()
  cdb.facebook.uploads.path <- path

  if (cdb.facebook.uploads.postDate == null)
  {
    local ltm = ::get_local_time();
    local date = ltm.year +"/"+ ltm.month +"/"+ ltm.day;
    cdb.facebook.uploads.postDate = date;
  }

  save_profile(false);

  if (::current_base_gui_handler)
    ::current_base_gui_handler.msgBox("facebook_finish_upload_screenshot", ::loc("facebook/successUpload"), [["ok"]], "ok")
}

function on_facebook_destroy_waitbox()
{
  local guiScene = ::get_gui_scene()
  if (!guiScene)
    return
  local facebook_obj = guiScene["facebook_login"]
  if (::checkObj(facebook_obj))
    guiScene.destroyElement(facebook_obj)

  ::broadcastEvent("CheckFacebookLoginStatus")
}

function on_facebook_friends_loaded(blk)
{
  foreach(id, block in blk)
    ::no_dump_facebook_friends[id] <- block.name

  //TEST ONLY!
  //foreach (id, data in blk)
  //  dagor.debug("FACEBOOK FRIEND: id="+id+" name="+data.name)

  if(::no_dump_facebook_friends.len()==0)
  {
    ::on_facebook_destroy_waitbox()
    ::showInfoMsgBox(::loc("msgbox/no_friends_added"), "facebook_failed")
  }

  local inBlk = ::DataBlock()
  foreach(id, block in ::no_dump_facebook_friends)
    inBlk.id <- id.tostring()

  if(inBlk=="")
    return

  local taskId = ::facebook_find_friends(inBlk, ::EPL_MAX_PLAYERS_IN_LIST)
  if(taskId < 0)
  {
    ::on_facebook_destroy_waitbox()
    ::showInfoMsgBox(::loc("msgbox/no_friends_added"), "facebook_failed")
  }
  else
    ::add_bg_task_cb(taskId, function(){
        local resultBlk = ::facebook_find_friends_result()
        ::addSocialFriends(resultBlk, ::EPL_FACEBOOK)
        ::addContactGroup(::EPL_FACEBOOK)
      })
}

function on_facebook_login_finished()
{
  if(::facebook_is_logged_in() && after_facebook_login)
      after_facebook_login()
  on_facebook_destroy_waitbox()

  if (::is_builtin_browser_active)
    ::close_browser_modal()
}

function start_facebook_login()
{
  if (::is_platform_ps4)
  {
    local result = ::ps4_facebook_login()
    if (result == 0) // successful login
      ::on_facebook_login_finished()
    return
  }

  ::scene_msg_box("facebook_login", null, ::loc("facebook/connecting"),
                  [["cancel", function() {::facebook_cancel_login()}]],
                  "cancel",
                  {waitAnim=true, delayedButtons = 10}
                 )
  ::facebook_login()
}

function show_facebook_login_reminder()
{
  if (::is_unlocked(::UNLOCKABLE_ACHIEVEMENT, "facebook_like"))
    return;

  local gmBlk = ::get_game_settings_blk()
  local daysCounter = gmBlk && gmBlk.reminderFacebookLikeDays || 0
  local lastDays = ::loadLocalByAccount("facebook/lastDayFacebookLikeReminder", 0)
  local days = ::get_days_by_time( ::get_utc_time() )
  if ( !lastDays || daysCounter > 0 && days - lastDays > daysCounter )
  {
    ::gui_start_modal_wnd(::gui_handlers.facebookReminderModal);
    ::saveLocalByAccount( "facebook/lastDayFacebookLikeReminder", days )
  }
}

function show_facebook_screenshot_button(scene, show = true, id = "btn_upload_facebook_scrn")
{
  show = show && !::is_platform_ps4 && ::has_feature("FacebookScreenshots")
  local fbObj = ::showBtn(id, show, scene)
  if (!::checkObj(fbObj))
    return

  fbObj.tooltip = ::format(::loc("mainmenu/facebookShareLimit"), ::uploadLimit)
}

class ::gui_handlers.facebookReminderModal extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    scene.findObject("award_name").setValue(::loc("options/facebookTitle"));
    scene.findObject("award_desc").setValue(format(::loc("facebook/reminderText"), ::get_unlock_reward("facebook_like")));
    scene.findObject("award_image")["background-image"] = "#ui/images/facebook_like.jpg?P1";
    scene.findObject("award_image")["height"] = "0.5w"
    scene.findObject("btn_ok").setValue(::loc("options/facebookLogin"));
    showSceneBtn("btn_upload_facebook_scrn", false)
  }

  function onOk()
  {
    ::gui_start_gameplay(::top_menu_handler, "social");
    ::start_facebook_login()
  }

  wndType = handlerType.MODAL
  sceneBlkName = "gui/showUnlock.blk";
}

class ::gui_handlers.facebookMsgModal extends ::gui_handlers.GroupOptionsModal
{
  function initScreen() { }

  function onApply()
  {
    local text = scene.findObject("facebook_msg").getValue()
    if (::is_chat_message_empty(text))
    {
      msgBox("need_text", ::loc("facebook/needText"),
        [["ok", function() {} ]], "ok")
      return;
    }

    ::facebook_like(::loc("facebook/like_url"), text);
    shared = true;
    goBack();
  }

  function goBack()
  {
    base.goBack()
  }

  function afterModalDestroy()
  {
    if (shared && owner && ("onFacebookLikeShared" in owner) && owner.onFacebookLikeShared)
      owner.onFacebookLikeShared.call(owner);
  }

  wndType = handlerType.MODAL
  sceneBlkName = "gui/facebookMsgWindow.blk";
  owner = null;
  shared = false;
}

function addSteamFriends()
{
  local taskId = ::steam_find_friends(::EPL_MAX_PLAYERS_IN_LIST)
  if (taskId < 0)
    return

  local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
  ::add_bg_task_cb(taskId, (@(progressBox) function () {
    ::destroyMsgBox(progressBox)
    local blk = ::DataBlock();
    blk = ::steam_find_friends_result();
    ::addSocialFriends(blk, ::EPL_STEAM)
  })(progressBox))
}

function addSocialFriends(blk, group)
{
  local addedFriendsNumber = 0
  local resultMessage = ""
  local players = {}

  foreach(userId, info in blk)
    players[userId] <- info.nick

  if (players.len())
  {
    if(!isInArray(group, ::contacts_groups))
      ::addContactGroup(group)
    addedFriendsNumber = ::addPlayersToContacts(players, group)
  }
  if (addedFriendsNumber == 0)
    resultMessage = ::loc("msgbox/no_friends_added");
  else if (addedFriendsNumber == 1)
    resultMessage = ::loc("msgbox/added_friends_one");
  else
    resultMessage = format(::loc("msgbox/added_friends_number"), addedFriendsNumber)

  ::on_facebook_destroy_waitbox()
  ::showInfoMsgBox(resultMessage, "friends_added")
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

function ps4PostActivityFeed(config, customFeedParams)
{
  if (!::is_platform_ps4 || !::has_feature("ActivityFeedPs4"))
    return

  local locId = ::getTblValue("locId", config, "")
  if (locId == "")
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
    local sample = "\"%s\":\"%s\""
    local captions = ""
    local localizedTable = ::get_localized_text_with_abbreviation(locId)
    local i = 0

    foreach(lang, string in localizedTable)
    {
      local localizationTable = {}
      foreach(name, value in activityFeed_config)
        localizationTable[name] <- ::get_tbl_value_by_path_array([name, lang], localizedKeyWords, value)

      captions += ::format(sample, lang, ::replaceParamsInLocalizedText(string, localizationTable))
      captions += (i == (localizedTable.len() - 1) ? "" : ",")
      i++
    }

    return captions
  })(activityFeed_config, localizedKeyWords)

  local blk = ::DataBlock()

  blk.apiGroup = "activityFeed"
  blk.method = ::HTTP_METHOD_POST
  blk.path = ::format("/v1/users/%s/feed", ::ps4_get_online_id())

  local titleId = (::ps4_get_region() == ::SCE_REGION_SCEA) ? "CUSA00224_00" : "CUSA00182_00"

  local captions = getFilledFeedTextByLang("activityFeed/" + locId)
  local condensedCaptions = getFilledFeedTextByLang("activityFeed/" + locId + "/condensed")

  local subType = ::getTblValue("subType", config, 0)
  local imageUrlsConfig = ::getRandomActivityFeedImageUrl(customFeedParams)
  local smallImage = ::getTblValue("mainUrl", imageUrlsConfig, "")
  local largeImage = smallImage + ::getTblValue("bigLogoEnd", imageUrlsConfig, "")
  local fileExtension = ::getTblValue("fileExtension", imageUrlsConfig, "")

  local txt = "{"
  txt += "\"captions\":{" + captions + "},"
  txt += "\"condensedCaptions\":{" + condensedCaptions + "},"
  txt += "\"source\": {\"meta\":\"" + ::ps4_get_online_id() + "\",\"type\":\"ONLINE_ID\"},"
  txt += "\"storyType\":\"IN_GAME_POST\","
  txt += "\"subType\": " + subType + ","
  txt += "\"targets\": ["
  txt += "{\"meta\":\"" + titleId + "\",\"type\":\"TITLE_ID\"}"

  if (smallImage != "")
    txt += ",{\"meta\":\"" + smallImage + fileExtension + "\",\"type\":\"SMALL_IMAGE_URL\",\"aspectRatio\":\"2.08:1\"}"
  if (largeImage != "")
    txt += ",{\"meta\":\"" + largeImage + fileExtension + "\",\"type\":\"LARGE_IMAGE_URL\"}"

  txt += "]"
  txt += "}"

  blk.request = txt
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

function addPsnFriends()
{
  if (::ps4_show_friend_list_ex(true, true, false) == 1)
  {
    local taskId = ::ps4_find_friend()
    if (taskId < 0)
      return

    local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
    ::add_bg_task_cb(taskId, (@(progressBox) function () {
      ::destroyMsgBox(progressBox)
      local blk = ::DataBlock()
      blk = ::ps4_find_friends_result()
      if (blk.paramCount() || blk.blockCount())
        ::addSocialFriends(blk, ::EPLX_PS4_FRIENDS)
      else
      {
        local blockName = "PS4_Specific/invitationsRecievers"
        local selectedPlayer = ::ps4_selected_friend()
        if (typeof(selectedPlayer) != "string" || selectedPlayer == "")
          return

        local msgText = ::loc("msgbox/no_psn_friends_added")
        local buttonsArray = [["ok", function() {}]]
        local defaultButton = "ok"
        local inviteConfig = {}

        local path = blockName + "/" + selectedPlayer
        local isSecondTry = ::load_local_custom_settings(path, false)
        if (!isSecondTry)
        {
          inviteConfig = {
                           target = selectedPlayer,
                           inviteType = "gameStart",
                           expireMinutes = 1440
                         }
          msgText += "\n" + ::loc("msgbox/send_game_invitation", {friendName = selectedPlayer})
          buttonsArray = [
                           ["yes", (@(path, inviteConfig) function() {
                                if (::sendInvitationPsn(inviteConfig) == 0)
                                  ::save_local_custom_settings(path, true)
                              })(path, inviteConfig)],
                           ["no", function() {}]
                         ]
          defaultButton = "yes"
        }

        ::scene_msg_box("friends_added", null, msgText, buttonsArray, defaultButton)
      }
    })(progressBox))
  }
}

function addSteamFriendsOnStart()
{
  local cdb = ::get_local_custom_settings_blk();
  if (cdb.steamFriendsAdded != null && cdb.steamFriendsAdded)
    return;

  local friendListFreeSpace = ::EPL_MAX_PLAYERS_IN_LIST - ::contacts[::EPL_FRIENDLIST].len();
  if (friendListFreeSpace <= 0)
    return;

  if (::skip_steam_confirmations)
    addSteamFriends()
  else
    ::scene_msg_box("add_steam_friend", null, ::loc("msgbox/add_steam_friends"),
      [
        ["yes", function() { addSteamFriends() }],
        ["no",  function() {}],
      ], "no")

  cdb.steamFriendsAdded = true;
  save_profile(false);
}

function update_ps4_friends()
{
  if (::is_platform_ps4 && ::dagor.getCurTime() - ::last_update_ps4_friends > ::PS4_UPDATE_TIMER_LIMIT)
  {
    ::last_update_ps4_friends = ::dagor.getCurTime()
    ::getPS4FriendsFromIndex(0)
  }
}

function getPS4FriendsFromIndex(index)
{
  local blk = ::DataBlock()
  blk.apiGroup = "userProfile"
  blk.method = ::HTTP_METHOD_GET
  local query = ::format("/v1/users/%s/friendList?friendStatus=friend&offset=%d&limit=%d",
    ::ps4_get_online_id(), index, ::LIMIT_FOR_ONE_TASK_GET_PS4_FRIENDS)
  blk.path = query
  blk.respSize = 8*1024

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    dagor.debug("Error: "+ret.error);
    dagor.debug("Error text: "+ret.errorStr);
  }
  else if ("response" in ret)
  {
    dagor.debug("json Response: "+ret.response);
    local parsedRetTable = ::parse_json(ret.response)

    local startIndex = ::getTblValue("start", parsedRetTable, 0)
    local size = ::getTblValue("size", parsedRetTable, 0)
    local endIndex = size >= ::getTblValue("totalResults", parsedRetTable, 0)? 0 : size

    ::addContactGroup(::EPLX_PS4_FRIENDS)
    ::processPS4FriendsFromArray(::getTblValue("friendList", parsedRetTable, []), endIndex)
  }
}

function processPS4FriendsFromArray(ps4FriendsArray, lastIndex)
{
  if (ps4FriendsArray.len() == 0)
    return

  for(local i = ::contacts[::EPL_FRIENDLIST].len()-1; i >= 0; i--)
  {
    foreach(num, ps4playerBlock in ps4FriendsArray)
    {
      local playerName = "*" + ps4playerBlock.onlineId
      ::ps4_console_friends[playerName] <- ps4playerBlock

      local friendBlock = ::contacts[::EPL_FRIENDLIST][i]
      if ((playerName) == friendBlock.name)
      {
        ::contacts[::EPLX_PS4_FRIENDS].append(friendBlock)
        ::contacts[::EPL_FRIENDLIST].remove(i)
        dagor.debug(::format("Change contacts group from '%s' to '%s', for '%s', uid %s",
          ::EPL_FRIENDLIST, ::EPLX_PS4_FRIENDS, friendBlock.name, friendBlock.uid))
        break
      }
    }
  }

  ::contacts[::EPLX_PS4_FRIENDS].sort(::sortContacts)

  if (lastIndex != 0)
    ::getPS4FriendsFromIndex(lastIndex+1)
}

function isPlayerPS4Friend(playerName)
{
  return ::is_platform_ps4 && playerName in ::ps4_console_friends
}
