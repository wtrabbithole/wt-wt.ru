const PX_FONTS_CSS    = "gui/const/const_pxFonts.css"
const SCALE_FONTS_CSS = "gui/const/const_fonts.css"

const FONTS_SAVE_PATH = "fonts_css"

function get_fixed_fonts() //return null if can change fonts
{
  if (::use_touchscreen || ::is_platform_android || ::is_platform_shield_tv())
    return SCALE_FONTS_CSS
  if (::screen_height() <= 800 && ::is_low_width_screen())
    return PX_FONTS_CSS
  return null
}

function can_change_fonts()
{
  return ::get_fixed_fonts() == null
}

function get_default_fonts_css()
{
  local fixedFonts = ::get_fixed_fonts()
  if (fixedFonts)
    return fixedFonts

  if (::is_platform_ps4 || ::is_steam_big_picture())
    return SCALE_FONTS_CSS

  if (::screen_height() * ::display_scale() <= 1200)
    return PX_FONTS_CSS
  return SCALE_FONTS_CSS
}

function get_current_fonts_css()
{
  if (!::can_change_fonts())
    return ::get_default_fonts_css()

  if (!::g_login.isAuthorized())
  {
    local isPxFonts = ::getSystemConfigOption("video/pxFonts")
    return isPxFonts == null ? ::get_default_fonts_css()
      : isPxFonts ? PX_FONTS_CSS
      : SCALE_FONTS_CSS
  }

  local fontsCss = ::loadLocalByScreenSize(FONTS_SAVE_PATH)
  if (::isInArray(fontsCss, [PX_FONTS_CSS, SCALE_FONTS_CSS]))
    return fontsCss

  //compatibility with old fonts save data
  fontsCss = ::get_gui_option_in_mode(::USEROPT_FONTS_CSS, ::OPTIONS_MODE_GAMEPLAY)
  if (fontsCss)
  {
    ::set_gui_option_in_mode(::USEROPT_FONTS_CSS, false, ::OPTIONS_MODE_GAMEPLAY) //load compatibility only once
    if (::set_current_fonts_css(fontsCss))
      return fontsCss
  }

  return ::get_default_fonts_css()
}

//return isChanged
function set_current_fonts_css(fontsCss)
{
  if (!::isInArray(fontsCss, [PX_FONTS_CSS, SCALE_FONTS_CSS])
      || !::can_change_fonts())
    return false

  local curFontsCss = ::loadLocalByScreenSize(FONTS_SAVE_PATH)
  local isChanged = fontsCss != curFontsCss
  if (isChanged)
    ::saveLocalByScreenSize(FONTS_SAVE_PATH, fontsCss)

  ::save_config_fonts(fontsCss)
  return isChanged
}

function save_config_fonts(fontsCss)
{
  local isPxFonts = fontsCss == PX_FONTS_CSS
  if (::getSystemConfigOption("video/pxFonts") != isPxFonts)
    ::setSystemConfigOption("video/pxFonts", isPxFonts)
}

function validate_saved_config_fonts()
{
  if (::can_change_fonts())
    ::save_config_fonts(::get_current_fonts_css())
}