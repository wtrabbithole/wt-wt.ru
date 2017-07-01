const SEARCH_CATEGORIES_SAVE_ID = "chat/searchCategories"

::g_chat_categories <- {
  [PERSISTENT_DATA_PARAMS] = ["list", "listSorted", "defaultCategoryName", "searchCategories"]

  list = {}
  listSorted = []
  defaultCategoryName = ""
  searchCategories = []
}

function g_chat_categories::isEnabled()
{
  return list.len() > 0 && ::has_feature("ChatThreadCategories")
}

function g_chat_categories::onEventInitConfigs(p)
{
  initThreadCategories()
}

function g_chat_categories::initThreadCategories()
{
  list.clear()
  listSorted.clear()
  searchCategories.clear()
  defaultCategoryName = ""

  local guiBlk = ::configs.GUI.get()
  local listBlk = guiBlk.chat_categories
  if (!::u.isDataBlock(listBlk))
    return

  local total = listBlk.blockCount()
  for(local i = 0; i < total; i++)
  {
    local cBlk = listBlk.getBlock(i)
    local name = cBlk.getBlockName()
    local category = ::buildTableFromBlk(cBlk)
    category.id <- name
    list[name] <- category
    listSorted.append(category)

    if (cBlk.isDefault || defaultCategoryName == "")
      defaultCategoryName = name
  }

  loadSearchCategories()
}

function g_chat_categories::loadSearchCategories()
{
  local blk = ::load_local_custom_settings(SEARCH_CATEGORIES_SAVE_ID)
  if (::u.isDataBlock(blk))
  {
    foreach(cat in listSorted)
      if (blk[cat.id])
        searchCategories.append(cat.id)
  }
  if (!searchCategories.len())
    searchCategories = ::u.map(listSorted, function(c) { return c.id })
}

function g_chat_categories::saveSearchCategories()
{
  local blk = null
  if (!isSearchAnyCategory())
  {
    blk = ::DataBlock()
    foreach(catName in searchCategories)
      blk[catName] <- true
  }
  ::save_local_custom_settings(SEARCH_CATEGORIES_SAVE_ID, blk)
}

function g_chat_categories::getSearchCategoriesLList()
{
  return searchCategories
}

function g_chat_categories::isSearchAnyCategory()
{
  return searchCategories.len() == 0 || searchCategories.len() >= list.len()
}

function g_chat_categories::getCategoryNameText(categoryName)
{
  return ::loc("chat/category/" + categoryName)
}

function g_chat_categories::fillCategoriesListObj(listObj, selCategoryName, handler)
{
  if (!::checkObj(listObj))
    return

  local view = {
    optionTag = "option"
    options= []
  }
  local selIdx = -1
  foreach(idx, category in listSorted)
  {
    local name = category.id
    if (name == selCategoryName)
      selIdx = idx

    view.options.append({
      text = getCategoryNameText(name)
      enabled = true
    })
  }

  local data = ::handyman.renderCached(("gui/options/spinnerOptions"), view)
  listObj.getScene().replaceContentFromText(listObj, data, data.len(), handler)

  if (selIdx >= 0)
    listObj.setValue(selIdx)
}

function g_chat_categories::getSelCategoryNameByListObj(listObj, defValue)
{
  if (!::checkObj(listObj))
    return defValue

  local category = ::getTblValue(listObj.getValue(), listSorted)
  if (category)
    return category.id
  return defValue
}

function g_chat_categories::openChooseCategoriesMenu(align = "top", alignObj = null)
{
  if (!isEnabled())
    return

  local optionsList = []
  local curCategories = getSearchCategoriesLList()
  foreach(cat in listSorted)
    optionsList.append({
      text = getCategoryNameText(cat.id)
      value = cat.id
      selected = ::isInArray(cat.id, curCategories)
    })

  ::gui_start_multi_select_menu({
    list = optionsList
    onFinalApplyCb = function(values) { ::g_chat_categories._setSearchCategories(values) }
    align = align
    alignObj = alignObj
  })
}

function g_chat_categories::_setSearchCategories(newValues)
{
  searchCategories = newValues
  saveSearchCategories()
  ::broadcastEvent("ChatSearchCategoriesChanged")
}

::g_script_reloader.registerPersistentDataFromRoot("g_chat_categories")
::subscribe_handler(::g_chat_categories, ::g_listener_priority.DEFAULT_HANDLER)