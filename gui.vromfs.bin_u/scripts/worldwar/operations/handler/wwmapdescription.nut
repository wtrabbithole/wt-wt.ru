//show info about WwMap, WwOperation or WwOperationgroup
class ::gui_handlers.WwMapDescription extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  descItem = null //WwMap, WwQueue, WwOperation, WwOperationGroup
  needEventHeader = true

  rootDescId = "item_desc"

  //this handler dosnt create own scene, just search objects in already exist scene.
  static function link(_scene, _descItem = null)
  {
    local params = {
      scene = _scene
      descItem = _descItem
    }

    if (_descItem instanceof ::WwOperation)
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
    local isVisible = isVisible()
    updateVisibilities(isVisible)
    if (!isVisible)
      return

    updateName()
    updateDescription()
    updateWorldCoords()
    updateCountriesList()
  }

  function isVisible()
  {
    return descItem != null
  }

  function updateVisibilities(isVisible)
  {
    if (scene.id == rootDescId)
      scene.show(isVisible)
    else
      showSceneBtn(rootDescId, isVisible)
  }

  function checkAndUpdateVisible()
  {
    if (!showDesc)
      return false

    return true
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
    return {
      countries = ::u.map(countries,
                    function (countryName) {
                      return {
                        countryName = countryName
                        countryIcon = ::get_country_icon(countryName)
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
    }
    local data = ::handyman.renderCached("gui/worldWar/wwOperationCountriesInfo", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }
}
