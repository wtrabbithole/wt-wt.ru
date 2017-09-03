local InventoryClient = class {
  items = {}
  waitingItems = []
  itemdefs = {}

  REQUEST_TIMEOUT_MSEC = 15000
  REQUEST_DELTA_MSEC = 5000
  lastUpdateTime = -1
  lastRequestTime = -1
  hasChanges = false

  function request(action, headers, data, callback)
  {
    headers.appid <- WT_APPID
    local request = {
      add_token = true,
      headers = headers,
      action = action
    }

    if (data) {
      request["data"] <- data;
    }

    ::inventory.request(request, callback)
  }

  function getResultData(result, name)
  {
    return ::getTblValue(name , ::getTblValue("response" , result))
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
            hasChanges = true
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
        hasChanges = true
      }

      processWaitingItems();

      if (waitingItems.len() > 0) {
        requestItemDefs();
      }
      else {
        notifyInventoryUpdate()
      }
    }.bindenv(this))
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
          hasChanges = true
        }
      }
      else {
        itemdefs[item.itemdef] <- {}
      }
    }
  }

  function requestItemDefs(cb = null) {
    local itemdefids = ""
    foreach(key, value in itemdefs) {
      if (value.len() == 0) {
        if (itemdefids.len() > 0)
          itemdefids += ","

        itemdefids += key.tostring()
      }
    }

    if (itemdefids.len() == 0)
      return;

    dagor.debug("Request itemdefs " + itemdefids)

    request("GetItemDefs", {itemdefids = itemdefids}, null, function(result) {
      local itemdef_json = getResultData(result, "itemdef_json");
      if (!itemdef_json) {
        if (cb) {
          cb()
        }
        return
      }

      foreach (itemdef in itemdef_json) {
        addItemDef(itemdef)
      }

      processWaitingItems()
      notifyInventoryUpdate()
      if (cb) {
        cb()
      }
    }.bindenv(this))

    return false
  }

  function removeItem(itemid) {
    delete items[itemid]
    hasChanges = true
    notifyInventoryUpdate()
  }

  function notifyInventoryUpdate() {
    if (hasChanges) {
      hasChanges = false
      ::dagor.debug("ExtInventory changed")
      ::broadcastEvent("InventoryChanged")
    }
  }

  function getItems() {
    return items
  }

  function getItemdefs() {
    return itemdefs
  }

  function addItemDef(itemdef) {
    local tags = ::getTblValue("tags" , itemdef, null)
    if (!tags)
      return

    local parsedTags = {}
    foreach (pair in ::split(tags, ";")) {
      local parsed = ::split(pair, ":")
      if (parsed.len() == 2) {
        parsedTags[parsed[0]] <- parsed[1]
      }
    }

    itemdef.tags = parsedTags

    itemdefs[itemdef.itemdefid] <- itemdef
  }

  function handleItemsDelta(result, cb = null) {
    local itemJson = getResultData(result, "item_json")
    if (!itemJson)
      return

    local newItems = []
    foreach (item in itemJson) {
      local oldItem = ::getTblValue(item.itemid, items)
      if (item.quantity == 0) {
        if (oldItem) {
          delete items[item.itemid]
          hasChanges = true
        }

        continue
      }

      if (oldItem) {
        item.itemdef = oldItem.itemdef
        items[item.itemid] <- item
        hasChanges = true
        continue
      }

      newItems.append(item)
      waitingItems.append(item);
    }

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
      });
    }
    else {
      notifyInventoryUpdate()
      if (cb) {
        cb(newItems)
      }
    }
  }

  function exchange(materials, outputitemdefid, cb = null) {
    local req = {
        outputitemdefid = outputitemdefid,
        materials = materials
    }

    request("ExchangeItems", {}, req, function(result) {
      handleItemsDelta(result, cb)
    }.bindenv(this))
  }

  function openChest(id, cb = null) {
    local outputitemdefid = items[id].itemdef.itemdefid + 1
    exchange([[id, 1]], outputitemdefid, cb)
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
}

return InventoryClient()