const NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID = "statistic:new_player_tutorial_choice"
::skip_tutorial_bitmask_id <- "skip_tutorial_bitmask"
::tutorials_to_check <- [ //idx in this array used for local profile option ::skip_tutorial_bitmask_id
  {
    id = "fighter"
    tutorial = "tutorialB_fighter"
    canSkipByFeature = "AllowedToSkipBaseTutorials"
  }
  {
    id = "bomber"
    tutorial = "tutorialB_bomber"
  }
  {
    id = "assaulter"
    tutorial = "tutorialB_assaulter"
  }
  {
    id = "lightTank"
    tutorial = "tutorial_tank_basics_arcade"
    canSkipByFeature = "AllowedToSkipBaseTankTutorials"
    requiresFeature = "Tanks"
  }
  {
    id = "lightTank_part2"
    tutorial = "tutorial_tank_basics_arcade_part2"
    requiresFeature = "Tanks"
    isNeedAskInMainmenu = function()
    {
      return  ::is_unlocked(-1, "player_is_out_of_tank_sandbox")
              && ::is_tutorial_complete("tutorial_tank_basics_arcade_part1")
    }
  }
]

::check_tutorial_reward_data <- null
::launched_tutorial_questions_peer_session <- 0
::dagui_propid.add_name_id("userInputType")

::g_script_reloader.registerPersistentData("TutorialsGlobal", ::getroottable(),
  ["check_tutorial_reward_data", "launched_tutorial_questions_peer_session"])

function gui_start_checkTutorial(checkId, checkSkip = true)
{
  local idx = -1
  local data = null
  foreach(i, item in ::tutorials_to_check)
    if (item.id == checkId)
    {
      if (("requiresFeature" in item) && !::has_feature(item.requiresFeature))
        return false
      if (::launched_tutorial_questions_peer_session & (1 << i) && checkSkip)
        return false

      ::launched_tutorial_questions_peer_session = ::launched_tutorial_questions_peer_session | (1 << i)
      idx = i
      data = item
      break
    }

  if (!data)
    return false

  if (checkSkip)
  {
    local skipTutorial = ::loadLocalByAccount(::skip_tutorial_bitmask_id, 0)
    if (::is_bit_set(skipTutorial, idx))
      return false
  }

  local mData = ::get_uncompleted_tutorial_data(data.tutorial)
  if (!mData)
    return false

  ::gui_start_modal_wnd(::gui_handlers.NextTutorialHandler,
    {
      tutorialMission = mData.mission
      rewardText = mData.rewardText
      checkIdx = idx
    })
  return true
}

