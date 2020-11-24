local { checkTutorialsList, reqTutorial, tutorialRewardData, clearTutorialRewardData
} = require("scripts/tutorials/tutorialsData.nut")

local TutorialRewardHandler = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "gui/showUnlock.blk"

  misName = ""
  rewardText = ""
  afterRewardText = ""

  function initScreen() {
    scene.findObject("award_name").setValue(::loc("mainmenu/btnTutorial"))

    local descObj = scene.findObject("award_desc")
    descObj["text-align"] = "center"

    local msgText = ::colorize("activeTextColor", ::loc("MISSION_SUCCESS") + "\n" + ::loc("missions/" + misName, ""))
    descObj.setValue(msgText)

    scene.findObject("award_reward").setValue(rewardText)

    foreach(t in checkTutorialsList)
      if (t.tutorial == misName)
      {
        local image = ::get_country_flag_img("tutorial_" + t.id + "_win")
        if (image == "")
          continue

        scene.findObject("award_image")["background-image"] = image
        break
      }

    if (!::is_any_award_received_by_mode_type("char_versus_battles_end_count_and_rank_test"))
      afterRewardText = ::loc("award/tutorial_fighter_next_award/desc")

    local nObj = scene.findObject("next_award")
    if (::checkObj(nObj))
      nObj.setValue(afterRewardText)
  }

  function onOk() {
    goBack()
  }
}

::gui_handlers.TutorialRewardHandler <- TutorialRewardHandler

local function getMoneyFromDebriefingResult(paramName) {
  local res = ::Cost()
  if (::debriefing_result == null)
    return res

  local exp = ::debriefing_result.exp
  res.wp = exp?[$"wp{paramName}"] ?? 0
  res.gold = exp?[$"gold{paramName}"] ?? 0
  res.frp = exp?[$"exp{paramName}"] ?? 0
  return res
}

local function tryOpenTutorialRewardHandler() {
  if (tutorialRewardData.value == null)
    return false

  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  local progress = ::get_mission_progress(tutorialRewardData.value.fullMissionName)
  ::set_mp_mode(mainGameMode)

  if (tutorialRewardData.value.presetFilename != "")
    ::apply_joy_preset_xchange(tutorialRewardData.value.presetFilename)

  local newCountries = null
  if (progress!=tutorialRewardData.value.progress)
  {
    local misName = tutorialRewardData.value.missionName

    if (tutorialRewardData.value.progress>=3 && progress>=0 && progress<3)
    {
      local rewardText = ""
      local rBlk = ::get_pve_awards_blk()
      local dataBlk = rBlk?[::get_game_mode_name(::GM_TRAINING)]
      local miscText = dataBlk?[misName].rewardWndInfoText ?? ""
      if (dataBlk?[misName].slot != null)
      {
        ::g_crews_list.invalidate()
        ::reinitAllSlotbars()
      }

      ::gather_debriefing_result()
      local reward = getMoneyFromDebriefingResult("Mission")
      rewardText = ::getRewardTextByBlk(dataBlk || ::DataBlock(), misName, 0, "reward", false, true, false, reward)

      ::gui_start_modal_wnd(::gui_handlers.TutorialRewardHandler,
      {
        misName = misName
        rewardText = rewardText
        afterRewardText = ::loc(miscText)
      })
    }

    if (::u.search(reqTutorial, @(val) val == misName) != null)
    {
      newCountries = checkUnlockedCountries()
      foreach(c in newCountries)
        ::checkRankUpWindow(c, -1, ::get_player_rank_by_country(c))
    }
  }

  clearTutorialRewardData()
  return newCountries && newCountries.len() > 0 //is new countries unlocked by tutorial?
}

return {
  tryOpenTutorialRewardHandler = tryOpenTutorialRewardHandler
}