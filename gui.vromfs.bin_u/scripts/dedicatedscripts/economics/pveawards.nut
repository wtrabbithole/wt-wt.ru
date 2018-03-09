function get_pve_award(isWon, reward_str, mis, sessionTime, total_flight_time, unit_flight_time, score) {
  local ws = ::get_warpoints_blk()
  local econCommonBlk = get_economy_config_block("common")
  local econ_blk = null
  local award_name = null
  if (reward_str == "Wp")
  {
    econ_blk = get_economy_config_block("warpoints")
    award_name = mis.pveWPAwardName+"Wp"
  }
  else
  {
    econ_blk = get_economy_config_block("ranks")
    award_name = mis.pveXPAwardName+"Exp"
  }
  local missionResultMul = isWon ? econ_blk.getReal(award_name+"Win", 0) : econ_blk.getReal(award_name+"Lose", 0)
  local misRank = mis.ranks.max != null ? mis.ranks.max : 0
  local misRank = mis.ranks != null ? (mis.ranks.max != null ? mis.ranks.max : 0) : 0
  local baseRankAward = econ_blk.getInt("pveUnitRankMultiplier"+reward_str+misRank, 0)

  local award = missionResultMul * baseRankAward
  dagor.debug("get_pve_award "+reward_str+" Step 1. award "+award+" win? "+isWon+" baseMul "+award_name+" "+missionResultMul+" missionRank "+misRank+" baseRankAward "+baseRankAward)

  local unitAwardPart = total_flight_time > 0 ? (unit_flight_time.tofloat() / total_flight_time) : 0
  award *= unitAwardPart
  dagor.debug("get_pve_award "+reward_str+" Step 2. award "+award+" total_flight_time "+total_flight_time+" unit_flight_time "+unit_flight_time+" unit time share "+unitAwardPart)

  local timeAwardMul = 0
  if (isWon)
    timeAwardMul = ws.getInt("pveTimeAwardWin", 0)
  else
  {
    local awardStage = get_pve_time_award_stage(sessionTime)
    if (awardStage > 0)
      timeAwardMul = ws.getInt("pveTimeAwardStage"+awardStage, ws.getInt("pveTimeAwardMaxLose", 0))
  }


  award *= timeAwardMul

  local scoreTime = get_score_time(unit_flight_time, total_flight_time, sessionTime, true)

  local activity_coef = player_activity_coef(score, scoreTime);

  award *= activity_coef
  dagor.debug("get_pve_award "+reward_str+" Step 3. award "+award+" win? "+isWon+" timeAwardMul "+timeAwardMul+" activity_coef "+activity_coef)

  local earlyExitMul = econCommonBlk.getReal("pveEarlyExitMul", 0)
  local minFlightTimeRate = econCommonBlk.getReal("pveMinFlightTimeRate", 0.5)
  local flightTimeRate = sessionTime > 0 ? (total_flight_time / sessionTime) : 0

  if (flightTimeRate < minFlightTimeRate) award *= earlyExitMul

  dagor.debug("get_pve_award "+reward_str+" Step 4. award "+award+" flightTime to sessionTime: "+flightTimeRate+" minFlightTimeRate "+minFlightTimeRate)

  return award
}
dagor.debug("pveAwards script loaded")