class ::gui_handlers.NextTutorialHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  canSkipTutorial = true
  function initScreen()
  {
    if (!tutorialMission)
      return goBack()

    local msgText = ::loc("askPlayTutorial")
    msgText += "\n" + ::colorize("userlogColoredText", ::loc("missions/" + tutorialMission.name))
    if (rewardText != "")
      msgText += "\n\n" + rewardText
    scene.findObject("msgText").setValue(msgText)

    local canSkipTutorial = true
    if (checkIdx in ::tutorials_to_check)
    {
      local tutorialBlock = ::tutorials_to_check[checkIdx]
      local image = ::get_country_flag_img("tutorial_" + tutorialBlock.id)
      if (image != "")
        scene.findObject("tutorial_image")["background-image"] = image
      if ("canSkipByFeature" in tutorialBlock)
        canSkipTutorial = ::has_feature(tutorialBlock.canSkipByFeature)
      if (!canSkipTutorial)
        canSkipTutorial = ::loadLocalByAccount("firstRunTutorial_"+tutorialMission.name, false)
    }
    foreach (name in ["skip_tutorial", "btn_close_tutorial"])
    {
      local obj = scene.findObject(name)
      if (obj)
        obj.show(canSkipTutorial)
    }
    if (canSkipTutorial)
    {
      local obj = scene.findObject("skip_tutorial")
      if (::checkObj(obj))
      {
        local skipTutorial = ::loadLocalByAccount(::skip_tutorial_bitmask_id, 0)
        obj.setValue(::is_bit_set(skipTutorial, checkIdx))
      }
    }
  }

  function onStart(obj = null)
  {
    sendTutorialChoiceStatisticOnce("start", obj)
    ::save_tutorial_to_check_reward(tutorialMission)
    ::saveLocalByAccount("firstRunTutorial_"+tutorialMission.name, true)

    ::set_mp_mode(::GM_TRAINING)
    ::select_mission(tutorialMission, true)
    ::current_campaign_mission = tutorialMission.name
    guiScene.performDelayed(this, function(){ goForward(::gui_start_flight); })
    ::save_profile(false)
  }

  function onClose(obj = null)
  {
    if( ! canSkipTutorial)
      return;
    sendTutorialChoiceStatisticOnce("close", obj)
    goBack()
  }

  function sendTutorialChoiceStatisticOnce(action, obj = null)
  {
    if(::loadLocalByAccount(NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID, false))
      return
    local info = {
                  action = action,
                  reminder = ::is_bit_set(::loadLocalByAccount(::skip_tutorial_bitmask_id, 0), checkIdx) ? "off" : "on"
                  missionName = tutorialMission.name
                  }
    if(obj != null)
      info["input"] <- getObjectUserInputType(obj)
    ::add_big_query_record ("new_player_tutorial_choice", ::save_to_json(info))
    ::saveLocalByAccount(NEW_PLAYER_TUTORIAL_CHOICE_STATISTIC_SAVE_ID, true)
  }

  function onSkipTutorial(obj)
  {
    if (!obj)
      return

    local skipTutorial = ::loadLocalByAccount(::skip_tutorial_bitmask_id, 0)
    skipTutorial = ::change_bit(skipTutorial, checkIdx, obj.getValue())
    ::saveLocalByAccount(::skip_tutorial_bitmask_id, skipTutorial)
  }

  function getObjectUserInputType(obj)
  {
    local VALID_INPUT_LIST = ["mouse", "keyboard", "gamepad"]
    local userInputType = obj.userInputType || ""
    if(::isInArray(userInputType, VALID_INPUT_LIST))
      return userInputType
    return "invalid"
  }

  wndType = handlerType.MODAL
  sceneBlkName = "gui/nextTutorial.blk"

  tutorialMission = null
  rewardText = ""
  checkIdx = 0
}

function save_tutorial_to_check_reward(mission)
{
  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  local campId = ::get_game_mode_name(::GM_TRAINING)
  local fullMissionName = mission.getStr("chapter", campId) + "/" + mission.name
  local progress = ::get_mission_progress(fullMissionName)

  local usePresetFileName = ""
  local preset = ::g_controls_presets.getCurrentPreset()
  if (preset.name.find("hotas4") != null
      && ::check_joystick_thustmaster_hotas(false)
      && ! ::has_feature("DisableSwitchPresetOnTutorialForHotas4"))
    {
      usePresetFileName = preset.fileName
      ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename("dualshock4"))
    }

  ::check_tutorial_reward_data = { missionName = mission.name,
                                   progress = progress,
                                   fullMissionName = fullMissionName,
                                   presetFilename = usePresetFileName
                                 }
  ::set_mp_mode(mainGameMode)
}

