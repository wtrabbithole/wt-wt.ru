local time = require("scripts/time.nut")


function fill_gamer_card(cfg = null, show = true, prefix = "gc_", scene = null, save_scene=true)
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
  local logoFound = ::checkObj(div) ? ::show_title_logo(true, div) : false
  local show = show && ::g_login.isLoggedIn()
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
        case "icon":
          obj["background-image"] = prefix == "gc_" ? ("#ui/opaque#" + val + "_ico") : ("#ui/images/avatars/" + val)
          break
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
          obj.setValue(expTable? (expTable.exp + "/" + expTable.rankExp) : "")
          obj.tooltip = ::loc("ugm/total") + ::loc("ui/colon") + cfg.exp
          break
        case "clanTag":
          local show = val != ""
          showClanTag = show
          if (show)
          {
            local btnText = obj.findObject("gc_clanTag_name")
            if (::checkObj(btnText))
              btnText.setValue(::checkClanTagForDirtyWords(val.tostring()))
          }
          break
        case "gold":
          local valStr = ::g_string.intToStrWithDelimiter(val)
          local tooltipText = ::getGpPriceText(::colorize("activeTextColor", valStr), true)
          tooltipText += "\n" + ::loc("mainmenu/gold")
          obj.getParent().tooltip = tooltipText

          obj.setValue(valStr)
          break
        case "balance":
          local valStr = ::g_string.intToStrWithDelimiter(val)
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
          local valStr = ::g_string.intToStrWithDelimiter(val)
          local tooltipText = ::getFreeRpPriceText(::colorize("activeTextColor", valStr), true) + "\n" + ::loc("currency/freeResearchPoints/desc")
          local bonus = ::get_current_bonuses_text(::BoosterEffectType.RP)
          if (!::u.isEmpty(bonus))
          {
            local title = "\n\n<b>" + ::loc("mainmenu/bonusTitle") + ::loc("ui/colon") + "</b>"
            tooltipText += title + "\n" + bonus
          }

          obj.tooltip = tooltipText
          obj.showBonusCommon = ::have_active_bonuses_by_effect_type(::BoosterEffectType.RP, false)? "yes" : "no"
          obj.showBonusPersonal = ::have_active_bonuses_by_effect_type(::BoosterEffectType.RP, true)? "yes" : "no"

          local textObj = obj.findObject("gc_free_exp_text")
          if (::checkObj(textObj))
            textObj.setValue(::getShortTextFromNum(valStr))
          break
        case "name":
          if (::u.isEmpty(val))
            val = ::loc("mainmenu/pleaseSignIn")
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
    local logObj = getObj(prefix+"userlog")
    if (logObj && logObj.isValid())
    {
      local newLogs = ::check_new_user_logs().len()
      logObj.show(newLogs==0)
      local newLogObj = getObj(prefix+"new_userlog")
      newLogObj.wink = newLogs>0? "yes" : "no"
      newLogObj.tooltip = format(::loc("userlog/new_messages"), newLogs)
    }
  }

  //chat
  if (gchat_is_enabled() && ::has_feature("Chat"))
  {
    local chatObj = getObj(prefix+"chat")
    if (::checkObj(chatObj))
    {
      local haveNewMessages = ::g_chat.haveNewMessages()
      chatObj.show(!haveNewMessages)
      local newChatObj = getObj(prefix+"new_chat")
      newChatObj.wink = haveNewMessages ? "yes" : "no"

      local newCountChatObj = getObj(prefix+"new_chat_messages")
      local newMessagesCount = ::g_chat.getNewMessagesCount()
      local newMessagesText = ""
      if (newMessagesCount != 0)
        newMessagesText = newMessagesCount.tostring()

      newCountChatObj.setValue(newMessagesText)
    }

    local chat
  }

  if (::has_feature("Friends"))
  {
    local friendsOnline = ::getFriendsOnlineNum()
    local fObj = getObj(prefix + "contacts")
    if (::checkObj(fObj))
      fObj.tooltip = format(::loc("contacts/friends_online"), friendsOnline)

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
                             gc_contacts = canHaveFriends
                             gc_chat_btn = canChat
                             gc_shop = is_in_menu && canSpendGold
                             gc_eagles = canSpendGold
                             gc_PremiumAccount = canSpendGold && featureEnablePremiumPurchase || hasPremiumAccount
                             gc_dropdown_premium_button = featureEnablePremiumPurchase
                             gc_dropdown_shop_eagles_button = canSpendGold
                             gc_items_shop_button = ::ItemsManager.isEnabled() && ::has_feature("ItemsShop")
                             gc_online_shop_button = ::has_feature("OnlineShopPacks")
                             gc_clanAlert = ::g_clans.getUnseenCandidatesCount() > 0
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

  local disableForPs4Temporary = !(::is_platform_ps4 && ::is_in_loading_screen()) //!!!HACK, till hover is not working on loading
  local buttonsEnableTable = {
                                gc_clanTag = showClanTag && is_in_menu
                                gc_profile = disableForPs4Temporary
                                gc_contacts = canHaveFriends && disableForPs4Temporary
                                gc_chat_btn = canChat && ::ps4_is_chat_enabled() && disableForPs4Temporary
                                gc_userlog_btn = disableForPs4Temporary
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

  local battleButtonObj = getObj("gamercard_tobattle")
  if (::checkObj(battleButtonObj))
    battleButtonObj.allowDecreaseFont = ::is_low_width_screen()? "yes" : "no"

  ::update_discount_notifications(scene)
  ::setVersionText(scene)
  ::server_message_update_scene(scene)
  ::update_gc_invites(scene)
}

function update_gamercards()
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

function do_with_all_gamercards(func)
{
  foreach(scene in ::last_gamercard_scenes)
    if (::checkObj(scene))
      func(scene)
}

::last_gamercard_scenes <- []
function add_gamercard_scene(scene)
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

function set_last_gc_scene_if_exist(scene)
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

function getLastGamercardScene()
{
  if(::last_gamercard_scenes.len() > 0)
    for(local i = ::last_gamercard_scenes.len() - 1; i >= 0; i--)
      if(::checkObj(::last_gamercard_scenes[i]))
        return ::last_gamercard_scenes[i]
      else
        ::last_gamercard_scenes.remove(i)
  return null
}

function update_gc_invites(scene)
{
  local obj = scene.findObject("gc_invites")
  local objNew = scene.findObject("gc_new_invites")
  if (!::checkObj(obj) || !::checkObj(objNew))
    return

  local hasNew = ::g_invites.newInvitesAmount > 0
  obj.show(!hasNew)
  objNew.wink = hasNew ? "yes" : "no"
}

function get_active_gc_popup_nest_obj()
{
  local gcScene = ::getLastGamercardScene()
  local nestObj = gcScene ? gcScene.findObject("chatPopupNest") : null
  return ::check_obj(nestObj) ? nestObj : null
}

function update_clan_alert_icon()
{
  local needAlert = ::g_clans.getUnseenCandidatesCount() > 0
  ::do_with_all_gamercards(
    (@(needAlert) function(scene) {
      ::showBtn("gc_clanAlert", needAlert, scene)
    })(needAlert))
}
