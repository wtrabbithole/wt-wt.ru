function gui_start_eula(eulaType)
{
  ::gui_start_modal_wnd(::gui_handlers.EulaWndHandler, { eulaType = eulaType })
}

class ::gui_handlers.EulaWndHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/eulaFrame.blk"
  shouldBlurSceneBg = false

  eulaType = ::TEXT_EULA

  function initScreen()
  {
    local textObj = scene.findObject("eulaText")
    textObj["punctuation-exception"] = "-.,'\"():/\\@"
    local isEULA = eulaType == ::TEXT_EULA
    ::load_text_content_to_gui_object(textObj, isEULA ? ::loc("eula_filename") : ::loc("nda_filename"))
    if (isEULA && ::is_platform_ps4)
    {
      local regionTextRootMainPart = "scee"
      if (::ps4_get_region() == ::SCE_REGION_SCEA)
        regionTextRootMainPart = "scea"

      local eulaText = textObj.getValue()
      local locId = "sony/" + regionTextRootMainPart
      local legalLocText = ::loc(locId, "")
      if (legalLocText == "")
      {
        ::dagor.debug("Cannot find '" + locId + "' text for " + ::get_current_language() + " language.")
        eulaText += ::dagor.getLocTextForLang(locId, "English")
      }
      else
        eulaText += legalLocText

      textObj.setValue(eulaText)
    }
  }

  function onAcceptEula()
  {
    set_agreed_eula_version(eulaType == ::TEXT_NDA ? ::nda_version : ::eula_version, eulaType)
    goBack()
  }

  function afterModalDestroy()
  {
    if (eulaType == ::TEXT_NDA)
      if (should_agree_eula(::eula_version, ::TEXT_EULA))
        ::gui_start_eula(::TEXT_EULA)
  }

  function onExit()
  {
    ::exit_game()
  }
}