function check_tutorial_reward()
{
  if (!::check_tutorial_reward_data)
    return false

  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  local progress = ::get_mission_progress(::check_tutorial_reward_data.fullMissionName)
  ::set_mp_mode(mainGameMode)

  if (::check_tutorial_reward_data.presetFilename != "")
    ::apply_joy_preset_xchange(::check_tutorial_reward_data.presetFilename)

  local newCountries = null
  if (progress!=::check_tutorial_reward_data.progress)
  {
    local misName = ::check_tutorial_reward_data.missionName

    if (::check_tutorial_reward_data.progress>=3 && progress>=0 && progress<3)
    {
      local rewardText = ""
      local rBlk = ::DataBlock()
      rBlk = ::get_pve_awards_blk()
      local dataBlk = rBlk[::get_game_mode_name(::GM_TRAINING)]
      local miscText = ""
      if (dataBlk && dataBlk[misName] && dataBlk[misName].rewardWndInfoText)
        miscText = dataBlk[misName].rewardWndInfoText
      if (dataBlk && dataBlk[misName] && dataBlk[misName].slot != null)
      {
        local tasksData = [];
        local slot = dataBlk[misName].slot;
        if (::crews_list.len()==0)
          ::crews_list = ::get_crew_info();
        foreach(c in ::crews_list)
          if (c.crews.len() == slot && c.crews[slot-1].isEmpty == 1)
          {
            local airName = ::getReserveAircraftName({country = c.country});
            if (airName=="")
              continue
            local crewId = c.crews[slot-1].id;
            tasksData.append({crewId = crewId, airName = airName});
          }
        if (tasksData.len())
          ::batch_train_crew(tasksData)
      }

      ::gather_debriefing_result()
      local reward = ::get_money_from_debriefing_result("Mission")
      rewardText = ::getRewardTextByBlk(dataBlk || ::DataBlock(), misName, 0, "reward", false, true, false, reward)

      ::gui_start_modal_wnd(::gui_handlers.ShowTutorialRewardHandler,
      {
        misName = misName
        rewardText = rewardText
        afterRewardText = ::loc(miscText)
      })
    }

    if (::isInArray(misName, ::req_tutorial))
    {
      newCountries = checkUnlockedCountries()
      foreach(c in newCountries)
        ::checkRankUpWindow(c, -1, ::get_player_rank_by_country(c))
    }
  }

  ::check_tutorial_reward_data = null
  return newCountries && newCountries.len() > 0 //is new countries unlocked by tutorial?
}

function get_money_from_debriefing_result(paramName)
{
  local res = ::Cost()
  if (!::debriefing_result)
    return res

  local exp = ::debriefing_result.exp
  res.wp = ::getTblValue("wp" + paramName, exp)
  res.gold = ::getTblValue("gold" + paramName, exp)
  res.frp = ::getTblValue("exp" + paramName, exp)
  return res
}

function getReserveAircraftName(paramsTable)
{
  local preferredCrew = ::getTblValue("preferredCrew", paramsTable, null)

  // Trained level by unit name.
  local trainedSpec = ::getTblValue("trainedSpec", preferredCrew, {})

  foreach (unitName, unitSpec in trainedSpec)
  {
    local unit = ::getAircraftByName(unitName)
    if (unit != null && checkReserveUnit(unit, paramsTable))
      return unit.name
  }

  foreach (unit in ::all_units)
    if (checkReserveUnit(unit, paramsTable))
      return unit.name

  return ""
}

function checkReserveUnit(unit, paramsTable)
{
  local country = ::getTblValue("country", paramsTable, "")
  local unitType = ::getTblValue("unitType", paramsTable, ::ES_UNIT_TYPE_AIRCRAFT)
  local ignoreUnits = ::getTblValue("ignoreUnits", paramsTable, [])
  local ignoreSlotbarCheck = ::getTblValue("ignoreSlotbarCheck", paramsTable, false)

  return (unit.shopCountry == country &&
         (::get_es_unit_type(unit) == unitType || unitType == ::ES_UNIT_TYPE_INVALID) &&
         !::isInArray(unit.name, ignoreUnits) &&
         ::is_default_aircraft(unit.name) &&
         (ignoreSlotbarCheck || !::isUnitInSlotbar(unit)))
}

/**
 * @param onSuccess - Callback func, has no params.
 * @param onError   - Callback func, MUST take 1 param: integer taskResult.
 */
