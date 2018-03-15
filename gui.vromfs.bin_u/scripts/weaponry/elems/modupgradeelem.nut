local elemModelType = ::require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = ::require("sqDagui/elemUpdater/elemViewType.nut")

elemModelType.addTypes({
  MOD_UPGRADE = {
    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    onEventModUpgraded = @(p) notify([p.unit.name, p.mod.name])
    onEventOverdriveActivated = @(p) notify([])
  }
})

elemViewType.addTypes({
  MOD_UPGRADE_ICON = {
    model = elemModelType.MOD_UPGRADE
    getBhvParamsString = @(params) bhvParamsToString(
      params.__update({
        subscriptions = [params?.unit || "", params?.mod || ""]
      }))
    createMarkup = @(params, objId = null) ::format("modUpgradeImg { id:t='%s'; value:t='%s' } ",
      objId || "", ::g_string.stripTags(getBhvParamsString(params)))

    updateView = function(obj, params)
    {
      local unitName = params?.unit
      obj.show(!!unitName)
      if (!unitName)
        return

      local modName = params?.mod
      local color = !modName ? "#00000000"
        : ::get_modification_level(unitName, modName) ? "#FFFFFFFF"
        : ::is_mod_upgradeable(modName) ? "#80808080"
        : "#00000000"
      obj.set_prop_latent("background-color", color)
      obj.set_prop_latent("foreground-color",
        modName && ::has_active_overdrive(unitName, modName) ? "#FFFFFFFF" : "#00000000")
      obj.updateRendElem()
    }
  }
})

local makeConfig = @(unitName, modName) unitName && modName ? { unit = unitName, mod = modName } : {}
return {
  createMarkup = @(objId = null, unitName = null, modName = null)
    elemViewType.MOD_UPGRADE_ICON.createMarkup(makeConfig(unitName, modName), objId)
  setValueToObj = @(obj, unitName, modName)
    ::check_obj(obj) && obj.setValue(elemViewType.MOD_UPGRADE_ICON.getBhvParamsString(makeConfig(unitName, modName)))
}