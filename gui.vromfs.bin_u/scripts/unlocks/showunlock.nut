::delayed_unlock_wnd <- []
function showUnlockWnd(config)
{
  if (::isHandlerInScene(::gui_handlers.ShowUnlockHandler) ||
      ::isHandlerInScene(::gui_handlers.RankUpModal) ||
      ::isHandlerInScene(::gui_handlers.TournamentRewardReceivedWnd))
    return ::delayed_unlock_wnd.append(config)

  ::gui_start_unlock_wnd(config)
}

function gui_start_unlock_wnd(config)
{
  local unlockType = ::getTblValue("type", config, -1)
  if (unlockType == ::UNLOCKABLE_COUNTRY)
    return ::show_country_unlock(config)
  else if (unlockType == "TournamentReward")
    return ::gui_handlers.TournamentRewardReceivedWnd.open(config)
  else if (unlockType == ::UNLOCKABLE_AIRCRAFT)
  {
    if (!::has_feature("Tanks") && ::isTank(::getAircraftByName(::getTblValue("id", config))))
      return false
  }

  ::gui_start_modal_wnd(::gui_handlers.ShowUnlockHandler, { config=config })
  return true
}

function check_delayed_unlock_wnd(prevUnlockData = null)
{
  local disableLogId = ::getTblValue("disableLogId", prevUnlockData, null)
  if (disableLogId != null && ::disable_user_log_entry_by_id(disableLogId))
    ::save_online_job()

  if (!::delayed_unlock_wnd.len())
    return

  local unlockData = ::delayed_unlock_wnd.remove(0)
  if (!::gui_start_unlock_wnd(unlockData))
    ::check_delayed_unlock_wnd(unlockData)
}

