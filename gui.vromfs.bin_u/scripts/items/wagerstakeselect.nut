class ::gui_handlers.WagerStakeSelect extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  parentObj = null
  align = null
  wagerItem = null
  _currentValue = 0
  _maxValue = 0
  helperCost = Cost() // Used to generate properly colored markup.
  cb = null // Main callback (from items shop).
  hasPopupMenuArrow = null

  static function open(parentObj, align, wagerItem, cb, hasPopupMenuArrow = true)
  {
    local params = {
      parentObj = parentObj
      align = align
      wagerItem = wagerItem
      cb = cb
      hasPopupMenuArrow = hasPopupMenuArrow
    }
    ::handlersManager.loadHandler(::gui_handlers.WagerStakeSelect, params)
  }

  function initScreen()
  {
    if (!::checkObj(scene))
      return goBack()
    if (::checkObj(guiScene["wager_select"])) //duplicate protection
      return goBack()
    local view = {
      hasPopupMenuArrow = hasPopupMenuArrow
    }
    local blk = ::handyman.renderCached(("gui/items/wagerStakeSelect"), view)
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(parentObj, align, scene.findObject("stake_select"), {
      customPosY = 0.9
    })
    setMaxValue(getMaxValueByItem(wagerItem))
    setCurrentValue(getValueByStake(getMaxStake(wagerItem)))
    updateButtons()
    initFocusArray()
  }

  function getMainFocusObj()
  {
    return scene.findObject("skillSlider")
  }

  function setMaxValue(value)
  {
    _maxValue = value
    local skillSliderObj = scene.findObject("skillSlider")
    if (::checkObj(skillSliderObj))
      skillSliderObj.max = _maxValue
    local newSkillProgressObj = scene.findObject("newSkillProgress")
    if (::checkObj(newSkillProgressObj))
      newSkillProgressObj.max = _maxValue
    if (_currentValue > _maxValue)
      setCurrentValue(_maxValue)
  }

  function setCurrentValue(value)
  {
    _setCurrentValue(value, true)
  }

  /**
   * @param includeMainSlider Helps to avoid recursion when
   * calling this method from within main slider callback.
   */
  function _setCurrentValue(value, includeMainSlider)
  {
    _currentValue = ::clamp(value, 0, _maxValue)
    if (includeMainSlider)
    {
      local skillSliderObj = scene.findObject("skillSlider")
      if (::checkObj(skillSliderObj))
        skillSliderObj.setValue(_currentValue)
    }
    local newSkillProgressObj = scene.findObject("newSkillProgress")
    if (::checkObj(newSkillProgressObj))
      newSkillProgressObj.setValue(_currentValue)
    wagerItem.curWager = getStakeByValue(_currentValue)
    updateStakeText()
  }

  function getStakeByValue(value)
  {
    return ::ceil(::lerp(0, _maxValue, wagerItem.minWager, wagerItem.maxWager, value))
  }

  function getValueByStake(stake)
  {
    return ::ceil(::lerp(wagerItem.minWager, wagerItem.maxWager, 0, _maxValue, stake))
  }

  function getMaxValueByItem(item)
  {
    local value = ::ceil((item.maxWager - item.minWager) / ::max(item.wagerStep, 1)).tointeger()
    return ::min(value, 100).tointeger()
  }

  function getMaxStake(item)
  {
    local maxUserStakeResource = item.isGoldWager
      ? ::get_cur_rank_info().gold
      : ::get_cur_rank_info().wp
    return ::min(item.maxWager, maxUserStakeResource)
  }

  function updateButtons()
  {
    local buttonDecObj = scene.findObject("buttonDec")
    if (::checkObj(buttonDecObj))
      buttonDecObj.enable(_currentValue > 0)
    local buttonIncObj = scene.findObject("buttonInc")
    if (::checkObj(buttonIncObj))
      buttonIncObj.enable(_currentValue < _maxValue)
  }

  function updateStakeText()
  {
    local stakeTextObj = scene.findObject("stake_select_stake")
    if (!::checkObj(stakeTextObj))
      return
    if (wagerItem.isGoldWager)
      helperCost.gold = wagerItem.curWager
    else
      helperCost.wp = wagerItem.curWager
    local text
    if (wagerItem.isGoldWager)
      text = helperCost.getGoldText(true, true)
    else if (wagerItem.curWager == 0)
      text = helperCost.getColoredWpText()
    else
      text = helperCost.getTextAccordingToBalance()
    stakeTextObj.setValue(text)
  }

  function onSkillChanged(obj)
  {
    _setCurrentValue(obj.getValue(), false)
    updateButtons()
  }

  function onButtonDec(obj)
  {
    if (_currentValue > 0)
      setCurrentValue(_currentValue - 1)
  }

  function onButtonInc(obj)
  {
    if (_currentValue < _maxValue)
      setCurrentValue(_currentValue + 1)
  }

  function onMainButton(obj)
  {
    wagerItem.activate((@(cb) function (result) {
      if (result.success)
        goBack()
      cb(result)
    })(cb).bindenv(this), this)
  }
}
