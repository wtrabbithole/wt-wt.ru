local time = require("scripts/time.nut")
local platformModule = require("scripts/clientState/platform.nut")

::fill_gamer_card <- function fill_gamer_card(cfg = null, show = true, prefix = "gc_", scene = null, save_scene=true)
{
  if (!::checkObj(scene))
  {
    scene = ::getLastGamercardScene()
    if (!scene)
      return
  }
  local getObj = (@(scene) function(id) {
    return scene.findObject(id)
  })(scene)

  local div = getObj("gamercard_div")
  if (::check_obj(div))
    ::show_title_logo(true, div)
  show = show && ::g_login.isLoggedIn()
  if (::checkObj(div))
    div.show(show)

  if (scene && save_scene && prefix=="gc_" && ::checkObj(div))
    ::add_gamercard_scene(scene)

  if (!show)
    return

  if (!cfg)
    cfg = ::get_profile_info()

  local showClanTag = false
  foreach(name, val in cfg)
  {
    local obj = getObj(prefix+name)
    if (::checkObj(obj))
      switch(name)
      {
        case "country":
          obj["background-image"] = ::get_country_icon(val)
          break
        case "rankProgress":
          local value = val.tointeger()
          if (value >= 0)
            obj.setValue(val.tointeger())
          obj.show(value >= 0 && show)
          break
        case "prestige":
          if (val != null)
            obj["background-image"] = "#ui/gameuiskin#prestige" + val
          local titleObj = getObj(prefix + "prestige_title")
          if (titleObj)
          {
            local prestigeTitle = (val > 0)
                                  ? ::loc("rank/prestige" + val)
                                  : ""
            titleObj.setValue(prestigeTitle)
          }
          break
        case "exp":
          local expTable = ::get_cur_exp_table("", cfg)
          obj.setValue(expTable? (::g_language.decimalFormat(expTable.exp) + ::nbsp + "/" + ::nbsp +
            ::g_language.decimalFormat(expTable.rankExp)) : "")
          obj.tooltip = ::loc("ugm/total") + ::loc("ui/colon") +
            ::g_language.decimalFormat(cfg.exp)
          break
        case "clanTag":
          local isVisible = val != ""
          showClanTag = isVisible
          if (isVisible)
          {
            local clanTagName = ::checkClanTagForDirtyWords(val.tostring())
            local btnText = obj.findObject(prefix + name + "_name")
            if (::check_obj(btnText))
              btnText.setValue(clanTagName)
            else
              obj.setValue(clanTagName)
          }
          break
        case "gold":
          local moneyInst = ::Money(money_type.none, 0, val)
          local valStr = moneyInst.toStringWithParams({isGoldAlwaysShown = true})

          local tooltipText = ::colorize("activeTextColor", valStr)
          tooltipText += "\n" + ::loc("mainmenu/gold")
          obj.getParent().tooltip = tooltipText

          obj.setValue(moneyInst.toStringWithParams({isGoldAlwaysShown = true, needIcon = false}))
          break
        case "balance":
          local valStr = ::g_language.decimalFormat(val)
          local tooltipText = ::getWpPriceText(::colorize("activeTextColor", valStr), true) + "\n" + ::loc("mainmenu/warpoints")
          local bonus = ::get_current_bonuses_text(::BoosterEffectType.WP)
          if (!::u.isEmpty(bonus))
          {
            local title = "\n\n<b>" + ::loc("mainmenu/bonusTitle") + ::loc("ui/colon") + "</b>"
            tooltipText += title + "\n" + bonus
          }

          local buttonObj = obj.getParent()
          buttonObj.tooltip = tooltipText
          buttonObj.showBonusCommon = ::have_active_bonuses_by_effect_type(::BoosterEffectType.WP, false)? "yes" : "no"
          buttonObj.showBonusPersonal = ::have_active_bonuses_by_effect_type(::BoosterEffectType.WP, true)? "yes" : "no"

          obj.setValue(valStr)
          break
        case "free_exp":
          local valStr = ::Balance(0,0,val).toStringWithParams({isFrpAlwaysShown = true})
          local tooltipText = ::colorize("activeTextColor", valStr) + "\n" + ::loc("currency/freeResearchPoints/desc")
          local bonus = ::get_current_bonuses_text(::BoosterEffectType.RP)
          if (!::u.isEmpty(bonus))
          {
            local title = "\n\n<b>" + ::loc("mainmenu/bonusTitle") + ::loc("ui/colon") + "</b>"
            tooltipText += title + "\n" + bonus
          }

          obj.tooltip = tooltipText
          obj.showBonusCommon = ::have_active_bonuses_by_effect_type(::BoosterEffectType.RP, false)? "yes" : "no"
          obj.showBonusPersonal = ::have_active_bonuses_by_effect_type(::BoosterEffectType.RP, true)? "yes" : "no"
          break
        case "name":
          if (::u.isEmpty(val))
            val = ::loc("mainmenu/pleaseSignIn")
          else
            val = platformModule.getPlayerName(val)
        default:
          if (val == null)
            val = ""
          obj.setValue(val.tostring())
      }
  }

  if (prefix != "gc_")
    return //not gamercard

  //checklogs
  if (::has_feature("UserLog"))
  {
    local objBtn = getObj(prefix + "userlog_btn")
    if(::check_obj(objBtn))
    {
      local newLogsCount = ::check_new_user_logs().len()
      local haveNew = newLogsCount > 0
      local tooltip = haveNew ?
        format(::loc("userlog/new_messages"), newLogsCount) : ::loc("userlog/no_new_messages")
      ::update_gc_button(objBtn, haveNew, tooltip)
    }
  }

  //chat
  if (gchat_is_enabled() && ::has_feature("Chat"))
  {
    local objBtn = getObj(prefix + "chat_btn")
    if (::check_obj(objBtn))
    {
      local haveNew = ::g_chat.haveNewMessages()
      local tooltip = ::loc(haveNew ? "mainmenu/chat_new_messages" : "mainmenu/chat")
      ::update_gc_button(objBtn, haveNew, tooltip)

      local newCountChatObj = objBtn.findObject(prefix + "new_chat_messages")
      local newMessagesCount = ::g_chat.getNewMessagesCount()
      local newMessagesText = newMessagesCount ? newMessagesCount.tostring() : ""
      newCountChatObj.setValue(newMessagesText)
    }
  }

  if (::has_feature("Friends"))
  {
    local friendsOnline = ::getFriendsOnlineNum()
    local cObj = getObj(prefix + "contacts")
    if (::checkObj(cObj))
      cObj.tooltip = format(::loc("contacts/friends_online"), friendsOnline)

    local fObj = getObj(prefix + "friends_online")
    if (::checkObj(fObj))
      fObj.setValue(friendsOnline > 0? friendsOnline.tostring() : "")
  }

  local totalText = ""
  foreach(name in ["PremiumAccount", "RateWeek"])
  {
    local expire = ::entitlement_expires_in(name)
    local text = ::loc("mainmenu/noPremium")
    local premPic = "#ui/gameuiskin#sub_premium_noactive"
    if (expire > 0)
    {
      text = ::loc("charServer/entitlement/" + name) + ::loc("ui/colon") + time.getExpireText(expire)
      totalText += ((totalText=="")? "":"\n") + text
      premPic = "#ui/gameuiskin#sub_premiumaccount"
    }
    local obj = getObj(prefix+name)
    if (obj && obj.isValid())
    {
      local icoObj = obj.findObject("gc_prempic")
      if (::checkObj(icoObj))
        icoObj["background-image"] = premPic
      obj.tooltip = text
    }
  }
  if (totalText!="")
  {
    local name = prefix+"subscriptions"
    local obj = getObj(name)
    if (obj && obj.isValid())
    {
      obj.show(true)
      obj.tooltip = totalText
    }
  }

  local queueTextObj = getObj("gc_queue_wait_text")
  ::g_qi_view_utils.updateShortQueueInfo(queueTextObj, queueTextObj, getObj("gc_queue_wait_icon"))

  local canSpendGold = ::has_feature("SpendGold")
  local featureEnablePremiumPurchase = ::has_feature("EnablePremiumPurchase")
  local canHaveFriends = ::has_feature("Friends")
  local canChat = ::has_feature("Chat")
  local is_in_menu = ::isInMenu()
  local hasPremiumAccount = ::entitlement_expires_in("PremiumAccount") > 0

  local buttonsShowTable = {
                             gc_clanTag = showClanTag
                             gc_profile = ::has_feature("Profile")
                             gc_contacts = canHaveFriends
                             gc_chat_btn = canChat
                             gc_shop = is_in_menu && canSpendGold
                             gc_eagles = canSpendGold
                             gc_warpoints = ::has_feature("WarpointsInMenu")
                             gc_PremiumAccount = (canSpendGold && featureEnablePremiumPurchase) || hasPremiumAccount
                             gc_dropdown_premium_button = featureEnablePremiumPurchase
                             gc_dropdown_shop_eagles_button = canSpendGold
                             gc_free_exp = ::has_feature("SpendGold") && ::has_feature("SpendFreeRP")
                             gc_items_shop_button = ::ItemsManager.isEnabled() && ::has_feature("ItemsShop")
                             gc_online_shop_button = ::has_feature("OnlineShopPacks")
                             gc_clanAlert = ::g_clans.getUnseenCandidatesCount() > 0
                             gc_invites_btn = !::is_platform_xboxone || ::has_feature("XboxCrossConsoleInteraction")
                           }

  foreach(id, status in buttonsShowTable)
  {
    local bObj = getObj(id)
    if (::checkObj(bObj))
    {
      bObj.show(status)
      bObj.enable(status)
      bObj.inactive = status? "no" : "yes"
    }
  }

  local buttonsEnableTable = {
                                gc_clanTag = showClanTag && is_in_menu
                                gc_contacts = canHaveFriends
                                gc_chat_btn = canChat && ::g_chat.isChatEnabled()
                                gc_free_exp = canSpendGold && is_in_menu
                                gc_warpoints = canSpendGold && is_in_menu
                                gc_eagles = canSpendGold && is_in_menu
                                gc_PremiumAccount = canSpendGold && featureEnablePremiumPurchase && is_in_menu
                              }

  foreach(id, status in buttonsEnableTable)
  {
    local pObj = getObj(id)
    if (::checkObj(pObj))
    {
      pObj.enable(status)
      pObj.inactive = status? "no" : "yes"
    }
  }

  ::g_discount.updateDiscountNotifications(scene)
  ::setVersionText(scene)
  ::server_message_update_scene(scene)
  ::update_gc_invites(scene)
}