class ::gui_handlers.ShowUnlockHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/showUnlock.blk"
  sceneNavBlkName = "gui/showUnlockTakeAirNavBar.blk"

  needShowUnitTutorial = false

  config = null
  unit = null
  slotbarActions = [ "take", "weapons", "info" ]

  function initScreen()
  {
    if (!config)
      return

    guiScene.setUpdatesEnabled(false, false)
    scene.findObject("award_name").setValue(config.name)

    if (::getTblValue("type", config, -1) == ::UNLOCKABLE_AIRCRAFT || "unitName" in config)
    {
      local id = ::getTblValue("id", config)
      local unitName = ::getTblValue("unitName", config, id)
      unit = ::getAircraftByName(unitName)
      updateUnitItem()
    }

    updateTexts()
    updateImage()
    guiScene.setUpdatesEnabled(true, true)
    checkUnitTutorial()
    updateButtons()
  }

  function updateUnitItem()
  {
    if (!unit)
      return

    local params = {active = true}
    local data = ::build_aircraft_item(unit.name, unit, params)
    local airObj = scene.findObject("reward_aircrafts")
    guiScene.replaceContentFromText(airObj, data, data.len(), this)
    ::fill_unit_item_timers(airObj.findObject(unit.name), unit, params)
  }

  function updateTexts()
  {
    local desc = ::getTblValue("desc", config)
    if (desc)
    {
      local descObj = scene.findObject("award_desc")
      if (::checkObj(descObj))
      {
        descObj.setValue(desc)

        if("descAlign" in config)
          descObj["text-align"] = config.descAlign
      }
    }

    local rewardText = ::getTblValue("rewardText", config, "")
    if (rewardText != "")
    {
      local rewObj = scene.findObject("award_reward")
      if (::checkObj(rewObj))
        rewObj.setValue(::loc("challenge/reward") + " " + config.rewardText)
    }

    local nObj = scene.findObject("next_award")
    if (::checkObj(nObj) && ("id" in config))
      nObj.setValue(::get_next_award_text(config.id))
  }

  function updateImage()
  {
    local image = ::g_language.getLocTextFromConfig(config, "popupImage", "")
    if (image == "")
      return

    local imgObj = scene.findObject("award_image")
    if (!::checkObj(imgObj))
      return

    imgObj["background-image"] = image

    if ("ratioHeight" in config)
      imgObj["height"] = config.ratioHeight + "w"
    else if ("id" in config)
    {
      local unlockBlk = ::g_unlocks.getUnlockById(config.id)
      if (unlockBlk && unlockBlk.aspect_ratio)
        imgObj["height"] = unlockBlk.aspect_ratio + "w"
    }
  }

  function updateButtons()
  {
    showSceneBtn("btn_sendEmail", ::getTblValue("showSendEmail", config, false)
                                  && !::is_vietnamese_version())

    showSceneBtn("btn_postLink", ::has_feature("FacebookWallPost")
                                 && ::getTblValue("showPostLink", config, false))

    local linkText = ::g_promo.getLinkText(config)
    local show = linkText != ""
    local linkObj = showSceneBtn("btn_link_to_site", show)
    if (show)
    {
      if (::checkObj(linkObj))
      {
        linkObj.link = linkText
        local linkBtnText = ::g_promo.getLinkBtnText(config)
        if (linkBtnText != "")
          ::set_double_text_to_button(scene, "btn_link_to_site", linkBtnText)
      }

      local imageObj = scene.findObject("award_image_button")
      if (::checkObj(imageObj))
        imageObj.link = linkText
    }

    local showSetAir = unit != null && unit.isUsable() && !::isUnitInSlotbar(unit)
    local canBuyOnline = unit != null && ::canBuyUnitOnline(unit)
    local canBuy = unit != null && !unit.isRented() && !unit.isBought() && (::canBuyUnit(unit) || canBuyOnline)
    showSceneBtn("btn_set_air", showSetAir)
    local okObj = showSceneBtn("btn_ok", !showSetAir)
    if ("okBtnText" in config)
      okObj.setValue(::loc(config.okBtnText))

    showSceneBtn("btn_close", !showSetAir || !needShowUnitTutorial)

    local buyObj = showSceneBtn("btn_buy_unit", canBuy)
    if (canBuy && ::checkObj(buyObj))
    {
      local locText = ::loc("shop/btnOrderUnit", { unit = ::getUnitName(unit.name) })
      local unitCost = canBuyOnline? ::Cost() : ::getUnitCost(unit)
      ::placePriceTextToButton(scene, "btn_buy_unit", locText, unitCost)
    }

    ::show_facebook_screenshot_button(scene, ::getTblValue("showShareBtn", config, false))
  }

  function onTake(unitToTake = null)
  {
    if (!unitToTake && !unit)
      return

    if (!unitToTake)
      unitToTake = unit

    if (needShowUnitTutorial)
      ::saveLocalByAccount("tutor/takeUnit", true)

    local handler = this
    ::gui_start_selecting_crew({unit = unitToTake,
                               unitObj = scene.findObject(unitToTake.name),
                               cellClass = "slotbarClone",
                               useTutorial = needShowUnitTutorial,
                               afterSuccessFunc = (@(handler) function() { handler.goBack() })(handler)
                              })
    needShowUnitTutorial = false
  }

  function onTakeNavBar(obj)
  {
    onTake()
  }

  function onMsgLink(obj)
  {
    if(::getTblValue("type", config) == "regionalPromoPopup")
      ::add_big_query_record("promo_popup_click", ::save_to_json(
        {id = ::u.getFirstFound(["id", "link", "popupImage"], [config], -1)}))
    ::g_promo.openLink(this, [obj.link, ::getTblValue("forceExternalBrowser", config, false)],
      "show_unlock")
  }

  function buyUnit()
  {
    if (::canBuyUnitOnline(unit))
      OnlineShopModel.showGoods({unitName = unit.name})
    else
      ::buyUnit(unit)
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }

  function onEventCrewTakeUnit(params)
  {
    if (needShowUnitTutorial)
      return goBack()

    updateUnitItem()
  }

  function onEventUnitBought(params)
  {
    updateUnitItem()
    updateButtons()
    onTake()
  }

  function afterModalDestroy()
  {
    ::check_delayed_unlock_wnd(config)
  }

  function sendInvitation()
  {
    sendInvitationEmail()
  }

  function sendInvitationEmail()
  {
    local linkString = ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)
    local msg_head = ::format(::loc("mainmenu/invitationHead"), ::my_user_name)
    local msg_body = ::format(::loc("mainmenu/invitationBody"), linkString)
    ::shell_launch("mailto:yourfriend@email.com?subject=" + msg_head + "&body=" + msg_body)
  }

  function onFacebookPostLink()
  {
    local link = ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)
    local message = ::loc("facebook/wallMessage")
    ::make_facebook_login_and_do((@(link, message) function() {
                 ::scene_msg_box("facebook_login", null, ::loc("facebook/uploading"), null, null)
                 ::facebook_post_link(link, message)
               })(link, message), this)
  }

  function onOk()
  {
    local onOkFunc = ::getTblValue("onOkFunc", config)
    if (onOkFunc)
      onOkFunc()
    goBack()
  }

  function checkUnitTutorial()
  {
    if (!unit)
      return

    local showedHelp = ::loadLocalByAccount("tutor/takeUnit", !::is_me_newbie())
    if (showedHelp)
      return

    needShowUnitTutorial = true
  }

  function goBack()
  {
    if (needShowUnitTutorial)
      onTake()
    else
      base.goBack()
  }
}
