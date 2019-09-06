return [
//-------------------------------------------------------
  {
    id = "ID_COMMON_BASIC_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TACTICAL_MAP"
    checkGroup = ctrlGroups.COMMON
  }
  {
    id = "ID_MPSTATSCREEN"
    checkGroup = ctrlGroups.COMMON
  }
  {
    id = "ID_BAILOUT"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_SHOW_HERO_MODULES"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_LOCK_TARGET"
    checkGroup = ctrlGroups.COMMON
  }
  {
    id = "ID_PREV_TARGET"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_NEXT_TARGET"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  // Use last chat mode, but can not be renamed to "ID_TOGGLE_CHAT" for compatibility reasons
  {
    id = "ID_TOGGLE_CHAT_TEAM"
    checkGroup = ctrlGroups.COMMON
    checkAssign = ::is_platform_pc
  }
  // Use CO_ALL chat mode, but can not be renamed to "ID_TOGGLE_CHAT_ALL" for compatibility reasons
  {
    id = "ID_TOGGLE_CHAT"
    checkGroup = ctrlGroups.COMMON
    checkAssign = ::is_platform_pc
  }
  {
    id = "ID_TOGGLE_CHAT_PARTY"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CHAT_SQUAD"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CHAT_MODE"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_PTT"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    condition = @() ::gchat_is_voice_enabled()
    showFunc = ::g_chat.canUseVoice
  }
]