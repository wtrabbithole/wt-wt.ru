//show info about WwMap, WwOperation or WwOperationgroup
class ::gui_handlers.WwMapDescription extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  descItem = null //WwMap, WwQueue, WwOperation, WwOperationGroup
  map = null
  needEventHeader = true

  rootDescId = "item_desc"

  //this handler dosnt create own scene, just search objects in already exist scene.
  static function link(_scene, _descItem = null, _map = null)
  {
    local params = {
      scene = _scene
      descItem = _descItem
      map = _map
    }

    if ((!_descItem && _map) || (_descItem instanceof ::WwOperation))
      return ::handlersManager.loadHandler(::gui_handlers.WwOperationDescriptionCustomHandler, params)
    else if (_descItem instanceof ::WwQueue)
      return ::handlersManager.loadHandler(::gui_handlers.WwQueueDescriptionCustomHandler, params)
    else
      return ::handlersManager.loadHandler(::gui_handlers.WwMapDescription, params)
  }

  function initScreen()
  {
    scene.setUserData(this) //to not unload handler even when scene not loaded
    updateView()

    local timerObj = scene.findObject("ww_map_description_timer")
    if (timerObj)
      timerObj.setUserData(this)
  }

  function setDescItem(newDescItem)
  {
    descItem = newDescItem
    updateView()
  }

  function initCustomHandlerScene()
  {
    //this handler dosnt replace content in scene.
    guiScene = scene.getScene()
    return true
  }

  function updateView()
  {
    local isShow = isVisible()
    updateVisibilities(isShow)
    if (!isShow)
      return

    updateName()
    updateDescription()
    updateWorldCoords()
    updateCountriesList()
    updateTotalClansText()
    updateAvailableText()
  }

  function isVisible()
  {
    return descItem != null && map != null
  }

  function updateVisibilities(isShow)
  {
    if (scene.id == rootDescId)
      scene.show(isShow)
    else
      showSceneBtn(rootDescId, isShow)
  }

  function updateName()
  {
    local nameObj = scene.findObject("item_name")
    if (::checkObj(nameObj))
      nameObj.setValue(descItem.getNameText())
  }

  function updateDescription()
  {
    local desctObj = scene.findObject("item_desc")
    if (::checkObj(desctObj))
      desctObj.setValue(descItem.getDescription())
  }

  function updateWorldCoords()
  {
    local obj = scene.findObject("world_coords_text")
    if (::checkObj(obj))
      obj.setValue(descItem.getGeoCoordsText())
  }

  function mapCountriesToView(countries)
  {
    local teamsInfoText = descItem.getMinClansCondition()
    return {
      countries = ::u.map(countries,
                    function (countryName) {
                      return {
                        countryName = countryName
                        countryIcon = ::get_country_icon(countryName)
                        teamsInfoText = teamsInfoText
                      }
                    }
                  )
    }
  }

  function updateCountriesList()
  {
    local obj = scene.findObject("div_before_text")
    if (!::checkObj(obj))
      return

    local cuntriesByTeams = descItem.getCountriesByTeams()
    local view = {
      side1 = mapCountriesToView(::getTblValue(::SIDE_1, cuntriesByTeams, {}))
      side2 = mapCountriesToView(::getTblValue(::SIDE_2, cuntriesByTeams, {}))
      vsText = ::loc("country/VS") + "\n "
    }
    local data = ::handyman.renderCached("gui/worldWar/wwOperationCountriesInfo", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    obj.show(true)
  }

  function updateTotalClansText()
  {
    local obj = scene.findObject("total_members_text")
    if (!::check_obj(obj))
      return

    obj.setValue(descItem.getClansNumberInQueueText())
  }

  function updateAvailableText()
  {
    local obj = scene.findObject("available_text")
    if (!::check_obj(obj) || !descItem)
      return

    obj.setValue(descItem.getMapChangeStateTimeText())
  }

  function onTimerDescriptionUpdate(obj, dt)
  {
    updateAvailableText()
  }
}
