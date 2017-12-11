foreach (notificationName, callback in
          {
            ["msquad.notify_invite"] = function(params)
              {
                local replaces = ::getTblValue("replaces", params, "").tostring()
                local squad = ::getTblValue("squad", params, null)
                local invite = ::getTblValue("invite", params, null)
                local leader = ::getTblValue("leader", params, null)

                if (invite == null || invite.id.tostring() == ::my_user_id_str)
                {
                  if (!::u.isEmpty(replaces))
                    ::g_invites.removeInviteToSquad(replaces)
                  ::g_invites.addInviteToSquad(squad.id, leader.id.tostring())
                }
                else
                  ::g_squad_manager.addInvitedPlayers(invite.id.tostring())
              },

            ["msquad.notify_invite_revoked"] = function(params)
              {
                local invite = ::getTblValue("invite", params, null)
                local squad = ::getTblValue("squad", params, null)
                if (invite == null || invite.id.tostring() == ::my_user_id_str)
                  ::g_invites.removeInviteToSquad(squad.id.tostring())
                else
                  ::g_squad_manager.removeInvitedPlayers(invite.id.tostring())
              },

            ["msquad.notify_invite_rejected"] = function(params)
              {
                local invite = ::getTblValue("invite", params, null)
                ::g_squad_manager.removeInvitedPlayers(invite.id.tostring())
                if (::g_squad_manager.getSquadSize(true) == 1)
                  ::g_squad_manager.disbandSquad()
              },

            ["msquad.notify_invite_expired"] = function(params)
              {
                local invite = ::getTblValue("invite", params, null)
                local squad = ::getTblValue("squad", params, null)
                if (invite == null || invite.id.tostring() == ::my_user_id_str)
                  ::g_invites.removeInviteToSquad(squad.id.tostring())
                else
                {
                  ::g_squad_manager.removeInvitedPlayers(invite.id.tostring())
                  if (::g_squad_manager.getSquadSize(true) == 1)
                    ::g_squad_manager.disbandSquad()
                }
              },

            ["msquad.notify_member_joined"] = function(params)
              {
                local userId = ::getTblValue("userId", params, "")
                if (userId.tostring() != ::my_user_id_str && ::g_squad_manager.isInSquad())
                {
                  ::g_squad_manager.addMember(userId.tostring())
                  ::g_squad_manager.joinSquadChatRoom()
                }
              },

            ["msquad.notify_member_leaved"] = function(params)
              {
                local userId = ::getTblValue("userId", params, "")
                if (userId.tostring() == ::my_user_id_str)
                  ::g_squad_manager.reset()
                else
                {
                  ::g_squad_manager.removeMember(userId.tostring())
                  if (::g_squad_manager.getSquadSize(true) == 1)
                    ::g_squad_manager.disbandSquad()
                }
              },

            ["msquad.notify_leader_changed"] = function(params)
              {
                if (::g_squad_manager.isInSquad())
                  ::g_squad_manager.requestSquadData(::g_squad_manager.onLeadershipTransfered)
              },

            ["msquad.notify_disbanded"] = function(params)
              {
                ::g_squad_manager.reset()
              },

            ["msquad.notify_data_changed"] = function(params)
              {
                if (::g_squad_manager.isInSquad())
                  ::g_squad_manager.requestSquadData()
              },

            ["msquad.notify_member_data_changed"] = function(params)
              {
                local userId = ::getTblValue("userId", params, "").tostring()
                if (userId != ::my_user_id_str && ::g_squad_manager.isInSquad())
                  ::g_squad_manager.requestMemberData(userId)
              },

            ["msquad.notify_member_login"] = function(params)
              {
                local userId = ::getTblValue("userId", params, "").tostring()
                if (userId != ::my_user_id_str && ::g_squad_manager.isInSquad())
                  ::g_squad_manager.setMemberOnlineStatus(userId, true)
              },

            ["msquad.notify_member_logout"] = function(params)
              {
                local userId = ::getTblValue("userId", params, "").tostring()
                if (userId != ::my_user_id_str && ::g_squad_manager.isInSquad())
                  ::g_squad_manager.setMemberOnlineStatus(userId, false)
              }
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)
