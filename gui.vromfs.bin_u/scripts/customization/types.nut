local enums = ::require("std/enums.nut")
local guidParser = require("scripts/guidParser.nut")
local time = require("scripts/time.nut")
local skinLocations = ::require("scripts/customization/skinLocations.nut")

::g_decorator_type <- {
  types = []
  cache = {
    byListId = {}
    byUnlockedItemType = {}
    byResourceType = {}
  }

  template = {
    unlockedItemType = -1
    resourceType = ""
    defaultLimitUsage = -1
    categoryWidgetIdPrefix = ""
    listId = ""
    listHeaderLocId = ""
    currentOpenedCategoryLocalSafePath = "wnd/unknownCategory"
    categoryPathPrefix = ""
    groupPathPrefix = ""
    removeDecoratorLocId = ""
    emptySlotLocId = ""
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_decal"
    prizeTypeIcon = "#ui/gameuiskin#item_type_unlock"
    defaultStyle = ""

    getAvailableSlots = function(unit) { return 0 }
    getMaxSlots = function() {return 1 }

    getImage = function(decorator) { return "" }
    getRatio = function(decorator) { return 1 }
    getImageSize = function(decorator) { return "0, 0" }

    getSmallIcon = @(decorator) decorator ? prizeTypeIcon : ""

    getLocName = function(decoratorName, addUnitName = false) { return ::loc(decoratorName) }
    getLocDesc = function(decoratorName) { return ::loc(decoratorName + "/desc", "") }
    getLocParamsDesc = @(decorator) ""

    function getTypeDesc(decorator)
    {
      local text = ::loc("trophy/unlockables_names/" + resourceType)
      if (decorator.category != "" && categoryPathPrefix != "")
        text += ::loc("ui/comma") + ::loc(categoryPathPrefix + decorator.category)
      if (decorator.group != "" && groupPathPrefix != "")
        text += ::loc("ui/comma") + ::loc(groupPathPrefix + decorator.group)
      return text
    }

    getCost = function(decoratorName) { return ::Cost() }
    getDecoratorNameInSlot = function(slotIdx, unitName, skinId, checkPremium = false) { return "" }
    getDecoratorGroupInSlot = function(slotIdx, unitName, skinId, checkPremium = false) { return "" }

    isAvailable = function(unit) { return false }
    isAllowed = function(decoratorName) { return true }
    isVisible = function(block, decorator)
    {
      if (!block)
        return true
      if (!isAllowed(block.getBlockName()))
        return false
      if (block.psn && !::is_platform_ps4)
        return false
      if (block.ps_plus && !::ps4_has_psplus())
        return false
      if (block.showByEntitlement && !::has_entitlement(block.showByEntitlement))
        return false
      if ((block % "hideForLang").find(::g_language.getLanguageName()) >= 0)
        return false
      foreach (feature in block % "reqFeature")
        if (!::has_feature(feature))
          return false

      if (!isPlayerHaveDecorator(decorator.id))
      {
        local isVisibleOnlyUnlocked = block.hideUntilUnlocked || !decorator.canRecieve()
        if (block.beginDate || block.endDate)
          isVisibleOnlyUnlocked = !time.isInTimerangeByUtcStrings(block.beginDate, block.endDate)
        if (isVisibleOnlyUnlocked)
          return false
      }
      return true
    }
    isPlayerHaveDecorator = function(decoratorName) { return false }

    getBlk = function() { return ::DataBlock() }
    getSpecialDecorator = function(id) { return null }
    getUgcDecorator = @(id, cache) null

    specifyEditableSlot = @(slotIdx, needFocus = true) null
    addDecorator = function(decoratorName) {}
    exitEditMode = function(apply, save = false, callback = function (){}) {}
    enterEditMode = function(decoratorName) {}
    removeDecorator = @(slotIdx, save) false
    replaceDecorator = function(slotIdx, decoratorName) {}

    buyFunc = function(unitName, id) {}
    save = function(unitName, showProgressBox) {}

    canRotate = function() { return false }
    canResize = function() { return false }
    canMirror = function() { return false }
    canToggle = function() { return false }
  }
}

