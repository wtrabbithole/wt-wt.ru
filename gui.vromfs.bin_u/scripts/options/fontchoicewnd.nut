local FONT_CHOICE_SAVE_ID = "tutor/fontChange"

local wasOpened = false

class ::gui_handlers.FontChoiceWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/options/fontChoiceWnd"

  option = null

  static function openIfRequired()
  {
    if (!::gui_handlers.FontChoiceWnd.isSeen() && ::g_font.getAvailableFonts().len() > 1)
      ::handlersManager.loadHandler(::gui_handlers.FontChoiceWnd)
  }

  static function isSeen()
  {
    return ::load_local_account_settings(FONT_CHOICE_SAVE_ID, false)
  }

  static function markSeen(isSeen = true)
  {
    return ::save_local_account_settings(FONT_CHOICE_SAVE_ID, isSeen)
  }

  function getSceneTplView()
  {
    option = ::get_option(::USEROPT_FONTS_CSS)
    return {
      options = ::create_option_combobox(option.id, option.items, option.value, null, false)
    }
  }

  function initScreen()
  {
    if (!wasOpened)
    {
      ::statsd_counter("temp_test.fontChoice.open")
      wasOpened = true
    }
  }

  function onFontsChange(obj)
  {
    local newValue = obj.getValue()
    if (newValue == option.value)
      return

    ::set_option(::USEROPT_FONTS_CSS, newValue, option)
    guiScene.performDelayed(this, @() ::handlersManager.getActiveBaseHandler().fullReloadScene())
  }

  function goBack()
  {
    markSeen(true)
    ::statsd_counter("temp_test.fontChoice.close")
    base.goBack()
  }
}