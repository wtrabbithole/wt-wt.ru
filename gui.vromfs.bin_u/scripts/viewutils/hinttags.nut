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
  makeTag = function(param) { return typeName }
}

::g_enum_utils.addTypesByGlobalName("g_hint_tag", {
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
      local slice = {}
      local shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(tagName)
      slice.shortcut <- (@(shortcutType, tagName) function () {
        local input = shortcutType.getFirstInput(tagName)
        return input.getMarkup()
      })(shortcutType, tagName)
      return [slice]
    }
  }

  IMAGE = {
    typeName = "img="
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return ::g_string.startsWith(tagName, typeName) }
    getViewSlices = function(tagName, params)
    {
      return [{ image = ::cut_prefix(tagName, typeName, "") }]
    }
    makeTag = function(image) { return typeName + image }
  }

  MISSION_ATTEMPTS_LEFT = {
    typeName = "attempts_left" //{{attempts_left}} or {{attempts_left=locId}}
    checkOrder = hintTagCheckOrder.REGULAR
    checkTag = function(tagName) { return ::g_string.startsWith(tagName, typeName) }
    getViewSlices = function(tagName, params)
    {
      local attempts = ::get_num_attempts_left()
      local attemptsText = attempts < 0 ? ::loc("options/attemptsUnlimited") : attempts
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
