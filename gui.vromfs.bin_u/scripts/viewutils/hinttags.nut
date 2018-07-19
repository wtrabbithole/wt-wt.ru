local enums = ::require("std/enums.nut")
enum hintTagCheckOrder {
  EXACT_WORD //single word tags
  REGULAR
  ALL_OTHER //all other tags are work as shortcuts
}

::g_hint_tag <- {
  types = []
}

::g_hint_tag.template <- {
  typeName = ""
  checkOrder = hintTagCheckOrder.EXACT_WORD

  checkTag = function(tagName) { return typeName == tagName }
  getViewSlices = function(tagName, params) { return [] }
  makeTag = function(params = null) { return typeName }
  makeFullTag = @(params = null) ::g_hints.hintTags[0] + makeTag(params) + ::g_hints.hintTags[1]
}

enums.addTypesByGlobalName("g_hint_tag", {
  TIMER = {
    typeName = "@"
    getViewSlices = function(tagName, params)
    {
      local total = (::getTblValue("time", params, 0) + 0.5).tointeger()
      local offset = ::getTblValue("timeoffset", params, 0)
      return [{
               timer = {
                 incFactor = total ? 360.0 / total : 0
                 angle = (offset && total) ? (360 * offset / total).tointeger() : 0
                 hideWhenStopped = ::getTblValue("hideWhenStopped", params, false)
                 timerOffsetX = ::getTblValue("timerOffsetX", params)
               }
             }]
    }
  }

  SHORTCUT = {
    typeName = ""
    checkOrder = hintTagCheckOrder.ALL_OTHER
    checkTag = function(tagName) { return true }

    getViewSlices = function(tagName, params) //tagName == shortcutId
    {
      local slices = []

      local expanded = ::g_shortcut_type.expandShortcuts([tagName])
      foreach (expandedShortcut in expanded)
      {
        local shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(expandedShortcut)
        slices.append({
          shortcut = function () {
            local input = shortcutType.getFirstInput(expandedShortcut)
            return input.getMarkup()
          }
        })
      }
      return slices
    }
  }

  IMAGE = {
    typeName = "img="
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return ::g_string.startsWith(tagName, typeName) }
    colorParam = "color="
    sizeParam = "sizeStyle="
    delimiter = " "
    getViewSlices = function(tagName, params)
    {
      local paramsList = ::split(tagName, delimiter)
      local res = {
        image = ::g_string.cutPrefix(paramsList[0], typeName,  "")
        color = null
        sizeStyle = null
      }
      for(local i = 1; i < paramsList.len(); i++)
      {
        res.color = res.color || ::g_string.cutPrefix(paramsList[i], colorParam)
        res.sizeStyle = res.sizeStyle || ::g_string.cutPrefix(paramsList[i], sizeParam)
      }
      return [res]
    }
    makeTag = function(params = null)
    {
      return typeName + (params?.image || "")
        + (params?.color      ? delimiter + colorParam + params.color : "")
        + (params?.sizeStyle  ? delimiter + sizeParam + params.sizeStyle : "")
    }
  }

  MISSION_ATTEMPTS_LEFT = {
    typeName = "attempts_left" //{{attempts_left}} or {{attempts_left=locId}}
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return ::g_string.startsWith(tagName, typeName) }
    getViewSlices = function(tagName, params)
    {
      local attempts = ::get_num_attempts_left()
      local attemptsText = ""
      if (attempts < 0)
        attemptsText = ::loc("options/attemptsUnlimited")
      else
      {
        if (!::is_player_unit_alive())
          attempts--
        attemptsText = attempts
      }
      if (tagName.len() > typeName.len() + 1) //{{attempts_left=locId}}
      {
        local locId = tagName.slice(typeName.len() + 1)
        attemptsText = ::loc(locId, {
          attemptsText = attemptsText
          attempts = attempts
        })
      }
      return [{
        text = attemptsText
      }]
    }
  }

  INPUT_BUTTON = {
    typeName = "INPUT_BUTTON"
    delimiter = " "
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return ::g_string.startsWith(tagName, typeName) }

    getViewSlices = function(tagName, params) //tagName == shortcutId
    {
      local paramsList = ::split(tagName, delimiter)
      local shortcut = ::SHORTCUT?[paramsList?[1]]
      if (!u.isTable(shortcut))
        return []

      return [{
        shortcut = ::Input.Button(shortcut.dev[0], shortcut.btn[0]).getMarkup()
      }]
    }
  }
})

::g_hint_tag.types.sort(function(a, b) {
  if (a.checkOrder != b.checkOrder)
    return a.checkOrder < b.checkOrder ? -1 : 1
  return 0
})

function g_hint_tag::getHintTagType(tagName)
{
  foreach(tagType in types)
    if (tagType.checkTag(tagName))
      return tagType

  return SHORTCUT
}
