function debug_show_test_unlocks(chapter = "test", group = null)
{
  if (!::is_dev_version)
    return

  local awardsList = []
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
    if((!chapter || unlock.chapter == chapter) && (!group || unlock.group == group))
      awardsList.append(::build_log_unlock_data({ id = unlock.id }))
  ::showUnlocksGroupWnd([{
    unlocksList = awardsList
    titleText = "debug_show_test_unlocks (total: " + awardsList.len() + ")"
  }])
}

function debug_show_all_streaks()
{
  if (!::is_dev_version)
    return

  local total = 0
  local awardsList = []
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    if (unlock.type != "streak" || unlock.hidden)
      continue
    total++

    if (!::g_unlocks.isUnlockMultiStageLocId(unlock.id))
    {
      local data = ::build_log_unlock_data({ id = unlock.id })
      data.title = unlock.id
      awardsList.append(data)
    }
    else
    {
      local paramShift = ::getTblValueByPath("stage.param", unlock, 0)
      foreach(key, stageId in ::g_unlocks.multiStageLocId[unlock.id])
      {
        local stage = ::is_numeric(key) ? key : 99
        local data = ::build_log_unlock_data({ id = unlock.id, stage = stage - paramShift })
        data.title = unlock.id + " / " + stage
        awardsList.append(data)
      }
    }
  }

  ::showUnlocksGroupWnd([{
    unlocksList = awardsList,
    titleText = "debug_show_all_streaks (total: " + total + ")"
  }])
}

function gen_all_unlocks_desc(showCost = false)
{
  dlog("GP: gen all unlocks description")
  local res = ""
  local params = {showCost = showCost}
  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    local data = ::build_conditions_config(unlock)
    local desc = ::getUnlockDescription(data, params)
    res += "\n" + unlock.id + ":" + (desc != ""? "\n" : "") + desc
  }
  dlog("GP: res:")
  dagor.debug(res)
  dlog("GP: done")
}

function gen_all_unlocks_desc_to_blk(path = "unlockDesc", showCost = false, showValue = false, all_langs = true)
{
  if (!all_langs)
    return gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  local curLang = ::get_current_language()
  local info = ::g_language.getGameLocalizationInfo()
  _gen_all_unlocks_desc_to_blk(path, showCost, showValue, info, curLang)
}

function _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang)
{
  local lang = langsInfo.pop()
  ::g_language.setGameLocalization(lang.id, false, false)
  gen_all_unlocks_desc_to_blk_cur_lang(path, showCost, showValue)

  if (!langsInfo.len())
    return ::g_language.setGameLocalization(curLang, false, false)

  //delayed to easy see progress, and avoid watchdog crash.
  local guiScene = ::get_main_gui_scene()
  guiScene.performDelayed(this, (@(path, showCost, showValue, langsInfo, curLang) function () {
    _gen_all_unlocks_desc_to_blk(path, showCost, showValue, langsInfo, curLang)
  })(path, showCost, showValue, langsInfo, curLang))
}

function gen_all_unlocks_desc_to_blk_cur_lang(path = "unlockDesc", showCost = false, showValue = false)
{
  local fullPath = ::format("%s/unlocks%s.blk", path, ::get_current_language())
  dlog("GP: gen all unlocks description to " + fullPath)

  local res = ::DataBlock()
  local params = {
                   showCost = showCost,
                   curVal = showValue ? null : "{value}",
                   maxVal = showValue ? null : "{maxValue}"
                 }

  foreach(id, unlock in ::g_unlocks.getAllUnlocks())
  {
    local data = ::build_conditions_config(unlock)
    local desc = ::getUnlockDescription(data, params)

    local blk = ::DataBlock()
    blk.name = ::get_unlock_name_text(data.unlockType, id)
    blk.desc = desc
    res[id] = blk
  }
  ::dd_mkpath(fullPath)
  res.saveToTextFile(fullPath)
}

function debug_show_unlock_popup(unlockId)
{
  ::gui_start_unlock_wnd(
    ::build_log_unlock_data(
      ::build_conditions_config(
        ::g_unlocks.getUnlockById(unlockId)
      )
    )
  )
}
