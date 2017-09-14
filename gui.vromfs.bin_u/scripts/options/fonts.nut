const FONTS_SAVE_PATH = "fonts_css"
const FONTS_SAVE_PATH_CONFIG = "video/fonts"

enum FONT_SAVE_ID {
  SMALL = "small"
  MEDIUM = "medium"
  BIG = "big"

  //wop_1_69_3_x fonts
  PX = "px"
  SCALE = "scale"

  //wop_1_69_3_X
  PX_COMPATIBILITY = "gui/const/const_pxFonts.css"
  SCALE_COMPATIBILITY = "gui/const/const_fonts.css"
}

enum FONT_SIZE_ORDER {
  PX    //wop_1_69_3_X
  SMALL
  MEDIUM
  BIG
  SCALE  //wop_1_69_3_X
}

::g_font <- {
  types = []
  cache = { bySaveId = {} }
}

::g_font.template <- {
  id = ""  //by type name
  fontGenId = ""
  saveId = ""
  saveIdCompatibility = null //array of ids. need to easy switch between fonts by feature
  isScaleable = true
  sizeMultiplier = 1.0
  sizeOrder = 0 //FONT_SIZE_ORDER

  isAvailable = @(sWidth, sHeight) true
  getFontSizePx = @(sWidth, sHeight) ::min(sHeight, sWidth * 0.75) * sizeMultiplier
  getPixelToPixelFontSizeOutdatedPx = @(sWidth, sHeight) 800 //!!TODO: remove this together with old fonts
  isLowWidthScreen = function(sWidth, sHeight)
  {
    if (sWidth > 3 * sHeight) //tripple screen
      sWidth = sWidth / 3
    local sf = getFontSizePx(sWidth, sHeight)
    return 10.0 / 16 * sWidth / sf < 0.99
  }

  genCssString = function()
  {
    local sWidth = ::screen_width()
    local sHeight = ::screen_height()
    local config = {
      set = fontGenId
      scrnTgt = getFontSizePx(sWidth, sHeight)
      pxFontTgtOutdated = getPixelToPixelFontSizeOutdatedPx(sWidth, sHeight)
    }
    return ::handyman.renderCached("gui/const/const_fonts_css", config)
  }

  getOptionText = @() (100 * sizeMultiplier).tointeger() + "%" //text visible in options
}

::g_enum_utils.addTypesByGlobalName("g_font",
{
  SMALL = {
    fontGenId = "_set_small"
    saveId = FONT_SAVE_ID.SMALL
    sizeMultiplier = 0.667
    sizeOrder = FONT_SIZE_ORDER.SMALL

    isAvailable = @(sWidth, sHeight) ::has_feature("newFontsSizes") && ::min(0.75 * sWidth, sHeight) >= 900
  }

  MEDIUM = {
    fontGenId = "_set_medium"
    saveId = FONT_SAVE_ID.MEDIUM
    sizeMultiplier = 0.834
    saveIdCompatibility = [FONT_SAVE_ID.PX]
    sizeOrder = FONT_SIZE_ORDER.MEDIUM

    isAvailable = @(sWidth, sHeight) ::has_feature("newFontsSizes") && ::min(0.75 * sWidth, sHeight) >= 800
  }

  BIG = {
    fontGenId = "_hud" //better to rename it closer to major
    saveId = FONT_SAVE_ID.BIG
    sizeMultiplier = 1.0
    sizeOrder = FONT_SIZE_ORDER.BIG
    saveIdCompatibility = [FONT_SAVE_ID.SCALE]

    isAvailable = @(sWidth, sHeight) ::has_feature("newFontsSizes")
  }
},
null,
"id")

::g_font.types.sort(@(a, b) a.sizeOrder <=> b.sizeOrder)

function g_font::getAvailableFontBySaveId(saveId)
{
  local res = ::g_enum_utils.getCachedType("saveId", saveId, cache.bySaveId, this, null)
  if (res && res.isAvailable(::screen_width(), ::screen_height()))
    return res

  foreach(font in types)
    if (font.saveIdCompatibility
      && ::isInArray(saveId, font.saveIdCompatibility)
      && font.isAvailable(::screen_width(), ::screen_height()))
      return font

  return null
}

function g_font::getAvailableFonts()
{
  local sWidth = ::screen_width()
  local sHeight = ::screen_height()
  return ::u.filter(types, @(f) f.isAvailable(sWidth, sHeight))
}

function g_font::getFixedFont() //return null if can change fonts
{
  local availableFonts = getAvailableFonts()
  return availableFonts.len() == 1 ? availableFonts[0] : null
}

function g_font::canChange()
{
  return getFixedFont() == null
}

function g_font::getDefault()
{
  local fixedFont = getFixedFont()
  if (fixedFont)
    return fixedFont

  if (!::has_feature("newFontsSizes"))
  {
    if (::is_platform_ps4 || ::is_steam_big_picture())
      return SCALE
    if (::screen_height() * ::display_scale() <= 1200)
      return PX
    return SCALE
  }

  if (::is_platform_shield_tv() || ::is_platform_ps4 || ::is_platform_xboxone || ::is_steam_big_picture())
    return BIG

  local displayScale = ::display_scale()
  local sWidth = ::screen_width()
  local sHeight = ::screen_height()
  if (displayScale <= 1.2 && SMALL.isAvailable(sWidth, sHeight))
    return SMALL
  if (displayScale <= 1.4 && MEDIUM.isAvailable(sWidth, sHeight))
    return MEDIUM
  return BIG
}

function g_font::getCurrent()
{
  if (!canChange())
    return getDefault()

  if (!::g_login.isProfileReceived())
  {
    local fontSaveId = ::getSystemConfigOption(FONTS_SAVE_PATH_CONFIG)
    return (fontSaveId && getAvailableFontBySaveId(fontSaveId))
      || getDefault()
  }

  local fontSaveId = ::loadLocalByScreenSize(FONTS_SAVE_PATH)
  return getAvailableFontBySaveId(fontSaveId) || getDefault()
}

//return isChanged
function g_font::setCurrent(font)
{
  if (!canChange())
    return false

  local fontSaveId = ::loadLocalByScreenSize(FONTS_SAVE_PATH)
  local isChanged = font.saveId != fontSaveId
  if (isChanged)
    ::saveLocalByScreenSize(FONTS_SAVE_PATH, font.saveId)

  saveFontToConfig(font)
  return isChanged
}

function g_font::saveFontToConfig(font)
{
  if (::getSystemConfigOption(FONTS_SAVE_PATH_CONFIG) != font.saveId)
    ::setSystemConfigOption(FONTS_SAVE_PATH_CONFIG, font.saveId)
}

function g_font::validateSavedConfigFonts()
{
  if (canChange())
    saveFontToConfig(getCurrent())
}