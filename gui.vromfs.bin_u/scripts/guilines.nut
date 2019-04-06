/* guiBox API
  isIntersect(box)      - (bool) return true if box intersect current

  addBox(box)           - modify current box to minimal size which contains both boxes
  cutBox(boxToCutFrom)  - return array of boxes which fill full empty space of boxToCutFrom not intersect with current
                          return null when no intersections with boxToCutFrom
                          return empty array when boxToCutFrom completely inside current box

  incSize(kAdd, kMul)   - increase box size around
  setFromDaguiObj(obj)  - set size and pos from dagui object params
  cloneBox(incSize = 0) - clones box. can increase new box size when incSize != 0
  getBlkText(tag)       - generate text with this tag for replaceContentFromText in guiScene


  LinesGenerator API
  createLinkLines(links, obstacles, interval = 0, lineWidth = 1, priority = 0)
                     - return { lines = array(::GuiBox), dots0 = array(::Point2), dots1  = array(::Point2)}
                     - links = array([box from, box to])
                     - obstacles = array(::GuiBox)
                     - interval - minimum interval between lines
                     - priority - start priority

  findGoodPos(obj, axis, obstacles, min, max, bestPos = null)   - integer
                     - search good position for dagui object by axis to not intersect with any obstacles
                     - between min and max value
                     - preffered bestPos, but if it null, than middle pos between min and max.
                     - return null when not found any position without intersect something

  getLinkLinesMarkup(config)
                     - config = {
                         startObjContainer - container using for find start's views
                         endObjContainer - container using for find end's views
                         lineInterval - minimal interval between lines
                         lineWidth - width of lines
                         obstacles - list of object (or object id) to view (required) which will be taken into
                         account in the lines generation. in addition to linked objects
                         links = [
                           {
                             start - object (or object id) to view (required)
                             or
                             {
                               obj - object (or object id) to view (required)
                               priority - priority of obstacles from lines_priorities (lines_priorities.TARGET by default)
                             }
                             end - object (or object id) to view (required)
                             or
                              {
                               obj - object (or object id) to view (required)
                               priority - priority of obstacles from lines_priorities (lines_priorities.TEXT by default)
                             }
                           }
                         ]
                       }

  generateLinkLinesMarkup(links, obstacleBoxList, interval = "@helpLineInterval", width = "@helpLineWidth")
                     - links - pairs of boxes which need link
                     - obstacleBoxList - lines will try to come round boxes in this list
                     - interval - minimal interval between lines
                     - width - line width
*/

enum lines_priorities //lines intersect priority
{
  OBSTACLE = 0
  TARGET   = 1,
  LINE     = 2,
  TEXT     = 3,

  MAXIMUM  = 3
}

class ::GuiBox
{
  c1 = null  //[x1, y1]
  c2 = null  //[x2, y2]
  priority = 0
  isToStringForDebug = true

  constructor(_x1 = 0, _y1 = 0, _x2 = 0, _y2 = 0, _priority = 0)
  {
    c1 = [_x1, _y1]
    c2 = [_x2, _y2]
    priority = _priority
  }

  function setFromDaguiObj(obj)
  {
    local size = obj.getSize()
    local pos = obj.getPosRC()
    c1 = [pos[0], pos[1]]
    c2 = [pos[0] + size[0], pos[1] + size[1]]
    return this
  }

  function addBox(box)
  {
    for(local i = 0; i < 2; i++)
    {
      if (box.c1[i] < c1[i])
        c1[i] = box.c1[i]
      if (box.c2[i] > c2[i])
        c2[i] = box.c2[i]
    }
  }

  function _tostring()
  {
    return ::format("GuiBox((%d,%d), (%d,%d)%s)", c1[0], c1[1], c2[0], c2[1],
      priority ? (", priority = " + priority) : "")
  }

  function isIntersect(box)
  {
    return  !(box.c1[0] >= c2[0] || c1[0] >= box.c2[0]
           || box.c1[1] >= c2[1] || c1[1] >= box.c2[1])
  }

  function isInside(box)
  {
    return   (box.c1[0] <= c1[0] && c2[0] <= box.c2[0]
           && box.c1[1] <= c1[1] && c2[1] <= box.c2[1])
  }

  function getIntersectCorner(box)
  {
    if (!isIntersect(box))
      return null

    return ::Point2((box.c2[0] > c1[0]) ? c1[0] : c2[0],
                    (box.c2[1] > c1[1]) ? c1[1] : c2[1])
  }

