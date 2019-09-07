local canBuyNotResearched = @(unit) unit.isVisibleInShop()
  && ::canResearchUnit(unit)
  && unit.isSquadronVehicle()
  && !unit.getOpenCost().isZero()

return {
  canBuyNotResearched = canBuyNotResearched
}