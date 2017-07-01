const PX_FONTS_CSS    = "gui/const/const_pxFonts.css"
const SCALE_FONTS_CSS = "gui/const/const_fonts.css"

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

  if (::screen_height() <= 1200)
    return PX_FONTS_CSS
  return SCALE_FONTS_CSS
}

function get_current_fonts_css()
{
  if (!::can_change_fonts())
    return ::get_default_fonts_css()

  if (!::g_login.isAuthorized())
  {
    local pxFonts = ::getSystemConfigOption("video/pxFonts")
    return (pxFonts != null) ? (pxFonts ? PX_FONTS_CSS : SCALE_FONTS_CSS) : ::get_default_fonts_css()
  }

  local pxFonts = ::get_gui_option_in_mode(::USEROPT_FONTS_CSS, ::OPTIONS_MODE_GAMEPLAY)
  if (::isInArray(pxFonts, [PX_FONTS_CSS, SCALE_FONTS_CSS]))
    return pxFonts
  return ::get_default_fonts_css()
}