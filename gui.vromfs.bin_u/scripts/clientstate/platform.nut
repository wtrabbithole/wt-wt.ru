local getPlayerName = @(name) name
if (::is_platform_xboxone)
  getPlayerName = @(name) ::g_string.cutPrefix(name, "*", name)

local isCrossPlayEnabled = @() (!::is_platform_xboxone || ::loadLocalByAccount("isCrossPlayEnabled", true))

return {
  getPlayerName = getPlayerName
  isCrossPlayEnabled = isCrossPlayEnabled
}