function batch_train_crew(requestData, taskOptions = null, onSuccess = null, onError = null, handler = null)
{
  local onTaskSuccess = onSuccess ? ::Callback(onSuccess, handler) : null
  local onTaskError   = onError   ? ::Callback(onError,   handler) : null

  if (::disable_network() || !requestData.len())
  {
    if (onTaskSuccess)
      onTaskSuccess()
    return
  }

  local requestBlk = ::create_batch_train_crew_request_blk(requestData)
  local taskId = ::char_send_blk("cln_bulk_train_aircraft", requestBlk)
  ::g_tasker.addTask(taskId, taskOptions, onTaskSuccess, onTaskError)
}

function create_batch_train_crew_request_blk(requestData)
{
  local requestBlk = ::DataBlock()
  requestBlk.batchTrainCrew <- ::DataBlock()
  foreach (requestItem in requestData)
  {
    local itemBlk = ::DataBlock()
    itemBlk.crewId <- requestItem.crewId
    itemBlk.unitName <- requestItem.airName
    requestBlk.batchTrainCrew.trainCrew <- itemBlk
  }
  return requestBlk
}

class ::gui_handlers.ShowTutorialRewardHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    scene.findObject("award_name").setValue(::loc("mainmenu/btnTutorial"))

    local descObj = scene.findObject("award_desc")
    descObj["text-align"] = "center"

    local msgText = ::colorize("activeTextColor", ::loc("MISSION_SUCCESS") + "\n" + ::loc("missions/" + misName, ""))
    descObj.setValue(msgText)

    scene.findObject("award_reward").setValue(rewardText)

    foreach(t in ::tutorials_to_check)
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

  function onOk()
  {
    goBack();
  }

  wndType = handlerType.MODAL
  sceneBlkName = "gui/showUnlock.blk"

  misName = ""
  rewardText = ""
  afterRewardText = ""
}

function is_tutorial_complete(tutorialName)
{
  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress
  local progress = ::get_mission_progress("tutorial/" + tutorialName)
  ::set_mp_mode(mainGameMode)
  return progress >= 0 && progress < 3
}

function get_uncompleted_tutorial_data(misName, diff = -1, checkDebriefing = false)
{
  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress

  local tutorialMission = null

  local campId = ::get_game_mode_name(::GM_TRAINING)
  local chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  local progress = -1
  foreach(chapter in chapters)
    foreach(m in chapter)
      if ((misName && misName == m.name) || (!misName && m.chapter == "tutorial"))
      {
        local fullMissionName = m.getStr("chapter", campId) + "/" + m.name
        progress = ::get_mission_progress(fullMissionName)
        if ((diff<0 && progress == 3) || (diff>=0 && (progress==3 || progress<diff))) // 3 == unlocked, 0-2 - completed at difficulty
        {
          tutorialMission = m
          break
        } else
          if (misName)
            break
      }

  ::set_mp_mode(mainGameMode)
  if (!tutorialMission)
    return null

  local res = { mission = tutorialMission, rewardText = "" }

  if (progress == 3) //tutorials have reward only once
  {
    local rBlk = ::DataBlock()
    rBlk = ::get_pve_awards_blk()
    local dataBlk = rBlk[campId]
    if (dataBlk)
      res.rewardText = ::getRewardTextByBlk(dataBlk, tutorialMission.name, 0, "reward", true, true)
  }
  return res
}

function check_tutorial_on_mainmenu()
{
  foreach(tutorial in ::tutorials_to_check)
  {
    local func = ::getTblValue("isNeedAskInMainmenu", tutorial)
    if (!func || !func())
      continue

    if (::gui_start_checkTutorial(tutorial.id))
      return
  }
}

function check_tutorial_on_start()
{
  local tutorial = "fighter"

  local curUnit = ::get_show_aircraft()
  if (curUnit && ::isTank(curUnit) && ::has_feature("Tanks"))
    tutorial = "lightTank"

  if (!::gui_start_checkTutorial(tutorial))
    check_tutorial_on_mainmenu()
}