::PS4_BACK_UP_INVITATION_STRING <- ""
::PS4_IGNORE_INVITE_STRING <- "#ignore#"

function sendInvitationPsn(config)
{
  local inviteType = ::getTblValue("inviteType", config, "")

  local blk = ::DataBlock()
  local dataNameLocId = "ps4/invitation/" + inviteType + "/name"
  local dataDescriptionLocId = "ps4/invitation/" + inviteType + "/detail"

  blk.userMessage = ""
  blk.target = ::getTblValue("target", config, "") //::ps4_get_friend()
  blk.dataName = ::loc(dataNameLocId)
  blk.dataDetail = ::loc(dataDescriptionLocId)

  local localizedNameTable = ::get_localized_text_with_abbreviation(dataNameLocId)
  local localizedDetailTable = ::get_localized_text_with_abbreviation(dataDescriptionLocId)

  if (localizedNameTable.len() > 0 && localizedDetailTable.len() > 0)
  {
    local locNames = ::DataBlock()
    local locDetails = ::DataBlock()
    foreach (abbrev, nameText in localizedNameTable)
    {
      local descrText = ::getTblValue(abbrev, localizedDetailTable, "")
      if (descrText == "")
      {
        ::dagor.debug("Not found abbreviation '" + abbrev + "' in descriptionTable, locId - " + dataDescriptionLocId)
        debugTableData(localizedNameTable)
        debugTableData(localizedDetailTable)
        continue
      }
      local n = ::DataBlock()
      local d = ::DataBlock()
      n.language <- abbrev
      d.language <- abbrev

      n.str <- nameText
      d.str <- descrText

      locNames.loc <- n
      locDetails.loc <- d
    }
    blk.locNames = locNames
    blk.locDetails = locDetails
  }

  blk.expireMinutes = ::getTblValue("expireMinutes", config, 10) //60*24*7; //week
  blk.data = (inviteType == "gameStart"? ::PS4_IGNORE_INVITE_STRING : "") + ::my_user_name //::get_player_user_id_str()
  blk.imagePath = "ui/images/invite_small.jpg"

  return ::ps4_send_message(blk)
}

function checkSquadInvitesFromPS4Friends(checkNewPS4Invitation = true, contProcessItemId = true)
{
  if (!::is_platform_ps4)
    return

  local itemId = ""

  if (checkNewPS4Invitation)
  {
    itemId = ::ps4_fetch_invitation()
    if (itemId != "")
      ::PS4_BACK_UP_INVITATION_STRING = itemId
  }
  else
    itemId = ::PS4_BACK_UP_INVITATION_STRING

  if (itemId == "")
    return

  if (!::isInMenu())
  {
    ::get_cur_gui_scene().performDelayed(this, function() {
      local curBaseGuiHandler = ::get_cur_base_gui_handler()
      curBaseGuiHandler.goForward(function(){ ::gui_start_flight_menu()} )
      ::showInfoMsgBox(::loc("msgbox/add_to_squad_after_fight"), "add_to_squad_after_fight")
    })
    return
  }

  ::broadcastEvent("PS4AvailableNewInvite")

  if (::is_in_loading_screen() || !::g_login.isLoggedIn() || !::gchat_is_connected())
    return

  if (contProcessItemId)
    ::getSquadInvitesFromPS4Friends(itemId)
}

function getSquadInvitesFromPS4Friends(itemId)
{
  local blk = ::DataBlock()
  blk.apiGroup = "gameCustomData"
  blk.method = ::HTTP_METHOD_GET
  local query = ::format("/v1/users/%s/gameCustomData/items/%s/gameData", ::ps4_get_online_id(), itemId)
  blk.path = query
  blk.respSize = 8*1024

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    debugTableData(blk)
    dagor.debug("Error: "+ret.error)
    dagor.debug("Error text: "+ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::approveLastPs4SquadInvite(ret.response)
    ::sendSquadInviteRecieveApprovement(itemId)
  }
}

function sendSquadInviteRecieveApprovement(itemId)
{
  local blk = ::DataBlock()
  blk.apiGroup = "gameCustomData"
  blk.method = ::HTTP_METHOD_PUT
  local query = ::format("/v1/users/%s/gameCustomData/items/%s", ::ps4_get_online_id(), itemId)
  blk.path = query
  blk.request = "{\n\"dataUsedFlag\": true\n}"

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    debugTableData(blk)
    dagor.debug("Error: "+ret.error)
    dagor.debug("Error text: "+ret.errorStr)
  }
}

function approveLastPs4SquadInvite(squadInviter = "")
{
  if (!::is_platform_ps4
      || squadInviter == ""
      || (squadInviter.len() > ::PS4_IGNORE_INVITE_STRING.len()
          && squadInviter.slice(::PS4_IGNORE_INVITE_STRING.len()) == ::PS4_IGNORE_INVITE_STRING)
     )
    return

  broadcastEvent("ApproveLastPs4SquadInvite")
}

function on_ps4_squad_room_joined()
{
  if (!::is_platform_ps4)
     return

  ::PS4_BACK_UP_INVITATION_STRING = ""
}

function on_ps4_game_alert()
{
  /*!!!calls from code, when recieved invitation to squad
  via ps4 service*/

  ::checkSquadInvitesFromPS4Friends(true)
}