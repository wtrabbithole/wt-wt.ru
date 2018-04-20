local contentPresets = []
local contentPresetIdxByName = {}
local defaultPresetIdx = -1

local function getContentPresets() {
  if (contentPresets.len() > 0 || !::g_login.isLoggedIn())
    return contentPresets

  local blk = ::get_ugc_blk()
  if (blk.presets)
    foreach(preset in blk.presets)
      contentPresets.append(preset.getBlockName())

  contentPresetIdxByName = u.invert(contentPresets)
  defaultPresetIdx = contentPresets.len()-1
  return contentPresets
}

local function getCurPresetId() {
  local option = ::get_option(::USEROPT_CONTENT_ALLOWED_PRESET)
  local defValue = option.value in option.values? option.values[option.value] : "historical"
  return ::get_gui_option_in_mode(::USEROPT_CONTENT_ALLOWED_PRESET, ::OPTIONS_MODE_GAMEPLAY, defValue)
}

local function setPreset(presetId) {
  if (!presetId)
    return
  ::set_gui_option_in_mode(::USEROPT_CONTENT_ALLOWED_PRESET, presetId, ::OPTIONS_MODE_GAMEPLAY)
}

local function getMaxPresetId(presetId1, presetId2) {
  return getContentPresets().len() > 0
    ? getContentPresets()[::max(
      contentPresetIdxByName?[presetId1] ?? defaultPresetIdx,
      contentPresetIdxByName?[presetId2] ?? defaultPresetIdx)]
    : getCurPresetId()
}

local function hasAnyTagFromPreset(tags, presetsBlk) {
  foreach (tagName, value in tags)
    if (value && presetsBlk?[tagName])
      return true

  return false
}

local function getPresetIdByTags(tags) {
  local curPresetId = getCurPresetId()

  if (::u.isEmpty(tags))
    return curPresetId

  local presetsBlk = ::get_ugc_blk().presets
  if (!presetsBlk)
    return curPresetId

  local curPresetBlk = presetsBlk[curPresetId]
  if (curPresetBlk && hasAnyTagFromPreset(tags, curPresetBlk))
    return curPresetId

  foreach (presetName, preset in presetsBlk)
  {
    if (presetName != curPresetId && hasAnyTagFromPreset(tags, preset))
      return presetName
  }

  return curPresetId
}

local function getPresetIdBySkin(unitId, skinId) {
  return ::get_preset_by_skin_tags(unitId, skinId) || getCurPresetId()
}

local function showConfirmMsgbox(newPreset, keyMessageDesc, onConfirmCb, onCancelCb) {
  local curPreset = getCurPresetId()

  local pathMessage = "msgbox/optionWillBeChanged"
  local message = ::loc(pathMessage, {
    name     = ::colorize("userlogColoredText", ::loc("options/content_allowed_preset"))
    oldValue = ::colorize("userlogColoredText", ::loc("content/tag/" + curPreset))
    newValue = ::colorize("userlogColoredText", ::loc("content/tag/" + newPreset))
  }) + (keyMessageDesc != "" ?
    ("\n" + ::loc(pathMessage+"/"+keyMessageDesc,
      {oldValue = ::colorize("userlogColoredText", ::loc("content/tag/" + curPreset))})) : "")

  local msgboxParams = {
    data_below_buttons = ::format("textarea{ text:t='%s'}", ::g_string.stripTags(::loc("msgbox/optionWillBeChanged/comment")))
  }

  ::scene_msg_box("content_preset", null, message, [ ["ok", onConfirmCb], ["cancel", onCancelCb] ], "ok", msgboxParams)
}

return {
  getContentPresets = getContentPresets
  getCurPresetId = getCurPresetId
  setPreset = setPreset
  getPresetIdBySkin = getPresetIdBySkin
  showConfirmMsgbox = showConfirmMsgbox
  getPresetIdByTags = getPresetIdByTags
  getMaxPresetId = getMaxPresetId
}
