function update_unit_skins_list(unitName)
{
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return

  unit.skins.clear()
  unit.skins = ::get_skins_for_unit(unitName)
}
