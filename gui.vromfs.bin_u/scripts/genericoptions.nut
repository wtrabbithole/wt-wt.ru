::generic_options <- null

function check_disable_saving_options()
{
  local gm = ::get_game_mode()
  local gameType = ::get_game_type_by_mode(::get_game_mode())

  if ((gm == ::GM_EVENT) || (
    (gameType & ::GT_COOPERATIVE) || (gameType & ::GT_VERSUS)
    ))
    ::disable_saving_options <- true;
  else if ((gm == ::GM_SINGLE_MISSION) || (gm == ::GM_USER_MISSION) || (gm == ::GM_DYNAMIC) || (gm == ::GM_BUILDER))
    if (::mission_settings.coop)
      ::disable_saving_options <- true;
}

class ::gui_handlers.GenericOptions extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/options/genericOptions.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"

  optionsId = "generic_options"
  options = null
  optionsConfig = null //config forwarded to get_option
  optionsContainers = null
  applyFunc = null
  cancelFunc = null
  forcedSave = false

  columnsRatio = 0.5 //0..1
  titleText = null

  owner = null

  function initScreen()
  {
    ::disable_saving_options <- false
    ::generic_options = this //?? FIX ME - need to remove this

    if (!optionsContainers)
      optionsContainers = []
    if (options)
      loadOptions(options, optionsId)

    ::set_menu_title(titleText, scene, "menu-title")
  }

  function loadOptions(opt, optId)
  {
    local optListObj = scene.findObject("optionslist")
    if (!::checkObj(optListObj))
      return ::dagor.assertf(false, "Error: cant load options when no optionslist object.")

    local container = ::create_options_container(optId, opt, true, true, columnsRatio, true, true, optionsConfig)
    guiScene.setUpdatesEnabled(false, false);

    guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    fill_weapons_list_tooltips(optListObj, container.descr.data)
    optionsContainers.push(container.descr)
    guiScene.setUpdatesEnabled(true, true)

    updateLinkedOptions()
    onHintUpdate()
  }

  function updateLinkedOptions()
  {
    checkBulletsRows()
    checkRocketDisctanceFuseRow()
    onLayoutChange(null)
    checkMissionCountries()
    checkBotsOption()
    updateTripleAerobaticsSmokeOptions()
    updateVerticalTargetingOption()
  }

  function applyReturn()
  {
    if (applyFunc != null)
      applyFunc()
    else
      base.goBack()
  }

  function onAppliedOptions(appliedTypes)
  {
    foreach (type in appliedTypes)
    {
      if (::is_measure_unit_user_option(type))
      {
        ::broadcastEvent("MeasureUnitsChanged")
        break
      }
    }
  }

  function doApply()
  {
    local changedList = []
    foreach (container in optionsContainers)
    {
      local objTbl = getObj(container.name)
      if (objTbl == null)
        continue

      foreach(idx, option in container.data)
      {
        if(option.controlType == optionControlType.HEADER)
          continue

        local obj = getObj(option.id)
        if (!::checkObj(obj))
        {
          ::script_net_assert_once("Bad option",
            "Error: not found obj for option " + option.id + ", type = " + option.type)
          continue
        }

        if (!::set_option(option.type, obj.getValue(), option))
          return false
        else
          changedList.append(option.type)
      }
    }

    onAppliedOptions(changedList)

    ::save_profile_offline_limited(forcedSave)
    forcedSave = false
    return true
  }

