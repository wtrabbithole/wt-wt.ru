local colors = {}

colors.hud <- {}
::with_table(colors.hud, function () {
  teamBlueColor = Color(82, 122, 255)
  teamBlueLightColor = Color(153, 177, 255)
  teamBlueInactiveColor = Color(92, 99, 122)
  teamBlueDarkColor = Color(16, 24, 52)
  chatTextTeamColor = Color(189, 204, 255)
  teamRedColor = Color(255, 90, 82)
  teamRedLightColor = Color(255, 162, 157)
  teamRedInactiveColor = Color(124, 95, 93)
  teamRedDarkColor = Color(52, 17, 16)
  squadColor = Color(62, 158, 47)
  chatTextSquadColor = Color(198, 255, 189)
})


colors.hud.damageModule <- {}
::with_table(colors.hud.damageModule, function () {
  active = Color(255, 255, 255)
  alert = Color(221, 17, 17)
  alertHighlight = Color(255, 255, 255) //for flashing animations
  inactive = Color(45, 55, 63, 80)

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
