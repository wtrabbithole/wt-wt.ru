local canBuyNotResearched = @(unit) unit.isVisibleInShop()
  && ::canResearchUnit(unit)
  && unit.isSquadronVehicle()
  && !unit.getOpenCost().isZero()

local function isShipWithoutPurshasedTorpedoes(unit)
{
  if (!unit?.isShip())
    return false

  local torpedoes = null
  if (::isAirHaveSecondaryWeapons(unit))
    torpedoes = ::u.search(unit.weapons, @(weapon) weapon.name == "torpedoes")    //!!! FIX ME: Need determine weapons by weapon mask. WeaponMask now available only for air

  if (!torpedoes)
    return false

  if (::g_weaponry_types.getUpgradeTypeByItem(torpedoes).getAmount(unit, torpedoes) > 0)
    return false

  return true
}

return {
  canBuyNotResearched = canBuyNotResearched
  isShipWithoutPurshasedTorpedoes = isShipWithoutPurshasedTorpedoes
}