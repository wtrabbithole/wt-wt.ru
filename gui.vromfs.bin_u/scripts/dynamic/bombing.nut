function _generateBombingMission(isFreeFlight, ground_type, createGroundUnitsProc)
{
  local mission_preset_name = "bombing_preset01";
  ::mgBeginMission("gameData/missions/dynamic_campaign/objectives/"+mission_preset_name+".blk");
  local playerSide = ::mgGetPlayerSide();
  local enemySide = ::mgGetEnemySide();
  local bombtargets = createGroundUnitsProc(enemySide);

  local enemy1Angle = ::rndRange(-90, 90);
  local enemy2Angle = ::rndRange(-90, 90);
  local evacAngle = ::rndRange(-10, 10);
  local bombersCountMin = 0;
  local bombersCountMax = 0;
  local indicator_icon = "";

//planes selection
  local playerBomberPlane = "";

//planes cost and warpoint ratio calculate
  local wpMax = 1000000;
  local allyFighterPlane = ::getAnyFighter(playerSide, 0, wpMax);
  local allyFighterPlaneCost = ::getAircraftCost(allyFighterPlane);
  if (allyFighterPlaneCost == 0)
    allyFighterPlaneCost = 250;

  local enemyFighterPlane = ::getEnemyPlaneByWpCost(allyFighterPlaneCost, enemySide);
  local enemyPlaneCost = ::getAircraftCost(enemyFighterPlane);
  if (enemyPlaneCost == 0)
    enemyPlaneCost = 250;

  local planeCost = ::planeCostCalculate(allyFighterPlaneCost, enemyPlaneCost);



//ally bombers count
  local bombTargetsCount = ::mgGetUnitsCount("#bomb_targets");
  if ( bombtargets == ""  || bombTargetsCount <= 0) {return}

  if (ground_type == "tank" || ground_type == "building")
  {
    bombersCountMin = 1*(bombTargetsCount)-4;
    bombersCountMax = 3*(bombTargetsCount)-4;
    playerBomberPlane = ::getAircraftDescription(playerSide, "bomber", ["bomber"],
                                               ["antiTankBomb"], true, 0, wpMax);
    indicator_icon = ground_type;
  }
  else if (ground_type == "artillery")
  {
    bombersCountMin = 1*(bombTargetsCount)-4;
    bombersCountMax = 3*(bombTargetsCount)-4;
    playerBomberPlane = ::getAircraftDescription(playerSide, "bomber", ["bomber"],
                                               ["bomb"], true, 0, wpMax);
    indicator_icon = "cannon";
  }
  else if (ground_type == "destroyer")
  {
    bombersCountMin = 4*(bombTargetsCount)-4;
    bombersCountMax = 16*(bombTargetsCount)-4;
    playerBomberPlane = ::getAircraftDescription(playerSide, "bomber", ["bomber"],
                                               ["antiShipBomb"], true, 0, wpMax);
    indicator_icon = "ship";
    ::mgSetBool("variables/is_target_ship", true);
  }
  else if (ground_type == "carrier")
  {
    bombersCountMin = 8*bombTargetsCount-4;
    bombersCountMax = 32*bombTargetsCount-4;
    playerBomberPlane = ::getAircraftDescription(playerSide, "bomber", ["bomber"],
                                               ["antiShipBomb"], true, 0, wpMax);
    indicator_icon = "ship";
    ::mgSetBool("variables/is_target_ship", true);
  }
  else
    return;

  ::mgReplace("mission_settings/briefing/part", "icontype", "carrier", ground_type);
  ::mgReplace("triggers", "icon", "air", indicator_icon);
  ::mgSetInt("variables/count_to_kill", 1);

  if (indicator_icon != "ship")
  {
    ::mgReplace("mission_settings/briefing/part", "target", "target_waypoint_bombers", "#bomb_targets");
    ::mgReplace("mission_settings/briefing/part", "lookAt", "target_waypoint_bombers", "#bomb_targets");
    ::mgReplace("mission_settings/briefing/part", "point", "target_waypoint_bombers", "#bomb_targets");
  }

  if (playerBomberPlane == "" || enemyFighterPlane == "" || allyFighterPlane == "")
    return;


  local  bombersCount = ::rndRangeInt(bombersCountMin, bombersCountMax);
  if (bombersCount < 4)
    bombersCount = 0;
  if (bombersCount > 20)
    bombersCount = 20;


//ally fighters count
  local allyFighterCountMin = (bombersCount/2+2)*planeCost;
  local allyFighterCountMax = (bombersCount+4)*planeCost;
  local allyFightersCount = ::rndRangeInt(allyFighterCountMin, allyFighterCountMax);
  if (allyFightersCount < 4)
    allyFightersCount = 4;
  if (allyFightersCount > 24)
    allyFightersCount = 24;

//enemy fighters count
  local enemyTotalCountMin = (bombersCount*0.5+allyFightersCount+4)*0.5/planeCost;
  local enemyTotalCountMax = (bombersCount+allyFightersCount+4)/planeCost;
  local enemyTotalCount = ::rndRangeInt(enemyTotalCountMin, enemyTotalCountMax);
  if (enemyTotalCount < 8)
    enemyTotalCount = 8;
  if (enemyTotalCount > 44)
    enemyTotalCount = 44;


//wave count
  local enemyWaveCount = 0;
  if (enemyTotalCount < 12)
    enemyWaveCount = 1;
  else if (enemyTotalCount < 24)
    enemyWaveCount = ::rndRangeInt(1,2);
  else
    enemyWaveCount = ::rndRangeInt(2,3);

  local enemyWaveCount_temp = enemyWaveCount;
  local wave1 = 0;
  local wave2 = 0;
  local wave3 = 0;
  local j = 0;

  do
  {
   j = ::rndRangeInt(1,3);
   if (j == 1 && wave1 == 0){wave1 = 1; --enemyWaveCount_temp}
   if (j == 2 && wave2 == 0){wave2 = 1; --enemyWaveCount_temp}
   if (j == 3 && wave3 == 0){wave3 = 1; --enemyWaveCount_temp}
  }   while (enemyWaveCount_temp > 0)

//enemy planes in each wave
  local enemyTotalCount_temp = enemyTotalCount;
  enemyWaveCount_temp = enemyWaveCount;

  local enemyPlanesInWave = enemyTotalCount_temp/enemyWaveCount_temp;
  local enemy1Count = 0;
  local enemy2Count = 0;
  local enemy3Count = 0;



  if (wave1 == 1)
  {
    enemy1Count = enemyPlanesInWave*::rndRange(2/3.0,3/2.0);
    if (enemy1Count < 4)
      enemy1Count = 4
    enemyTotalCount_temp = enemyTotalCount_temp - enemy1Count;
    enemyWaveCount_temp = enemyWaveCount_temp - 1;
  }
  if (wave2 == 1 && enemyWaveCount_temp > 0)
  {
    enemy2Count = enemyTotalCount_temp/(enemyWaveCount_temp)*::rndRange(2/3.0,3/2.0);
    if (enemy2Count < 4)
      enemy2Count = 4
    enemyTotalCount_temp = enemyTotalCount_temp - enemy2Count;
  }
  if (wave3 == 1 && enemyWaveCount_temp > 0)
  {
    enemy3Count = enemyTotalCount_temp;
    if (enemy3Count < 4)
      enemy3Count = 4
  }

//speed and distance
  local playerSpeed = 300*1000/60.0;
  local enemy1Speed = ::getDistancePerMinute(enemyFighterPlane);
  local enemy2Speed = ::getDistancePerMinute(enemyFighterPlane);
  local enemy3Speed = ::getDistancePerMinute(enemyFighterPlane);

  local timeToTarget = ::rndRange(120 + wave1*45 + wave2*45, 120 + wave1*60 + wave2*60)/60.0;
  local timeToEvac = ::rndRange(90+wave3*60, 90+wave3*90)/60.0;
  local timeToEnemy1 = 0;
  if (wave1 == 1)
    timeToEnemy1 = ::rndRange(30, timeToTarget*60/4.0)/60.0;
  local timeToEnemy2 = ::rndRange(30+timeToEnemy1*30, timeToTarget*60/4.0+timeToEnemy1*60)/60.0;
  local timeToEnemy3 = ::rndRange(30, 60)/60.0;

  local rndHeight = ::rndRange(2000, 4000);

  if (timeToTarget > timeToEvac)
    ::mgSetDistToAction(playerSpeed*timeToTarget+2000);
  else
    ::mgSetDistToAction(playerSpeed*timeToEvac+2000);

  ::mgSetupAirfield(bombtargets, playerSpeed*timeToTarget+3000);
  local startLookAt = ::mgCreateStartLookAt();


//areas setup`
  ::mgSetupArea("player_start", bombtargets, startLookAt, 180, playerSpeed*timeToTarget, rndHeight);
  ::mgSetupArea("target_waypoint_bombers", bombtargets, "", 0, 0, rndHeight);
  ::mgSetupArea("target_waypoint_fighters", bombtargets, "", 0, 0, rndHeight+500);
  ::mgSetupArea("evac", bombtargets, "player_start", evacAngle, playerSpeed*timeToEvac+3000, 1000);
  ::mgSetupArea("evac_forCut", "evac", bombtargets, 0,
              2000, 1000);
  ::mgSetupArea("ally_evac", bombtargets, "player_start", evacAngle, 90000, 1000);
  ::mgSetupArea("enemy_evac", bombtargets, "player_start", evacAngle-180, 90000, 1000);

  ::mgSetupArea("enemy1_pointToFight", "player_start", bombtargets, 0,
              playerSpeed*timeToEnemy1, rndHeight+::rndRange(0,2000));
  ::mgSetupArea("enemy1_start", "enemy1_pointToFight", bombtargets, enemy1Angle,
              enemy1Speed*timeToEnemy1, 0);

  ::mgSetupArea("enemy2_pointToFight", "enemy1_pointToFight", bombtargets, 0,
              playerSpeed*timeToEnemy2, rndHeight+::rndRange(0,2000));
  ::mgSetupArea("enemy2_start", "enemy2_pointToFight", bombtargets, enemy2Angle,
              enemy2Speed*timeToEnemy2, 0);

  ::mgSetupArea("enemy3_start", bombtargets, "player_start", 180,
              enemy3Speed*timeToEnemy3, rndHeight+::rndRange(0,2000));



//player and ally armada setup
  ::mgSetupArmada("#player.bomber", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerBomberPlane);
  ::mgSetupArmada("#player_cut.any", "player_start", Point3(0, 0, 0), bombtargets, "", 4, 4, playerBomberPlane);
  ::gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.bomber");



  ::mgSetupArmada("#ally01.bomber", "player_start", Point3(1000, -300, 0), bombtargets,
                "#ally_bombers_group", bombersCount, bombersCount, playerBomberPlane);

  ::mgSetupArmada("#ally02.fighter", "player_start", Point3(500, 500, 0), bombtargets,
                "#ally_fighters_group", allyFightersCount, allyFightersCount, allyFighterPlane);




//enemy armada setup
  if (wave1 == 1)
    ::mgSetupArmada("#enemy01.fighter", "enemy1_start", Point3(0, 0, 0), "#player.bomber",
                  "#enemy_fighters_group01", enemy1Count, enemy1Count, enemyFighterPlane);
  if (wave2 == 1)
  {
    ::mgSetupArmada("#enemy02.fighter", "enemy2_start", Point3(0, 0, 0), "#player.bomber",
                  "#enemy_fighters_group02", enemy2Count, enemy2Count, enemyFighterPlane);
    ::mgSetInt("variables/enemy2_time", timeToEnemy1*60);
  }
  if (wave3 == 1)
    ::mgSetupArmada("#enemy03.fighter", "enemy3_start", Point3(0, 0, 0), "#player.bomber",
                  "#enemy_fighters_group03", enemy3Count, enemy3Count, enemyFighterPlane);


  ::mgSetMinMaxAircrafts("player", "", 1, 8);
  ::mgSetMinMaxAircrafts("ally", "fighter", 0, 24);
  ::mgSetMinMaxAircrafts("ally", "bomber", 0, 20);
  ::mgSetMinMaxAircrafts("enemy", "fighter", 0, 44);

//mission warpoint cost calculate
  local mission_mult = ::sqrt(enemyTotalCount/20.0+0.05);
  local ally_all_count = allyFightersCount + (bombersCount-4)*0.5;
  local missionWpCost = warpointCalculate(mission_preset_name, ally_all_count, enemyTotalCount, 1,
                                          playerBomberPlane, mission_mult);
  ::mgSetInt("mission_settings/mission/wpAward", missionWpCost);
  ::mgSetEffShootingRate(0.1);

  local sector = ::mgGetMissionSector();
  local level = ::mgGetLevelName();

  local player_plane_name = "";
  local enemy_plane_name = "";
  if (playerBomberPlane != "")
  {
    player_plane_name = ::mgUnitClassFromDescription(playerBomberPlane);
  }
  else
    return;

  ::slidesReplace(level, sector, player_plane_name, enemy_plane_name, ground_type);

  ::mgSetBool("variables/training_mode", isFreeFlight);

 //  mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/testBombing_temp.blk");
  if (::mgFullLogs())
    dagor.debug_dump_stack();

   ::mgAcceptMission();
}




