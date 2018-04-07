local ugcTagsPreset = require("scripts/ugc/ugcTagsPreset.nut")
local time = require("scripts/time.nut")

local GIGANTIC_HATS_SAVE_ID = "tutor/aprilFools2018Hats"

class ::gui_handlers.EnableGiganticHatsWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/enableGiganticHatsWnd.blk"

  static function open()
  {
    if (::get_charserver_time_sec() > ::april_fools_day_event_end_t)
      return
    ::handlersManager.loadHandler(::gui_handlers.EnableGiganticHatsWnd)
  }

  static function openIfRequired()
  {
    if (::get_charserver_time_sec() > ::april_fools_day_event_end_t)
      return
    if (! ::gui_handlers.EnableGiganticHatsWnd.isSeen())
      ::handlersManager.loadHandler(::gui_handlers.EnableGiganticHatsWnd)
  }

  static function isSeen()
  {
    return ::load_local_account_settings(GIGANTIC_HATS_SAVE_ID, false)
  }

  static function markSeen(isSeen = true)
  {
    return ::save_local_account_settings(GIGANTIC_HATS_SAVE_ID, isSeen)
  }

  function initScreen()
  {
    if (ugcTagsPreset.getPreset() == "any")
      onGiganticHatsEnabled()

    local introTextObj = scene.findObject("txt_intro")
    if (::check_obj(introTextObj))
      introTextObj.setValue(::loc("aprilFoolsDay2018/hats/intro/date", {
        datetime = time.buildDateTimeStr(::get_time_from_t(::april_fools_day_event_end_t))
      }))

    if (::has_feature("Marketplace"))
    {
      local textObj = scene.findObject("txt_how_to_get")
      if (::check_obj(textObj))
        textObj.setValue(::loc("aprilFoolsDay2018/hats/warbonds") + " " + ::loc("aprilFoolsDay2018/hats/marketplace"))
      showSceneBtn("btn_marketplace", true)
    }
  }

  function goBack()
  {
    markSeen()
    base.goBack()
  }

  function onGiganticHatsEnabled()
  {
    showSceneBtn("btn_show_gigantic_hats", false)
    showSceneBtn("gigantic_hats_enabled", true)
  }

  function onShowGiganticHats(obj)
  {
    local ugcTagsPresetId = "any"
    ugcTagsPreset.showConfirmMsgbox(ugcTagsPresetId, "",
      ::Callback(function() {
        ugcTagsPreset.setPreset(ugcTagsPresetId)
        onGiganticHatsEnabled()
      }, this)
      ::Callback(function() {}, this)
    )
  }

  function onGoToWarbondsShop(obj)
  {
    ::g_warbonds.openShop()
  }

  function onGoToMarketplace(obj)
  {
    if (!::has_feature("Marketplace"))
      return
    local itemMarketHashName = "Hat Trophy"
    local inventoryClient = require("scripts/inventory/inventoryClient.nut")
    local link = inventoryClient.getMarketplaceBaseUrl() + "?viewitem&a=" + ::WT_APPID + "&n=" + ::encode_uri_component(itemMarketHashName)
    local validLink = ::g_url.validateLink(link)
    if (validLink)
      ::open_url(validLink, true)
  }
}
