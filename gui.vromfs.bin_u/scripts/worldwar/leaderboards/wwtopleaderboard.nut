local wwLeaderboardData = require("scripts/worldWar/operations/model/wwLeaderboardData.nut")


local function initTop(handler, obj, appId, mode, type, amount = 3, field = "rating")
{
  wwLeaderboardData.requestWwLeaderboardData(appId, mode, type, 0, amount, field,
    function(lbData) {
      displayTop(handler, obj, lbData, { mode = mode, type = type })
    }.bindenv(this))
}

local function generateTableRow(row, rowIdx, lbCategory)
{
  local rowName = "row_" + rowIdx
  local rowData = [
    {
      text = (row.pos + 1).tostring()
      width = "0.01@sf"
      cellType = "top_numeration"
    },
    {
      id = "name"
      width = "0.5pw"
      tdAlign = "left"
      text = row.name
      active = false
    }
  ]

  if (lbCategory)
  {
    local td = lbCategory.getItemCell(::getTblValue(lbCategory.field, row, -1))
    td.tdAlign <- "right"
    rowData.append(td)
  }

  return ::buildTableRow(rowName, rowData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
}

local function displayTop(handler, obj, lbData, lbInfo)
{
  if (!handler.isValid() || !::check_obj(obj))
    return

  if (lbData?.error)
    return

  local lbRows = ::u.filter(wwLeaderboardData.convertWwLeaderboardData(lbData).rows,
    @(lb) lb.pos >= 0)
  local hasLbRows = lbRows.len() > 0
  obj.show(hasLbRows)

  if (!hasLbRows)
    return

  local lbCategory = ::events.getLbCategoryByField("rating")
  local rowIdx = 0
  local topView = {
    titleText = ::loc("worldwar/top/" + lbInfo.mode + "/" + lbInfo.type)
    lbMode = lbInfo.mode
    lbType = lbInfo.type
    rows = ::u.map(lbRows, @(row) { row = generateTableRow(row, rowIdx++, lbCategory) })
  }
  local topBlk = ::handyman.renderCached("gui/worldWar/wwTopLeaderboard", topView)
  ::get_cur_gui_scene().replaceContentFromText(obj, topBlk, topBlk.len(), handler)

  handler.showTopListBlock(true)
}

return {
  initTop = initTop
  displayTop = displayTop
}
