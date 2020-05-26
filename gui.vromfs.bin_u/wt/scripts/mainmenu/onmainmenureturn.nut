local onMainMenuReturnActions = require("scripts/mainmenu/onMainMenuReturnActions.nut")

local time = require("scripts/time.nut")
local penalties = require("scripts/penitentiary/penalties.nut")
local itemNotifications = ::require("scripts/items/itemNotifications.nut")

//called after all first mainmenu actions
onMainMenuReturnActions.onMainMenuReturn <- function(handler, isAfterLogin) {
  if (!handler)
    return
  local isAllowPopups = ::g_login.isProfileReceived() && !::getFromSettingsBlk("debug/skipPopups")
  local guiScene = handler.guiScene
  if (isAllowPopups)
    ::SessionLobby.checkSessionReconnect()

  if (!isAfterLogin)
  {
    ::g_warbonds_view.resetShowProgressBarFlag()
    ::checkUnlockedCountriesByAirs()
    penalties.showBannedStatusMsgBox(true)
    if (isAllowPopups && !::disable_network())
    {
      handler.doWhenActive(::g_user_utils.checkShowRateWnd)
      handler.doWhenActive(::check_joystick_thustmaster_hotas)
      handler.doWhenActive(::check_tutorial_on_mainmenu)
    }
  }

  ::check_logout_scheduled()

  ::sysopt.configMaintain()

  ::checkNewNotificationUserlogs()
  ::checkNonApprovedResearches(true)
  if (isAllowPopups)
  {
    handler.doWhenActive(::gui_handlers.FontChoiceWnd.openIfRequired)

    handler.doWhenActive(@() ::g_psn_sessions.checkAfterFlight() )
    handler.doWhenActive(@() ::g_play_together.checkAfterFlight() )
    handler.doWhenActive(@() ::g_xbox_squad_manager.checkAfterFlight() )
    handler.doWhenActive(@() ::g_battle_tasks.checkNewSpecialTasks() )
    handler.doWhenActiveOnce("checkNonApprovedSquadronResearches")
  }

  if(isAllowPopups && ::has_feature("Invites") && !guiScene.hasModalObject())
  {
    local invitedPlayersBlk = ::DataBlock()
    ::get_invited_players_info(invitedPlayersBlk)
    if(invitedPlayersBlk.blockCount() == 0)
    {
      local gmBlk = ::get_game_settings_blk()
      local reminderPeriod = gmBlk?.viralAcquisitionReminderPeriodDays ?? 10
      local today = time.getUtcDays()
      local never = 0
      local lastShowTime = ::load_local_account_settings("viralAcquisition/lastShowTime", never)
      local lastLoginDay = ::load_local_account_settings("viralAcquisition/lastLoginDay", today)

      // Game designers can force reset lastShowTime of all users by increasing this value in cfg:
      if (gmBlk?.resetViralAcquisitionDaysCounter)
      {
        local newResetVer = gmBlk.resetViralAcquisitionDaysCounter
        local knownResetVer = ::load_local_account_settings("viralAcquisition/resetDays", 0)
        if (newResetVer > knownResetVer)
        {
          ::save_local_account_settings("viralAcquisition/resetDays", newResetVer)
          lastShowTime = never
        }
      }

      ::save_local_account_settings("viralAcquisition/lastLoginDay", today)
      if ((lastLoginDay - lastShowTime) > reminderPeriod)
      {
        ::save_local_account_settings("viralAcquisition/lastShowTime", today)
        ::show_viral_acquisition_wnd()
      }
    }
  }

  if (!guiScene.hasModalObject() && isAllowPopups)
  {
    handler.doWhenActive(@() ::g_user_utils.checkAutoShowPS4EmailRegistration())
    handler.doWhenActive(@() ::g_user_utils.checkAutoShowSteamEmailRegistration())
  }

  if (isAllowPopups && !guiScene.hasModalObject() && !::is_platform_ps4 && ::has_feature("Facebook"))
    handler.doWhenActive(show_facebook_login_reminder)
  if (isAllowPopups)
    handler.doWhenActive(function () { ::checkRemnantPremiumAccount() })
  if (handler.unitInfoPanel == null)
  {
    handler.unitInfoPanel = ::create_slot_info_panel(handler.scene, true, "mainmenu")
    handler.registerSubHandler(handler.unitInfoPanel)
  }
  ::g_user_presence.init()

  if (isAllowPopups)
  {
    handler.doWhenActiveOnce("checkNoviceTutor")
    handler.doWhenActiveOnce("checkUpgradeCrewTutorial")
    handler.doWhenActiveOnce("initPromoBlock")
    handler.doWhenActiveOnce("checkNewUnitTypeToBattleTutor")
    handler.doWhenActiveOnce("checkShowChangelog")

    local hasModalObjectVal = guiScene.hasModalObject()
    handler.doWhenActive((@(hasModalObjectVal) function() { ::g_popup_msg.showPopupWndIfNeed(hasModalObjectVal) })(hasModalObjectVal))
    handler.doWhenActive(function () { itemNotifications.checkOfferToBuyAtExpiration() })
  }

  handler.doWhenActive(::pop_gblk_error_popups)

  guiScene.initCursor("gui/cursor.blk", "normal")
}