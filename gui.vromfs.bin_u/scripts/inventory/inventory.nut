const WT_APPID = 257;

local InventoryClient = class {
  function request(action, data, callback)
  {
    local request = {
      add_token = true,
      headers = { appid = WT_APPID },
      action = action
    }

    if (data) {
      request["data"] <- data;
    }

    inventory.request(request, callback);
  }
}
inventoryClient <- InventoryClient()

function testinv()
{
  inventoryClient.request("GetInventory", null, function(result) {
    debugTableData(result);
  })

  inventoryClient.request("GetItemDefs", null, function(result) {
    debugTableData(result);
  })
}