enum ALIGN
{
  LEFT   = "left"
  TOP    = "top"
  RIGHT  = "right"
  BOTTOM = "bottom"
}

::g_dagui_utils <- {
  textAreaTagsRegexp = [
    regexp2("</?color[^>]*>")
    regexp2("</?link[^>]*>")
    regexp2("</?b>")
  ]
}

/*
* count amount of items can be filled in current obj.
* return table with itemsCount and items sizes in pixels
  {
    itemsCountX, itemsCountY (int)  //min = 1
    sizeX, sizeY, spaceX, spaceY (int)
  }
* parameters^
  * listObj - list of items object
  * sizeX, sizeY - item size in pixels (int) or dagui constant (string)
  * spaceX, spaceY - space between items in pixels (int) or dagui constant (string)
  * reserveX, reserveY - space items in pixels (int) or dagui constant (string) reserved for non-item listObj's elements
*/
function g_dagui_utils::countSizeInItems(listObj, sizeX, sizeY, spaceX, spaceY, reserveX = 0, reserveY = 0)
{
  local res = {
    itemsCountX = 1
    itemsCountY = 1
    sizeX = 0
    sizeY = 0
    spaceX = 0
    spaceY = 0
    reserveX = 0
    reserveY = 0
  }
  if (!::check_obj(listObj))
    return res

  local listSize = listObj.getSize()
  local guiScene = listObj.getScene()
  res.sizeX = toPixels(guiScene, sizeX)
  res.sizeY = toPixels(guiScene, sizeY)
  res.spaceX = toPixels(guiScene, spaceX)
  res.spaceY = toPixels(guiScene, spaceY)
  res.reserveX = toPixels(guiScene, reserveX)
  res.reserveY = toPixels(guiScene, reserveY)
  res.itemsCountX = ::max(1, ((listSize[0] - res.spaceX - res.reserveX) / (res.sizeX + res.spaceX)).tointeger())
  res.itemsCountY = ::max(1, ((listSize[1] - res.spaceY - res.reserveY) / (res.sizeY + res.spaceY)).tointeger())
  return res
}

/**
*  adjust window object size to make listobject size integer amount of items.
   work only when listobject size linear dependent on window object size
*  return table with itemsCount and items sizes in pixels
   {
    itemsCountX, itemsCountY (int) //min = 1
    sizeX, sizeY, spaceX, spaceY (int)
  }
 * parameters:
   * wndObj - window object
   * listObj - list of items object
   * sizeX, sizeY - item size in pixels (int) or dagui constant (string)
   * spaceX, spaceY - space between items in pixels (int) or dagui constant (string)
 */
function g_dagui_utils::adjustWindowSize(wndObj, listObj, sizeX, sizeY, spaceX, spaceY)
{
  local res = countSizeInItems(listObj, sizeX, sizeY, spaceX, spaceY)
  if (!::check_obj(wndObj) || !::check_obj(listObj))
    return res

  local wndSize = wndObj.getSize()
  local listSize = listObj.getSize()

  local wndSizeX = ::min(wndSize[0], wndSize[0] - listSize[0] + (res.spaceX + res.itemsCountX * (res.sizeX + res.spaceX)))
  local wndSizeY = ::min(wndSize[1], wndSize[1] - listSize[1] + (res.spaceY + res.itemsCountY * (res.sizeY + res.spaceY)))
  wndObj.size = ::format("%d, %d", wndSizeX, wndSizeY)
  return res
}

/*
* return pixels (int)
* operations depend on value type^
  * int, float - tointeger()
  * string - calculate string by dagui calculator
*/

function g_dagui_utils::toPixels(guiScene, value, obj = null)
{
  if (::is_numeric(value))
    return value.tointeger()
  if (::u.isString(value))
    return guiScene.calcString(value, obj)
  return 0
}

//remove all textarea tags from @text to made it usable in behaviour:text
function g_dagui_utils::removeTextareaTags(text)
{
  foreach(re in textAreaTagsRegexp)
    text = re.replace("", text)
  return text
}

function g_dagui_utils::color4ToDaguiString(color)
{
  return format("%02X%02X%02X%02X",
    ::clamp(255 * color.a, 0, 255),
    ::clamp(255 * color.r, 0, 255),
    ::clamp(255 * color.g, 0, 255),
    ::clamp(255 * color.b, 0, 255))
}

