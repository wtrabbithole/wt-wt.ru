const SEARCH_CATEGORIES_SAVE_ID = "chat/searchCategories"

::g_chat_categories <- {
  [PERSISTENT_DATA_PARAMS] = ["list", "listSorted", "defaultCategoryName", "searchCategories"]

  list = {}
  listSorted = []
  defaultCategoryName = ""
  searchCategories = []
}

g_chat_categories.isEnabled <- function isEnabled()
{
  return list.len() > 0 && ::has_feature("ChatThreadCategories")
}

g_chat_categories.onEventInitConfigs <- function onEventInitConfigs(p)
{
  initThreadCategories()
}

g_chat_categories.initThreadCategories <- function initThreadCategories()
{
  list.clear()
  listSorted.clear()
  searchCategories.clear()
  defaultCategoryName = ""

  local guiBlk = ::configs.GUI.get()
  local listBlk = guiBlk?.chat_categories
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

    if (cBlk?.isDefault == true || defaultCategoryName == "")
      defaultCategoryName = name
  }

  loadSearchCategories()
}

g_chat_categories.loadSearchCategories <- function loadSearchCategories()
{
  local blk = ::load_local_account_settings(SEARCH_CATEGORIES_SAVE_ID)
  if (::u.isDataBlock(blk))
  {
    foreach(cat in listSorted)
      if (blk?[cat.id])
        searchCategories.append(cat.id)
  }
  if (!searchCategories.len())
    searchCategories = ::u.map(listSorted, function(c) { return c.id })
}

g_chat_categories.saveSearchCategories <- function saveSearchCategories()
{
  local blk = null
  if (!isSearchAnyCategory())
  {
    blk = ::DataBlock()
    foreach(catName in searchCategories)
      blk[catName] <- true
  }
  ::save_local_account_settings(SEARCH_CATEGORIES_SAVE_ID, blk)
}

g_chat_categories.getSearchCategoriesLList <- function getSearchCategoriesLList()
{
  return searchCategories
}

g_chat_categories.isSearchAnyCategory <- function isSearchAnyCategory()
{
  return searchCategories.len() == 0 || searchCategories.len() >= list.len()
}

g_chat_categories.getCategoryNameText <- function getCategoryNameText(categoryName)
{
  return ::loc("chat/category/" + categoryName)
}

g_chat_categories.fillCategoriesListObj <- function fillCategoriesListObj(listObj, selCategoryName, handler)
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

g_chat_categories.getSelCategoryNameByListObj <- function getSelCategoryNameByListObj(listObj, defValue)
{
  if (!::checkObj(listObj))
    return defValue

  local category = ::getTblValue(listObj.getValue(), listSorted)
  if (category)
    return category.id
  return defValue
}

g_chat_categories.openChooseCategoriesMenu <- function openChooseCategoriesMenu(align = "top", alignObj = null)
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

g_chat_categories._setSearchCategories <- function _setSearchCategories(newValues)
{
  searchCategories = newValues
  saveSearchCategories()
  ::broadcastEvent("ChatSearchCategoriesChanged")
}

::g_script_reloader.registerPersistentDataFromRoot("g_chat_categories")
::subscribe_handler(::g_chat_categories, ::g_listener_priority.DEFAULT_HANDLER)