enums.addTypesByGlobalName("g_decorator_type", {
  UNKNOWN = {
  }

  DECALS = {
    unlockedItemType = ::UNLOCKABLE_DECAL
    resourceType = "decal"
    categoryWidgetIdPrefix = "decals_category_"
    listId = "slots_list"
    listHeaderLocId = "decals"
    currentOpenedCategoryLocalSafePath = "wnd/decalsCategory"
    categoryPathPrefix = "decals/category/"
    groupPathPrefix = "decals/group/"
    removeDecoratorLocId = "mainmenu/requestDeleteDecal"
    emptySlotLocId = "mainmenu/decalFreeSlot"
    prizeTypeIcon = "#ui/gameuiskin#item_type_decal"
    defaultStyle = "reward_decal"

    jobCallbacksStack = {}

    getAvailableSlots = function(unit) { return ::get_num_decal_slots(unit.name) }
    getMaxSlots = function() { return ::get_max_num_decal_slots() }

    getImage = function(decorator)
    {
      return decorator
        ? ("@!" + decorator.tex + "*")
        : ""
    }

    getRatio = function(decorator) { return decorator? (decorator.aspect_ratio || 1) : 1 }
    getImageSize = function(decorator) { return ::format("256, %d", ::floor(256.0 / getRatio(decorator) + 0.5)) }

    getLocName = function(decoratorName, ...) { return ::loc("decals/" + decoratorName) }
    getLocDesc = function(decoratorName) { return ::loc("decals/" + decoratorName + "/desc", "") }

    getCost = function(decoratorName)
    {
      return ::Cost(::max(0, ::get_decal_cost_wp(decoratorName)),
                    ::max(0, ::get_decal_cost_gold(decoratorName)))
    }
    getDecoratorNameInSlot = function(slotIdx, unitName, skinId, checkPremium = false)
    {
      return ::hangar_get_decal_in_slot(unitName, skinId, slotIdx, checkPremium) //slow function
    }

    isAllowed = function(decoratorName) { return ::is_decal_allowed(decoratorName, "") }
    isAvailable = function(unit) { return ::has_feature("DecalsUse") && ::isUnitBought(unit) }
    isPlayerHaveDecorator = function(decoratorName) { return ::player_have_decal(decoratorName) }

    getBlk = function() { return ::get_decals_blk() }

    specifyEditableSlot = function(slotIdx, needFocus = true)
    {
      ::hangar_set_current_decal_slot(slotIdx)
      if (needFocus)
        ::hangar_focus_on_current_decal()
    }
    addDecorator = function(decoratorName) { return ::hangar_set_decal_in_slot(decoratorName) }
    removeDecorator = function(slotIdx, save)
    {
      specifyEditableSlot(slotIdx, false)
      enterEditMode("")
      return exitEditMode(true, save)
    }

    replaceDecorator = function(slotIdx, decoratorName)
    {
      specifyEditableSlot(slotIdx)
      addDecorator(decoratorName)
    }
    enterEditMode = function(decoratorName) { return ::hangar_enter_decal_mode(decoratorName) }
    exitEditMode = function(apply, save = false, callback = function () {}) {
      local res = ::hangar_exit_decal_mode(apply, save)
      if (res.success)
      {
        if (res.taskId != -1)
          jobCallbacksStack[res.taskId] <- callback
        else
          callback()
      }
      return res.success
    }

    buyFunc = function(unitName, id, afterSuccessFunc)
    {
      local blk = ::DataBlock()
      blk["name"] = id
      blk["type"] = "decal"
      blk["unitName"] = unitName

      local taskId = ::char_send_blk("cln_buy_resource", blk)
      local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
      ::g_tasker.addTask(taskId, taskOptions, afterSuccessFunc)
    }

    save = function(unitName, showProgressBox)
    {
      if (!::has_feature("DecalsUse"))
        return

      local taskId = ::save_decals(unitName)
      local taskOptions = { showProgressBox = showProgressBox }
      ::g_tasker.addTask(taskId, taskOptions)
    }

    canRotate = function() { return true }
    canResize = function() { return true }
    canMirror = function() { return true }
    canToggle = function() { return true }
  }

  ATTACHABLES = {
    unlockedItemType = ::UNLOCKABLE_ATTACHABLE
    resourceType = "attachable"
    defaultLimitUsage = 1
    categoryWidgetIdPrefix = "attachable_category_"
    listId = "slots_attachable_list"
    listHeaderLocId = "decorators"
    currentOpenedCategoryLocalSafePath = "wnd/attachablesCategory"
    categoryPathPrefix = "attachables/category/"
    groupPathPrefix = "attachables/group/"
    removeDecoratorLocId = "mainmenu/requestDeleteDecorator"
    emptySlotLocId = "mainmenu/attachableFreeSlot"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_attachable"
    prizeTypeIcon = "#ui/gameuiskin#item_type_attachable"
    defaultStyle = "reward_attachable"

    getAvailableSlots = function(unit) { return ::get_num_attachables_slots(unit.name) }
    getMaxSlots = function() { return ::get_max_num_attachables_slots() }

    getImage = function(decorator)
    {
      return decorator
        ? decorator.blk?.image || "#ui/images/attachables/" + decorator.id
        : ""
    }
    getImageSize = function(...) { return "128, 128" }

    getLocName = function(decoratorName, ...) { return ::loc("attachables/" + decoratorName) }
    getLocDesc = function(decoratorName) { return ::loc("attachables/" + decoratorName + "/desc", "") }
    getLocParamsDesc = function(decorator)
    {
      local paramPathPrefix = "attachables/param/"
      local angle = decorator.blk?.maxSurfaceAngle
      if (!angle)
        return ""

      return ::loc(paramPathPrefix + "maxSurfaceAngle", {value = angle})
    }

    getCost = function(decoratorName)
    {
      return ::Cost(::max(0, ::get_attachable_cost_wp(decoratorName)),
                    ::max(0, ::get_attachable_cost_gold(decoratorName)))
    }
    getDecoratorNameInSlot = function(slotIdx, ...) { return ::hangar_get_attachable_name(slotIdx) }
    getDecoratorGroupInSlot = function(slotIdx, ...) { return ::hangar_get_attachable_group(slotIdx) }

    isAvailable = function(unit) { return ::has_feature("AttachablesUse") && ::isUnitBought(unit) && ::isTank(unit) }
    isPlayerHaveDecorator = function(decoratorName) { return ::player_have_attachable(decoratorName) }

    getBlk = function() { return ::get_attachable_blk() }

    removeDecorator = function(slotIdx, save)
    {
      ::hangar_remove_attachable(slotIdx)
      exitEditMode(true, save)
    }

    specifyEditableSlot = @(slotIdx, needFocus = true) ::hangar_select_attachable_slot(slotIdx)
    enterEditMode = function(decoratorName) { return ::hangar_add_attachable(decoratorName) }
    exitEditMode = function(apply, save, callback = function () {}) {
      local res = ::hangar_exit_attachables_mode(apply, save)
      if (res)
        callback()
      return res
    }

    buyFunc = function(unitName, id, afterSuccessFunc)
    {
      local blk = ::DataBlock()
      blk["name"] = id
      blk["type"] = "attachable"
      blk["unitName"] = unitName

      local taskId = ::char_send_blk("cln_buy_resource", blk)
      local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
      ::g_tasker.addTask(taskId, taskOptions, afterSuccessFunc)
    }

    save = function(unitName, showProgressBox)
    {
      if (!::has_feature("AttachablesUse"))
        return

      local taskId = ::save_attachables(unitName)
      local taskOptions = { showProgressBox = showProgressBox }
      ::g_tasker.addTask(taskId, taskOptions)
    }

    canRotate = function() { return true }
  }
  SKINS = {
    unlockedItemType = ::UNLOCKABLE_SKIN
    resourceType = "skin"
    userlogPurchaseIcon = "#ui/gameuiskin#unlock_skin"
    prizeTypeIcon = "#ui/gameuiskin#item_type_skin"
    defaultStyle = "reward_skin"

    getImage = function(decorator)
    {
      if (!decorator)
        return ""
      local mask = skinLocations.getSkinLocationsMaskBySkinId(decorator.id)
      local iconType = skinLocations.getIconTypeByMask(mask)
      return "#ui/gameuiskin/item_skin" + (iconType == "forest" ? "" : ("_" + iconType))
    }

    getSmallIcon = function(decorator)
    {
      if (!decorator)
        return ""
      return "#ui/gameuiskin#icon_skin_" +
        skinLocations.getIconTypeByMask(skinLocations.getSkinLocationsMaskBySkinId(decorator.id))
    }

    getLocName = function(decoratorName, addUnitName = false)
    {
      if (guidParser.isGuid(decoratorName))
        return ::loc(decoratorName, ::loc("default_ugc_skin_loc"))

      local unitName = ::g_unlocks.getPlaneBySkinId(decoratorName)

      if (::g_unlocks.isDefaultSkin(decoratorName))
        decoratorName = ::loc(unitName + "/default", ::loc("default_skin_loc"))

      local name = ::loc(decoratorName)
      if (addUnitName && !::u.isEmpty(unitName))
        name += ::loc("ui/parentheses/space", { text = ::getUnitName(unitName) })

      return name
    }
    getLocDesc = function(decoratorName)
    {
      local defaultLocId = guidParser.isGuid(decoratorName) ? "default_ugc_skin_loc/desc" : "default_skin_loc/desc"
      return ::loc(decoratorName + "/desc", ::loc(defaultLocId))
    }

    function getTypeDesc(decorator)
    {
      local unit = ::getAircraftByName(::g_unlocks.getPlaneBySkinId(decorator.id))
      if (!unit)
        return ::loc("trophy/unlockables_names/skin")
      return ::loc("reward/skin_for") + " " +
        ::getUnitName(unit) + ::loc("ui/comma") + ::loc(::getUnitCountry(unit))
    }

    getCost = function(decoratorName)
    {
      local unitName = ::g_unlocks.getPlaneBySkinId(decoratorName)
      return ::Cost(::max(0, ::get_skin_cost_wp(unitName, decoratorName)),
                    ::max(0, ::get_skin_cost_gold(unitName, decoratorName)))
    }

    isPlayerHaveDecorator = function(decoratorName)
    {
      if (::g_unlocks.isDefaultSkin(decoratorName))
        return true

      return ::player_have_skin(::g_unlocks.getPlaneBySkinId(decoratorName),
                                ::g_unlocks.getSkinNameBySkinId(decoratorName))
    }

    getBlk = function() { return ::get_skins_blk() }

    buyFunc = function(unitName, id, afterSuccessFunc)
    {
      local blk = ::DataBlock()
      blk["name"] = id
      blk["type"] = "skin"
      blk["unitName"] = unitName

      local taskId = ::char_send_blk("cln_buy_resource", blk)
      local taskOptions = { showProgressBox = true, progressBoxText = ::loc("charServer/purchase") }
      ::g_tasker.addTask(taskId, taskOptions, afterSuccessFunc)
    }

    getSpecialDecorator = function(id)
    {
      if (::g_unlocks.getSkinNameBySkinId(id) == "default")
        return ::Decorator(id, this)
      return null
    }

    getUgcDecorator = function(id, cache)
    {
      if (id in cache)
        return cache[id]

      local isUgcDownloaded = guidParser.isGuid(::g_unlocks.getSkinNameBySkinId(id))
      local isUgcItemContent = !isUgcDownloaded && guidParser.isGuid(id)
      if (!isUgcDownloaded && !isUgcItemContent)
        return null

      cache[id] <- ::Decorator(getBlk()[id] || id, this)
      return cache[id]
    }
  }
}, null, "name")

function g_decorator_type::getTypeByListId(listId)
{
  return enums.getCachedType("listId", listId, ::g_decorator_type.cache.byListId, ::g_decorator_type, ::g_decorator_type.UNKNOWN)
}

function g_decorator_type::getTypeByUnlockedItemType(UnlockedItemType)
{
  return enums.getCachedType("unlockedItemType", UnlockedItemType, ::g_decorator_type.cache.byUnlockedItemType, ::g_decorator_type, ::g_decorator_type.UNKNOWN)
}

function g_decorator_type::getTypeByResourceType(resourceType)
{
  return enums.getCachedType("resourceType", resourceType, ::g_decorator_type.cache.byResourceType, ::g_decorator_type, ::g_decorator_type.UNKNOWN)
}
