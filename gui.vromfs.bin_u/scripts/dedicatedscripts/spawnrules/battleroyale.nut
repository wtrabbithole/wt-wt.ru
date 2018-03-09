//-- mission logic
::battleRoyaleAreaTable <- {}
function gen_sectors_array(len, mod, excludeList)
{
  local sectorsArray = []
  for (local i = mod; i < len + mod; i++)
    for (local j = mod; j < len + mod; j++)
    {
      local sector = "(" + i + "," + j + ")"
      if (excludeList.find(sector) < 0)
        sectorsArray.append(Point2(i,j))
    }

  return sectorsArray
}

function on_set_battle_royale_area(blk, type, radius, curPoint1, curPoint2)
{
  dagor.debug("on_set_battle_royale_area started. current battle area: type " + type +
              ", radius " + radius + ", curPoint1 (" + curPoint1.x + ", " + curPoint1.y +
              "), curPoint2 (" + curPoint2.x + ", " + curPoint2.y + ")")

  if ("runNum" in battleRoyaleAreaTable)
    battleRoyaleAreaTable.runNum++
  else
  {
    battleRoyaleAreaTable.runNum <- 1
    battleRoyaleAreaTable.startPoint1 <- curPoint1
    battleRoyaleAreaTable.startPoint2 <- curPoint2

    local sectorSize = 100
    local areaDiv = blk.getInt("areaDivIntVar", 1)
    if (areaDiv > 25)
      areaDiv = 25
    if (areaDiv > 0)
      sectorSize = (curPoint2.x - curPoint1.x) / areaDiv

    battleRoyaleAreaTable.sectorSize <- sectorSize

    local finalSectorsArray = gen_sectors_array(areaDiv, 1, blk.getStr("finalSectorExcludeStrVar", ""))
    local finalSector = finalSectorsArray[(::math.frnd() * (finalSectorsArray.len() - 0.001)).tointeger()]
    finalSector.x = curPoint1.x + (finalSector.x - 1) * sectorSize
    finalSector.y = curPoint1.y + (finalSector.y - 1) * sectorSize
    battleRoyaleAreaTable.finalSector <- finalSector

    battleRoyaleAreaTable.sidesExclude <- blk.getStr("sideChangeExclude", "(0,0)")

    dagor.debug("on_set_battle_royale_area sectorSize " + battleRoyaleAreaTable.sectorSize +
                ", finalSector (" + finalSector.x + ", " + finalSector.y + ")")
  }

  local newAreaName = "battleRoyaleBattleAreaSetNum" + battleRoyaleAreaTable.runNum
  local sectorSize = battleRoyaleAreaTable.sectorSize
  local warningTime = blk.getInt("warningTimeIntVar", 0)
  local newPoint1 = Point2(0, 0)
  local newPoint2 = Point2(0, 0)
  local finalSector = battleRoyaleAreaTable.finalSector

  local sidesArray = gen_sectors_array(3, -1, battleRoyaleAreaTable.sidesExclude)

  while (sidesArray.len() > 0)
  {
    local side = sidesArray[(::math.frnd() * (sidesArray.len() - 0.001)).tointeger()]
    local canChange = true
    newPoint1.x = curPoint1.x
    newPoint1.y = curPoint1.y
    newPoint2.x = curPoint2.x
    newPoint2.y = curPoint2.y

    if (side.x > 0)
    {
      if (newPoint1.x + side.x > finalSector.x)
        canChange = false
      else
        newPoint1.x += side.x * sectorSize
    }
    else
    if (side.x < 0)
    {
      if (newPoint2.x + side.x < finalSector.x + sectorSize)
        canChange = false
      else
        newPoint2.x += side.x * sectorSize
    }
    if (side.y > 0)
    {
      if (newPoint1.y + side.y > finalSector.y)
        canChange = false
      else
        newPoint1.y += side.y * sectorSize
    }
    else
    if (side.y < 0)
    {
      if (newPoint2.y + side.y < finalSector.y + sectorSize)
        canChange = false
      else
        newPoint2.y += side.y * sectorSize
    }
    if (!canChange)
    {
      battleRoyaleAreaTable.sidesExclude += ";(" + side.x + "," + side.y + ")"
      sidesArray = gen_sectors_array(3, -1, battleRoyaleAreaTable.sidesExclude)
    }
    else
      break
  }

  if (sidesArray.len() == 0)
    newPoint2 = newPoint1

  local reset = blk.getBool("reset", false)
  if (reset)
  {
    newPoint1 = battleRoyaleAreaTable.startPoint1
    newPoint2 = battleRoyaleAreaTable.startPoint2
    warningTime = 0
  }

  dagor.debug("on_set_battle_royale_area next battle area" + newAreaName + ": point1 (" + newPoint1.x +
              ", " + newPoint1.y + "), point2 (" + newPoint2.x + ", " + newPoint2.y + "), warningTime " +
              warningTime + ", reset " + reset)

  local newBattleAreaTable = {
    name = newAreaName
    timer = warningTime
    type = ::AREA_TYPE_BOX
    point1 = newPoint1
    point2 = newPoint2
  }

  return newBattleAreaTable
}

dagor.debug("battleRoyale script loaded")