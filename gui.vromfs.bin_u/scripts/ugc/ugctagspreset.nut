local tagsPresetNameByIdx = [
  "historical",
  "semihistorical",
  "any"
]

local tagsPresetIdxByName = u.invert(tagsPresetNameByIdx)

local defaulttagsPreset = tagsPresetNameByIdx.len()-1

local function getMaxUgcTagsPresetId(ugcTagsPresetId1, ugcTagsPresetId2) {
  return  tagsPresetNameByIdx[ ::max(
    tagsPresetIdxByName?[ugcTagsPresetId1] ?? defaulttagsPreset,
    tagsPresetIdxByName?[ugcTagsPresetId2] ?? defaulttagsPreset)]
}

local function getPreset() {
  local option = ::get_option(::USEROPT_UGC_ALLOWED_TAGS_PRESET)
  local defValue = option.value in option.values? option.values[option.value] : "historical"
  return ::get_gui_option_in_mode(::USEROPT_UGC_ALLOWED_TAGS_PRESET, ::OPTIONS_MODE_GAMEPLAY, defValue)
}

local function setPreset(presetId) {
  if (!presetId)
    return
  ::set_gui_option_in_mode(::USEROPT_UGC_ALLOWED_TAGS_PRESET, presetId, ::OPTIONS_MODE_GAMEPLAY)
}

local function hasAnyTagFromPreset(tags, presetsBlk) {
  foreach (tagName, value in tags)
    if (value && presetsBlk?[tagName])
      return true

  return false
}

local function getUgcTagsPresetByTags(tags) {
  local curPresetName = getPreset()

  if (::u.isEmpty(tags))
    return curPresetName

  local presetsBlk = ::get_ugc_blk().presets
  if (!presetsBlk)
    return curPresetName

  local curPresetBlk = presetsBlk[curPresetName]
  if (curPresetBlk && hasAnyTagFromPreset(tags, curPresetBlk))
    return curPresetName

  foreach (presetName, preset in presetsBlk)
  {
    if (presetName != curPresetName && hasAnyTagFromPreset(tags, preset))
      return presetName
  }

  return curPreset
}

local function getPresetBySkin(unitId, skinId) {
  return ::get_ugc_tags_preset_by_skin_tags(unitId, skinId) || getPreset()
}

local function showConfirmMsgbox(newPreset, keyMessageDesc, onConfirmCb, onCancelCb) {
  local curPreset = getPreset()

  local pathMessage = "msgbox/optionWillBeChanged"
  local message = ::loc(pathMessage, {
    name     = ::colorize("userlogColoredText", ::loc("options/ugc_allowed_tags_preset"))
    oldValue = ::colorize("userlogColoredText", ::loc("ugc/tag/" + curPreset))
    newValue = ::colorize("userlogColoredText", ::loc("ugc/tag/" + newPreset))
  }) + (keyMessageDesc != "" ?
    ("\n" + ::loc(pathMessage+"/"+keyMessageDesc,
      {oldValue = ::colorize("userlogColoredText", ::loc("ugc/tag/" + curPreset))})) : "")

  local msgboxParams = {
    data_below_buttons = ::format("textarea{ text:t='%s'}", ::g_string.stripTags(::loc("msgbox/optionWillBeChanged/comment")))
  }

  ::scene_msg_box("ugc_tags_preset", null, message, [ ["ok", onConfirmCb], ["cancel", onCancelCb] ], "ok", msgboxParams)
}

return {
  getPreset = getPreset
  setPreset = setPreset
  getPresetBySkin = getPresetBySkin
  showConfirmMsgbox = showConfirmMsgbox
  getUgcTagsPresetByTags = getUgcTagsPresetByTags
  getMaxUgcTagsPresetId = getMaxUgcTagsPresetId
}
