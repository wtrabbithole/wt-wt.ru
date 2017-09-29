//to correct scale prefer to set 1080p before using this function.
//size:
//   int - image size on 1080p big fonts
//   null - various image sizes
//   string - daguiConstant
function debug_svg(image, size = null, bgColor = "#808080")
{
  local baseHeight = ::u.isInteger(size) ? 1080 : ::screen_height()
  local view = {
    image = image
    bgColor = bgColor
    blocks= []
  }

  if (::u.isString(size))
    size = ::to_pixels(size)

  if (::u.isInteger(size) && size > 0)
  {
    local block = { header = size, sizeList = [] }
    local screenHeights = [720, 768, 800, 864, 900, 960, 1024, 1050, 1080, 1200, 1440, 1800, 2160]
    foreach(sf in screenHeights)
      block.sizeList.append({ name = sf, size = (size.tofloat() * sf / baseHeight + 0.5).tointeger() })
    view.blocks.append(block)
  } else
  {
    local screenHeights = [720, 1080, 2160]
    local smallestFont = ::g_font.getSmallestFont(1280, 720)
    if (smallestFont && smallestFont.sizeMultiplier < 1)
      screenHeights.insert(0, smallestFont.sizeMultiplier * 720)
    local sizes = ["@sIco", "@cIco", "@dIco", "@lIco"]
    foreach(sf in screenHeights)
    {
      local block = { header = "screen height " + sf, sizeList = [] }
      view.blocks.append(block)
      foreach(s in sizes)
      {
        local px = ::to_pixels(s)
        block.sizeList.append({ name = " " + s + " ", size = (px.tofloat() * sf / baseHeight + 0.5).tointeger() })
      }
    }
  }

  debug_wnd("gui/debugTools/dbgSvg.tpl", view)
}