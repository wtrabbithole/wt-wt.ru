//---- Team spawn score BEGIN ----

//initTeamSpawnScoreFunction
function tss_get_init_score()
{
  return get_spawn_score_param("initial_team_score", 0.0)
}

//updateSpawnScoreFunction
function tss_update_unit_spawn_score(userId, unitname)
{
// no double cost in TSS, do nothing
}

//teamSpawnScoreIncFunction
function tss_spawn_score_inc(unitname)
{
//const multiplier?
  return get_spawn_score_param("team_score_mul", 1.0)
}

//teamSpawnScoreUpdFunction
function tss_spawn_score_upd(unitname, weapon)
{
  //cost of technics without weapon. FIXME: more parameters?
  return get_unit_spawn_score(null, unitname)
}

//---- Team spawn score END ----

dagor.debug("teamSpawnScore script loaded successfully")