  function cutBox(box) //return array of boxes cutted from box
  {
    if (!isIntersect(box))
      return null

    local cutList = []
    if (box.c1[0] < c1[0])
      cutList.append(::GuiBox(box.c1[0], box.c1[1], c1[0], box.c2[1]))
    if (box.c2[0] > c2[0])
      cutList.append(::GuiBox(c2[0], box.c1[1], box.c2[0], box.c2[1]))

    local offset1 = ::max(c1[0], box.c1[0])
    local offset2 = ::min(c2[0], box.c2[0])
    if (box.c1[1] < c1[1])
      cutList.append(::GuiBox(offset1, box.c1[1], offset2, c1[1]))
    if (box.c2[1] > c2[1])
      cutList.append(::GuiBox(offset1, c2[1], offset2, box.c2[1]))

    return cutList
  }

  function incPos(inc)
  {
    for(local i=0; i < 2; i++)
    {
      c1[i] += inc[i]
      c2[i] += inc[i]
    }
    return this
  }

  function incSize(kAdd, kMul = 0)
  {
    for(local i=0; i < 2; i++)
    {
      local inc = kAdd
      if (kMul)
        inc += ((c2[i] - c1[i]) * kMul).tointeger()
      if (inc)
      {
        c1[i] -= inc
        c2[i] += inc
      }
    }
    return this
  }

  function cloneBox(incSize = 0)
  {
    return ::GuiBox(c1[0] - incSize, c1[1] - incSize, c2[0] + incSize, c2[1] + incSize)
  }

  function getBlkText(tag)
  {
    return format("%s { size:t='%d, %d'; pos:t='%d, %d'; position:t='absolute' } ", tag, c2[0] - c1[0], c2[1] - c1[1], c1[0], c1[1])
  }
}

function get_help_dot_blk_text(point /*Point2*/, tag = "helpLineDot")
{
  return format("%s { pos:t='%d-0.5w, %d-0.5h'; position:t='absolute' } ", tag, point.x.tointeger(), point.y.tointeger())
}

::LinesGenerator <- {
}

function LinesGenerator::getLinkLinesMarkup(config)
{
  if (!config)
    return ""

  local startObjContainer = ::getTblValue("startObjContainer", config, null)
  if (!checkObj(startObjContainer))
    return ""

  local endObjContainer = ::getTblValue("endObjContainer", config, null)
  if (!checkObj(endObjContainer))
    return ""

  local linksDescription = ::getTblValue("links", config)
  if (!linksDescription)
    return ""

  local boxList = []
  local links = []
  foreach(idx, linkDescriprion in linksDescription)
  {
    local startBlock = ::guiTutor.getBlockFromObjData(linkDescriprion.start, startObjContainer)
    if (!startBlock)
      continue

    startBlock.box.priority = ::getTblValue("priority", linkDescriprion.start, lines_priorities.TEXT)
    boxList.append(startBlock.box)

    local endBlock = ::guiTutor.getBlockFromObjData(linkDescriprion.end, endObjContainer)
    if (!endBlock)
      continue

    endBlock.box.priority = ::getTblValue("priority", linkDescriprion.end, lines_priorities.TARGET)
    boxList.append(endBlock.box)

    links.append([endBlock.box, startBlock.box])
  }

  local lineInterval = config?.lineInterval ?? "@helpLineInterval"
  local lineWidth = ::getTblValue("lineWidth", config, "@helpLineWidth")

  local obstacles = ::getTblValue("obstacles", config, null)
  if (obstacles != null)
    foreach(idx, obstacle in obstacles)
    {
      local obstacleBlock = ::guiTutor.getBlockFromObjData(obstacle, startObjContainer) ||
                                                ::guiTutor.getBlockFromObjData(obstacle, endObjContainer)
      if (!obstacleBlock)
        continue

      obstacleBlock.box.priority = ::getTblValue("priority", obstacle, lines_priorities.OBSTACLE)
      boxList.append(obstacleBlock.box)
    }

  return generateLinkLinesMarkup(links, boxList, lineInterval, lineWidth)
}

function LinesGenerator::generateLinkLinesMarkup(links, obstacleBoxList, interval = "@helpLineInterval", width = "@helpLineWidth")
{
  local guiScene = ::get_cur_gui_scene()
  local lines = createLinkLines(links, obstacleBoxList, guiScene.calcString(interval, null),
                                                 guiScene.calcString(width, null))
  local data = ""
  foreach(box in lines.lines)
    data += box.getBlkText("helpLine")
  foreach(dot in lines.dots0)
    data += ::get_help_dot_blk_text(dot)

  return data
}

