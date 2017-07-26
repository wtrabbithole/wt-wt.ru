::g_script_reloader.loadOnce("scripts/options/bhvHarmonizedImage.nut")

::country_flags_preset <- {}

function get_country_flags_preset()
{
  if (::is_vendor_tencent())
    return "tencent"
  if (::is_vietnamese_version())
    return "vietnam"
  return "default"
}

function get_country_flag_img(id)
{
  return (id in ::country_flags_preset)? ::country_flags_preset[id] : ""
}

function get_country_icon(countryId, big=false, locked=false)
{
  local id = countryId + (big ? "_big" : "") + (locked ? "_locked" : "")
  return ::get_country_flag_img(id)
}

function init_country_flags_preset()
{
  local blk = ::configs.GUI.get()
  if (!blk)
    return
  local texBlk = blk.texture_presets
  if (!texBlk || typeof(texBlk)!="instance" || !(texBlk instanceof ::DataBlock))
  {
    ::script_net_assert_once("flags_presets", "Error: not texture_presets block in gui.blk")
    return
  }

  local defPreset = "default"
  local presetsList = [::get_country_flags_preset()]
  if (presetsList[0] != defPreset)
    presetsList.append(defPreset)

  ::country_flags_preset = {}

  foreach(blockName in presetsList)
  {
    local block = texBlk[blockName]
    if (!block || typeof(block)!="instance" || !(block instanceof ::DataBlock))
      continue

    foreach(name, value in block)
      if (!(name in ::country_flags_preset) && typeof(value) == "string")
        ::country_flags_preset[name] <- value
  }
}

::add_event_listener("GameLocalizationChanged", function(params) {
    ::init_country_flags_preset()
  }, null, ::g_listener_priority.CONFIG_VALIDATION)

::init_country_flags_preset()