::update_gamercards <- function update_gamercards()
{
  local info = ::get_profile_info()
  for(local idx=::last_gamercard_scenes.len()-1; idx>=0; idx--)
  {
    local s = ::last_gamercard_scenes[idx]
    if (!s || !s.isValid())
      ::last_gamercard_scenes.remove(idx)
    else
      ::fill_gamer_card(info, true, "gc_", s, false)
  }
  checkNewNotificationUserlogs()
  ::broadcastEvent("UpdateGamercard")
}

::do_with_all_gamercards <- function do_with_all_gamercards(func)
{
  foreach(scene in ::last_gamercard_scenes)
    if (::checkObj(scene))
      func(scene)
}

::last_gamercard_scenes <- []
::add_gamercard_scene <- function add_gamercard_scene(scene)
{
  for(local idx=::last_gamercard_scenes.len()-1; idx>=0; idx--)
  {
    local s = ::last_gamercard_scenes[idx]
    if (!::checkObj(s))
      ::last_gamercard_scenes.remove(idx)
    else if (s.isEqual(scene))
      return
  }
  ::last_gamercard_scenes.append(scene)
}

::set_last_gc_scene_if_exist <- function set_last_gc_scene_if_exist(scene)
{
  foreach(idx, gcs in ::last_gamercard_scenes)
    if (::check_obj(gcs) && scene.isEqual(gcs)
        && idx < ::last_gamercard_scenes.len()-1)
    {
      ::last_gamercard_scenes.remove(idx)
      ::last_gamercard_scenes.append(scene)
      break
    }
}

