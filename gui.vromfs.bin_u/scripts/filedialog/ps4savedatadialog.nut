local time = require("scripts/time.nut")
local stdpath = require("std/path.nut")
local progressMsg = ::require("sqDagui/framework/progressMsg.nut")
const SAVEDATA_PROGRESS_MSG_ID = "SAVEDATA_IO_OPERATION"


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

  function isEntrySelected()
  {
    return selectedEntry.path != "" && selectedEntry.comment != ""
  }

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
  }

  function showWaitAnimation(show)
  {
    if (show)
      progressMsg.create(SAVEDATA_PROGRESS_MSG_ID, null)
    else
      progressMsg.destroy(SAVEDATA_PROGRESS_MSG_ID)
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
    entries.sort(@(a,b) -(a.mtime <=> b.mtime))

    renderSaveDataContents(entries)
    showWaitAnimation(false)
    updateSelectionAfterDataLoaded()
  }

  function requestEntries()
  {
    showWaitAnimation(true)
    local cb = ::Callback(onReceivedSaveDataListing, this)
    getSaveDataContents(@(blk) cb(blk))
  }

  function updateButtons()
  {
    local inFileTable = getObj("file_table").isFocused()
    showSceneBtn("btn_delete", doDelete && inFileTable && isEntrySelected())
    showSceneBtn("btn_load", doLoad && inFileTable && isEntrySelected())
    showSceneBtn("btn_save", doSave)
  }


  function renderSaveDataContents(entries)
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

    tableEntries.clear()

    local isEven = false
    foreach (idx, e in entries)
    {
      local timeView = ::get_time_from_t(e.mtime)
      timeView.sec = -1

      local rowView = {
        row_id = "file_row_"+idx
        even = isEven
        cells = [{text=e.comment, width="fw"},
                 {text=time.buildIso8601DateTimeStr(timeView, " "), width="0.18@sf"}]
      }
      view.rows.append(rowView)
      tableEntries[rowView.row_id] <- e
      isEven = !isEven
    }

    local data = ::handyman.renderCached("gui/fileDialog/fileTable", view)
    guiScene.replaceContentFromText(fileTableObj, data, data.len(), this)
  }

  function updateSelectionAfterDataLoaded()
  {
    local fileTableObj = getObj("file_table")
    if (!fileTableObj)
      return

    fileTableObj.select()
    if (tableEntries.len() > 0)
      fileTableObj.setValue(1)
    updateSelectedEntry(false)
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
      local entry = selectedEntry
      selectedEntry = createEntry()
      doDelete(entry)
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
    if (selectedEntry.comment == "")
    {
      ::showInfoMsgBox(::loc("save/saveNameMissing"))
      return
    }

    local onConfirmedSave = function()
    {
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

    local onConfirmedLoad = function()
    {
      doLoad(selectedEntry)
    }

    ::scene_msg_box("savedata_confirm_load_msg_box",
                    null,
                    ::loc("save/confirmLoad", {name=selectedEntry.comment}),
                    [["yes", ::Callback(onConfirmedLoad, this)], ["no", function(){}]],
                    "no",
                    {})
  }


  function onCancel()
  {
    if (doCancel)
      doCancel()
    goBack()
  }
}
