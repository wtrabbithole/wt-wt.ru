local enums = ::require("sqStdlibs/helpers/enums.nut")
const FONTS_SAVE_PATH = "fonts_css"
const FONTS_SAVE_PATH_CONFIG = "video/fonts"

enum FONT_SAVE_ID {
  TINY = "tiny"
  SMALL = "small"
  COMPACT = "compact"
  MEDIUM = "medium"
  LARGE = "big"

  //wop_1_69_3_x fonts
  PX = "px"
  SCALE = "scale"

  //wop_1_69_3_X
  PX_COMPATIBILITY = "gui/const/const_pxFonts.css"
  SCALE_COMPATIBILITY = "gui/const/const_fonts.css"
}

enum FONT_SIZE_ORDER {
  PX    //wop_1_69_3_X
  TINY
  SMALL
  COMPACT
  MEDIUM
  LARGE
  SCALE  //wop_1_69_3_X
}

local hasNewFontsSizes = ::is_dev_version || ::is_version_equals_or_newer("1.71.1.63")
local hasNewFonts = ::is_dev_version || ::is_version_equals_or_newer("1.71.1.72")

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

  //text visible in options
  getOptionText = @() ::loc("fontSize/" + id.tolower())
    + ::loc("ui/parentheses/space", { text = (100 * sizeMultiplier).tointeger() + "%" })
  getFontExample = @() "small_text" + fontGenId
}

enums.addTypesByGlobalName("g_font",
{
  TINY = {
    fontGenId = "_set_tiny"
    saveId = FONT_SAVE_ID.TINY
    sizeMultiplier = 0.5
    sizeOrder = FONT_SIZE_ORDER.TINY

    isAvailable = @(sWidth, sHeight) hasNewFonts && ::min(0.75 * sWidth, sHeight) >= 800
  }

  SMALL = {
    fontGenId = "_set_small"
    saveId = FONT_SAVE_ID.SMALL
    sizeMultiplier = 0.667
    sizeOrder = FONT_SIZE_ORDER.SMALL

    isAvailable = @(sWidth, sHeight) ::min(0.75 * sWidth, sHeight) >= (hasNewFontsSizes ? 768 : 900)
  }

  COMPACT = {
    fontGenId = "_set_compact"
    saveId = FONT_SAVE_ID.COMPACT
    sizeMultiplier = 0.75
    sizeOrder = FONT_SIZE_ORDER.COMPACT

    isAvailable = @(sWidth, sHeight) hasNewFonts && ::min(0.75 * sWidth, sHeight) >= 720
  }

  MEDIUM = {
    fontGenId = "_set_medium"
    saveId = FONT_SAVE_ID.MEDIUM
    sizeMultiplier = 0.834
    saveIdCompatibility = [FONT_SAVE_ID.PX]
    sizeOrder = FONT_SIZE_ORDER.MEDIUM

    isAvailable = @(sWidth, sHeight) ::min(0.75 * sWidth, sHeight) >= (hasNewFontsSizes ? 720 : 800)
  }

  LARGE = {
    fontGenId = "_hud" //better to rename it closer to major
    saveId = FONT_SAVE_ID.LARGE
    sizeMultiplier = 1.0
    sizeOrder = FONT_SIZE_ORDER.LARGE
    saveIdCompatibility = [FONT_SAVE_ID.SCALE]
  }
},
null,
"id")

::g_font.types.sort(@(a, b) a.sizeOrder <=> b.sizeOrder)

function g_font::getAvailableFontBySaveId(saveId)
{
  local res = enums.getCachedType("saveId", saveId, cache.bySaveId, this, null)
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

function g_font::getSmallestFont(sWidth, sHeight)
{
  local res = null
  foreach(font in types)
    if (font.isAvailable(sWidth, sHeight) && (!res || font.sizeMultiplier < res.sizeMultiplier))
      res = font
  return res
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

  if (::is_platform_shield_tv() || ::is_ps4_or_xbox || ::is_steam_big_picture())
    return LARGE

  local displayScale = ::display_scale()
  local sWidth = ::screen_width()
  local sHeight = ::screen_height()
  if (displayScale <= 1.2 && COMPACT.isAvailable(sWidth, sHeight))
    return COMPACT
  if (displayScale <= 1.4 && MEDIUM.isAvailable(sWidth, sHeight))
    return MEDIUM
  return LARGE
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

  local fontSaveId = ::load_local_account_settings(FONTS_SAVE_PATH)
  local res = getAvailableFontBySaveId(fontSaveId)
  if (!res) //compatibility with 1.77.0.X
  {
    fontSaveId = ::loadLocalByScreenSize(FONTS_SAVE_PATH)
    if (fontSaveId)
    {
      res = getAvailableFontBySaveId(fontSaveId)
      if (res)
        ::save_local_account_settings(FONTS_SAVE_PATH, fontSaveId)
      ::clear_local_by_screen_size(FONTS_SAVE_PATH)
    }
  }
  return res || getDefault()
}

//return isChanged
function g_font::setCurrent(font)
{
  if (!canChange())
    return false

  local fontSaveId = ::load_local_account_settings(FONTS_SAVE_PATH)
  local isChanged = font.saveId != fontSaveId
  if (isChanged)
    ::save_local_account_settings(FONTS_SAVE_PATH, font.saveId)

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