
g_missions_manager <- {
  isRemoteMission = false
}

function g_missions_manager::fastStartSkirmishMission(mission)
{
  local params = {
    canSwitchMisListType = false
    showAllCampaigns = false
    mission = mission
    wndGameMode = ::GM_SKIRMISH
  }

  ::prepare_start_skirmish()
  isRemoteMission = true
  ::handlersManager.loadHandler(::gui_handlers.RemoteMissionModalHandler, params)
}

function g_missions_manager::startRemoteMission(params)
{
  local url = params.url
  local name = params.name || "remote_mission"

  if (!::isInMenu() || ::handlersManager.isAnyModalHandlerActive())
    return

  local urlMission = UrlMission(name, url)
  local callback = (@(urlMission) function(success) {
                     local mission = {
                       id = urlMission.name
                       isHeader = false
                       isCampaign = false
                       isUnlocked = true
                       campaign = ""
                       chapter = ""
                     }

                     mission.urlMission <- urlMission
                     mission.blk <- urlMission.getMetaInfo()

                     ::g_missions_manager.fastStartSkirmishMission(mission)
                   })(urlMission)

  ::scene_msg_box("start_mission_from_live_confirmation",
                  null,
                  ::loc("urlMissions/live/loadAndStartConfirmation", params),
                  [["yes", (@(urlMission, callback) function() { ::g_url_missions.loadBlk(urlMission, callback) })(urlMission, callback) ],
                   ["no", function() {} ]],
                  "yes", { cancel_fn = function() {}}
                )
}

function on_start_remote_mission(params)
{
  ::g_missions_manager.startRemoteMission(params)
}

web_rpc.register_handler("start_remote_mission", on_start_remote_mission)