function LinesGenerator::createLinkLines(links, obstacles, interval = 0, lineWidth = 1, priority = 0, initial = true)
{
  local res = {
    lines = []
    dots0 = []
    dots1 = []
  }
  if (initial)
  {
    local _links = links
    links = []
    for(local i = _links.len() - 1; i >= 0; i--) //reverse to save order of links generation
      links.append(_links[i])
    local _obstacles = obstacles
    obstacles = []
    for(local i = 0; i < _obstacles.len(); i++)
      if (_obstacles[i].priority >= priority)
        obstacles.append(interval? _obstacles[i].cloneBox(interval) : _obstacles[i])
    checkLinkIntersect(res, links)
  } else
    for(local i = obstacles.len() - 1; i >= 0; i--)
      if (obstacles[i].priority < priority)
        obstacles.remove(i)

  genMonoLines  (res, links, obstacles, interval, lineWidth, priority)
  genDoubleLines(res, links, obstacles, interval, lineWidth, priority)

  //local _timer = ::dagor.getCurTime()
  //dlog("GP: after priority " + priority + ", links " + links.len() + ", obstacles = " + obstacles.len() + ", time = " + (::dagor.getCurTime() - _timer))
  if (links.len() && priority < lines_priorities.MAXIMUM)
  {
    local addRes = ::LinesGenerator.createLinkLines(links, obstacles, interval, lineWidth, priority + 1, false)
    foreach(key in ["lines", "dots0", "dots1"])
      res[key].extend(addRes[key])
  }
  return res
}

function LinesGenerator::checkLinkIntersect(res, links)
{
  for(local i = links.len() - 1; i >= 0; i--)
  {
    local link = links[i]
    local dot = link[1].getIntersectCorner(link[0])
    if (!dot)
      continue

    res.dots0.append(dot)
    res.dots1.append(dot)
    links.remove(i)
  }
  return res
}

function LinesGenerator::genMonoLines(res, links, obstacles, interval, lineWidth, priority)
{
  for(local i = links.len() - 1; i >= 0; i--)
  {
    local link = links[i]
    //find box of available lines
    local checkBox = null
    local axis = 0 //intersection axis
    for(local a = 0; a < 2; a++)
      if ( link[0].c2[a] > link[1].c1[a]
        && link[1].c2[a] > link[0].c1[a])
      {
        axis = a
        checkBox = ::GuiBox()
        checkBox.c1[1-a] = ::min(link[0].c2[1-a], link[1].c2[1-a])
        checkBox.c2[1-a] = ::max(link[0].c1[1-a], link[1].c1[1-a])
        checkBox.c1[a] = ::max(link[0].c1[a], link[1].c1[a])
        checkBox.c2[a] = ::min(link[0].c2[a], link[1].c2[a])
        break
      }
    if (!checkBox)
      continue

    //count available diapasons array by obstacles
    local diapason = monoLineCountDiapason(link, checkBox, axis, obstacles)
    if (!diapason || !diapason.len())
      continue

    //search best position from available diapasons array
    local pos = monoLineGetBestPos(diapason, checkBox, axis, lineWidth)
    if (pos == null)
      continue

    //add lines and dots
    checkBox.c1[axis] = pos
    checkBox.c2[axis] = pos + lineWidth
    res.lines.append(checkBox)
    addLinesBoxes(obstacles, [checkBox], priority, interval)

    local dotPos = pos + (0.5 * lineWidth).tointeger()
    local dot0 = getP2byAxisCoords(axis, dotPos, checkBox.c1[1-axis])
    local dot1 = getP2byAxisCoords(axis, dotPos, checkBox.c2[1-axis])
    local invertDots = link[0].c1[1-axis] > link[1].c1[1-axis]
    res.dots0.append(invertDots? dot1 : dot0)
    res.dots1.append(invertDots? dot0 : dot1)
    links.remove(i)
  }
  return res
}

