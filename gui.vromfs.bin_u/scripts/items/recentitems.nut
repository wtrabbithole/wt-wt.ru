::g_recent_items <- {
  MAX_RECENT_ITEMS = 4
  wasCreated = false
}

function g_recent_items::getRecentItems()
{
  local items = ::ItemsManager.getInventoryList(itemType.ALL, function (item) {
    return item.includeInRecentItems
  })
  items.sort(::ItemsManager.itemsSortComparator)
  local resultItems = []
  foreach (item in items)
  {
    resultItems.push(item)
    if (resultItems.len() == MAX_RECENT_ITEMS)
      break
  }

  return resultItems
}

function g_recent_items::createHandler(owner, containerObj)
{
  if (!::checkObj(containerObj))
    return null

  wasCreated = true
  return ::handlersManager.loadHandler(::gui_handlers.RecentItemsHandler, { scene = containerObj })
}

function g_recent_items::getNumOtherItems()
{
  local inactiveItems = ::ItemsManager.getInventoryList(itemType.ALL, function (item) {
    return item.getMainActionName() != ""
  })
  return inactiveItems.len()
}

function g_recent_items::reset()
{
  wasCreated = false
}
