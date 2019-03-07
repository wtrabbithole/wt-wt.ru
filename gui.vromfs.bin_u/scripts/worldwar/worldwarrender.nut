local stdMath = require("std/math.nut")

const WW_ENABLE_RENDER_CATEGORY_ID = "ww_enable_render_category_bitmask"

::g_world_war_render <-
{
  flags = 0
  DEFAULT_FLAGS = ~(1 << ::ERC_ARMY_RADIUSES)
  DEFAULT_PREVIEW_FLAGS = (1 << ::ERC_ZONES) | (1 << ::ERC_BATTLES) | (1 << ::ERC_MAP_PICTURE)
}


function g_world_war_render::init()
{
  flags = ::loadLocalByAccount(WW_ENABLE_RENDER_CATEGORY_ID, DEFAULT_FLAGS)
  for (local cat = ::ERC_ARMY_RADIUSES; cat < ::ERC_TOTAL; ++cat)
    setCategory(cat, isCategoryEnabled(cat))
}


function g_world_war_render::isCategoryEnabled(category)
{
  return stdMath.is_bit_set(flags, category)
}


function g_world_war_render::isCategoryVisible(category)
{
  return true
}


function g_world_war_render::setPreviewCategories()
{
  for (local cat = ::ERC_ARMY_RADIUSES; cat < ::ERC_TOTAL; ++cat)
  {
    local previewCatEnabled = stdMath.is_bit_set(DEFAULT_PREVIEW_FLAGS, cat)
    ::ww_enable_render_map_category_for_preveiw(cat, previewCatEnabled)
  }
}


function g_world_war_render::setCategory(category, enable)
{
  flags = stdMath.change_bit(flags, category, enable)
  ::saveLocalByAccount(WW_ENABLE_RENDER_CATEGORY_ID, flags)

  ww_enable_render_map_category(category, enable)
}