function LinesGenerator::monoLineCountDiapason(link, checkBox, axis, obstacles)
{
  //check obstacles to get available diapaosn of line variants
  local diapason = [[checkBox.c1[axis], checkBox.c2[axis]]]
  for(local j = obstacles.len() - 1; j >= 0; j--)
  {
    local box = obstacles[j]
    if (!box.isIntersect(checkBox))
      continue
    if (link && (link[0].isInside(box) || link[1].isInside(box)))
      continue

    if (box.c1[axis] < checkBox.c1[axis] && box.c2[axis] > checkBox.c2[axis])
    {
      diapason = null
      break
    }

    local found = false
    local start = box.c1[axis]
    local end = box.c2[axis]
    for(local d = diapason.len() - 1; d >= 0; d--)
    {
      local segment = diapason[d]
      if (segment[1] < start)
        break
      if (!found && segment[0] > end)
        continue

      diapason.remove(d)
      if (!found && segment[1] > end)
        diapason.insert(d, [end + 1, segment[1]])
      found = true

      if (segment[0] < start)
      {
        diapason.insert(d, [segment[0], start - 1])
        break
      }
    }
  }
  return diapason
}

function LinesGenerator::monoLineGetBestPos(diapason, checkBox, axis, lineWidth, bestPos = null) //return null -> not found
{
  if (bestPos == null)
    bestPos = ((checkBox.c1[axis] + checkBox.c2[axis] - lineWidth) / 2).tointeger()

  local found = false
  local pos = 0
  for(local d = diapason.len() - 1; d >= 0; d--)
  {
    local segment = diapason[d]
    if (segment[1] - segment[0] < lineWidth)
      continue

    if (segment[0] > bestPos)
    {
      pos = segment[0]
      found = true
      continue
    }

    local _pos = ::min(bestPos, segment[1] - lineWidth)
    if (!found || (bestPos - _pos) < (pos - bestPos))
      pos = _pos
    found = true
    break
  }
  return found ? pos : null
}

function LinesGenerator::findGoodPos(obj, axis, obstacles, min, max, bestPos = null)
{
  local box = ::GuiBox().setFromDaguiObj(obj)
  local objWidth = box.c2[axis] - box.c1[axis]
  box.c1[axis] = min
  box.c2[axis] = max

  local diapason = monoLineCountDiapason(null, box, axis, obstacles)
  if (diapason && diapason.len())
    return monoLineGetBestPos(diapason, box, axis, objWidth, bestPos)
  return null
}

function LinesGenerator::genDoubleLines(res, links, obstacles, interval, lineWidth, priority)
{
  for(local i = links.len() - 1; i >= 0; i--)
  {
    local link = links[i]
    local zones = doubleLineGetZones(link)

    //apply obstacles to zones diapason
    zones = doubleLineZoneCheckObstacles(zones, link, obstacles)
    if (!zones.len())
      continue

    //sort by corners priority.  left/top corner is the best
    zones.sort(function(a,b)
      {
        if (a.axis != b.axis)
          return a.axis ? 1 : -1
        if (a.wayAxis != b.wayAxis)
          return a.wayAxis? -1 : 1
        if (a.wayAltAxis != b.wayAltAxis)
          return a.wayAltAxis? -1 : 1
        return 0;
      })

    //choose best double Line
    for(local z = 0; z < zones.len(); z++)
    {
      local zoneData = zones[z]
      local lineData = doubleLineChooseBestInZone(zoneData, link, lineWidth)
      if (!lineData)
        continue

      local axis = zoneData.axis
      local box = zoneData.box
      local halfWidth = (0.5 * lineWidth).tointeger()
      local dot0 = getP2byAxisCoords(axis, zoneData.wayAxis? box.c1[axis] : box.c2[axis], lineData[1])
      local dot1 = getP2byAxisCoords(axis, lineData[0], lineData[1])
      local dot2 = getP2byAxisCoords(axis, lineData[0], zoneData.wayAltAxis? box.c2[1-axis] : box.c1[1-axis])

      local linesList = [ getLineBoxByP2(dot0, dot1, lineWidth)
                          getLineBoxByP2(dot1, dot2, lineWidth)
                        ]
      res.lines.extend(linesList)
      addLinesBoxes(obstacles, linesList, priority, interval)

      dot0.x += halfWidth
      dot0.y += halfWidth
      dot2.x += halfWidth
      dot2.y += halfWidth
      res.dots0.append(dot0)
      res.dots1.append(dot2)
      links.remove(i)
      break
    }
  }
  return res
}

