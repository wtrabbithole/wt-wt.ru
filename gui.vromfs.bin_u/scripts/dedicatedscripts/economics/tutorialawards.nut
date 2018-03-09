function player_was_active_in_session(userId) {
  local sessionStat = ::wp_stat_get_exp_for_player(userId)

  if (sessionStat != null)
  {
    dagor.debug("player_was_active_in_session - score "+sessionStat.score.tostring()+" player "+userId.tostring())

    if (sessionStat.score > 0)
    {
      return true
    }
    else
    {
      return false
    }
  }

  return false
}

function battle_is_tutorial_for_player(numBattlesPlayed) {
  local game_settings = ::get_game_settings_blk()

  if (game_settings == null || game_settings.newPlayersBattlesExp == null)
  {
    dagor.debug("ERROR: game_settings config broken. game_settings.newPlayersBattlesExp do not exist")
    return false
  }

  local tutorial_end_battle = game_settings.newPlayersBattlesExp.getInt("tutorial_end_battle", 0)

  if (numBattlesPlayed+1 >= tutorial_end_battle)
    return false

  dagor.debug("battle_is_tutorial_for_player - tutorial_end_battle:"+tutorial_end_battle+", numBattlesPlayed:"+numBattlesPlayed)

  return true
}

function on_battle_finished_tutorial(param) {
  local diff = param.diff
  local userId = param.userId
  local unit_list = param.aircrafts
  local ws_cost = ::get_wpcost_blk()
  local game_settings = ::get_game_settings_blk()
  local numBattles = ::get_played_sessions_count(userId)

  if (game_settings == null || game_settings.newPlayersBattlesExp == null)
  {
    dagor.debug("ERROR: game_settings config broken. game_settings.newPlayersBattlesExp do not exist")
    return 0
  }

  local battle_mod = game_settings.newPlayersBattlesExp.getInt("battle_mod", 2)
  local battle_unit = game_settings.newPlayersBattlesExp.getInt("battle_unit", 3)

  dagor.debug("on_battle_finished_tutorial started: battle played(this one not included) = "+numBattles+", battle_mod "+battle_mod+", battle_unit "+battle_unit)

  if (!battle_is_tutorial_for_player(numBattles))
    return 0

  if (!player_was_active_in_session(userId))
  {
    dagor.debug("on_battle_finished_tutorial. player was not active in mission")
    return 0
  }

  local custBlk = ::get_es_custom_blk(userId)
  local lastBattleAwarded = 0
  if (custBlk.lastBattleAwarded != null)
    lastBattleAwarded = custBlk.lastBattleAwarded

  if (lastBattleAwarded >= numBattles+1)
  {
    dagor.debug("on_battle_finished_tutorial. detected double attempt tutorial award")
    return 0
  }

  custBlk.lastBattleAwarded = numBattles+1

  local best_unit_name = ""
  local best_unit_bt = -1

  if (numBattles+1 == battle_mod)
  {
    foreach (unit_table in unit_list)
      if (ws_cost[unit_table.airname] != null)
      {
        dagor.debug("on_battle_finished_tutorial. "+unit_table.airname+" "+unit_table.battleTime)

        if ((ws_cost[unit_table.airname].costGold == null || ws_cost[unit_table.airname].costGold == 0) &&
            !ws_cost[unit_table.airname].premPackAir && best_unit_bt < unit_table.battleTime)
        {
          best_unit_name = unit_table.airname
          best_unit_bt = unit_table.battleTime
        }

      }

    dagor.debug("on_battle_finished_tutorial. best air is "+best_unit_name)
  }

  local coef = 0.0

  if (numBattles > 0)
  {
    foreach (unit_table in unit_list)
      if (ws_cost[unit_table.airname] != null)
      {
        if (best_unit_name == "")
          best_unit_name = unit_table.airname

        if (numBattles+1 == battle_mod && best_unit_name == unit_table.airname)
          coef = 1.0
        else
        if (ws_cost[unit_table.airname].costGold > 0 && !ws_cost[unit_table.airname].isFirstBattleAward)
          coef = 0.025
        else
          coef = 0.3

        add_unit_module_exp(userId, unit_table.airname, coef)
        dagor.debug("on_battle_finished_tutorial. Add "+(coef*100).tostring()+"% from max RP to current module research for "+unit_table.airname+" costGold "+
                     ws_cost[unit_table.airname].costGold+" isFirstBattleAward "+ws_cost[unit_table.airname].isFirstBattleAward)
      }

      if (numBattles+1 == battle_unit)
        coef = 1.0
      else
        coef = 0.3
  }

  if (coef > 0 && ws_cost[best_unit_name] != null)
  {
    add_unit_exp(userId, best_unit_name, coef)
    dagor.debug("on_battle_finished_tutorial. Add "+(coef*100).tostring()+"% from max RP to current unit research. Country and unit_type have been chosen from "+best_unit_name)
  }
  else
    dagor.debug("on_battle_finished_tutorial. expWasNotAdded. coef "+coef+", best_unit_name "+best_unit_name)
}
dagor.debug("tutorialAwards script loaded")