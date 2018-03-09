local function getPreset() {
  return ::get_gui_option_in_mode(::USEROPT_UGC_ALLOWED_TAGS_PRESET, ::OPTIONS_MODE_GAMEPLAY)
}

local function setPreset(presetId) {
  ::set_gui_option_in_mode(::USEROPT_UGC_ALLOWED_TAGS_PRESET, presetId, ::OPTIONS_MODE_GAMEPLAY)
}

local function getPresetBySkin(unitId, skinId) {
  return ::get_ugc_tags_preset_by_skin_tags(unitId, skinId)
}

local function showConfirmMsgbox(unitId, skinId, onConfirmCb, onCancelCb) {
  local curPreset = getPreset()
  local newPreset = getPresetBySkin(unitId, skinId)

  local message = ::loc("msgbox/optionWillBeChanged", {
    name     = ::colorize("userlogColoredText", ::loc("options/ugc_allowed_tags_preset"))
    oldValue = ::colorize("userlogColoredText", ::loc("ugc/tag/" + curPreset))
    newValue = ::colorize("userlogColoredText", ::loc("ugc/tag/" + newPreset))
  })

  ::scene_msg_box("ugc_tags_preset", null, message, [ ["ok", onConfirmCb], ["cancel", onCancelCb] ], "ok")
}

return {
  getPreset = getPreset
  setPreset = setPreset
  getPresetBySkin = getPresetBySkin
  showConfirmMsgbox = showConfirmMsgbox
}