function LinesGenerator::doubleLineGetZones(link)
{
  local zones = []  //list of available zones for double line
                    //{ box, zone, axis, wayAxis, wayAltAxis }
  for(local j = 0; j < 2; j++) //check all variants, but here can be only 2
  {
    if (link[0].c1[j] > link[1].c1[j])  //main way left/top
    {
      if (link[0].c1[1-j] < link[1].c1[1-j]) //alt way bottom / right
        zones.append({
          box = getBoxByAxis(j, link[1].c1[j], link[0].c1[j], link[0].c1[1-j], link[1].c1[1-j])
          zone = [{ start = link[1].c1[j]
                    end   = ::min(link[0].c1[j],   link[1].c2[j])
                    diapason = [[link[0].c1[1-j], ::min(link[1].c1[1-j], link[0].c2[1-j])]]
                 }]
          axis = j
          wayAxis = false
          wayAltAxis = true
        })
      if (link[0].c2[1-j] > link[1].c2[1-j])  //alt way top / left
        zones.append({
          box = getBoxByAxis(j, link[1].c1[j], link[0].c1[j], link[1].c2[1-j], link[0].c2[1-j])
          zone = [{ start = link[1].c1[j]
                    end   = ::min(link[0].c1[j],   link[1].c2[j])
                    diapason = [[::max(link[1].c2[1-j], link[0].c1[1-j]), link[0].c2[1-j]]]
                 }]
          axis = j
          wayAxis = false
          wayAltAxis = false
        })
    }
    if (link[0].c2[j] < link[1].c2[j])  //main way right / bottom
    {
      if (link[0].c1[1-j] < link[1].c1[1-j])  //alt way bottom / right
        zones.append({
          box = getBoxByAxis(j, link[0].c2[j], link[1].c2[j], link[0].c1[1-j], link[1].c1[1-j])
          zone = [{ start = ::max(link[0].c2[j], link[1].c1[j])
                    end   = link[1].c2[j]
                    diapason = [[link[0].c1[1-j], ::min(link[1].c1[1-j], link[0].c2[1-j])]]
                 }]
          axis = j
          wayAxis = true
          wayAltAxis = true
        })
      if (link[0].c2[1-j] > link[1].c2[1-j]) //alt way top / left
        zones.append({
          box = getBoxByAxis(j, link[0].c2[j], link[1].c2[j], link[1].c2[1-j], link[0].c2[1-j])
          zone = [{ start = ::max(link[0].c2[j], link[1].c1[j])
                    end   = link[1].c2[j]
                    diapason = [[::max(link[1].c2[1-j], link[0].c1[1-j]), link[0].c2[1-j]]]
                 }]
          axis = j
          wayAxis = true
          wayAltAxis = false
        })
    }
  }
  return zones
}

function LinesGenerator::doubleLineZoneCheckObstacles(zones, link, obstacles)
{
  for(local o = obstacles.len() - 1; o >= 0; o--)
  {
    local box = obstacles[o]
    for(local z = zones.len() - 1; z >= 0; z--)
    {
      local zoneData = zones[z]
      if (!box.isIntersect(zoneData.box))
        continue

      local axis = zoneData.axis
      if (link[0].isInside(box) || link[1].isInside(box))
        continue //ignore boxes intersect and full override this side

      local count = doubleLineCutZoneList(zoneData, box)
      if (!count)
        zones.remove(z)
    }
    if (!zones.len())
      break
  }
  return zones
}

function LinesGenerator::doubleLineCutZoneList(zoneData, box)
{
  local axis = zoneData.axis
  local zoneList = zoneData.zone
  local wayAxis = zoneData.wayAxis
  local wayAltAxis = zoneData.wayAltAxis

  local beforeZone = true
  local afterZone = false
  local zStart = box.c1[axis]
  local zEnd   = box.c2[axis]
  local dStart = box.c1[1-axis]
  local dEnd   = box.c2[1-axis]
  for(local z = zoneList.len() - 1; z >= 0; z--)
  {
    local zone = zoneList[z]
    if (zone.end > zEnd && zone.start < zEnd)
    {
      local newZone = cloneDoubleLineZone(zone)
      zone.end = zEnd
      newZone.start = zEnd + 1
      zoneList.insert(++z, newZone)
      zone = newZone
    } else if (zone.end > zStart && zone.start < zStart)
    {
      local newZone = cloneDoubleLineZone(zone)
      zone.end = zStart - 1
      newZone.start = zStart
      zoneList.insert(++z, newZone)
      zone = newZone
    }

    if ((!wayAxis && zone.start > zEnd)
        || (wayAxis && zone.end < zStart))
      continue //inside corners not blocked by box

    local found = false
    local diapason = zone.diapason
    local zoneFree = zone.start >= zEnd || zone.end <= zStart
    for(local d = diapason.len() - 1; d >= 0; d--)
    {
      local segment = diapason[d]
      if (segment[1] < dStart)
        if (!zoneFree && wayAltAxis)
        {
          diapason.remove(d)
          continue
        } else
          break

      if (!found && segment[0] > dEnd)
      {
        if (!zoneFree && !wayAltAxis)
          diapason.remove(d)
        continue
      }

      diapason.remove(d)
      if ((zoneFree || wayAltAxis) && !found && segment[1] > dEnd)
        diapason.insert(d, [dEnd + 1, segment[1]])
      found = true

      if ((zoneFree || !wayAltAxis) && segment[0] < dStart)
      {
        diapason.insert(d, [segment[0], dStart - 1])
        break
      }
    }
    if (!diapason.len())
      zoneList.remove(z)
  }
  return zoneList.len()
}

