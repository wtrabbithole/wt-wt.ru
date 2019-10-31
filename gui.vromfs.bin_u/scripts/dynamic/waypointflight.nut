missionGenFunctions.append( function (isFreeFlight)
{
  if (!isFreeFlight){return}

  ::mgBeginMission("gameData/missions/dynamic_campaign/objectives/free_flight_preset01.blk");
  local startHeight = ::rndRange(1500, 3000);
  local startPos = ::mgCreateStartPoint(startHeight);

  ::mgSetDistToAction(10000);
  ::mgSetupAirfield(startPos, 1000);

  local ws = ::get_warpoints_blk();
  local wpMax = ws.dynPlanesMaxCost;
  local startLookAt = ::mgCreateStartLookAt();
  local playerFighterPlane = ::getAnyPlayerFighter(0, wpMax);
  if (playerFighterPlane == "")
    return;

  local playerSpeed = ::getDistancePerMinute(playerFighterPlane);

  ::waypointFlightWpHeightNext <- 0;
  ::waypointFlightWpHeight <- startHeight;


  local maxWpOnSpeed = 9;
  local maxTimeOnSpeed = 40;
  if (playerSpeed > 7000){maxWpOnSpeed = 7; maxTimeOnSpeed = 35}
  if (playerSpeed > 10000){maxWpOnSpeed = 5; maxTimeOnSpeed = 30}

  local wpDist = playerSpeed*1.0/60;

  wpMax = ::rndRangeInt(4,maxWpOnSpeed);

  ::mgSetInt("variables/wp_max", wpMax);

  ::wpHeightCalc <- function()
  {
    ::waypointFlightWpHeightNext = ::rndRange(-1000, 1000);
    ::waypointFlightWpHeight = ::waypointFlightWpHeight+::waypointFlightWpHeightNext;
    if (::waypointFlightWpHeight < 1000)
    {
      ::waypointFlightWpHeight = ::waypointFlightWpHeight-::waypointFlightWpHeightNext;
      ::waypointFlightWpHeightNext = ::rndRange(0, 1000);
      ::waypointFlightWpHeight = ::waypointFlightWpHeight+::waypointFlightWpHeightNext;
    }
  }

  local lastWp = "";
  local secondToLastWp = "";




  ::mgSetupArea("waypoint01", startPos, startLookAt, 180+::rndRange(-60,60), wpDist*maxTimeOnSpeed,
              0);
  wpHeightCalc();
  ::mgSetupArea("waypoint02", "waypoint01", startPos, ::rndRange(-60,60), -wpDist*::rndRange(10,maxTimeOnSpeed),
              waypointFlightWpHeightNext);
  wpHeightCalc();

  local offsetPoints = [startPos, "waypoint01", "waypoint02"];

  for (local j = 2; j<10; j++)
  {
    if (wpMax > j){
      ::mgSetupArea("waypoint0"+(j+1), "waypoint0"+j, "waypoint0"+(j-1), ::rndRange(-60,60),
                  -wpDist*::rndRange(10,maxTimeOnSpeed), waypointFlightWpHeightNext);
      wpHeightCalc();
      offsetPoints.append("waypoint0"+(j+1));
      lastWp = "waypoint0"+(j+1);
      secondToLastWp = "waypoint0"+j;
    } else ::mgRemoveStrParam("mission_settings/briefing/part", "waypoint0"+(j+1));
  }

  ::mgSetupArea("evac", lastWp, secondToLastWp, ::rndRange(-60,60),
              -wpDist*maxTimeOnSpeed, waypointFlightWpHeightNext);

  offsetPoints.append("evac");
  ::mgEnsurePointsInMap(offsetPoints);

  ::mgSetupArea("evac_forCut", "evac", lastWp, 0, 2000, 0);


  ::mgSetupArmada("#player.any", startPos, Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane);
  ::mgSetupArmada("#player_cut.any", startPos, Point3(0, 0, 0), "waypoint01", "", 4, 4, playerFighterPlane);
  ::gmMarkCutsceneArmadaLooksLike("#player_cut.any", "#player.any");

  ::mgSetInt("mission_settings/mission/wpAward", 0);

 local sector = ::mgGetMissionSector();
 local level = ::mgGetLevelName();

 local player_plane_name = "";
 local enemy_plane_name = "";
 if (playerFighterPlane != "")
 {
   player_plane_name = ::mgUnitClassFromDescription(playerFighterPlane);
 }
 else
   return;

 ::mgSetMinMaxAircrafts("player", "", 1, 8)

 ::slidesReplace(level, sector, player_plane_name, enemy_plane_name, "none");

//  mgDebugDump("E:/dagor2/skyquake/develop/gameBase/gameData/missions/dynamic_campaign/objectives/test_wpFlight_temp.blk");
  if (::mgFullLogs())
    dagor.debug_dump_stack();

  ::mgAcceptMission();
}
);
