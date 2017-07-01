enum profileEvent {
  AVATAR_CHANGED = "AvatarChanged"
}

enum OwnUnitsType
{
  ALL = "all",
  BOUGHT = "only_bought",
}

function gui_start_profile(curPage = "")
{
  ::gui_start_modal_wnd(::gui_handlers.Profile, { initialSheet = curPage })
}

class ::gui_handlers.Profile extends ::gui_handlers.UserCardHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/profile.blk"
  initialSheet = ""

  curDifficulty = "any"
  curPlayerMode = 0
  curFilter = ""
  curSubFilter = -1
  curFilterType = ""
  airStatsInited = false
  profileInited = false

  airStatsList = null
  statsType = ::ETTI_VALUE_INHISORY
  statsMode = ""
  statsCountries = null
  statsSortBy = ""
  statsSortReverse = false
  curStatsPage = 0

  pending_logout = false

  presetSheetList = ["Profile", "Statistics", "Medal", "UnlockAchievement", "UnlockSkin", "UnlockDecal"]

  tabImageNamePrefix = "#ui/gameuiskin#sh_"
  tabLocalePrefix = "#mainmenu/btn"
  defaultTabImageName = "unlockachievement"

  sheetsList = null
  customMenuTabs = null

  curPage = ""

  unlockTypesToShow = [
    ::UNLOCKABLE_ACHIEVEMENT,
    ::UNLOCKABLE_CHALLENGE,
    ::UNLOCKABLE_SKIN,
    ::UNLOCKABLE_TITLE,
    ::UNLOCKABLE_MEDAL,
    ::UNLOCKABLE_DECAL,
    ::UNLOCKABLE_TROPHY
    ::UNLOCKABLE_TROPHY_PSN
    ::UNLOCKABLE_TROPHY_STEAM
  ]

  unlocksPages = {
    achievement = ::UNLOCKABLE_ACHIEVEMENT
    skin = ::UNLOCKABLE_SKIN
    decal = ::UNLOCKABLE_DECAL
    challenge = ::UNLOCKABLE_CHALLENGE
    medal = ::UNLOCKABLE_MEDAL
    title = ::UNLOCKABLE_TITLE
  }

  unlocksTree = {}
  skinsCache = null
  uncollapsedChapterName = null

  unlockFilters = {
    Medal = []
    UnlockAchievement = null
    UnlockChallenge = null
    UnlockSkin = []
    UnlockDecal = []
    /*
    Unlock = [
      {page = "Achievement"}
      {page = "Skin"}
      {page = "Decal"}
    ]
    */
  }

  filterTable = {
    Medal = "country"
    UnlockDecal = "category"
    UnlockSkin = "airCountry"
  }

  function initScreen()
  {
    if (!scene)
      return goBack()

    isOwnStats = true
    scene.findObject("profile_update").setUserData(this)

    //prepare options
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)
//    local container = create_options_container("options_profile", profileOptions, true, true, true)
//    local profileObj = scene.findObject("profile-optionsbox")
//    guiScene.replaceContentFromText(profileObj, container.tbl, container.tbl.len(), this)
//    profileObj.scrollType = "center"
//    optionsContainers.push(container.descr)

    initStatsParams()
    initSheetsList()
    initTabs()

    unlocksTree = {}

    //fill decals categories
    if ("UnlockDecal" in unlockFilters)
      unlockFilters.UnlockDecal = ::g_decorator.getCachedOrderByType(::g_decorator_type.DECALS)

    //fill skins filters
    if ("UnlockSkin" in unlockFilters)
    {
      local skinCountries = getUnlockFiltersList("skin", function(unlock)
        {
          local country = getSkinCountry(unlock.getStr("id", ""))
          return (country != "")? country : null
        })

      unlockFilters.UnlockSkin = []
      foreach(c in skinCountries)
        unlockFilters.UnlockSkin.append(c)
    }

    //fill skins filters
    if ("Medal" in unlockFilters)
    {
      local countries = getUnlockFiltersList("medal", function(unlock)
        {
          return unlock.country
        })

      unlockFilters.Medal = []
      foreach(c in countries)
        unlockFilters.Medal.append(c)
    }

    initLeaderboardModes()

    onSheetChange(null)
    initShortcuts()
    initFocusArray()
  }

  function initSheetsList()
  {
    customMenuTabs = {}
    sheetsList = clone presetSheetList
    local hasAnyUnlocks = false
    local hasAnyMedals = false //skins and decals tab also have resources without unlocks

    local customCategoryConfig = ::getTblValue("customProfileMenuTab", ::get_gui_regional_blk(), null)
    local tabImage = null
    local tabText = null

    foreach(cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      local unlockType = cb.type || ""
      local unlockTypeId = ::get_unlock_type(unlockType)

      if (!::isInArray(unlockTypeId, unlockTypesToShow))
        continue
      if (!::is_unlock_visible(cb))
        continue

      hasAnyUnlocks = true
      if (unlockTypeId == ::UNLOCKABLE_MEDAL)
        hasAnyMedals = true

      if (!cb.customMenuTab)
        continue

      local lowerCaseTab = cb.customMenuTab.tolower()
      if (lowerCaseTab in customMenuTabs)
        continue

      sheetsList.push(lowerCaseTab)
      unlockFilters[lowerCaseTab]  <- null

      if (cb.customMenuTab in customCategoryConfig)
      {
        tabImage = ::getTblValue("image", customCategoryConfig[cb.customMenuTab], tabImageNamePrefix + defaultTabImageName)
        tabText = tabLocalePrefix + ::getTblValue("title", customCategoryConfig[cb.customMenuTab], cb.customMenuTab)
      }
      else
      {
        tabImage = tabImageNamePrefix + defaultTabImageName
        tabText = tabLocalePrefix + cb.customMenuTab
      }
      customMenuTabs[lowerCaseTab] <- {
        image = tabImage
        title = tabText
      }
    }

    local sheetsToHide = []
    if (!hasAnyMedals)
      sheetsToHide.append("Medal")
    if (!hasAnyUnlocks)
      sheetsToHide.append("UnlockAchievement")
    foreach(sheetName in sheetsToHide)
    {
      local idx = sheetsList.find(sheetName)
      if (idx >= 0)
        sheetsList.remove(idx)
    }
  }

  function initTabs()
  {
    local view = { tabs = [] }
    local curSheetIdx = 0
    local tabImage = null
    local tabText = null

    foreach(idx, sheet in sheetsList)
    {
      if (sheet in customMenuTabs)
      {
        tabImage = customMenuTabs[sheet].image
        tabText = customMenuTabs[sheet].title
      }
      else
      {
        tabImage = tabImageNamePrefix + sheet.tolower()
        tabText = tabLocalePrefix + sheet
      }

      view.tabs.append({
        id = sheet
        tabImage = tabImage
        tabName = tabText
        navImagesText = ::get_navigation_images_text(idx, sheetsList.len())
        hidden = !isSheetVisible(sheet)
      })

      if (initialSheet == sheet)
        curSheetIdx = idx
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local sheetsListObj = scene.findObject("profile_sheet_list")
    guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(curSheetIdx)
  }

  function isSheetVisible(sheetName)
  {
    if (sheetName == "Medal")
      return ::has_feature("ProfileMedals")
    return true
  }

  function initShortcuts()
  {
    local obj = scene.findObject("btn_profile_icon")
    if (::checkObj(obj))
      obj.btnName = "X"
    obj = scene.findObject("profile-currentUser-title")
    if (::checkObj(obj))
      obj.btnName = "Y"
  }

  function getUnlockFiltersList(type, getCategoryFunc)
  {
    local categories = []
    local unlocks = ::g_unlocks.getUnlocksByType(type)
    foreach(unlock in unlocks)
      if (::is_unlock_visible(unlock))
        ::append_once(getCategoryFunc(unlock), categories, true)

    return categories
  }

  function updateButtons()
  {
    local sheet = getCurSheet()
    local isProfileOpened = sheet == "Profile"
    local buttonsList = {
                          btn_changeAccount = ::isInMenu() && isProfileOpened && !::is_platform_ps4 && !::is_vendor_tencent()
                          btn_changeName = ::isInMenu() && isProfileOpened && !::is_platform_ps4 && !::is_vendor_tencent()
                          btn_getLink = !::is_in_loading_screen() && isProfileOpened && ::has_feature("Invites")
                          btn_ps4Registration = isProfileOpened && ::is_platform_ps4 && ::check_account_tag("psnlogin")
                          btn_SteamRegistration = isProfileOpened && ::steam_is_running() && ::check_account_tag("steamlogin")
                          paginator_place = (sheet == "Statistics") && airStatsList && (airStatsList.len() > statsPerPage)
                        }
    foreach(name, show in buttonsList)
      scene.findObject(name).show(show)
  }

  function onSheetChange(obj)
  {
    local sheet = getCurSheet()
    curFilterType = ""
    foreach(btn in ["btn_top_place", "btn_pagePrev", "btn_pageNext", "checkbox_only_for_bought"])
      showSceneBtn(btn, false)

    if (sheet == "Profile")
    {
      showSheetDiv("profile")
      if (!profileInited)
      {
        updateStats()
        profileInited = true
      }
    }
    else if (sheet=="Statistics")
    {
      showSheetDiv("stats")
      fillAirStats()
    }
    else if (sheet=="Medal" || sheet=="UnlockDecal")
    {
      showSheetDiv("decals", true)

      local selCategory = ""
      if (sheet == "UnlockDecal")
        selCategory = ::loadLocalByAccount("wnd/decalsCategory", "")
      else if (sheet == "Medal")
        selCategory = ::get_profile_info().country

      local selIdx = 0
      local view = { items = [] }
      foreach (idx, filter in unlockFilters[sheet])
      {
        if ((sheet == "Medal" || sheet == "UnlockDecal") && filter == selCategory)
          selIdx = idx

        view.items.append({
          text = (sheet == "Medal"? ("#") : ("#decals/category/")) + filter
        })
      }

      local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
      local pageList = scene.findObject("decals_list")
      guiScene.replaceContentFromText(pageList, data, data.len(), this)

      pageList.setValue(selIdx)
      onPageChange(null)
    }
    else if (sheet in unlockFilters)
    {
      if ((!unlockFilters[sheet]) || (unlockFilters[sheet].len() < 1))
      {
        //challange and achievents
        showSheetDiv("unlocks")
        curPage = getPageIdByName(sheet)
        fillUnlocksList()
      }
      else
      {
        showSheetDiv("unlocks", true, true)
        local pageList = scene.findObject("pages_list")
        local curCountry = ::get_profile_info().country
        local selIdx = 0

        local view = { items = [] }
        foreach(idx, item in unlockFilters[sheet])
        {
          selIdx = item == curCountry ? idx : selIdx
          view.items.append({ text = "#" + item })
        }

        local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
        guiScene.replaceContentFromText(pageList, data, data.len(), this)  // fill countries listbox
        pageList.setValue(selIdx)
        if (selIdx <= 0)
          onPageChange(null)
      }
    }
    else
      showSheetDiv("")

    updateButtons()
    focusCurSheetObj()
  }

  function getPageIdByName(name)
  {
    local start = name.find("Unlock")
    if (start!=null)
      return name.slice(start+6)
    return name
  }

  function showSheetDiv(name, pages = false, subPages = false)
  {
    foreach(div in ["profile", "unlocks", "stats", "decals"])
    {
      local show = div == name
      local divObj = scene.findObject(div + "-container")
      if (::checkObj(divObj))
      {
        divObj.show(show)
        if (show)
          updateDifficultySwitch(divObj)
      }
    }
    showSceneBtn("pages_list", pages)
    showSceneBtn("unit_type_list", subPages)
  }

  function onPageChange(obj)
  {
    local pageIdx = 0
    local sheet = getCurSheet()
    if (!(sheet in unlockFilters) || !unlockFilters[sheet])
      return

    if(sheet=="Medal" || sheet=="UnlockDecal")
      pageIdx = scene.findObject("decals_list").getValue()
    else
      pageIdx = scene.findObject("pages_list").getValue()

    if (pageIdx < 0 || pageIdx >= unlockFilters[sheet].len())
      return

    local filter = unlockFilters[sheet][pageIdx]
    curPage = ("page" in filter)? filter.page : getPageIdByName(sheet)

    if (sheet == "UnlockDecal")
      ::saveLocalByAccount("wnd/decalsCategory", filter)

    curFilterType = ::getTblValue(sheet, filterTable, "")

    if (curFilterType != "")
      curFilter = filter

    if (getCurSheet() == "UnlockSkin")
      refreshUnitTypeControl()
    else
      fillUnlocksList()
  }

  function onSubPageChange(obj = null)
  {
    local subSwitch = getObj("unit_type_list")
    if (::check_obj(subSwitch))
    {
      curSubFilter = ::getTblValue(subSwitch.getValue(), ::unitTypesList, ::ES_UNIT_TYPE_INVALID)
      refreshOwnUnitControl(subSwitch.getValue())
    }
    fillUnlocksList()
  }

  function onOnlyForBoughtCheck(obj)
  {
    onSubPageChange()
  }

  function refreshUnitTypeControl()
  {
    local unitypeListObj = scene.findObject("unit_type_list")
    if ( ! ::check_obj(unitypeListObj))
      return

    if ( ! unitypeListObj.childrenCount())
    {
      local view = { items = [] }
      foreach(unitType in ::unitTypesList)
        view.items.append({text = ::get_unit_type_army_text(unitType)})

      local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
      guiScene.replaceContentFromText(unitypeListObj, data, data.len(), this)
    }

    local indexForSelection = -1
    local previousSelectedIndex = unitypeListObj.getValue()
    local total = unitypeListObj.childrenCount()
    for(local i = 0; i < total; i++)
    {
      local obj = unitypeListObj.getChild(i)
      local unitType = ::getTblValue(i, ::unitTypesList, ::ES_UNIT_TYPE_INVALID)
      local isVisible = getSkinsCache(curFilter, unitType, OwnUnitsType.ALL).len() > 0
      if (isVisible && (indexForSelection == -1 || previousSelectedIndex == i))
        indexForSelection = i;
      obj.enable(isVisible)
      obj.show(isVisible)
    }

    refreshOwnUnitControl(indexForSelection)

    if (indexForSelection > -1)
      unitypeListObj.setValue(indexForSelection)

    onSubPageChange(unitypeListObj)
  }

  function recacheSkins()
  {
    skinsCache = {}
    foreach(idx, cb in ::g_unlocks.getUnlocksByTypeInBlkOrder("skin"))
    {
      local skinName = cb.getStr("id", "")
      local unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(skinName))
      if (!unit)
        continue

      // Not showing skins for vehicles which
      // are not present or not visible in shop
      if ( ! ::is_unit_visible_in_shop(unit))
        continue

      local unitType = ::get_es_unit_type(unit)
      local unitCountry = ::getUnitCountry(unit)

      if ( ! (unitCountry in skinsCache))
        skinsCache[unitCountry] <- {}
      if ( ! (unitType in skinsCache[unitCountry]))
        skinsCache[unitCountry][unitType] <- {}

      local infoObject = {
        id = skinName
        country = unitCountry
        itemText = ::g_decorator_type.SKINS.getLocName(skinName, true)
        itemIcon = ::player_have_skin(unit.name, skinName) ? "#ui/gameuiskin#unlocked" : "#ui/gameuiskin#locked"

        //sort params
        unitId = unit.name
        idx = idx
      }

      if ( ! (OwnUnitsType.ALL in skinsCache[unitCountry][unitType]))
        skinsCache[unitCountry][unitType][OwnUnitsType.ALL] <- []
      skinsCache[unitCountry][unitType][OwnUnitsType.ALL].push(infoObject)

      if( ! unit.isBought())
        continue

      if ( ! (OwnUnitsType.BOUGHT in skinsCache[unitCountry][unitType]))
              skinsCache[unitCountry][unitType][OwnUnitsType.BOUGHT] <- []
      skinsCache[unitCountry][unitType][OwnUnitsType.BOUGHT].push(infoObject)
    }

    foreach (countries in skinsCache)
      foreach (ownType in countries)
        foreach (unitTypeList in ownType)
          if (unitTypeList.len())
            unitTypeList.sort(function(a, b) {
              //some vehicles has a specific characters prefix in localized name,so sort by id
              if (a.unitId != b.unitId)
                return a.unitId > b.unitId ? 1 : -1
              return a.idx <=> b.idx
            })
  }

  function getSkinsCache(country, unitType, ownType = null)
  {
    if ( ! skinsCache)
      recacheSkins()
    if (ownType == null)
      ownType = getCurrentOwnType()
    return ::get_tbl_value_by_path_array([country, unitType, ownType], skinsCache, [])
  }

  function getCurrentOwnType()
  {
    local ownSwitch = scene.findObject("checkbox_only_for_bought")
    local ownType = ( ! ::checkObj(ownSwitch) || ! ownSwitch.getValue()) ? OwnUnitsType.ALL : OwnUnitsType.BOUGHT
    return ownType
  }

  function refreshOwnUnitControl(unitType)
  {
    local ownSwitch = scene.findObject("checkbox_only_for_bought")
    local tooltip = ::loc("profile/only_for_bought/hint")
    local enabled = true
    if(getSkinsCache(curFilter, unitType, OwnUnitsType.BOUGHT).len() < 1)
    {
      if(ownSwitch.getValue() == true)
        ownSwitch.setValue(false)
      tooltip = ::loc("profile/only_for_bought_disabled/hint")
      enabled = false
    }
    ownSwitch.tooltip = tooltip
    ownSwitch.enable(enabled)
    ownSwitch.show(true)
  }

  function fillUnlocksList()
  {
    guiScene.setUpdatesEnabled(false, false)
    local data = ""
    local lowerCurPage = curPage.tolower()
    local pageTypeId = ::get_unlock_type(lowerCurPage)
    local iconsListStyle = pageTypeId == ::UNLOCKABLE_MEDAL || pageTypeId == ::UNLOCKABLE_DECAL
    unlocksTree = {}

    local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(pageTypeId)
    if (pageTypeId == ::UNLOCKABLE_DECAL)
      data = getDecoratorsMarkup(decoratorType)
    else if (pageTypeId == ::UNLOCKABLE_SKIN)
      data = getSkinsMarkup()
    else
    {
      local view = { items = [] }
      view.items = generateItems(pageTypeId)
      data = ::handyman.renderCached("gui/commonParts/imgFrame", view)
    }

    local unlocksObj = scene.findObject(iconsListStyle ? "decals_zone" : "unlocks_group_list")
    local view = { items = [] }
    foreach (chapterName, chapterItem in unlocksTree)
    {
      view.items.append({
        itemTag = "campaign_item"
        id = chapterName
        itemText = "#unlocks/chapter/" + chapterName
        isCollapsable = chapterItem.groups.len() > 0
      })

      if (chapterItem.groups.len() > 0)
        foreach (groupName, groupItem in chapterItem.groups)
          view.items.append({
            id = chapterName + "/" + groupName
            itemText = "#unlocks/group/" + groupName
          })
    }
    data += ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(unlocksObj, data, data.len(), this)
    guiScene.setUpdatesEnabled(true, true)

    if (unlocksObj.childrenCount() > 0)
      unlocksObj.setValue(0)

    onUnlockSelect(unlocksObj)
    collapse()
  }

  function getSkinsMarkup()
  {
    local view = { items = getSkinsCache(curFilter, curSubFilter) }
    return ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
  }

  function generateItems(pageTypeId)
  {
    local items = []
    local lowerCurPage = curPage.tolower()
    local isCustomMenuTab = lowerCurPage in customMenuTabs
    local isUnlockTree = isCustomMenuTab || pageTypeId == -1 || pageTypeId == ::UNLOCKABLE_ACHIEVEMENT
    local chapter = ""
    local group = ""

    foreach(idx, cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      local name = cb.getStr("id", "")
      local unlockType = cb.type || ""
      local unlockTypeId = ::get_unlock_type(unlockType)
      if (unlockTypeId != pageTypeId
          && (!isUnlockTree || !::isInArray(unlockTypeId, unlockTypesToShow)))
        continue
      if (isUnlockTree && cb.isRevenueShare)
        continue
      if (!::is_unlock_visible(cb))
        continue
      if (cb.showAsBattleTask)
        continue

      if (isCustomMenuTab)
      {
        if (!cb.customMenuTab || cb.customMenuTab.tolower() != lowerCurPage)
          continue
      }
      else if (cb.customMenuTab)
        continue

      if (curFilterType == "country" && cb.getStr("country","") != curFilter)
        continue

      if (curFilterType == "category")
      {
        local dInfo = ::g_decorator.getCachedDecoratorByUnlockId(name, ::g_decorator_type.DECALS)
        if (!dInfo || dInfo.category != curFilter)
          continue
      }

      if (isUnlockTree)
      {
        local newChapter = cb.getStr("chapter","")
        local newGroup = cb.getStr("group","")
        if (newChapter != "")
        {
          chapter = newChapter
          group = newGroup
        }
        if(newGroup != "")
          group = newGroup
        if(!(chapter in unlocksTree))
          unlocksTree[chapter] <- {rootItems = [], groups = {}}
        if(group != "" && !(group in unlocksTree[chapter].groups))
          unlocksTree[chapter].groups[group] <- []
        if (group == "")
          unlocksTree[chapter].rootItems.append(name)
        else
          unlocksTree[chapter].groups[group].append(name)
        continue
      }

      if (pageTypeId == ::UNLOCKABLE_MEDAL)
        items.append({
          id = name
          tooltipId = ::g_tooltip.getIdUnlock(name, { showProgress = true })
          unlocked = ::is_unlocked_scripted(unlockTypeId, name)
          image = ::get_image_for_unlockable_medal(name)
        })
    }
    return items;
  }

  function getSkinsUnitType(skinName)
  {
    local unit = getUnitBySkin(skinName)
    if( ! unit)
        return ::ES_UNIT_TYPE_INVALID
    return ::get_es_unit_type(unit)
  }

  function getUnitBySkin(skinName)
  {
    return ::getAircraftByName(::g_unlocks.getPlaneBySkinId(skinName))
  }

  function getDecoratorsMarkup(decoratorType)
  {
    local view = { items = [] }

    local decoratorsList = ::g_decorator.getCachedDecoratorsDataByType(decoratorType)
    foreach (category, decorators in decoratorsList)
    {
      if (curFilter != category)
        continue

      foreach (decorator in decorators)
      {
        view.items.append({
          id = decorator.id
          tooltipId = ::g_tooltip.getIdDecorator(decorator.id, decoratorType.unlockedItemType)
          unlocked = decorator.isUnlocked()
          image = decoratorType.getImage(decorator)
          imgRatio = decoratorType.getRatio(decorator)
        })
      }
    }

    return ::handyman.renderCached("gui/commonParts/imgFrame", view)
  }

  function checkSkinVehicle(unitName)
  {
    local unit = ::getAircraftByName(unitName)
    if (unit == null)
      return false
    if (!::has_feature("Tanks") && ::isTank(unit))
      return false
    return ::is_unit_visible_in_shop(unit)
  }

  function collapse(itemName = null)
  {
    local listObj = scene.findObject("unlocks_group_list")
    if (!listObj || !unlocksTree || unlocksTree.len() == 0)
      return

    local chapterRegexp = regexp2("/[^\\s]+")
    local chapterName = itemName && chapterRegexp.replace("", itemName)
    uncollapsedChapterName = (chapterName == uncollapsedChapterName)? null : chapterName
    local newValue = -1

    guiScene.setUpdatesEnabled(false, false)
    local total = listObj.childrenCount()
    for(local i = 0; i < total; i++)
    {
      local obj = listObj.getChild(i)
      local iName = obj.id
      if (iName in unlocksTree) //chapter
      {
        obj.collapsed = (iName == uncollapsedChapterName)? "no" : "yes"
        if (iName == chapterName)
          newValue = i
        continue
      }

      local iChapter = iName && chapterRegexp.replace("", iName)
      local visible = iChapter == uncollapsedChapterName
      obj.enable(visible)
      obj.show(visible)
    }
    guiScene.setUpdatesEnabled(true, true)

    if (newValue >= 0)
      listObj.setValue(newValue)
  }

  function onCollapse(obj)
  {
    if (!obj) return
    local id = obj.id
    if (id.len() > 4 && id.slice(0, 4) == "btn_")
    {
      collapse(id.slice(4))
      local listBoxObj = scene.findObject("unlocks_group_list")
      local listItemCount = listBoxObj.childrenCount()
      for(local i = 0; i < listItemCount; i++)
      {
        local listItemId = listBoxObj.getChild(i).id
        if(listItemId == id.slice(4))
        {
          listBoxObj.setValue(i)
          onUnlockSelect(obj)
          break
        }
      }
    }
  }

  function onGroupCollapse(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    collapse(obj.getChild(value).id)
  }

  function openCollapsedGroup(group, name)
  {
    collapse(group)
    local reqBlockName = group + (name? ("/" + name) : "")
    local listBoxObj = scene.findObject("unlocks_group_list")
    if (!::checkObj(listBoxObj))
      return

    local listItemCount = listBoxObj.childrenCount()
    for(local i = 0; i < listItemCount; i++)
    {
      local listItemId = listBoxObj.getChild(i).id
      if(reqBlockName == listItemId)
        return listBoxObj.setValue(i)
    }
  }

  function onMedalTooltipOpen(obj)
  {
    local id = getTooltipObjId(obj)
    if(!id)
      return
    if(id == "")
      return obj["class"] = "empty"

    local blk = ::g_unlocks.getUnlockById(id)
    if (blk == null)
      return

    local page_id = curPage.tolower()
    local stage = (obj.stage_num && obj.stage_num != "")? obj.stage_num.tointeger() : -1

    local config = build_conditions_config(blk, stage)
    local isCompleted = ::is_unlocked(-1, id)
    ::build_unlock_desc(config, {showProgress = !isCompleted, showCost = !isCompleted})
    local reward = ::g_unlock_view.getRewardText(config, stage)

    local header = page_id == "decal" ? ::loc("decals/" + id) : ::loc(id + "/name")
    local locId = ::getTblValue("locId", config, "")
    if (locId != "")
      header = ::get_locId_name(config)
    if (stage >= 0)
      header += " " + ::roman_numerals[stage + 1]

    guiScene.replaceContent(obj, "gui/medalTooltip.blk", this)
    obj.findObject("header").setValue(header)

    if(page_id == "decal")
    {
      local descObj = obj.findObject("decal_description")
      local descr = ::loc("decals/" + id + "/desc")
      if(header != descr && descr != "") {
        descObj.setValue(descr)
        descObj.show(true)
      }
    }

    local dObj = obj.findObject("description")
    dObj.setValue(config.text)
    if (!isCompleted)
    {
      local pObj = obj.findObject("progress")
      local progressData = config.getProgressBarData()
      pObj.setValue(progressData.value)
      pObj.show(progressData.show)
    }
    else if(config.text != "")
      obj.findObject("challenge_complete").show(true)
    local rObj = obj.findObject("reward")
    if(reward != "")
    {
      rObj.setValue(reward)
      rObj.show(true)
    }
    else
      rObj.show(false)
  }

  function onMedalTooltipClose(obj)
  {
    guiScene.performDelayed(this, (@(obj, guiScene) function() {
      if(obj && obj.isValid())
        guiScene.replaceContentFromText(obj, "", 0, this)
    })(obj, guiScene))
  }

  function onRewardTooltipOpen(obj)
  {
    local tooltipId = obj.tooltipId
    if (tooltipId != "reward") //need to move other tooltips to generic view
      return onGenericTooltipOpen(obj)

    local id = obj.reward
    local cb = id && id != "" && ::g_unlocks.getUnlockById(id)
    obj["class"] = cb ? "" : "empty"
    if(!cb)
      return

    local config = build_conditions_config(cb)
    ::build_unlock_desc(config)
    local name = config.id
    local unlockType = config.unlockType
    local isUnlocked = ::is_unlocked_scripted(unlockType, name)
    local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
    if (decoratorType == ::g_decorator_type.DECALS
        || decoratorType == ::g_decorator_type.ATTACHABLES
        || unlockType == ::UNLOCKABLE_MEDAL)
    {
      local bgImage = ::format("background-image:t='%s';", config.image)
      local size = ::format("size:t='128, 128/%f';", config.imgRatio)

      guiScene.appendWithBlk(obj, ::format("img{ %s }", bgImage + size), this)
    }
    else if (decoratorType == ::g_decorator_type.SKINS)
    {
      local unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(name))
      local text = []
      if (unit)
        text.append(::loc("reward/skin_for") + " " + ::getUnitName(unit))
      text.append(decoratorType.getLocDesc(name))

      text = ::locOrStrip(::implode(text, "\n"))
      local textBlock = "textareaNoTab {tinyFont:t='yes'; max-width:t='0.5@scrn_tgt_font'; text:t='%s';}"
      guiScene.appendWithBlk(obj, ::format(textBlock, text), this)
    }
  }

  function getSkinCountry(skinName)
  {
    local len0 = skinName.find("/")
    if (len0)
      return ::getShopCountry(skinName.slice(0, len0))
    return ""
  }

  function build_unlock_info_blk(page_id, name, blk, infoObj)
  {
    guiScene.replaceContentFromText(infoObj, "", 0, this)

    local isUnlocked = ::g_decorator_type.SKINS.isPlayerHaveDecorator(name)

    local config = ::build_conditions_config(blk)
    ::build_unlock_desc(config)

    if (config.image != "")
        append_big_icon(config.image, infoObj, isUnlocked, config.imgRatio, false)

    append_condition_item(config, 0, infoObj, true, isUnlocked)
    if ("shortText" in config)
      for(local i=0; i<config.stages.len(); i++)  //stages of challenge
      {
        local stage = config.stages[i]
        if (stage.val != config.maxVal)
        {
          local curValStage = (config.curVal > stage.val)? stage.val : config.curVal
          local isUnlockedStage = curValStage >= stage.val
          append_condition_item({
              text = config.progressText //do not show description for stages
              image = config.image
              curVal = curValStage
              maxVal = stage.val
            },
            i+1, infoObj, false, isUnlockedStage)
        }
      }

    //missions, countries
    local namesLoc = ::UnlockConditions.getLocForBitValues(config.type, config.names)
    local typeOR = ("compareOR" in config) && config.compareOR
    for(local i=0; i < namesLoc.len(); i++)
    {
      local isUnlocked = config.curVal & 1 << i
      append_condition_item({
            text = namesLoc[i]
            image = "" //isUnlocked? "#ui/gameuiskin#unlocked" : "#ui/gameuiskin#locked"
            curVal = 0
            maxVal = 0
          },
          i+1, infoObj, false, isUnlocked, i > 0 && typeOR)
    }
  }

  function append_condition_item(item, idx, obj, header, is_unlocked, typeOR = false)
  {
    local txtName = "unlock_txt_" + idx
    local data = ::format("textarea { id:t='%s'; text:t='' } \n %s \n",
                     txtName, (("image" in item) && (item.image!=""))? "" : "unlockImg{}")

    data += format("unlocked:t='%s'; ", is_unlocked ? "yes" : "no")

    local curVal = item.curVal
    local maxVal = item.maxVal
    local showStages = ("stages" in item) && (item.stages.len() > 1)

    //progressbar
    if ("getProgressBarData" in item)
    {
      local progressData = item.getProgressBarData()
      if (progressData.show)
        data += " challengeDescriptionProgress { id:t='progress' value:t='" + progressData.value + "'}"
    }

    if (header)
      data = "unlockConditionHeader { " + data + "}"
    else
      data = "unlockCondition { " + data + "}"

    guiScene.appendWithBlk(obj, data, this)

    local unlockDesc = typeOR ? ::loc("hints/shortcut_separator") + "\n" : ""
    unlockDesc += format(item.text, curVal, maxVal)
    if (showStages && item.curStage >= 0)
       unlockDesc += ::g_unlock_view.getRewardText (item, item.curStage)

    obj.findObject(txtName).setValue(unlockDesc)
  }

  function append_big_icon(img, obj, isUnlocked, ratio, doubleSize=false)
  {
    local data = ::format("bigMedalPlace { double:t='%s'; " +
                            "bigMedalImg { background-image:t='%s'; %s status:t='%s' } " +
                          "}\n",
                          doubleSize? "yes":"no",
                          img, getRatioText(ratio), isUnlocked? "unlocked" : "locked")
    guiScene.appendWithBlk(obj, data, this)
  }

  function unlockToFavorites(obj)
  {
    local unlockId = ::getTblValue("unlockId", obj)
    if (::u.isEmpty(unlockId))
      return
    obj.tooltip = obj.getValue() ?
     ::g_unlocks.addUnlockToFavorites(unlockId) : ::g_unlocks.removeUnlockFromFavorites(unlockId)
    ::g_unlock_view.fillUnlockFavCheckbox(obj)
  }

  function fillUnlockInfo(unlockBlk, unlockObj)
  {
    local itemData = build_conditions_config(unlockBlk)
    ::build_unlock_desc(itemData)
    unlockObj.show(true)
    unlockObj.enable(true)

    ::g_unlock_view.fillUnlockConditions(itemData, unlockObj, this)
    ::g_unlock_view.fillUnlockProgressBar(itemData, unlockObj)
    ::g_unlock_view.fillUnlockDescription(itemData, unlockObj)
    ::g_unlock_view.fillUnlockImage(itemData, unlockObj)
    ::g_unlock_view.fillReward(itemData, unlockObj)
    ::g_unlock_view.fillStages(itemData, unlockObj, this)
    ::g_unlock_view.fillUnlockTitle(itemData, unlockObj)
    ::g_unlock_view.fillUnlockFav(itemData.id, unlockObj)
  }

  function printUnlocksList(unlocksList)
  {
    local achievaAmount = unlocksList.len()
    local unlocksListObj = showSceneBtn("unlocks_list", true)
    local itemDescObj = showSceneBtn("item_desc", false)
    local blockAmount = unlocksListObj.childrenCount()

    guiScene.setUpdatesEnabled(false, false)

    if (blockAmount < achievaAmount)
    {
      local unlockItemBlk = "gui/profile/unlockItem.blk"
      for(; blockAmount < achievaAmount; blockAmount++)
        guiScene.createElementByObject(unlocksListObj, unlockItemBlk, "expandable", this)
    }
    else if (blockAmount > achievaAmount)
    {
      for(; blockAmount > achievaAmount; blockAmount--)
      {
        unlocksListObj.getChild(blockAmount - 1).show(false)
        unlocksListObj.getChild(blockAmount - 1).enable(false)
      }
    }

    local currentItemNum = 0
    foreach(unlock in ::g_unlocks.getAllUnlocksWithBlkOrder())
    {
      if (!::isInArray(unlock.id, unlocksList))
        continue

      fillUnlockInfo(unlock, unlocksListObj.getChild(currentItemNum))
      currentItemNum++
    }

    if (unlocksListObj.childrenCount() > 0)
      unlocksListObj.getChild(0).scrollToView();
    guiScene.setUpdatesEnabled(true, true)
  }

  function fillSkinDescr(name)
  {
    guiScene.setUpdatesEnabled(false, false)

    local objDesc = showSceneBtn("item_desc", true)

    local textName = ::loc(name)
    local unitName = ::g_unlocks.getPlaneBySkinId(name)
    local unitNameLoc = (unitName != "") ? ::getUnitName(unitName) : ""
    objDesc.findObject("item_name").setValue(textName)
    objDesc.findObject("item_name0").setValue(unitNameLoc)

    local cb = ::g_unlocks.getUnlockById(name)
    if (cb)
    {
      build_unlock_info_blk("skin", name, cb, scene.findObject("item_field"))
      ::g_unlock_view.fillUnlockFav(name, objDesc)
    }

    showSceneBtn("unlocks_list", false)

    guiScene.setUpdatesEnabled(true, true)
  }

  function onUnlockSelect(obj)
  {
    local list = scene.findObject("unlocks_group_list")
    local index = list.getValue()
    local unlocksList = []
    if ((index >= 0) && (index < list.childrenCount()))
    {
      local curObj = list.getChild(index)
      if (curPage.tolower() == "skin")
        fillSkinDescr(curObj.id)
      else
      {
        local id = curObj.id
        if(id in unlocksTree)
          unlocksList = unlocksTree[id].rootItems
        else
          foreach(chapterName, chapterItem in unlocksTree)
            if (chapterName.len() + 1 < id.len()
                && id.slice(0, chapterName.len()) == chapterName
                && id.slice(chapterName.len() + 1) in chapterItem.groups)
            {
              unlocksList = chapterItem.groups[id.slice(chapterName.len() + 1)]
              break
            }
        printUnlocksList(unlocksList)
      }
    }
  }

  function getCurSheet()
  {
    local obj = scene.findObject("profile_sheet_list")
    local sheetIdx = obj.getValue()
    if ((sheetIdx < 0) || (sheetIdx >= obj.childrenCount()))
      return ""

    return obj.getChild(sheetIdx).id
  }
  /*
//Stats page
  function fillStats()
  {
//    curDifficulty = "any"
    local statsObj = scene.findObject("stats_options")
    if (!statsInited || !statsObj)
    {
      local optionItems = []

      optionItems.append([::USEROPT_SEARCH_DIFFICULTY, "spinner"])
      optionItems.append([::USEROPT_SEARCH_PLAYERMODE, "spinner"])

      local container = create_options_container("stats_options", optionItems, true, false, true)
      local optList = scene.findObject("optionslist")
      guiScene.replaceContentFromText(optList, container.tbl, container.tbl.len(), this)
      if (optionItems.len()>0) optList.show(true)
      statsInited = true
    } else
      ::selectOptionsNavigatorObj(statsObj)

    updateStats()
  }
  */
  function calcStat(func, diff, mode, fm_idx = null) {
    local value = 0

    for (local idx = 0; idx < 3; idx++) //difficulty
      if (idx == diff || diff < 0)

        for(local pm=0; pm < 2; pm++)  //players
          if (mode == pm || mode < 0)

            if (fm_idx!=null)
              value += func(idx, fm_idx, pm)
            else
              value += func(idx, pm)

    return value
  }

  function getStatRowData(name, func, mode, fm_idx=null, timeFormat = false)
  {
    local row = [{ text = name, tdAlign = "left"}]
    for (local diff=0; diff < 3; diff++)
    {
      local value = 0
      if (fm_idx==null || fm_idx >= 0)
        value = calcStat(func, diff, mode, fm_idx)
      else
        for (local i = 0; i < 3; i++)
          value += calcStat(func, diff, mode, i)

      local s = timeFormat? ::format("%d:%02d:%02d",
                                value / TIME_HOUR_IN_SECONDS,
                                (value / TIME_MINUTE_IN_SECONDS) % TIME_MINUTE_IN_SECONDS,
                                value % TIME_MINUTE_IN_SECONDS)
                          : value
      local tooltip = ["#mainmenu/arcadeInstantAction", "#mainmenu/instantAction", "#mainmenu/fullRealInstantAction"][diff]
      row.append({ id = diff.tostring(), text = s.tostring(), tooltip = tooltip})
    }
    return buildTableRowNoPad("", row)
  }

  function updateStats()
  {
    local myStats = ::my_stats.getStats()
    if (!myStats || !::checkObj(scene))
      return

    fillProfileStats(myStats)
  }

  function getNewTitles(obj)
  {
    local myStats = ::my_stats.getStats()
    if(!isInMenu() || !myStats)
      return

    local availableTitles = ::my_stats.getTitles()
    if(!availableTitles || availableTitles.len() == 0)
    {
      openProfileTab("UnlockAchievement", "title")
      return
    }

    local curTitle = myStats.title
    local titles = [{
                     text = ::loc("title/clear_title")
                     tooltip = ""
                     action = function(){setNewTitle("")}
                   }]
    local name = ""
    local desc = ""
    local unlockBlk = null
    local itemData = null
    foreach(i, titleName in availableTitles)
    {
      unlockBlk = ::g_unlocks.getUnlockById(titleName)
      if (!unlockBlk)
        continue

      itemData = build_conditions_config(unlockBlk)
      ::build_unlock_desc(itemData)
      name = ::loc("title/" + titleName)
      desc = itemData.text
      titles.append({
                      text = name
                      tooltip = ::tooltipColorTheme(desc)
                      action = (@(titleName) function() {setNewTitle(titleName)})(titleName)
                   })
    }
    local goToTitlesListButton = {
                                   text = ::loc("title/all_titles")
                                   tooltip = ""
                                   action = function(){openProfileTab("UnlockAchievement", "title")}
                                 }
    titles.append(goToTitlesListButton)

    local position = ::show_console_buttons ? obj.getPosRC() : null
    ::gui_right_click_menu(titles, this, position)
  }

  function openProfileTab(tab, selectedBlock)
  {
    local obj = scene.findObject("profile_sheet_list")
    if(::checkObj(obj))
    {
      local num = ::find_in_array(sheetsList, tab)
      if(num < 0)
        return
      obj.setValue(num)
      openCollapsedGroup(selectedBlock, null)
    }
  }

  function setNewTitle(titleName)
  {
    taskId = ::select_current_title(titleName)
    if(taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = (@(titleName) function() {
        ::my_stats.clearStats()
        updateStats()
        fillTitleName(titleName)
      })(titleName)
    }
  }

  function fillProfileStats(stats)
  {
    fillTitleName(stats.titles.len() > 0 ? stats.title : "no_titles")
    if ("uid" in stats && stats.uid != ::my_user_id_str)
      ::externalIDsService.reqPlayerExternalIDsByUserId(stats.uid)
    fillClanInfo(stats)
    fillModeListBox(scene.findObject("profile-container"), curMode)
    ::fill_gamer_card(::get_profile_info(), true, "profile-", scene)
    fillShortCountryStats(stats)
    scene.findObject("profile_loading").show(false)
  }

  function onProfileStatsModeChange(obj)
  {
    if (!::checkObj(scene))
      return
    local myStats = ::my_stats.getStats()
    if (!myStats)
      return

    curMode = obj.getValue()

    ::set_current_wnd_difficulty(curMode)
    updateCurrentStatsMode(curMode)
    ::fill_profile_summary(scene.findObject("stats_table"), myStats.summary, curMode)
    fillLeaderboard()
  }

  /*
  function onDifficultyChange(obj)
  {
    if (obj != null)
    {
      local opdata = ::get_option(::USEROPT_SEARCH_DIFFICULTY)
      local idx = obj.getValue()

      if (idx in opdata.values)
        curDifficulty = opdata.values[idx]
      updateStats()
    }
  }

  function onPlayerModeChange(obj)
  {
    if (obj != null)
    {
      curPlayerMode = obj.getValue()

      updateStats()
    }
  }
  */

  function onUpdate(obj, dt)
  {
    if (pending_logout && ::is_app_active() && !::steam_is_overlay_active() && !::is_builtin_browser_active())
    {
      pending_logout = false
      guiScene.performDelayed(this, function() {
        ::gui_start_logout()
      })
    }
  }

  function onChangeName()
  {
    msgBox("question_change_name", ::loc("mainmenu/questionChangeName"),
      [
        ["ok", function() {
          ::open_url(::loc("url/changeName"), false, false, "profile_page")
          guiScene.performDelayed(this, function() { pending_logout = true})
        }],
        ["cancel", function() { }]
      ], "cancel")
  }

  function onChangeAccount()
  {
    msgBox("question_change_name", ::loc("mainmenu/questionChangePlayer"),
      [
        ["yes", ::gui_start_logout],
        ["no", function() { }]
      ], "no", { cancel_fn = function() {}})
  }

  function afterModalDestroy() {
    restoreMainOptions()
  }

  function onChangePilotIcon() {
    ::choose_pilot_icon_wnd(onIconChoosen, this)
  }

  function getPlayerLink()
  {
    ::show_viral_acquisition_wnd(this)
  }

  function onIconChoosen(option)
  {
    local value = ::get_option(::USEROPT_PILOT).value
    if (value == option.idx)
      return

    ::set_option(::USEROPT_PILOT, option.idx)
    ::save_profile(false)

    if (!::checkObj(scene))
      return

    local obj = scene.findObject("profile-icon")
    if (obj) obj["background-image"] = "#ui/images/avatars/" + ::get_profile_info().icon

    ::broadcastEvent(profileEvent.AVATAR_CHANGED)
  }

  function onEventMyStatsUpdated(params)
  {
    if (getCurSheet() == "Statistics")
      fillAirStats()
    if (getCurSheet() == "Profile")
      updateStats()
  }

  function initAirStats()
  {
    local myStats = ::my_stats.getStats()
    if (!myStats || !::checkObj(scene))
      return

    initAirStatsScene(myStats.userstat)
  }

  function fillAirStats()
  {
    local myStats = ::my_stats.getStats()
    if (!airStatsInited || !myStats || !myStats.userstat)
      return initAirStats()

    fillAirStatsScene(myStats.userstat)
  }

  function getPlayerStats()
  {
    return ::my_stats.getStats()
  }

  function getAchivementPageFocusObj()
  {
    if (!::checkObj(scene))
      return null

    local unlocksListObj = scene.findObject("unlocks_list")
    if (::checkObj(unlocksListObj) && unlocksListObj.isFocused())
      return unlocksListObj
    return scene.findObject("unlocks_group_list")
  }

  function switchAchiFocusObj(obj)
  {
    local id = obj.id
    local objsList = ["unlocks_group_list", "unlocks_list", "pages_list"]
    local idx = ::find_in_array(objsList, id)
    if (idx < 0)
      return
    for (local i = 1; i < objsList.len(); ++i)
    {
      local index = (idx + i) % objsList.len()
      local sObj = getObj(objsList[index])
      if (::checkObj(sObj) && sObj.isVisible() && sObj.isEnabled() && sObj.childrenCount())
      {
        sObj.select()
        if (sObj.getValue() < 0)
          sObj.setValue(0)
        break
      }
    }
  }

  function onGroupCancel(obj)
  {
    if (getCurSheet() == "UnlockSkin")
      onWrapUp(obj)
    else
      goBack()
  }

  function onBindPS4Email()
  {
    ::g_user_utils.launchPS4EmailRegistration()
  }

  function onBindSteamEmail()
  {
    ::g_user_utils.launchSteamEmailRegistration()
  }

  function getMainFocusObj()
  {
    local curSheet = getCurSheet()
    if (::isInArray(curSheet, ["Medal", "UnlockDecal"]))
      return getObj("decals_list")
    if (curSheet == "UnlockSkin")
      return getObj("unit_type_list")
    if (curSheet == "UnlockAchievement")
      return getAchivementPageFocusObj()
    return base.getMainFocusObj()
  }

  function getMainFocusObj2()
  {
    local curSheet = getCurSheet()
    if (curSheet == "UnlockSkin")
      return getObj("pages_list")
    return base.getMainFocusObj2()
  }

  function getMainFocusObj3()
  {
    local curSheet = getCurSheet()
    if (curSheet == "UnlockSkin")
      return getObj("unlocks_group_list")
    return base.getMainFocusObj3()
  }

  function getMainFocusObj4()
  {
    local curSheet = getCurSheet()
    if (curSheet == "UnlockSkin")
      return getObj("checkbox_only_for_bought")
    return base.getMainFocusObj4()
  }
}
