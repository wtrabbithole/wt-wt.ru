//---- Casualties helper BEGIN ----

function getInitialUnitsCount(unitname)
{
  if (wwSharedPoolInitialArmiesBlk == null)
    return -1

  local totalCount = 0

  foreach (armyname, army in wwSharedPoolInitialArmiesBlk)
    if (army.units != null && army.units[unitname] > 0)
    {
      totalCount += army.units[unitname]
      if (army.unitsParamsList != null && army.unitsParamsList[unitname] != null &&
          army.unitsParamsList[unitname].inactive > 0)
        totalCount -= army.unitsParamsList[unitname].inactive
    }

  return totalCount
}

function casualtiesHelper_onUnitKilled(teamName, unit, quantity=1.0)
{
  local misblk = ::get_mission_custom_state(true)
  local mul = (misblk.casualtiesMultiplier || 1.0).tofloat()
  local total = mul * quantity

  dagor.debug("casualtiesHelper_onUnitKilled " + teamName + " " + unit +
              " mul=" + mul + " quantity=" + quantity + " total=" + total)

  local teamblk = misblk.addBlock("casualties").addBlock(teamName)
  local newCasualties = teamblk.getReal(unit, 0.0) + total
  local initialUnitCount = getInitialUnitsCount(unit)
  if (initialUnitCount > -1 && newCasualties > initialUnitCount)
  {
    dagor.debug("casualtiesHelper_onUnitKilled initialUnitCount " + initialUnitCount + " < newCasualties " +
                newCasualties + ". fixing at " + initialUnitCount)
    newCasualties = initialUnitCount
  }
  
  teamblk.setReal(unit, newCasualties)
}


function casualtiesHelper_onAIUnitKilled(teamName, unit)
{
  local misinfo = get_current_mission_info_cached()
  local quantity = 1.0

  dagor.debug("casualtiesHelper_onAIUnitKilled " + teamName + " " + unit)

  local mapblk = misinfo.getBlockByName("aiCasualtiesMapping")
  if (mapblk)
  {
    local teamMapBlk = mapblk.getBlockByName(teamName)
    if (teamMapBlk)
    {
      local unitMapBlk = teamMapBlk.getBlockByName(unit)
      if (unitMapBlk)
      {
        local mappedUnit = unitMapBlk.getStr("mapToUnit", unit)
        local mappedQuantity = unitMapBlk.quantity
        if (mappedQuantity != null)
          quantity = mappedQuantity.tofloat()
        dagor.debug("casualtiesHelper_onAIUnitKilled found mapping for unit " + unit +
                    " (team " + teamName + "), mapped unit is " + mappedUnit +
                    ", quantity " + quantity)
        unit = mappedUnit
      }
    }
  }

  casualtiesHelper_onUnitKilled(teamName, unit, quantity)
}
//---- Casualties helper END ----
dagor.debug("casualtiesHelper loaded")
