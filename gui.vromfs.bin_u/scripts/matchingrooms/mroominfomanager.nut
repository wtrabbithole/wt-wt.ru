::g_mroom_info <- {
  infoByRoomId = {}
}

function g_mroom_info::get(roomId)
{
  clearOutdated()
  local info = ::getTblValue(roomId, infoByRoomId)
  if (info)
    return info

  info = ::MRoomInfo(roomId)
  infoByRoomId[roomId] <- info
  return info
}

function g_mroom_info::clearOutdated()
{
  foreach(roomId, info in infoByRoomId)
    if (!info.isValid())
      delete infoByRoomId[roomId]
}