local u = ::require("sqStdLibs/common/u.nut")

local WwGlobalBattle = class extends ::WwBattle
{
  operationId = -1
  sidesByCountry = null

  function updateParams(blk, params)
  {
    sidesByCountry = {}

    local teamsBlk = blk.getBlockByName("teams")
    if (!teamsBlk)
      return

    local countries = params?.countries
    for (local i = 0; i < teamsBlk.blockCount(); i++)
    {
      local teamBlk = teamsBlk.getBlock(i)
      local teamSide = teamBlk.side
      local teamCountry = countries?[teamSide]
      if (teamSide && teamCountry)
        sidesByCountry[teamCountry] <- ::ww_side_name_to_val(teamSide)
    }
  }

  function isStillInOperation()
  {
    return true
  }

  function hasSideCountry(country)
  {
    return sidesByCountry?[country]
  }

  function setOperationId(operId)
  {
    operationId = operId
  }

  function getSectorName()
  {
    return ""
  }

  function getSideByCountry(country)
  {
    return sidesByCountry?[country] ?? ::SIDE_NONE
  }
}

u.registerClass("WwGlobalBattle", WwGlobalBattle, @(b1, b2) b1.id == b2.id)

return WwGlobalBattle
