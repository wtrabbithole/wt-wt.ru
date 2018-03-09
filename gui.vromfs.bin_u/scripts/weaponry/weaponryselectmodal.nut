/*
  config = {
    unit  //unit for weapons
    onChangeValueCb = function(chosenWeaponryItem)   //callback on value select (only if value was changed)
    weaponItemParams = null //list of special items render params (for weaponVisual::updateItem)

    align = "top"/"bottom"/"left"/"right"
    alignObj = DaguiObj  //object to align menu

    list = [
      {
        //must have parameter:
        weaponryItem //weapon or modification from unit

        //optional parameters:
        selected = false
        enabled = true
        visualDisabled = false
      }
      ...
    ]
  }
*/
function gui_start_weaponry_select_modal(config)
{
  ::handlersManager.loadHandler(::gui_handlers.WeaponrySelectModal, config)
}

function gui_start_choose_unit_weapon(unit, cb, itemParams = null, alignObj = null, align = "bottom")
{
  local list = []
  local curWeaponName = ::get_last_weapon(unit.name)

  local testFlight = ::get_gui_options_mode() == ::OPTIONS_MODE_TRAINING
  local checkAircraftPurchased = !testFlight
  local checkWeaponPurchased = !testFlight && !::is_game_mode_with_spendable_weapons()
  local hasOnlyBought = !::is_in_flight() || !::g_mis_custom_state.getCurMissionRules().isWorldWar

  foreach(weapon in unit.weapons)
  {
    if (!::is_weapon_visible(unit, weapon, hasOnlyBought))
      continue

    list.append({
      weaponryItem = weapon
      selected = curWeaponName == weapon.name
      enabled = ::is_weapon_enabled(unit, weapon)
    })
  }

  ::gui_start_weaponry_select_modal({
    unit = unit
    list = list
    weaponItemParams = itemParams
    alignObj = alignObj
    align = align
    onChangeValueCb = (@(unit, cb) function(weapon) {
      ::set_last_weapon(unit.name, weapon.name)
      if (cb) cb()
    })(unit, cb)
  })
}

function ww_gui_start_choose_unit_weapon(unit, cb, itemParams = null, alignObj = null, align = "bottom")
{
  local list = []
  local curWeaponName = ::g_world_war.get_last_weapon_preset(unit.name)
  foreach(weapon in unit.weapons)
    list.append({
      weaponryItem = weapon
      selected = curWeaponName == weapon.name
      enabled = true
    })

  ::gui_start_weaponry_select_modal({
    unit = unit
    list = list
    weaponItemParams = itemParams
    alignObj = alignObj
    align = align
    onChangeValueCb = (@(unit, cb) function(weapon) {
      ::g_world_war.set_last_weapon_preset(unit.name, weapon.name)
      if (cb) cb(unit.name, weapon.name)
    })(unit, cb)
  })
}

class ::gui_handlers.WeaponrySelectModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneTplName = "gui/weaponry/weaponrySelectModal"
  shouldBlurSceneBg = false

  unit = null
  list = null
  currentValue = null
  weaponItemParams = null
  onChangeValueCb = null

  align = "bottom"
  alignObj = null

  rowsToClumnsProportion = 3

  wasSelIdx = 0
  selIdx = 0

  function getSceneTplView()
  {
    if (!unit || !list)
      return null

    local cols = ::ceil(::sqrt(list.len().tofloat() / rowsToClumnsProportion)).tointeger()
    local rows = cols ? ::ceil(list.len().tofloat() / cols).tointeger() : 0

    wasSelIdx = -1
    local params = { posX = 0, posY = 0, useGenericTooltip = true }
    local weaponryListMarkup = ""
    foreach(idx, config in list)
    {
      local weaponryItem = ::getTblValue("weaponryItem", config)
      if (!weaponryItem)
      {
        ::script_net_assert_once("cant load weaponry",
                                "Error: empty weaponryItem for WeaponrySelectModal. unit = " + (unit && unit.name))
        list = null //goback
        return null
      }

      if (::getTblValue("selected", config))
        wasSelIdx = idx

      params.posX = rows ? (idx / rows) : 0
      params.posY = rows ? (idx % rows) : 0
      weaponryListMarkup += ::weaponVisual.createItemLayout(idx, weaponryItem, weaponryItem.type, params)
    }

    selIdx = ::max(wasSelIdx, 0)
    local res = {
      weaponryList = weaponryListMarkup
      columns = cols
      rows = rows
      value = selIdx
    }
    return res
  }

  function initScreen()
  {
    if (!list || !unit)
      return goBack()

    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"))
    scene.findObject("weapons_list").select()
    updateItems()
    updateOpenAnimParams()
  }

  function updateItems()
  {
    local listObj = scene.findObject("weapons_list")
    local total = ::min(list.len(), listObj.childrenCount())
    for(local i = 0; i < total; i++)
    {
      local config = list[i]
      local itemObj = listObj.getChild(i)
      local enabled = ::getTblValue("enabled", config, true)
      itemObj.enable(enabled)

      weaponItemParams.visualDisabled <- !enabled || ::getTblValue("visualDisabled", config, false)
      ::weaponVisual.updateItem(unit, config.weaponryItem, itemObj, false, this, weaponItemParams)
    }
    weaponItemParams.visualDisabled <- false
  }

  function updateOpenAnimParams()
  {
    local animObj = scene.findObject("anim_block")
    if (!animObj)
      return
    local size = animObj.getSize()
    if (!size[0] || !size[1])
      return

    local scaleId = "height"
    local scaleAxis = 1
    if (align == "left" || align == "right")
    {
      scaleId = "width"
      scaleAxis = 0
    }

    animObj[scaleId] = "1"
    animObj[scaleId + "-base"] = "1"
    animObj[scaleId + "-end"] = size[scaleAxis].tostring()
  }

  function onChangeValue(obj)
  {
    selIdx = obj.getValue()
    goBack()
  }

  function onModItemClick(obj)
  {
    local idx = ::to_integer_safe(obj.holderId, -1)
    if (idx < 0)
      return
    selIdx = idx
    goBack()
  }

  function afterModalDestroy()
  {
    if (selIdx == wasSelIdx
        || !(selIdx in list)
        || !onChangeValueCb)
      return
    onChangeValueCb(::getTblValue("weaponryItem", list[selIdx]))
  }
}