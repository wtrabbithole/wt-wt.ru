local colors = {}

colors.hud <- {}
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