::getLastGamercardScene <- function getLastGamercardScene()
{
  if(::last_gamercard_scenes.len() > 0)
    for(local i = ::last_gamercard_scenes.len() - 1; i >= 0; i--)
      if(::checkObj(::last_gamercard_scenes[i]))
        return ::last_gamercard_scenes[i]
      else
        ::last_gamercard_scenes.remove(i)
  return null
}

::update_gc_invites <- function update_gc_invites(scene)
{
  local haveNew = ::g_invites.newInvitesAmount > 0
  ::update_gc_button(scene.findObject("gc_invites_btn"), haveNew)
}

::update_gc_button <- function update_gc_button(obj, isNew, tooltip = null)
{
  if(!::check_obj(obj))
    return

  if (tooltip)
    obj.tooltip = tooltip

  ::showBtnTable(obj, {
    icon    = !isNew
    iconNew = isNew
  })

  local objGlow = obj.findObject("iconGlow")
  if (::check_obj(objGlow))
    objGlow.wink = isNew ? "yes" : "no"
}

::get_active_gc_popup_nest_obj <- function get_active_gc_popup_nest_obj()
{
  local gcScene = ::getLastGamercardScene()
  local nestObj = gcScene ? gcScene.findObject("chatPopupNest") : null
  return ::check_obj(nestObj) ? nestObj : null
}

::update_clan_alert_icon <- function update_clan_alert_icon()
{
  local needAlert = ::g_clans.getUnseenCandidatesCount() > 0
  ::do_with_all_gamercards(
    (@(needAlert) function(scene) {
      ::showBtn("gc_clanAlert", needAlert, scene)
    })(needAlert))
}