/*  function afterSave()
  {
    if (::generic_options != null)
      ::generic_options.applyReturn()
  } */

  function goBack()
  {
    if (cancelFunc != null)
      cancelFunc()
    base.goBack()
  }

  function onApply(obj)
  {
    applyOptions(true)
  }

  function applyOptions(_forcedSave = false)
  {
    forcedSave = _forcedSave
    if (doApply())
      applyReturn()
  }

  function onApplyOffline(obj)
  {
    local coopObj = getObj("coop_mode")
    if (coopObj) coopObj.setValue(2)
    applyOptions()
  }

  function onShowInfo(obj)
  {
    // foreach (container in optionsContainers)
    // {
      // local objTbl = getObj(container.name)
      // if (objTbl == null)
        // continue
      // local curRow = objTbl.cur_row.tointeger()
      // if (curRow >= 0 && curRow < container.data.len())
      // {
        // infoBox(container.data[curRow].hint)
      // }

      // break // HACK
    // }
  }

  function onHintUpdate()
  {
    //disabled
    /*foreach (container in optionsContainers)
    {
      local objTbl = getObj(container.name)
      local objHint = getObj("hint_box")
      if (objTbl == null || objHint == null)
        continue

      local curRow = objTbl.cur_row.tointeger()
      if (curRow >= 0 && curRow < container.data.len())
      {
        local hint = null;
        if ("hints" in container.data[curRow])
        {
          local objItemId = container.data[curRow].id
          local objItem = getObj(objItemId)
          if (objItem != null)
            hint = ::loc(container.data[curRow].hints[objItem.getValue()])
        }
        else
          hint = ::loc(container.data[curRow].hint)

        if (hint != null)
        {
          local objItemRowId = container.data[curRow].id + "_tr"
          local objItemRow = getObj(objItemRowId)
          if (objItemRow != null)
            objItemRow.tooltip = hint;

          objHint.setValue(hint);
        }
      }

      break
    }*/
  }

  function updateOptionDescr(obj, func)
  {
    local newDescr = null
    foreach (container in optionsContainers)
    {
      for (local i = 0; i < container.data.len(); ++i)
      {
        if (container.data[i].id == obj.id)
        {
          newDescr = func(guiScene, obj, container.data[i])
          break
        }
      }

      if (newDescr != null)
        break
    }

    if (newDescr != null)
    {
      foreach (container in optionsContainers)
      {
        for (local i = 0; i < container.data.len(); ++i)
        {
          if (container.data[i].id == newDescr.id)
          {
            container.data[i] = newDescr
            return
          }
        }
      }
    }
  }

  function onAircraftUpdateSkin(obj)
  {
    updateOptionDescr(obj, ::update_skins_spinner)
  }

  function onAircraftUpdate(obj)
  {
    onAircraftUpdateSkin(obj)
    updateOptionDescr(obj, ::update_weapons_spinner)
  }

  function onAircraftCountryUpdate(obj)
  {
    updateOptionDescr(obj, ::update_aircraft_spinner)
    if (obj.id == "aircraft_country")
      onAircraftUpdate(getObj("aircraft"))
    else
      onAircraftUpdate(getObj("enemy_aircraft"))
  }

  function onWeaponOptionUpdate(obj)
  {
    if (::generic_options != null)
    {
      local guiScene = ::get_gui_scene();
      guiScene.performDelayed(this, function(){ ::generic_options.onHintUpdate(); });
    }
  }

  function onMyWeaponOptionUpdate(obj)
  {
    local option = get_option_by_id(obj.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    onWeaponOptionUpdate(obj)
    if ("hints" in option)
      obj.tooltip = option.hints[ obj.getValue() ]
    else if ("hint" in option)
      obj.tooltip = ::stripTags( ::loc(option.hint, "") )
    checkBulletsRows()
    checkRocketDisctanceFuseRow()
  }

  function checkBulletsRows()
  {
    if (typeof(::aircraft_for_weapons) != "string")
      return
    local air = ::getAircraftByName(::aircraft_for_weapons)
    if (!air)
      return

    for (local groupIndex = 0; groupIndex < ::BULLETS_SETS_QUANTITY; groupIndex++)
    {
      local optionId = get_option(::USEROPT_BULLETS0 + groupIndex).id
      local show = ::isBulletGroupActive(air, groupIndex)
      if (!showOptionRow(optionId, show))
        break
    }
  }

  function checkRocketDisctanceFuseRow()
  {
    local option = findOptionInContainers(::USEROPT_ROCKET_FUSE_DIST)
    if (!option)
      return
    local unit = ::getAircraftByName(::aircraft_for_weapons)
    showOptionRow(option.id, !!unit && ::is_unit_available_use_rocket_diffuse(unit))
  }

  function onEventUnitWeaponChanged(p) { checkRocketDisctanceFuseRow() }

  function onTripleAerobaticsSmokeSelected(obj)
  {
    local option = get_option_by_id(obj.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    updateTripleAerobaticsSmokeOptions();
  }

  function updateTripleAerobaticsSmokeOptions()
  {
    local options = find_options_in_containers([
      ::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR,
      ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR,
      ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR
    ])

    if (!options.len())
      return

    local show = (::get_option_aerobatics_smoke_type() > ::MAX_AEROBATICS_SMOKE_INDEX * 2);
    foreach(option in options)
      showOptionRow(option.id, show)
  }

  function showOptionRow(id, show)
  {
    local obj = getObj(id + "_tr")
    if (!::checkObj(obj))
      return false

    obj.show(show)
    obj.inactive = show ? null : "yes"
    return true
  }

  function onNumPlayers(obj)
  {
    if (obj != null)
    {
      local numPlayers = obj.getValue() + 2
      local objPriv = getObj("numPrivateSlots")
      if (objPriv != null)
      {
        local numPriv = objPriv.getValue()
        if (numPriv >= numPlayers)
          objPriv.setValue(numPlayers - 1)
      }
    }
  }

  function onNumPrivate(obj)
  {
    if (obj != null)
    {
      local numPriv = obj.getValue()
      local objPlayers = getObj("numPlayers")
      if (objPlayers != null)
      {
        local numPlayers = objPlayers.getValue() + 2
        if (numPriv >= numPlayers)
          obj.setValue(numPlayers - 1)
      }
    }
  }

  function onVolumeChange(obj)
  {
    if (obj.id == "volume_music")
      ::set_sound_volume(::SND_TYPE_MUSIC, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_menu_music")
      ::set_sound_volume(::SND_TYPE_MENU_MUSIC, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_sfx")
      ::set_sound_volume(::SND_TYPE_SFX, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_radio")
      ::set_sound_volume(::SND_TYPE_RADIO, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_engine")
      ::set_sound_volume(::SND_TYPE_ENGINE, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_dialogs")
      ::set_sound_volume(::SND_TYPE_DIALOGS, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_voice_in")
      ::set_sound_volume(::SND_TYPE_VOICE_IN, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_voice_out")
      ::set_sound_volume(::SND_TYPE_VOICE_OUT, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_master")
      ::set_sound_volume(::SND_TYPE_MASTER, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_guns")
      ::set_sound_volume(::SND_TYPE_GUNS, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_tinnitus")
      ::set_sound_volume(::SND_TYPE_TINNITUS, obj.getValue() / 100.0, false)
  }

  function onPTTChange(obj)
  {
    set_option_ptt(get_option(::USEROPT_PTT).value ? 0 : 1);
    ::showBtn("ptt_buttons_block", obj.getValue(), scene)
  }

  function onVoicechatChange(obj)
  {
    ::set_option_voicechat(obj.getValue() ? 1 : 0)
  }

  function onInstantOptionApply(obj)
  {
    local option = get_option_by_id(obj.id)
    if (option)
      ::set_option(option.type, obj.getValue(), option)
  }

  function get_option_by_id(id)
  {
    local res = null;
    foreach (container in optionsContainers)
      for (local i = 0; i < container.data.len(); ++i)
        if (container.data[i].id == id)
          res = container.data[i];
    return res;
  }

  function find_options_in_containers(optTypeList)
  {
    local res = []
    if (!optionsContainers)
      return res
    foreach (container in optionsContainers)
      for (local i = 0; i < container.data.len(); ++i)
        if (::isInArray(container.data[i].type, optTypeList))
          res.append(container.data[i])
    return res
  }

  function findOptionInContainers(optionType)
  {
    if (!optionsContainers)
      return null
    foreach (container in optionsContainers)
    {
      local option = ::u.search(container.data, @(o) o.type == optionType)
      if (option)
        return option
    }
    return null
  }

  function getSceneOptValue(optName)
  {
    local option = get_option_by_id(optName) || ::get_option(optName)
    local obj = scene.findObject(option.id)
    local value = obj? obj.getValue() : option.value
    if (value in option.values)
      return option.values[value]
    return option.values[option.value]
  }

  function onGammaChange(obj)
  {
    local gamma = obj.getValue() / 100.0
    ::set_option_gamma(gamma, false)
  }

  function onControls(obj)
  {
    goForward(::gui_start_controls);
  }

  function onProfileChange(obj)
  {
    fillGamercard()
  }

  function onLayoutChange(obj)
  {
    local countryOption = get_option(::USEROPT_MP_TEAM_COUNTRY);
    local cobj = getObj(countryOption.id);
    local country = ""
    if(::checkObj(cobj))
    {
      country = get_country_by_team(cobj.getValue())
      ::set_option(::USEROPT_MP_TEAM_COUNTRY, cobj.getValue())
    }
    local unitsByYears = get_number_of_units_by_years(country);
    local yearObj = getObj(get_option(::USEROPT_YEAR).id);
    if (!yearObj)
      return;

    dagor.assert(yearObj.childrenCount() == ::unit_year_selection_max - ::unit_year_selection_min + 1);
    for (local i = 0; i < yearObj.childrenCount(); i++)
    {
      local line = yearObj.getChild(i);
      if (!line)
        continue;
      local text = line.findObject("option_text");
      if (!text)
        continue;

      local enabled = true
      local tooltip = ""
      if (::current_campaign && country!="")
      {
        local yearId = country + "_" + ::get_option(::USEROPT_YEAR).values[i]
        local unlockBlk = ::g_unlocks.getUnlockById(yearId)
        if (!unlockBlk)
          ::dagor.assertf(false, "Error: not found year unlock = " + yearId)
        else
        {
          local blk = build_conditions_config(unlockBlk)
          ::build_unlock_desc(blk)
          enabled = ::is_unlocked_scripted(::UNLOCKABLE_YEAR, yearId)
          tooltip = enabled? "" : blk.text
        }
      }

      line.enable(enabled)
      line.tooltip = tooltip
      local year = ::unit_year_selection_min + i;
      local parameter1 = "year" + year;
      local units1 = (parameter1 in unitsByYears) ? unitsByYears[parameter1] : 0;
      local parameter2 = "beforeyear" + year;
      local units2 = (parameter2 in unitsByYears) ? unitsByYears[parameter2] : 0;
      local optionText = format(::loc("options/year_text"), year, units1, units2);
      text.setValue(optionText);
    }

    local value = yearObj.getValue();
    yearObj.setValue(value >= 0 ? value : 0);
  }

  function getOptValue(optName, return_default_when_no_obj = true)
  {
    local option = ::get_option(optName)
    local obj = scene.findObject(option.id)
    if (!obj && !return_default_when_no_obj)
      return null
    local value = obj? obj.getValue() : option.value
    if (option.controlType == optionControlType.LIST)
      return option.values[value]
    return value
  }

  function update_internet_radio(obj)
  {
    local option = get_option_by_id(obj.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)

    ::update_volume_for_music();
    updateInternerRadioButtons()
  }

  function onMissionCountriesType(obj)
  {
    checkMissionCountries()
  }

  function checkMissionCountries()
  {
    if (::getTblValue("isEventRoom", optionsConfig, false))
      return

    local optList = find_options_in_containers([::USEROPT_BIT_COUNTRIES_TEAM_A, ::USEROPT_BIT_COUNTRIES_TEAM_B])
    if (!optList.len())
      return

    local countriesType = getOptValue(::USEROPT_MISSION_COUNTRIES_TYPE)
    foreach(option in optList)
    {
      local show = countriesType == misCountries.CUSTOM
                   || (countriesType == misCountries.SYMMETRIC && option.type == ::USEROPT_BIT_COUNTRIES_TEAM_A)
      showOptionRow(option.id, show)
    }
  }

  function onOptionBotsAllowed(obj)
  {
    checkBotsOption()
  }

  function checkBotsOption()
  {
    local isBotsAllowed = getOptValue(::USEROPT_IS_BOTS_ALLOWED, false)
    if (isBotsAllowed == null) //no such option in current options list
      return

    local optList = find_options_in_containers([::USEROPT_USE_TANK_BOTS,
      ::USEROPT_USE_SHIP_BOTS, ::USEROPT_BOTS_RANKS])
    foreach(option in optList)
      showOptionRow(option.id, isBotsAllowed)
  }

  function onDifficultyChange(obj)
  {
    updateVerticalTargetingOption()
  }

  function updateVerticalTargetingOption()
  {
    local optList = find_options_in_containers([::USEROPT_GUN_VERTICAL_TARGETING])
    if (!optList.len())
      return
    local diffName = getOptValue(::USEROPT_DIFFICULTY, false)
    if (diffName == null) //no such option in current options list
      return

    foreach(option in optList)
      showOptionRow(option.id, diffName != ::g_difficulty.ARCADE.name)
  }

  function onMissionChange(obj) {}
  function onSectorChange(obj) {}
  function onYearChange(obj) {}
  function onGamemodeChange(obj) {}
  function onOptionsListboxDblClick(obj) {}
  function onGroupSelect(obj) {}
}

class ::gui_handlers.GenericOptionsModal extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"
  multipleInstances = true

  applyAtClose = true

  navigationHandlerWeak = null
  currentContainerName = ""
  headersToOptionsList = {}

  function initScreen()
  {
    base.initScreen()

    updateButtons()
    initNavigation()
  }

  function initNavigation()
  {
    local handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene = scene.findObject("control_navigation")
        onSelectCb = ::Callback(doNavigateToSection, this)
        panelWidth        = "0.35@sf, ph"
        // Align to helpers_mode and table first row
        headerHeight      = "0.05@sf + @sf/@pf"
        headerOffsetX     = "0.015@sf"
        headerOffsetY     = "0.015@sf"
        collapseShortcut  = "LB"
        navShortcutGroup  = "RS"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
  }

  function doNavigateToSection(navItem)
  {
    local objTbl = scene.findObject(currentContainerName)
    if ( ! ::check_obj(objTbl))
      return

    local trId = ""
    local index = 0
    foreach(idx, option in getCurrentOptionsList())
    {
      if(option.controlType == optionControlType.HEADER
        && option.id == navItem.id)
      {
        trId = option.getTrId()
        index = idx
        break
      }
    }
    if(::u.isEmpty(trId))
      return

    local rowObj = objTbl.findObject(trId)
    if ( ! ::check_obj(rowObj))
      return

    objTbl.setValue(index)

    // It scrolls correctly only when using two frame delays
    guiScene.performDelayed(this, (@(rowObj) function() {
      guiScene.performDelayed(this, (@(rowObj) function() {
        if (::checkObj(rowObj))
          rowObj.scrollToView(true)
      })(rowObj))
    })(rowObj))
  }

  function resetNavigation()
  {
    if(navigationHandlerWeak)
      navigationHandlerWeak.setNavItems([])
  }

  function onTblSelect(obj)
  {
    checkCurrentNavigationSection()
  }

  function checkCurrentNavigationSection()
  {
    local navItems = navigationHandlerWeak.getNavItems()
    if(navItems.len() < 2)
      return

    local currentOption = getSelectedOption()
    if( ! currentOption)
      return

    local currentHeader = getOptionHeader(currentOption)
    if( ! currentHeader)
      return

    foreach(navItem in navItems)
    {
      if(navItem.id == currentHeader.id)
      {
        navigationHandlerWeak.setCurrentItem(navItem)
        return
      }
    }
  }

  function getSelectedOption()
  {
    local objTbl = scene.findObject(currentContainerName)
    if (!::check_obj(objTbl))
      return null

    local idx = objTbl.getValue()
    if (idx < 0 || objTbl.childrenCount() <= idx)
      return null

    local trId = objTbl.getChild(idx).id
    return ::u.search(getCurrentOptionsList(), @(option) option.getTrId() == trId)
  }

  function getOptionHeader(option)
  {
    foreach(header, optionsArray in headersToOptionsList)
      if(optionsArray.find(option) != null)
        return header
    return null
  }

  function getCurrentOptionsList()
  {
    local containerName = currentContainerName
    local container = ::u.search(optionsContainers, @(c) c.name == containerName)
    return ::getTblValue("data", container, [])
  }

  function setNavigationItems()
  {
    headersToOptionsList.clear();
    local headersItems = []
    local lastHeader = null
    foreach(option in getCurrentOptionsList())
    {
      if(option.controlType == optionControlType.HEADER)
      {
        lastHeader = option
        headersToOptionsList[lastHeader] <- []
        headersItems.push({id = option.id, text = option.getTitle()})
      }
      else if (lastHeader != null)
        headersToOptionsList[lastHeader].push(option)
    }

    if (navigationHandlerWeak)
    {
      navigationHandlerWeak.setNavItems(headersItems)
      checkCurrentNavigationSection()
    }
  }

  function updateButtons()
  {
    local btnObj = scene.findObject("btn_apply")
    if (btnObj) btnObj.setValue(::loc("mainmenu/btnOk"))
  }

  function goBack()
  {
    if (applyAtClose)
      applyOptions(true)
    else
    {
      base.goBack()
      restoreMainOptions()
    }
  }

  function applyReturn()
  {
    if (!applyFunc)
      restoreMainOptions()
    base.applyReturn()
  }
}

class ::gui_handlers.GroupOptionsModal extends ::gui_handlers.GenericOptionsModal
{
  sceneBlkName = "gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "gui/options/navOptions.blk"

  optGroups = null
  curGroup = -1
  echoTest = false;

  function initScreen()
  {
    if (!optGroups)
      base.goBack()

    base.initScreen()

    local view = { tabs = [] }
    local curOption = 0
    foreach(idx, gr in optGroups)
    {
      view.tabs.append({
        tabName = "#options/" + gr.name
        navImagesText = ::get_navigation_images_text(idx, optGroups.len())
      })

      if (::getTblValue("selected", gr) == true)
        curOption = idx
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local groupsObj = scene.findObject("groups_list")
    guiScene.replaceContentFromText(groupsObj, data, data.len(), this)
    groupsObj.show(true)
    groupsObj.setValue(curOption)
    onGroupSelect(groupsObj)
  }

  function onGroupSelect(obj)
  {
    if (!obj)
      return

    local newGroup = obj.getValue()
    if (curGroup==newGroup && !(newGroup in optGroups))
      return

    resetNavigation()

    if (curGroup>=0)
    {
      applyFunc = (@(newGroup) function() {
        fillOptions(newGroup)
        applyFunc = null
      })(newGroup)
      applyOptions()
    } else
      fillOptions(newGroup)

    joinEchoChannel(false);
  }

  function fillOptions(group)
  {
    local config = optGroups[group]

    if ("fillFuncName" in config)
    {
      this[config.fillFuncName](group);
      return;
    }

    if ("options" in config)
      fillOptionsList(group, "optionslist")

    updateLinkedOptions()
  }

  function fillInternetRadioOptions(group)
  {
    guiScene.replaceContent(scene.findObject("optionslist"), "gui/options/internetRadioOptions.blk", this);
    fillLocalInternetRadioOptions(group)
    updateInternerRadioButtons()
  }

  function fillSocialOptions(group)
  {
    guiScene.replaceContent(scene.findObject("optionslist"), "gui/options/socialOptions.blk", this)

    local hasFacebook = ::has_feature("Facebook")
    local fObj = showSceneBtn("facebook_frame", hasFacebook)
    if (hasFacebook && fObj)
    {
      fObj.findObject("facebook_like_btn").tooltip = ::tooltipColorTheme(::loc("guiHints/facebookLike") + ::loc("ui/colon") + ::get_unlock_reward("facebook_like"))
      checkFacebookLoginStatus()
    }
  }


  function onFacebookLogin()
  {
    make_facebook_login_and_do(checkFacebookLoginStatus, this)
  }

  function onFacebookLike()
  {
    if (!::facebook_is_logged_in())
      return;

    ::facebook_like(::loc("facebook/like_url"), "");
    onFacebookLikeShared();
  }

  function onFacebookLikeShared()
  {
    scene.findObject("facebook_like_btn").enable(false);
  }

  function onEventCheckFacebookLoginStatus(params)
  {
    checkFacebookLoginStatus()
  }

  function checkFacebookLoginStatus()
  {
    if (!::checkObj(scene))
      return

    local fbObj = scene.findObject("facebook_frame")
    if (!::checkObj(fbObj))
      return

    local facebookLogged = ::facebook_is_logged_in();
    ::showBtn("facebook_login_btn", !facebookLogged, fbObj)
    fbObj.findObject("facebook_friends_btn").enable(facebookLogged)

    local showLikeBtn = ::has_feature("FacebookWallPost")
    local likeBtn = ::showBtn("facebook_like_btn", showLikeBtn, fbObj)
    if (::checkObj(likeBtn) && showLikeBtn)
    {
      local alreadyLiked = ::is_unlocked_scripted(::UNLOCKABLE_ACHIEVEMENT, "facebook_like")
      likeBtn.enable(facebookLogged && !alreadyLiked && !::is_platform_ps4)
      likeBtn.show(!::is_platform_ps4)
    }
  }

  function fillShortcutInfo(shortcut_id_name, shortcut_object_name)
  {
    local shortcut = ::get_shortcuts([shortcut_id_name]);
    local data = ::get_shortcut_text(shortcut, 0);
    if (data == "")
      data = "---";
    scene.findObject(shortcut_object_name).setValue(data);
  }
  function bindShortcutButton(devs, btns, shortcut_id_name, shortcut_object_name)
  {
    local shortcut = ::get_shortcuts([shortcut_id_name]);

    local event = shortcut[0];

    event.append({dev = devs, btn = btns});
    if (event.len() > 1)
      event.remove(0);

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(shortcut, [shortcut_id_name]);
    save(false);

    local data = ::get_shortcut_text(shortcut, 0);
    scene.findObject(shortcut_object_name).setValue(data);
  }

  function onClearShortcutButton(shortcut_id_name, shortcut_object_name)
  {
    local shortcut = ::get_shortcuts([shortcut_id_name]);

    shortcut[0] = [];

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(shortcut, [shortcut_id_name]);
    save(false);

    scene.findObject(shortcut_object_name).setValue("---");
  }

  function fillLocalInternetRadioOptions(group)
  {
    local config = optGroups[group]

    if ("options" in config)
      fillOptionsList(group, "internetRadioOptions")

    fillShortcutInfo("ID_INTERNET_RADIO", "internet_radio_shortcut");
    fillShortcutInfo("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
    fillShortcutInfo("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function onAssignInternetRadioButton()
  {
    assignButtonWindow(this, bindInternetRadioButton);
  }
  function bindInternetRadioButton(devs, btns)
  {
    bindShortcutButton(devs, btns, "ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onClearInternetRadioButton()
  {
    onClearShortcutButton("ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onAssignInternetRadioPrevButton()
  {
    assignButtonWindow(this, bindInternetRadioPrevButton);
  }
  function bindInternetRadioPrevButton(devs, btns)
  {
    bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onClearInternetRadioPrevButton()
  {
    onClearShortcutButton("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onAssignInternetRadioNextButton()
  {
    assignButtonWindow(this, bindInternetRadioNextButton);
  }
  function bindInternetRadioNextButton(devs, btns)
  {
    bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }
  function onClearInternetRadioNextButton()
  {
    onClearShortcutButton("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function fillVoiceChatOptions(group)
  {
    local config = optGroups[group]

    guiScene.replaceContent(scene.findObject("optionslist"), "gui/options/voicechatOptions.blk", this);
    if ("options" in config)
      fillOptionsList(group, "voiceOptions")

    local ptt_shortcut = ::get_shortcuts(["ID_PTT"]);
    local data = ::get_shortcut_text(ptt_shortcut, 0, false);
    if (data == "")
      data = "---";
    else
      data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"

    scene.findObject("ptt_shortcut").setValue(data)
    ::showBtn("ptt_buttons_block", get_option(::USEROPT_PTT).value, scene)

    local echoButton = scene.findObject("joinEchoButton");
    if (echoButton) echoButton.enable(true)
  }

  function onAssignVoiceButton()
  {
    assignButtonWindow(this, bindVoiceButton);
  }

  function bindVoiceButton(devs, btns)
  {
    local ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    local event = ptt_shortcut[0];

    event.append({dev = devs, btn = btns});
    if (event.len() > 1)
      event.remove(0);

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(ptt_shortcut, ["ID_PTT"]);
    save(false);

    local data = ::get_shortcut_text(ptt_shortcut, 0, false);
    data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"
    scene.findObject("ptt_shortcut").setValue(data);
  }

  function onClearVoiceButton()
  {
    local ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    ptt_shortcut[0] = [];

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(ptt_shortcut, ["ID_PTT"]);
    save(false);

    scene.findObject("ptt_shortcut").setValue("---");
  }

  function joinEchoChannel(join)
  {
    echoTest = join;
    ::gchat_voice_echo_test(join);
  }

  function onEchoTestButton()
  {
    local echoButton = scene.findObject("joinEchoButton");

    joinEchoChannel(!echoTest);
    if(echoButton)
    {
      echoButton.text = (echoTest)? (::loc("options/leaveEcho")) : (::loc("options/joinEcho"));
      echoButton.tooltip = (echoTest)? (::loc("guiHints/leaveEcho")) : (::loc("guiHints/joinEcho"));
    }
  }

  function fillSystemOptions(group)
  {
    curGroup = group
    optionsContainers = [{ name="options_systemOptions", data=[] }]
    ::sysopt.fillGuiOptions(scene.findObject("optionslist"), this)
  }

  function onSystemOptionChanged(obj)
  {
    ::sysopt.onGuiOptionChanged(obj)
  }

  function onSystemOptionsRestartClient(obj)
  {
    ::sysopt.configWrite()
    ::sysopt.configFree()
    ::sysopt.applyRestartClient()
  }

  function passValueToParent(obj)
  {
    if (!::checkObj(obj))
      return
    local objParent = obj.getParent()
    if (!::checkObj(objParent))
      return
    local val = obj.getValue()
    if (objParent.getValue() != val)
      objParent.setValue(val)
  }

  function fillOptionsList(group, objName)
  {
    curGroup = group
    local config = optGroups[group]

    if( ! optionsConfig)
        optionsConfig = {}
    optionsConfig.onTblClick <- "onTblSelect"

    currentContainerName = "options_" + config.name
    local container = ::create_options_container(currentContainerName, config.options, true, true, columnsRatio,
                        true, true, optionsConfig)
    optionsContainers = [container.descr]

    guiScene.setUpdatesEnabled(false, false)
    guiScene.replaceContentFromText(scene.findObject(objName), container.tbl, container.tbl.len(), this)
    onHintUpdate()
    setNavigationItems()
    guiScene.setUpdatesEnabled(true, true)
  }

  function onPostFxSettings(obj)
  {
    applyFunc = gui_start_postfx_settings
    applyOptions()
    joinEchoChannel(false);
  }

  function onWebUiMap()
  {
    if(::WebUI.get_port() == 0)
      return

    ::WebUI.launch_browser()
  }

  function afterModalDestroy()
  {
    joinEchoChannel(false);
    base.afterModalDestroy()
  }

  function doApply()
  {
    local result = base.doApply();

    local group = curGroup == -1 ? null : optGroups[curGroup];
    if (group && ("onApplyHandler" in group) && group.onApplyHandler)
      group.onApplyHandler();

    return result;
  }

  function onDialogAddRadio()
  {
    ::gui_start_modal_wnd(::gui_handlers.AddRadioModalHandler, { owner=this })
  }

  function onDialogEditRadio()
  {
    local radio = ::get_internet_radio_options()
    if (!radio)
      return updateInternerRadioButtons()
    ::gui_start_modal_wnd(::gui_handlers.AddRadioModalHandler, { owner=this, editStationName=radio.station })
  }

  function onRemoveRadio()
  {
    local radio = ::get_internet_radio_options()
    if (!radio)
      return updateInternerRadioButtons()
    local nameRadio = radio.station
    msgBox("warning",
      ::format(::loc("options/msg_remove_radio"), nameRadio),
      [
        ["ok", (@(nameRadio) function() {
          ::remove_internet_radio_station(nameRadio);
          ::broadcastEvent("UpdateListRadio", {})
        })(nameRadio)],
        ["cancel", function() {}]
      ], "ok")
  }

  function onEventUpdateListRadio(params)
  {
    local obj = scene.findObject("groups_list")
    if (!obj)
      return
    fillOptionsList(obj.getValue(), "internetRadioOptions")
    updateInternerRadioButtons()
  }

  function updateInternerRadioButtons()
  {
    local radio = ::get_internet_radio_options()
    local isEnable = (radio && radio.station) ? ::is_internet_radio_station_removable(radio.station) : false
    local btnEditRadio = scene.findObject("btn_edit_radio")
    if (btnEditRadio)
      btnEditRadio.enable(isEnable)
    local btnRemoveRadio = scene.findObject("btn_remove_radio")
    if (btnRemoveRadio)
      btnRemoveRadio.enable(isEnable)
  }
}

class ::gui_handlers.AddRadioModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/popup/addRadio.blk"

  focusArray = [
    "newradio_name"
    "newradio_url"
  ]
  currentFocusItem = 0
  editStationName = ""

  function initScreen()
  {
    restoreFocus()
    scene.findObject("newradio_name").select()
    ::gui_handlers.GroupOptionsModal.updateInternerRadioButtons.call(this)
    local nameRadio = ::loc("options/internet_radio_" + ((editStationName == "") ? "add" : "edit"))
    local titleRadio = scene.findObject("internet_radio_title")
    titleRadio.setValue(nameRadio)
    local btnAddRadio = scene.findObject("btn_add_radio")
    btnAddRadio.setValue(nameRadio)
    if (editStationName != "")
    {
      local editName = scene.findObject("newradio_name")
      editName.setValue(editStationName)
      local editUrl = scene.findObject("newradio_url")
      local url = ::get_internet_radio_path(editStationName)
      editUrl.setValue(url)
    }
  }

  function onChanged()
  {
    local msg = getMsgByEditbox("url")
    if (msg == "")
      msg = getMsgByEditbox("name")
    local btnAddRadio = scene.findObject("btn_add_radio")
    btnAddRadio.enable((msg != "") ? false : true)
    btnAddRadio.tooltip = msg
  }

  function getMsgByEditbox(name)
  {
    local isEmpty = ::is_chat_message_empty(scene.findObject("newradio_"+name).getValue())
    return isEmpty ? ::loc("options/no_"+name+"_radio") : ""
  }

  function onFocusUrl()
  {
    local guiScene = ::get_gui_scene()
    guiScene["newradio_url"].select()
  }

  function onAddRadio()
  {
    local value = scene.findObject("newradio_name").getValue()
    if (::is_chat_message_empty(value))
      return

    local name = ::clearBorderSymbols(value, [" "])
    local url = scene.findObject("newradio_url").getValue()
    if(url != "")
      url = ::clearBorderSymbols(url, [" "])

    if (name == "")
      return msgBox("warning",
          ::loc("options/no_name_radio"),
          [["ok", function() {}]], "ok")
    if (url == "")
      return msgBox("warning",
          ::loc("options/no_url_radio"),
          [["ok", function() {}]], "ok")

    local listRadio = ::get_internet_radio_stations()
    if (editStationName != "")
    {
      ::edit_internet_radio_station(editStationName, name, url)
    } else {
      foreach (radio in listRadio)
      {
        if (radio == name)
          return msgBox("warning",
            ::loc("options/msg_name_exists_radio"),
            [["ok", function() {}]], "ok")
        if (radio == url)
          return msgBox("warning",
            ::loc("options/msg_url_exists_radio"),
            [["ok", function() {}]], "ok")
      }
      ::add_internet_radio_station(name, url);
    }
    goBack()
    ::broadcastEvent("UpdateListRadio", {})
  }
}

