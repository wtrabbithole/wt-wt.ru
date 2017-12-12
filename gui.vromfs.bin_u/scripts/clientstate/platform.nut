local getPlayerName = @(name) name
if (::is_platform_xboxone)
  getPlayerName = @(name) ::g_string.cutPrefix(name, "*", name)

return {
  getPlayerName = getPlayerName
}