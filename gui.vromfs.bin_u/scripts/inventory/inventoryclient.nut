local progressMsg = ::require("sqDagui/framework/progressMsg.nut")

enum validationCheckBitMask {
  VARTYPE    = 0x01
  EXISTENCE  = 0x02
  INVALIDATE = 0x04

  // masks
  REQUIRED   = 0x03
  VITAL      = 0x07
}

const INVENTORY_PROGRESS_MSG_ID = "INVENTORY_REQUEST"

local InventoryClient = class {
  items = {}
  waitingItems = []
  itemdefs = {}

  REQUEST_TIMEOUT_MSEC = 15000
  REQUEST_DELTA_MSEC = 5000
  lastUpdateTime = -1
  lastRequestTime = -1

  hasInventoryChanges = false
  hasItemDefChanges = false

  validateResponseData = {
    item_json = {
      [ validationCheckBitMask.VITAL ] = {
        itemid = ""
        itemdef = -1
      },
      [ validationCheckBitMask.REQUIRED ] = {
        accountid = ""
        position = 0
        quantity = 0
        state = "none"
        timestamp = ""
      },
      [ validationCheckBitMask.VARTYPE ] = {
      },
    }
    itemdef_json = {
      [ validationCheckBitMask.VITAL ] = {
        itemdefid = -1
      },
      [ validationCheckBitMask.REQUIRED ] = {
        type = ""
        Timestamp = ""
        marketable = false
        tradable = false
        exchange = ""
        background_color = ""
        name_color = ""
        icon_url = ""
        icon_url_large = ""
        promo = ""
        item_quality = 0
        meta = ""
        tags = ""
        item_slot = ""
      },
      [ validationCheckBitMask.VARTYPE ] = {
        bundle = ""
        name = ""
        name_english = ""
        description = ""
        description_english = ""
      },
    }
  }

  function request(action, headers, data, callback, progressBoxData = null)
  {
    headers.appid <- WT_APPID
    local requestData = {
      add_token = true,
      headers = headers,
      action = action
    }

    if (data) {
      requestData["data"] <- data;
    }

    if (progressBoxData)
      progressMsg.create(INVENTORY_PROGRESS_MSG_ID, progressBoxData)
    callback = ::Callback(callback, this)

    ::inventory.request(requestData, function(res) {
      callback(res)
      if (progressBoxData)
        progressMsg.destroy(INVENTORY_PROGRESS_MSG_ID, true)
    })
  }

  function getResultData(result, name)
  {
    local data = result?.response?[name]
    return _validate(data, name)
  }

  function _validate(data, name)
  {
    local validation = validateResponseData?[name]
    if (!data || !validation)
      return data

    if (!::u.isArray(data))
      return null

    local itemsBroken  = []
    local keysMissing   = {}
    local keysWrongType = {}

    for (local i = data.len() - 1; i >= 0; i--)
    {
      local item = data[i]
      local isItemValid = ::u.isTable(item)
      local itemErrors = 0

      foreach (checks, keys in validation)
      {
        local shouldInvalidate     = checks & validationCheckBitMask.INVALIDATE
        local shouldCheckExistence = checks & validationCheckBitMask.EXISTENCE
        local shouldCheckType      = checks & validationCheckBitMask.VARTYPE

        if (isItemValid)
          foreach (key, defVal in keys)
          {
            local isExist = (key in item)
            local val = item?[key]
            local isTypeCorrect = isExist && (type(val) == type(defVal) || ::is_numeric(val) == ::is_numeric(defVal))

            local isMissing   = shouldCheckExistence && !isExist
            local isWrongType = shouldCheckType && isExist && !isTypeCorrect
            if (isMissing || isWrongType)
            {
              itemErrors++

              if (isMissing)
                keysMissing[key] <- true
              if (isWrongType)
                keysWrongType[key] <- type(val) + "," + val

              if (shouldInvalidate)
                isItemValid = false

              item[key] <- defVal
            }
          }
      }

      if (!isItemValid || itemErrors)
      {
        local itemDebug = []
        foreach (checks, keys in validation)
          if (checks & validationCheckBitMask.INVALIDATE)
            foreach (key, val in keys)
              if (key in item)
                itemDebug.append(key + "=" + item[key])
        itemDebug.append(isItemValid ? ("err=" + itemErrors) : "INVALID")
        itemDebug.append(::u.isTable(item) ? ("len=" + item.len()) : ("var=" + type(item)))

        itemsBroken.append(::g_string.implode(itemDebug, ","))
      }

      if (!isItemValid)
        data.remove(i)
    }

    if (itemsBroken.len() || keysMissing.len() || keysWrongType.len())
    {
      itemsBroken = ::g_string.implode(itemsBroken, ";")
      keysMissing = ::g_string.implode(::u.keys(keysMissing), ";")
      keysWrongType = ::g_string.implode(::u.map(::u.pairs(keysWrongType), @(i) i[0] + "=" + i[1]), ";")
      ::script_net_assert_once("inventory client bad response", "InventoryClient: Response has errors: " + name)
    }

    return data
  }

  function getMarketplaceBaseUrl()
  {
    local circuit = ::get_cur_circuit_name();
    local networkBlock = ::get_network_block();
    return networkBlock?[circuit]?.marketplaceURL ?? networkBlock?.marketplaceURL;
  }

  function getMarketplaceItemUrl(itemdefid, itemid = null)
  {
    local marketplaceBaseUrl = getMarketplaceBaseUrl()
    if (!marketplaceBaseUrl)
      return null

    local item = itemdefid && itemdefs?[itemdefid]
    if (item && item?.market_hash_name)
      return marketplaceBaseUrl + "?viewitem&a=" + ::WT_APPID + "&n=" + ::encode_uri_component(item.market_hash_name)

    return null
  }

  function requestAll()
  {
    if (!canRefreshData())
      return

    lastRequestTime = ::dagor.getCurTime()
    requestInventory(function(result) {
      lastUpdateTime = ::dagor.getCurTime()

      local itemJson = getResultData(result, "item_json");
      if (!itemJson)
        return

      local oldItems = items
      items = {}
      foreach (item in itemJson) {
        local oldItem = ::getTblValue(item.itemid, oldItems)
        if (oldItem) {
          if (oldItem.timestamp != item.timestamp) {
            hasInventoryChanges = true
          }

          item.itemdef = oldItem.itemdef
          items[item.itemid] <- item

          delete oldItems[item.itemid]

          continue
        }

        if (item.quantity > 0) {
          waitingItems.append(item);
        }
      }

      if (oldItems.len() > 0) {
        hasInventoryChanges = true
      }

      processWaitingItems();

      if (waitingItems.len() > 0) {
        requestItemDefs();
      }
      else {
        notifyInventoryUpdate()
      }
    })
  }

  function requestInventory(callback) {
    request("GetInventory", {}, null, callback)
  }

  function processWaitingItems() {
    for (local i = waitingItems.len() - 1; i >= 0; --i) {
      local item = waitingItems[i]
      local itemdef = ::getTblValue(item.itemdef, itemdefs, null)
      if (itemdef) {
        if (itemdef.len() > 0) {
          item.itemdef = itemdef
          items[item.itemid] <- item
          waitingItems.remove(i)
          hasInventoryChanges = true
        }
      }
      else {
        itemdefs[item.itemdef] <- {}
      }
    }
  }

  function requestItemDefs(cb = null, shouldRefreshAll = false) {
    local itemdefids = ""
    foreach(key, value in itemdefs) {
      if (shouldRefreshAll || value.len() == 0) {
        if (itemdefids.len() > 0)
          itemdefids += ","

        itemdefids += key.tostring()
      }
    }

    if (itemdefids.len() == 0)
      return;

    dagor.debug("Request itemdefs " + itemdefids)

    local steamLanguage = ::g_language.getCurrentSteamLanguage()
    request("GetItemDefsClient", {itemdefids = itemdefids, language = steamLanguage}, null,
      function(result) {
        local itemdef_json = getResultData(result, "itemdef_json");
        if (!itemdef_json) {
          if (cb) {
            cb()
          }
          return
        }

        foreach (itemdef in itemdef_json) {
          hasItemDefChanges = hasItemDefChanges || shouldRefreshAll || ::u.isEmpty(itemdefs?[itemdef.itemdefid])
          addItemDef(itemdef)
        }

        processWaitingItems()
        notifyInventoryUpdate()
        if (cb) {
          cb()
        }
      })

    return false
  }

  function removeItem(itemid) {
    if (itemid in items)
      delete items[itemid]
    hasInventoryChanges = true
    notifyInventoryUpdate()
  }

  function notifyInventoryUpdate() {
    if (hasItemDefChanges) {
      hasItemDefChanges = false
      ::dagor.debug("ExtInventory itemDef changed")
      ::broadcastEvent("ItemDefChanged")
    }
    if (hasInventoryChanges) {
      hasInventoryChanges = false
      ::dagor.debug("ExtInventory changed")
      ::broadcastEvent("ExtInventoryChanged")
    }
  }

  function getItems() {
    return items
  }

  function getItemdefs() {
    return itemdefs
  }

  function requestItemdefsByIds(itemdefIdsList, cb = null)
  {
    foreach (itemdefid in itemdefIdsList)
      if (!(itemdefid in itemdefs))
        itemdefs[itemdefid] <- {}
    requestItemDefs(cb)
  }

  function addItemDef(itemdef) {
    itemdef.tags = getTagsItemDef(itemdef)

    itemdefs[itemdef.itemdefid] <- itemdef
  }

  function getTagsItemDef(itemdef)
  {
    local tags = ::getTblValue("tags" , itemdef, null)
    if (!tags)
      return

    local parsedTags = {}
    foreach (pair in ::split(tags, ";")) {
      local parsed = ::split(pair, ":")
      if (parsed.len() == 2) {
        local v = parsed[1]
        parsedTags[parsed[0]] <- v == "yes" ? true
          : v == "no" ? false
          : v
      }
    }
    return parsedTags
  }

  function parseRecipesString(recipesStr)
  {
    local recipes = []
    foreach (recipe in ::split(recipesStr || "", ";"))
    {
      local components = []
      foreach (component in ::split(recipe, ","))
      {
        local pair = ::split(component, "x")
        if (!pair.len())
          continue
        components.append({
          itemdefid = ::to_integer_safe(pair[0])
          quantity  = (1 in pair) ? ::to_integer_safe(pair[1]) : 1
        })
      }
      recipes.append(components)
    }
    return recipes
  }

  function handleItemsDelta(result, cb = null, shouldCheckInventory = true) {
    local itemJson = getResultData(result, "item_json")
    if (!itemJson)
      return

    local newItems = []
    foreach (item in itemJson) {
      local oldItem = ::getTblValue(item.itemid, items)
      if (item.quantity == 0) {
        if (oldItem) {
          delete items[item.itemid]
          hasInventoryChanges = true
        }

        continue
      }

      if (oldItem) {
        item.itemdef = oldItem.itemdef
        items[item.itemid] <- item
        hasInventoryChanges = true
        continue
      }

      newItems.append(item)
      waitingItems.append(item);
    }

    if (!shouldCheckInventory)
      return cb(newItems)

    processWaitingItems()
    if (waitingItems.len() > 0) {
      requestItemDefs(function() {
        if (cb) {
          for (local i = newItems.len() - 1; i >= 0; --i) {
            if (typeof(newItems[i].itemdef) != "table") {
              newItems.remove(i)
            }
          }

          cb(newItems)
        }
      })
    }
    else {
      notifyInventoryUpdate()
      if (cb) {
        cb(newItems)
      }
    }
  }

  function exchange(materials, outputitemdefid, cb = null, shouldCheckInventory = true) {
    local req = {
        outputitemdefid = outputitemdefid,
        materials = materials
    }

    request("ExchangeItems", {}, req,
      function(result) {
        handleItemsDelta(result, cb, shouldCheckInventory)
      },
      { }
    )
  }

  function getChestGeneratorItemdefIds(itemdefid) {
    local usedToCreate = itemdefs?[itemdefid]?.used_to_create
    local parsedRecipes = parseRecipesString(usedToCreate)

    local res = []
    foreach (recipeCfg in parsedRecipes)
    {
      local id = ::to_integer_safe(recipeCfg?[0]?.itemdefid ?? "", -1)
      if (id != -1)
        res.append(id)
    }
    return res
  }

  function canRefreshData()
  {
    if (!::has_feature("ExtInventory"))
      return false

    if (lastRequestTime > lastUpdateTime && lastRequestTime + REQUEST_TIMEOUT_MSEC > ::dagor.getCurTime())
      return false
    if (lastUpdateTime > 0 && lastUpdateTime + REQUEST_DELTA_MSEC > ::dagor.getCurTime())
      return false

    return true
  }

  function forceRefreshItemDefs()
  {
    requestItemDefs(function() {
      foreach (itemid, item in items) {
        local itemdef = ::getTblValue(item.itemdef.itemdefid, itemdefs, null)
        if (itemdef) {
          if (itemdef.len() > 0) {
            item.itemdef = itemdef
            hasInventoryChanges = true
          }
        }
      }
      notifyInventoryUpdate()
    }, true)
  }
}

return InventoryClient()