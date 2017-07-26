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

function check_obj(obj)
{
  return obj!=null && obj.isValid()
}