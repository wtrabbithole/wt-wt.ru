::g_hud_hint_types <- {
  types = []
}

::g_hud_hint_types.template <- {
  nestId = ""
  hintStyle = ""

  isReplaceable = function (newHint, newEventData, oldHint, oldEventData) { return false }
  isSameReplaceGroup = function (hint1, hint2) { return hint1 == hint2 }
}

::g_enum_utils.addTypesByGlobalName("g_hud_hint_types", {
  COMMON = {
    nestId = "common_priority_hints"
    hintStyle = "hudHintCommon"
  }

  MISSION = {
    nestId = "mission_hints"
    hintStyle = "hudHintCommon"

    isReplaceable = function (newHint, newEventData, oldHint, oldEventData)
    {
      return newHint.getPriority(newEventData) >= oldHint.getPriority(oldEventData)
    }
    isSameReplaceGroup = function (hint1, hint2)
    {
      return hint1.hintType == hint2.hintType
    }
  }

  REPAIR = {
    nestId = "mission_hints"
    hintStyle = "hudHintCommon"
  }

  MINOR = {
    nestId = "minor_priority_hints"
    hintStyle = "hudMinor"
  }
})
