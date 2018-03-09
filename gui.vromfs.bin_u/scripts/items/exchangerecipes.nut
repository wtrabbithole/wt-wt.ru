local inventoryClient = require("scripts/inventory/inventoryClient.nut")

local ExchangeRecipes = class {
  components = null
  materials = null
  generatorId = null

  isUsable = false
  isMultipleItems = false
  isMultipleExtraItems = false

  constructor(parsedRecipe, _generatorId)
  {
    generatorId = _generatorId

    local componentsCount = parsedRecipe.len()
    isUsable = componentsCount > 0
    isMultipleItems = isMultipleItems || componentsCount > 1
    isMultipleExtraItems = isMultipleExtraItems || componentsCount > 2

    components = []
    materials = []
    foreach (component in parsedRecipe)
    {
      local items = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id == component.itemdefid)
      local inventoryItem = items?[0] ?? null

      local curQuantity = inventoryItem ? inventoryItem.amount : 0
      local isHave = curQuantity >= component.quantity
      isUsable = isUsable && isHave

      components.append({
        has = isHave
        itemdefId = component.itemdefid
        reqQuantity = component.quantity
        curQuantity = curQuantity
      })

      if (isUsable)
        for (local i = 0; i < component.quantity; i++)
          materials.append([ inventoryItem.uids[i], 1 ])
    }

    if (!isUsable)
      materials = null
  }

  function hasComponent(itemdefid)
  {
    foreach (c in components)
      if (c.itemdefId == itemdefid)
        return true
    return false
  }

  function getExchangeMarkup(componentItem, params)
  {
    local list = []
    foreach (component in components)
    {
      if (component.itemdefId == componentItem.id)
        continue
      list.append(::DataBlockAdapter({
        item  = component.itemdefId
        commentText = getComponentQuantityText(component)
      }))
    }
    return ::PrizesView.getPrizesListView(list, params)
  }

  static function getRequirementsMarkup(recipes, componentItem, params)
  {
    return _getRequirements(recipes, componentItem, params, true)
  }

  static function getRequirementsText(recipes, componentItem, params)
  {
    return _getRequirements(recipes, componentItem, params, false)
  }

  static function _getRequirements(recipes, componentItem, params, shouldReturnMarkup)
  {
    local isMultipleRecipes = recipes.len() > 1
    local isMultipleItems = false
    local isMultipleExtraItems = false

    foreach (recipe in recipes)
    {
      isMultipleItems      = isMultipleItems      || recipe.isMultipleItems
      isMultipleExtraItems = isMultipleExtraItems || recipe.isMultipleExtraItems
    }

    if (!isMultipleRecipes && !isMultipleItems)
      return ""

    local headerPrefix = componentItem.iType == itemType.CHEST ? "chest/requires/" : "key/requires/"
    local headerSuffix = isMultipleRecipes && isMultipleExtraItems  ? "any_of_item_sets"
      : !isMultipleRecipes && isMultipleExtraItems ? "items_set"
      : isMultipleRecipes && !isMultipleExtraItems ? "any_of_items"
      : "item"
    local headerFirst = ::colorize("grayOptionColor", ::loc(headerPrefix + headerSuffix))
    local headerNext = isMultipleRecipes && isMultipleExtraItems ?
      ::colorize("grayOptionColor", ::loc("hints/shortcut_separator")) : null

    local res = []
    foreach (recipe in recipes)
    {
      local list = []
      foreach (component in recipe.components)
      {
        if (component.itemdefId == componentItem.id)
          continue
        list.append(::DataBlockAdapter({
          item  = component.itemdefId
          commentText = getComponentQuantityText(component)
        }))
      }
      params.header <- !res.len() ? headerFirst : headerNext
      if (shouldReturnMarkup)
        res.append(::PrizesView.getPrizesListView(list, params))
      else
        res.append(::PrizesView.getPrizesListText(list, @(...) params.header))
    }

    return ::g_string.implode(res, shouldReturnMarkup ? "" : "\n")
  }

  static function getComponentQuantityText(component)
  {
    return ::colorize(component.has ? "goodTextColor" : "badTextColor",
      ::loc("ui/parentheses/space", { text = component.curQuantity + "/" + component.reqQuantity }))
  }

  static function tryUse(recipes, componentItem)
  {
    local recipe = null
    foreach (r in recipes)
      if (r.isUsable)
      {
        recipe = r
        break
      }

    if (recipe)
    {
      local text = ::loc("msgBox/chestOpen/confirm", { itemName = ::colorize("activeTextColor", componentItem.getName()) })
      local markup = ""
      local handler = null
      if (recipe.isMultipleItems)
      {
        text += "\n" + ::loc("msgBox/extra_items_will_be_spent")
        markup = recipe.getExchangeMarkup(componentItem, { widthByParentParent = true })
        handler = ::get_cur_base_gui_handler()
      }
      local msgboxParams = { data_below_text = markup, baseHandler = handler, cancel_fn = function() {} }

      ::scene_msg_box("chest_exchange", null, text, [
        [ "yes", ::Callback(@() recipe.doExchange(componentItem), this) ],
        [ "no" ]
      ], "yes", msgboxParams)
      return true
    }
    else
    {
      local text = ::colorize("badTextColor", ::loc("msgBox/chestOpen/cant"))
      local markupParams = { widthByParentParent = true }
      local markup = getRequirementsMarkup(recipes, componentItem, markupParams)
      local handler = ::get_cur_base_gui_handler()
      local msgboxParams = { data_below_text = markup, baseHandler = handler, cancel_fn = function() {} }

      // If only one item is required (usually a Key for a Chest), suggest to buy it now.
      local requiredItem = null
      if (::ItemsManager.isMarketplaceEnabled() && recipes.len() == 1 && recipes[0].components.len() == 2)
        foreach (c in recipes[0].components)
          if (c.itemdefId != componentItem.id)
          {
            local item = ::ItemsManager.findItemById(c.itemdefId)
            if (item && item.link != "")
              requiredItem = item
            break
          }

      local buttons = [ ["cancel"] ]
      local defBtn = "cancel"
      if (requiredItem)
      {
        buttons.insert(0, [ "find_on_marketplace", ::Callback(@() requiredItem.openLink(), this) ])
        defBtn = "find_on_marketplace"
      }

      ::scene_msg_box("cant_open_chest", null, text, buttons, defBtn, msgboxParams)
      return false
    }
  }


  //////////////////////////////////// Internal functions ////////////////////////////////////


  function doExchange(componentItem)
  {
    inventoryClient.exchange(materials, generatorId, function(items) {
      ::ItemsManager.markInventoryUpdate()

      local configsArray = []
      foreach (extItem in items)
      {
        local item = ::ItemsManager.findItemByUid(extItem?.itemid)
        if (item?.uids?[0])
          configsArray.append({
            id = componentItem.id
            item = item.id
          })
      }
      ::gui_start_open_trophy({ [componentItem.id] = configsArray })
    })
  }
}

return ExchangeRecipes
