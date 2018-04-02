local time = require("scripts/time.nut")
local stdpath = require("std/path.nut")


class ::gui_handlers.Ps4SaveDataDialog extends ::gui_handlers.BaseGuiHandlerWT
{
  static wndType = handlerType.MODAL
  static sceneBlkName = "gui/fileDialog/ps4SaveDataDialog.blk"

  getSaveDataContents = null

  doLoad = null
  doSave = null
  doDelete = null
  doCancel = null

  tableEntries = {}
  createEntry = @(comment="", path="", mtime=0) {comment = comment, path = path, mtime = mtime}
  selectedEntry = null

  function initScreen()
  {
    if (!scene)
      goBack()

    if (!getSaveDataContents)
    {
      ::script_net_assert_once("PS4 SaveDataDialog: no listing function",
                               "PS4 SaveDataDialog: no mandatory listing function")
      goBack()
      return
    }

    requestEntries()
    selectedEntry = createEntry()
    loadSaveDataContents()
  }

  function showWaitAnimation(show)
  {
    local waitSpinner = scene.findObject("saveDataDialogWaitAnimation");

    if (::checkObj(waitSpinner))
      waitSpinner.show(show);
  }

  function onReceivedSaveDataListing(blk)
  {
    if (!isValid())
      return

    local entries = []
    foreach (id, meta in blk)
    {
      if (::u.isDataBlock(meta))
        entries.append({path=meta.path, comment=meta.comment, mtime=meta.mtime})
    }

    tableEntries.clear()

    foreach (idx, e in entries)
    {
      tableEntries["file_row_" + idx] <- e
    }

    loadSaveDataContents()

    showWaitAnimation(false)
  }

  function requestEntries()
  {
    local cb = ::Callback(onReceivedSaveDataListing, this)
    getSaveDataContents(@(blk) cb(blk))
    showWaitAnimation(true)
  }

  function updateButtons()
  {
    local inFileTable = getObj("file_table").isFocused()
    showSceneBtn("btn_delete", doDelete && tableEntries.len() && inFileTable)
    showSceneBtn("btn_load", doLoad && tableEntries.len() && inFileTable)
    showSceneBtn("btn_save", doSave)
  }


  function loadSaveDataContents()
  {
    local fileTableObj = getObj("file_table")
    if (!fileTableObj)
      return

    local view = {rows = [{
      row_id = "file_header_row"
      isHeaderRow = true
      cells = [{id="file_col_name", text="#save/fileName", width="fw"},
               {id="file_col_mtime", text="#filesystem/fileMTime", width="0.18@sf"}]
    }]}

    local isEven = false
    foreach (rowId, e in tableEntries)
    {
      local timeView = ::get_time_from_t(e.mtime)
      timeView.sec = -1

      local rowView = {
        row_id = rowId
        even = isEven
        cells = [{text=e.comment, width="fw"},
                 {text=time.buildIso8601DateTimeStr(timeView, " "), width="0.18@sf"}]
      }
      view.rows.append(rowView)
      isEven = !isEven
    }

    local data = ::handyman.renderCached("gui/fileDialog/fileTable", view)
    guiScene.replaceContentFromText(fileTableObj, data, data.len(), this)

    fileTableObj.select()
    if (tableEntries.len() > 0)
      fileTableObj.setValue(1)
    updateButtons()
  }


  function updateSelectedEntry(is_manually_entered)
  {
    if (is_manually_entered)
    {
      local inputObj = getObj("file_name")
      selectedEntry = createEntry(inputObj.getValue())
      return
    }

    if (tableEntries.len())
    {
      local tableObj = getObj("file_table")
      local selectedRowIdx = tableObj.getValue()
      if (selectedRowIdx >= 0 && selectedRowIdx < tableObj.childrenCount())
      {
        local e = tableObj.getChild(selectedRowIdx)
        if (e.id in tableEntries)
        {
          selectedEntry = tableEntries[e.id]
          return
        }
      }
    }

    selectedEntry = createEntry()
  }


  function selectFileTable()
  {
    local fileTableObj = getObj("file_table")
    fileTableObj.select()
  }


  function onFileTableSelect()
  {
    updateSelectedEntry(false)
    updateButtons()
  }


  function onFileNameEditBoxChangeValue()
  {
    updateSelectedEntry(true)
    updateButtons()
  }


  function onFileNameEditBoxActivate()
  {
    onToggleFocusFileName()
  }


  function onFileNameEditBoxCancelEdit()
  {
    selectedEntry = createEntry()
  }


  function onToggleFocusFileName()
  {
    local fileTableObj = getObj("file_table")
    local fileNameObj = getObj("file_name")
    if (fileNameObj.isFocused())
      fileTableObj.select()
    else
      fileNameObj.select()

    updateSelectedEntry(fileNameObj.isFocused())
    updateButtons()
  }


  function onBtnDelete()
  {
    dagor.debug("PS4 SAVE Dialog: onBtnDelete for " + selectedEntry.path)
    local onConfirm = function() {
      showWaitAnimation(true)
      doDelete(selectedEntry)
    }

    ::scene_msg_box("savedata_delete_msg_box",
                    null,
                    ::loc("save/confirmDelete", {name=selectedEntry.comment}),
                    [["yes", ::Callback(onConfirm, this)], ["no", function(){}]],
                    "no",
                    {})
  }


  function onBtnSave()
  {
    dagor.debug("PS4 SAVE Dialog: onBtnSave for entry:")
    debugTableData(selectedEntry)
    if (selectedEntry.path == "" && selectedEntry.comment == "")
    {
      ::showInfoMsgBox(::loc("save/saveNameMissing"))
      return
    }

    local onConfirmedSave = function()
    {
      showWaitAnimation(true)
      doSave(selectedEntry)
    }

    if (selectedEntry.path == "")
      onConfirmedSave()
    else
    {
      ::scene_msg_box("savedata_overwrite_msg_box",
                      null,
                      ::loc("save/confirmOverwrite", {name=selectedEntry.comment}),
                      [["yes", ::Callback(onConfirmedSave, this)], ["no", function(){}]],
                      "no",
                      {})
    }
  }


  function onBtnLoad()
  {
    dagor.debug("PS4 SAVE Dialog: onBtnLoad for entry:")
    debugTableData(selectedEntry)
    showWaitAnimation(true)
    doLoad(selectedEntry)
  }


  function onCancel()
  {
    if (doCancel)
      doCancel()
    goBack()
  }
}
