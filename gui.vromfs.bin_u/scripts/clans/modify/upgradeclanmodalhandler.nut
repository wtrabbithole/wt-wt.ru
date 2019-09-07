class ::gui_handlers.UpgradeClanModalHandler extends ::gui_handlers.ModifyClanModalHandler
{
  owner = null

  function createView()
  {
    return {
      windowHeader = ::loc("clan/upgrade_clan_wnd_title")
      hasClanTypeSelect = false
      hasClanNameSelect = false
      hasClanSloganSelect = false
      hasClanRegionSelect = false
      isNonLatinCharsAllowedInClanName = ::g_clans.isNonLatinCharsAllowedInClanName()
    }
  }

  function initScreen()
  {
    newClanType = clanData.type.getNextType()
    lastShownReq = scene.findObject("req_newclan_tag")
    base.initScreen()
    updateSubmitButtonText()
    resetTagDecorationObj(clanData.tag)
    updateDescription()
    updateAnnouncement()
    scene.findObject("newclan_description").setValue(clanData.desc)
    local newClanTagObj = scene.findObject("newclan_tag")
    newClanTagObj.setValue(::g_clans.stripClanTagDecorators(clanData.tag))
    newClanTagObj.select()
    onFocus(newClanTagObj)

    // Helps to avoid redundant name length check.
    newClanName = clanData.name
  }

  // Override.
  function updateSubmitButtonText()
  {
    local cost = clanData.getClanUpgradeCost()
    setSubmitButtonText(::loc("clan/clan_upgrade/button"), cost)
  }

  // Important override.
  function getSelectedClanType()
  {
    return clanData.type.getNextType()
  }

  function onSubmit()
  {
    if(!prepareClanData())
      return
    local upgradeCost = clanData.getClanUpgradeCost()
    if (upgradeCost <= ::zero_money)
      upgradeClan()
    else if (::check_balance_msgBox(upgradeCost))
    {
      local msgText = ::warningIfGold(
        ::format(::loc("clan/needMoneyQuestion_upgradeClanPrimaryInfo"),
          upgradeCost.getTextAccordingToBalance()),
        upgradeCost)
      msgBox("need_money", msgText, [["ok", function() { upgradeClan() }],
        ["cancel"]], "ok")
    }
  }

  function upgradeClan()
  {
    if (isObsceneWord())
      return
    local clanId = (::my_clan_info != null && ::my_clan_info.id == clanData.id) ? "-1" : clanData.id
    local params = ::g_clans.prepareUpgradeRequest(
      newClanType,
      newClanTag,
      newClanDescription,
      newClanAnnouncement
    )
    ::g_clans.upgradeClan(clanId, params, this)
  }

  function getDecoratorsList()
  {
    // cannot use non-paid decorators for upgrade
    return ::g_clan_tag_decorator.getDecoratorsForClanType(newClanType)
  }
}