function LinesGenerator::doubleLineChooseBestInZone(zoneData, link, lineWidth)
{
  local axis = zoneData.axis
  local bestPos =    ((link[1].c1[axis] + link[1].c2[axis] - lineWidth) / 2).tointeger()
  local altBestPos = ((link[0].c1[1-axis] + link[0].c2[1-axis] - lineWidth) / 2).tointeger()
  local found = false
  local posAxis = 0
  local posAltAxis = 0
  local bestDiff = 0
  for(local z = zoneData.zone.len() - 1; z >= 0; z--)
  {
    local zone = zoneData.zone[z]
    if (zone.end - zone.start < lineWidth)
      continue

    local _posAxis = (zone.start > bestPos)? zone.start : ::min(bestPos, zone.end - lineWidth)
    local _posAltAxis = 0
    local dFound = false
    local diapason = zone.diapason
    for(local d = diapason.len() - 1; d >= 0; d--)
    {
      local segment = diapason[d]
      if (segment[1] - segment[0] < lineWidth)
        continue

      if (segment[0] > altBestPos)
      {
        _posAltAxis = segment[0]
        dFound = true
        continue
      }

      local _dpos = ::min(altBestPos, segment[1] - lineWidth)
      if (!dFound || (altBestPos - _dpos) < (_posAltAxis - altBestPos))
        _posAltAxis = _dpos
      dFound = true
      break
    }

    if (!dFound)
      continue

    local _bestDiff = abs(_posAxis - bestPos) + abs(_posAltAxis - altBestPos)
    if (!found || _bestDiff < bestDiff)
    {
      found = true
      bestDiff = _bestDiff
      posAxis = _posAxis
      posAltAxis = _posAltAxis
      if (bestDiff == 0)
        break
    }
  }
  if (found)
    return [posAxis, posAltAxis]
  return null
}

function LinesGenerator::cloneDoubleLineZone(zone)
{
  local diapason = []
  foreach(d in zone.diapason)
    diapason.append([d[0], d[1]])
  return {
    start = zone.start
    end = zone.end
    diapason = diapason
  }
}

function LinesGenerator::addLinesBoxes(obstacles, linesBoxes, priority, interval)
{
  if (priority > lines_priorities.LINE)
    return

  foreach(box in linesBoxes)
  {
    local newBox = interval ? box.cloneBox(interval) : box
    newBox.priority = lines_priorities.LINE
    obstacles.append(newBox)
  }
}

function LinesGenerator::getP2byAxisCoords(axis, axisValue, altAxisValue)
{
  return ::Point2(axis? altAxisValue : axisValue, axis? axisValue : altAxisValue)
}

function LinesGenerator::getBoxByAxis(axisIdx, axis0, axis1, altAxis0, altAxis1)
{
  if (axisIdx)
    return ::GuiBox(altAxis0, axis0, altAxis1, axis1)
  return ::GuiBox(axis0, altAxis0, axis1, altAxis1)
}

function LinesGenerator::getLineBoxByP2(dot1, dot2, lineWidth)
{
  return ::GuiBox(::min(dot1.x, dot2.x), ::min(dot1.y, dot2.y),
                  ::max(dot1.x, dot2.x) + ((dot1.x == dot2.x)? lineWidth : 0),
                  ::max(dot1.y, dot2.y) + ((dot1.y == dot2.y)? lineWidth : 0))
}
