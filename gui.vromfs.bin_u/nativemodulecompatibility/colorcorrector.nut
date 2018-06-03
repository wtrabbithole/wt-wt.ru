/**
 * Back caompatible only for daGUI, because old version can work only with string
 * representation of color in format "#AARRGGBB". daRg can't use old API because
 * it use integer instead of string to store color.
 */
return {
  correctHueTarget = @(color, target) ::correct_color_hue_target(color, target)
  correctColorLightness = @(color, lightness) ::correct_color_lightness(color, lightness)
  TARGET_HUE_ALLY = getroottable().__get("TARGET_HUE_ALLY", 0)
  TARGET_HUE_SQUAD = getroottable().__get("TARGET_HUE_SQUAD", 1)
  TARGET_HUE_ENEMY = getroottable().__get("TARGET_HUE_ENEMY", 2)
  TARGET_HUE_SPECTATOR_ALLY = getroottable().__get("TARGET_HUE_SPECTATOR_ALLY", 3)
  TARGET_HUE_SPECTATOR_ENEMY = getroottable().__get("TARGET_HUE_SPECTATOR_ENEMY", 4)
  TARGET_HUE_RELOAD = 5
  TARGET_HUE_RELOAD_DONE = 6
}
