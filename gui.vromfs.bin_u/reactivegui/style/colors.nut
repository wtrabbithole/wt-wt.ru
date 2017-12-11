local colors = {}

::with_table(colors, function () {
  transparent = Color(0, 0, 0, 0)
  white = Color(255, 255, 255)
  green = Color(0, 255, 0)
})

colors.menu <- {}
::with_table(colors.menu, function () {
  chatTextBlockedColor =  Color(128, 128, 128)
  commonTextColor = Color(192, 192, 192)
  unlockActiveColor = Color(255, 255, 255)
  userlogColoredText = Color(249, 219, 120)
  streakTextColor = Color(255, 229, 82)
  activeTextColor = Color(255, 255, 255)

  tabBackgroundColor = Color(3, 7, 12, 204)
  listboxSelOptionColor = Color(40, 51, 60)
  headerOptionHoverColor = Color(106, 34, 17, 153) //buttonCloseColorPushed
  headerOptionSelectedColor = Color(178, 57, 29) //buttonCloseColorHover
  headerOptionTextColor = Color(144, 143, 143) //buttonFontColorPushed, scrollbarSliderColor
  headerOptionSelectedTextColor = Color(224, 224, 224) //buttonFontColor, buttonHeaderTextColor, menuButtonTextColorHover, listboxSelTextColor

  scrollbarBgColor = Color(44, 44, 44, 51)
  scrollbarSliderColor = Color(144, 143, 143)
  scrollbarSliderColorHover = Color(224, 224, 224)

  silver = Color(170, 170, 170)
})

colors.hud <- {}
::with_table(colors.hud, function () {
  spectatorColor = Color(128, 128, 128)
  chatActiveInfoColor = Color(255, 255, 5)
  mainPlayerColor = Color(221, 163, 57)
  componentFill = Color(0, 0, 0, 192)
  componentBorder = Color(255, 255, 255)
  chatTextAllColor = colors.menu.commonTextColor
})

colors.hud.damageModule <- {}
::with_table(colors.hud.damageModule, function () {
  active = Color(255, 255, 255)
  alert = Color(221, 17, 17)
  alertHighlight = Color(255, 255, 255) //for flashing animations
  inactive = Color(45, 55, 63, 80)
  aiSwitchHighlight = colors.green

  dmModuleDamaged = Color(255, 176, 37)
  dmModuleNormal = inactive
  dmModuleDestroyed = alert
})


colors.hud.shipSteeringGauge <- {}
::with_table(colors.hud.shipSteeringGauge, function () {
  mark = Color(235, 235, 60, 200)
  serif = Color(135, 163, 160, 100)
  background = Color(0, 0, 0, 50)
})


return colors