missionGenFunctions.append( function(isFreeFlight)
{
   _generateBombingMission (isFreeFlight, "tank", function(enemySide)
     {
       ::mgSetStr("mission_settings/mission/name", "dynamic_bombing_vehicles");
       return ::mgCreateGroundUnits(enemySide,
         false, false,
       {
         heavy_vehicles = "#bomb_targets"
         light_vehicles = "#bomb_target_cover"
         infantry = "#bomb_target_cover"
         air_defence = "#bomb_target_cover"
         anti_tank = "#bomb_target_cover"
         bombtarget = "#bomb_target_cover"
         ships = "#bomb_target_cover"
         carriers = "#bomb_target_cover"
       }

       )
     }
   );
}
);


missionGenFunctions.append( function(isFreeFlight)
{
   _generateBombingMission (isFreeFlight, "artillery", function(enemySide)
     {
       ::mgSetStr("mission_settings/mission/name", "dynamic_bombing_anti_tank");
       return ::mgCreateGroundUnits(enemySide,
         false, false,
       {
         heavy_vehicles = "#bomb_target_cover"
         light_vehicles = "#bomb_target_cover"
         infantry = "#bomb_target_cover"
         air_defence = "#bomb_target_cover"
         anti_tank = "#bomb_targets"
         bombtarget = "#bomb_target_cover"
         ships = "#bomb_target_cover"
         carriers = "#bomb_target_cover"
       }

       )
     }
   );
}
);

