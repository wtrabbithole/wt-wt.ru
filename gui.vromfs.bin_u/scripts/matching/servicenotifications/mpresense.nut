/**[DEPRECATED] this notification callbacks call by mathing forced**/
function on_presences_update(params)
{
  local contactsDataList = []
  if ("presences" in params)
  {
    foreach(p in params.presences)
    {
      local player = {
        uid = ::getTblValue("userId", p)
        name = ::getTblValue("nick", p)
      }
      if (!::u.isString(player.uid) || !::u.isString(player.name))
      {
        local errText = "on_presences_update cant update presence of player:\n" + ::toString(p)
        ::script_net_assert_once(::toString(player), errText)
        continue
      }

      if ("presences" in p)
      {
        if ("online" in p.presences)
        {
          player.online <- p.presences.online
          player.unknown <- null
        }
        if ("unknown" in p.presences)
          player.unknown <- p.presences.unknown

        if ("status" in p.presences)
        {
          player.gameStatus <- null
          foreach(s in ["in_game", "in_queue"])
            if (s in p.presences.status)
            {
              local gameInfo = p.presences.status[s]

              // This is a workaround for a bug when something
              // is setting player presence with no event info.
              if (!("eventId" in gameInfo))
                continue

              player.gameStatus = s
              player.gameConfig <- {
                diff = gameInfo.diff
                country = gameInfo.country
                eventId = ::getTblValue("eventId", gameInfo, null)
              }
              break
            }
        }

        if("clanTag" in p.presences)
        {
          if (typeof(p.presences.clanTag) == "string")
            player.clanTag <- p.presences.clanTag
          else
          {
            if (typeof(p.presences.clanTag) == "array")
              debugTableData(p.presences.clanTag)
            ::dagor.assertf(false, "Error: presences: incorrect type of clantag = " + p.presences.clanTag + ", for user " + player.name + ", " + player.uid)
          }
        }

        if ("profile" in p.presences)
        {
          player.pilotIcon <- ::get_pilot_icon_by_id(p.presences.profile.pilotId)
          player.wins <- p.presences.profile.wins
          player.rank <- ::get_rank_by_exp(p.presences.profile.expTotal)
        }

        if ("in_game_ex" in p.presences)
        {
          player.inGameEx <- p.presences.in_game_ex
        }
      }
      player.replace <- ("update" in p) ? !p.update : false
      contactsDataList.append(player)
    }
  }

  ::update_contacts_by_list(contactsDataList, false)

  if ("groups" in params)
  {
    if (::is_platform_ps4)
      ::addContactGroup(::EPLX_PS4_FRIENDS)

    if( (::EPL_FACEBOOK in params.groups) &&
        (params.groups[::EPL_FACEBOOK].len()>0)
      )
      ::addContactGroup(::EPL_FACEBOOK)

    if( ::steam_is_running() &&
        (::EPL_STEAM in params.groups) &&
        (params.groups[::EPL_STEAM].len()>0)
      )
      ::addContactGroup(::EPL_STEAM)

    foreach(listName, list in params.groups)
    {
      if (list == null)
        continue

      if (listName == ::EPL_FRIENDLIST && ::is_platform_ps4)
        ::contacts[::EPLX_PS4_FRIENDS] <- []
      ::contacts[listName] <- []

      foreach(p in list)
      {
        local player = ::getContact(p.userId, p.nick)
        if (!player)
        {
          local errText = ::format("on_presences_update cant add player to group '%s':\n%s", listName, ::toString(p))
          ::script_net_assert_once("not found contact for group", errText)
          continue
        }

        if (listName == ::EPL_FRIENDLIST && player.online == null)
          player.online = null

        if (listName == ::EPL_FRIENDLIST)
          ::contacts[::getFriendGroupName(p.nick)].append(player)
        else
          ::contacts[listName].append(player)
      }
    }
  }
  ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, {groupName = null})

  update_gamercards()
}

foreach (notificationName, callback in
          {
            ["mpresence.notify_presence_update"] = on_presences_update,

            ["mpresence.on_added_to_contact_list"] = function (params)
              {
                local userData = ::getTblValue("user", params)
                if (userData)
                  ::g_invites.addFriendInvite(::getTblValue("name", userData, ""), ::getTblValue("userId", userData, ""))
              }
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)
