class ::gui_handlers.Ps4ControlsBackupManager extends ::gui_handlers.Ps4SaveDataDialog
{
  function initScreen()
  {
    if (!isAvailable())
      return

    getSaveDataContents = ::ps4_list_controls_backup
    base.initScreen()
  }

  function doSave(descr)
  {
    local blk = ::DataBlock()
    blk.comment = descr.comment
    blk.path = descr.path

    if (!::ps4_save_controls_backup(blk))
      ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
  }

  function doLoad(descr)
  {
    local blk = ::DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    if (::ps4_load_controls_backup(blk))
      ::preset_changed = true
    else
      ::showInfoMsgBox(::loc("msgbox/errorLoadingPreset"))
  }

  function doDelete(descr)
  {
    local blk = ::DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment
    if (!::ps4_delete_controls_backup(blk))
      ::showInfoMsgBox(::loc("save/deleteFailed"))
  }


  static function isAvailable()
  {
    return ::is_platform_ps4 && "ps4_list_controls_backup" in ::getroottable()
  }


  static function open()
  {
    ::handlersManager.loadHandler(::gui_handlers.Ps4ControlsBackupManager)
  }
}