function g_dagui_utils::daguiStringToColor4(colorStr)
{
  local res = Color4()
  if (!colorStr.len())
    return res
  if (colorStr.slice(0, 1) == "#")
    colorStr = colorStr.slice(1)

  if (colorStr.len() != 8 && colorStr.len() != 6)
    return res

  local colorInt = ::g_string.hexStringToInt(colorStr)
  if (colorStr.len() == 8)
    res.a = ((colorInt & 0xFF000000) >> 24).tofloat() / 255
  res.r = ((colorInt & 0xFF0000) >> 16).tofloat() / 255
  res.g = ((colorInt & 0xFF00) >> 8).tofloat() / 255
  res.b = (colorInt & 0xFF).tofloat() / 255
  return res
}

function g_dagui_utils::multiplyDaguiColorStr(colorStr, multiplier)
{
  return color4ToDaguiString(daguiStringToColor4(colorStr) * multiplier)
}

function g_dagui_utils::setObjPosition(obj, _reqPos, _border)
{
  if (!::check_obj(obj))
    return

  local guiScene = obj.getScene()

  guiScene.applyPendingChanges(true)

  local objSize = obj.getSize()
  local screenSize = [ ::screen_width(), ::screen_height() ]
  local reqPos = [toPixels(guiScene, _reqPos[0], obj), toPixels(guiScene, _reqPos[1], obj)]
  local border = [toPixels(guiScene, _border[0], obj), toPixels(guiScene, _border[1], obj)]

  local posX = ::clamp(reqPos[0], border[0], screenSize[0] - border[0] - objSize[0])
  local posY = ::clamp(reqPos[1], border[1], screenSize[1] - border[1] - objSize[1])

  if (obj.pos != null)
    obj.pos = ::format("%d, %d", posX, posY)
  else
  {
    obj.left = ::format("%d", posX)
    obj.top =  ::format("%d", posY)
  }
}

/**
 * Checks if menu fits in safearea with selected 'align'. If not, selects a better 'align'.
 * Sets menuObj object 'pos' and 'menu_align' properties, the way it fits into safearea,
 * and its 'popup_menu_arrow' points to parentObjOrPos.
 * @param {daguiObj|array(2)|null}  parentObjOrPos - Menu source - dagui object, or position.
 *                                  Position must be array(2) of numbers or strings.
 *                                  Use null for mouse pointer position.
 * @param {string} _align - recommended align (see ALIGN enum)
 * @param {daguiObj} menuObj - dagui object to be aligned.
 * @param {table} [params] - optional extra paramenters.
 * @return {string} - align which was applied to menuObj (see ALIGN enum).
 */