missionGenFunctions.append( function(isFreeFlight)
{
   _generateBombingMission (isFreeFlight, "building", function(enemySide)
     {
       ::mgSetStr("mission_settings/mission/name", "dynamic_bombing_buildings");
       return ::mgCreateGroundUnits(enemySide,
         false, false,
       {
         heavy_vehicles = "#bomb_target_cover"
         light_vehicles = "#bomb_target_cover"
         infantry = "#bomb_target_cover"
         air_defence = "#bomb_target_cover"
         anti_tank = "#bomb_target_cover"
         bombtarget = "#bomb_targets"
         ships = "#bomb_target_cover"
         carriers = "#bomb_target_cover"
       }

       )
     }
   );
}
);

missionGenFunctions.append( function(isFreeFlight)
{
   _generateBombingMission (isFreeFlight, "destroyer", function(enemySide)
     {
       ::mgSetStr("mission_settings/mission/name", "dynamic_bombing_ships");
       return ::mgCreateGroundUnits(enemySide,
         false, false,
       {
         heavy_vehicles = "#bomb_target_cover"
         light_vehicles = "#bomb_target_cover"
         infantry = "#bomb_target_cover"
         air_defence = "#bomb_target_cover"
         anti_tank = "#bomb_target_cover"
         bombtarget = "#bomb_target_cover"
         ships = "#bomb_targets"
         carriers = "#bomb_target_cover"
       }

       )
     }
   );
}
);

missionGenFunctions.append( function(isFreeFlight)
{
   _generateBombingMission (isFreeFlight, "carrier", function(enemySide)
     {
       ::mgSetStr("mission_settings/mission/name", "dynamic_bombing_carrier");
       return ::mgCreateGroundUnits(enemySide,
         false, true,
       {
         heavy_vehicles = "#bomb_target_cover"
         light_vehicles = "#bomb_target_cover"
         infantry = "#bomb_target_cover"
         air_defence = "#bomb_target_cover"
         anti_tank = "#bomb_target_cover"
         bombtarget = "#bomb_target_cover"
         ships = "#bomb_target_cover"
         carriers = "#bomb_targets"
       }

       )
     }
   );
}
);
