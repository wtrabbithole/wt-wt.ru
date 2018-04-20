class ::gui_handlers.Ps4ControlsBackupManager extends ::gui_handlers.Ps4SaveDataDialog
{
  function initScreen()
  {
    if (!isAvailable())
      return

    getSaveDataContents = ::ps4_request_list_controls_backup
    base.initScreen()
  }


  function doSave(descr)
  {
    local blk = ::DataBlock()
    blk.comment = descr.comment
    blk.path = descr.path

    local cb = ::Callback(onBackupSaved, this)
    ::ps4_request_save_controls_backup(@(result) cb(result), blk)
  }


  function onBackupSaved(params)
  {
    showWaitAnimation(false)
    if (!params.success)
      ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
    goBack()
  }


  function doLoad(descr)
  {
    local blk = ::DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    local cb = ::Callback(onBackupLoaded, this)
    ::ps4_request_load_controls_backup(@(result) cb(result), blk)
  }


  function onBackupLoaded(params)
  {
    showWaitAnimation(false)
    if (params.success)
      ::preset_changed = true
    else
      ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
    goBack()
  }


  function doDelete(descr)
  {
    local blk = ::DataBlock()
    blk.path = descr.path
    blk.comment = descr.comment

    local cb = ::Callback(onBackupDeleted, this)
    ::ps4_request_delete_controls_backup(@(result) cb(result), blk)
  }


  function onBackupDeleted(params)
  {
    showWaitAnimation(false)
    requestEntries()
  }


  static function isAvailable()
  {
    return ::is_platform_ps4 && "ps4_request_list_controls_backup" in ::getroottable()
  }


  static function open()
  {
    ::handlersManager.loadHandler(::gui_handlers.Ps4ControlsBackupManager)
  }
}