function g_dagui_utils::setPopupMenuPosAndAlign(parentObjOrPos, _align, menuObj, params = null)
{
  if (!::check_obj(menuObj))
    return _align

  local guiScene = menuObj.getScene()
  local menuSize = menuObj.getSize()

  local parentPos  = [0, 0]
  local parentSize = [0, 0]
  if (::u.isInstance(parentObjOrPos) && ::check_obj(parentObjOrPos))
  {
    parentPos  = parentObjOrPos.getPosRC()
    parentSize = parentObjOrPos.getSize()
  }
  else if (::u.isArray(parentObjOrPos) && parentObjOrPos.len() == 2)
  {
    parentPos[0] = toPixels(guiScene, parentObjOrPos[0])
    parentPos[1] = toPixels(guiScene, parentObjOrPos[1])
  }
  else if (parentObjOrPos == null)
  {
    parentPos  = ::get_dagui_mouse_cursor_pos_RC()
  }

  local screenBorders = ::getTblValue("screenBorders", params, ["@bw", "@bh"])
  local bw = toPixels(guiScene, screenBorders[0])
  local bh = toPixels(guiScene, screenBorders[1])
  local screenStart = [ bw, bh ]
  local screenEnd   = [ ::screen_width().tointeger() - bw, ::screen_height().tointeger() - bh ]

  local checkAligns = []
  switch (_align)
  {
    case ALIGN.BOTTOM: checkAligns = [ ALIGN.BOTTOM, ALIGN.TOP, ALIGN.RIGHT, ALIGN.LEFT, ALIGN.BOTTOM ]; break
    case ALIGN.TOP:    checkAligns = [ ALIGN.TOP, ALIGN.BOTTOM, ALIGN.RIGHT, ALIGN.LEFT, ALIGN.TOP ]; break
    case ALIGN.RIGHT:  checkAligns = [ ALIGN.RIGHT, ALIGN.LEFT, ALIGN.BOTTOM, ALIGN.TOP, ALIGN.RIGHT ]; break
    case ALIGN.LEFT:   checkAligns = [ ALIGN.LEFT, ALIGN.RIGHT, ALIGN.BOTTOM, ALIGN.TOP, ALIGN.LEFT ]; break
    default:           checkAligns = [ ALIGN.BOTTOM, ALIGN.RIGHT, ALIGN.TOP, ALIGN.LEFT,ALIGN.BOTTOM ]; break
  }

  foreach (checkIdx, align in checkAligns)
  {
    local isAlignForced = checkIdx == checkAligns.len() - 1

    local isVertical = true
    local isPositive = true
    switch (align)
    {
      case ALIGN.TOP:
        isPositive = false
        break
      case ALIGN.RIGHT:
        isVertical = false
        break
      case ALIGN.LEFT:
        isVertical = false
        isPositive = false
        break
    }

    local axis = isVertical ? 1 : 0
    local parentTargetPoint = [0.5, 0.5] //part of parent to target point
    local frameOffset = [ 0 - menuSize[0] / 2, 0 - menuSize[1] / 2 ]
    local frameOffsetText = [ "-w/2", "-h/2" ] //need this for animation

    if (isPositive)
    {
      parentTargetPoint[axis] = 1.0
      frameOffset[axis] = 0
      frameOffsetText[axis] = ""
    } else
    {
      parentTargetPoint[axis] = 0.0
      frameOffset[axis] = 0 - menuSize[isVertical ? 1 : 0]
      frameOffsetText[axis] = isVertical ? "-h" : "-w"
    }

    local targetPoint = [
      parentPos[0] + (parentSize[0] * ::getTblValue("customPosX", params, parentTargetPoint[0])).tointeger()
      parentPos[1] + (parentSize[1] * ::getTblValue("customPosY", params, parentTargetPoint[1])).tointeger()
    ]

    local isFits = [ true, true ]
    local sideSpace = [ 0, 0 ]
    foreach (i, v in sideSpace)
    {
      if (i == axis)
        sideSpace[i] = isPositive ? screenEnd[i] - targetPoint[i] : targetPoint[i] - screenStart[i]
      else
        sideSpace[i] = screenEnd[i] - screenStart[i]

      isFits[i] = sideSpace[i] >= menuSize[i]
    }

    if ((!isFits[0] || !isFits[1]) && !isAlignForced)
      continue

    local arrowOffset = [ 0, 0 ]
    local menuPos = [ targetPoint[0] + frameOffset[0], targetPoint[1] + frameOffset[1] ]

    foreach (i, v in menuPos)
    {
      if (i == axis && !isFits[i])
        continue

      if (menuPos[i] < screenStart[i] || !isFits[i])
      {
        arrowOffset[i] = menuPos[i] - screenStart[i]
        menuPos[i] = screenStart[i]
      }
      else if (menuPos[i] + menuSize[i] > screenEnd[i])
      {
        arrowOffset[i] = menuPos[i] + menuSize[i] - screenEnd[i]
        menuPos[i] = screenEnd[i] - menuSize[i]
      }
    }

    local menuPosText = [ "", "" ]
    foreach (i, v in menuPos)
      menuPosText[i] = (menuPos[i] - frameOffset[i]) + frameOffsetText[i]

    menuObj["menu_align"] = align
    menuObj["pos"] = ::g_string.implode(menuPosText, ", ")

    if (arrowOffset[0] || arrowOffset[1])
    {
      local arrowObj = menuObj.findObject("popup_menu_arrow")
      if (::check_obj(arrowObj))
      {
        guiScene.setUpdatesEnabled(true, true)
        local arrowPos = arrowObj.getPosRC()
        foreach (i, v in arrowPos)
          arrowPos[i] += arrowOffset[i]
        arrowObj["style"] = "position:root; pos:" + ::g_string.implode(arrowPos, ", ") + ";"
      }
    }

    return align
  }

  return _align
}

function check_obj(obj)
{
  return obj!=null && obj.isValid()
}

function show_obj(obj, status)
{
  if (!::check_obj(obj))
    return null

  obj.enable(status)
  obj.show(status)
  return obj
}