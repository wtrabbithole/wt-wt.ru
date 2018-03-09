function battle_royale_time_award_wp(avgBattleTime, avgbattleTimeAward, playerAliveTime) {
  local awardTime = playerAliveTime
  local econWpBlk = get_economy_config_block("warpoints")
  
  local commonAwardPerSec = (avgBattleTime > 0 ? (avgbattleTimeAward.tofloat() / avgBattleTime.tofloat()) : 0)
  local baseBattleTimeMul = awardTime > 0 ? econWpBlk.getReal("baseBattleTimeMul", 0.0) : 0.0
  dagor.debug("battle_royale_time_award_wp step 1. commonAwardPerSec "+commonAwardPerSec+" avgBattleTime "+avgBattleTime+" avgbattleTimeAward "+avgbattleTimeAward)

  local battleRoyaleTimeAward = econWpBlk.getReal("battleRoyaleTimeAward_wp", 0.0)

  local award = commonAwardPerSec * battleRoyaleTimeAward * awardTime + baseBattleTimeMul * avgbattleTimeAward
  dagor.debug("battle_royale_time_award_wp. award: "+award+" battleRoyaleTimeAward "+battleRoyaleTimeAward+" award time "+awardTime+" baseBattleTimeMul "+baseBattleTimeMul+" avgbattleTimeAward "+avgbattleTimeAward)


  return award
}

function battle_royale_award_mul(success, award_str) {
  local ws = ::get_warpoints_blk()
  local econBlk = award_str == "wp" ? get_economy_config_block("warpoints") : get_economy_config_block("ranks")

  local winK = award_str == "wp" ? ws.getReal("winK", 0.0) : 1.0
  local mul = winK
  local battleResultMul = 0.0

  if (success)
  {
    local alive = battle_royale_active_players.tofloat()
    local total = battle_royale_total_players.tofloat()
    local econCommonBlk = get_economy_config_block("common")
    local maxPlayersNumMul = econCommonBlk.getInt("ffaMaxPlayersNumMul", 0)
    local playersNumMul = (alive > 0) ? total / alive : 0.0
    playersNumMul = ::min(playersNumMul, maxPlayersNumMul)

    mul *= playersNumMul
    dagor.debug("battle_royale_award_mul "+award_str+" - step 1. mul = "+mul+" alive players: "+alive+" total players "+total+" playersNumMul "+playersNumMul+" winK "+winK)

    battleResultMul = econBlk.getReal("ffaWinK_"+award_str, 0.0)
  }
  else
  {
    battleResultMul = econBlk.getReal("ffaLoseK_"+award_str, 0.0)
  }

  mul *= battleResultMul

  dagor.debug("battle_royale_award_mul "+award_str+". mul = "+mul+" battleResultMul "+battleResultMul+" success "+success)
  return mul
}

function battle_royale_open_unlock_for_user(userId, position, isWinner = false) {
  local econCommonBlk = get_economy_config_block("common")
  local streaks_blk = econCommonBlk["ffa_streaks_awards"]
  if (!streaks_blk) {
    dagor.debug("[ERROR] economy.blk common config is broken! missing ffa_streaks_awards block")
    return
  }
  local minPlayersForAward = streaks_blk.getInt("minPlayersForAward", 64)

  if (battle_royale_total_players < minPlayersForAward) {
    dagor.debug("battle_royale_open_unlock_for_user. Not enough players for award: "+battle_royale_total_players+". Should be at least "+minPlayersForAward)
    return
  }
  local unlockForPosition = null

  if (isWinner && streaks_blk["winner"]) {
    unlockForPosition = streaks_blk["winner"]
  }
  else if (streaks_blk["place_"+position]) {
    unlockForPosition = streaks_blk["place_"+position]
  }
  else return

  open_unlock_for_user(userId, unlockForPosition)
  dagor.debug("battle_royale_open_unlock_for_user user: "+userId+" position "+position+" unlock name "+unlockForPosition+" win? "+isWinner)

}
dagor.debug("battleRoyaleAwards script loaded")