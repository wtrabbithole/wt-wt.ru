local u = ::require("std/u.nut")
local enums = ::require("sqStdlibs/helpers/enums.nut")
local elemModelType = ::require("sqDagui/elemUpdater/elemModelType.nut")

local viewType = {
  types = []
}

viewType.template <- {
  id = "" //filled automatically by typeName. so unique
  model = elemModelType.EMPTY

  bhvParamsToString = function(params)
  {
    params.viewId <- id
    return ::save_to_json(params)
  }

  createMarkup = @(params) ""
  updateView = @(obj, bhvConfig) null
}

viewType.addTypes <- function(typesTable)
{
  enums.addTypes(this, typesTable, null, "id")
}

viewType.addTypes({
  EMPTY = {}
})

//save get type by id. return EMPTY if not found
viewType.get <- @(typeId) this?[typeId] ?? EMPTY

viewType.buildBhvConfig <- function(params) {
  local tbl = u.isTable(params) ? params : null
  local viewType = get(tbl?.viewId ?? params)
  if (u.isString(params))
    tbl = viewType == EMPTY ? ::parse_json(params) : { viewId = params }

  if (!tbl?.viewId)
    return null

  viewType = get(tbl.viewId)
  local res = tbl
  res.viewType <- viewType
  if (!res?.subscriptions)
    res.subscriptions <- []
  return res
}

return viewType