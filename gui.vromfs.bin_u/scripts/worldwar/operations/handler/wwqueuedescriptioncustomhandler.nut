class ::gui_handlers.WwQueueDescriptionCustomHandler extends ::gui_handlers.WwMapDescription
{
  function mapCountriesToView(countries, amountByCountry, joinedCountries)
  {
    return {
      countries = ::u.map(countries,
                    (@(amountByCountry, joinedCountries) function (countryName) {
                      return {
                        countryName = countryName
                        countryIcon = ::get_country_icon(countryName)
                        amount      = ::getTblValue(countryName, amountByCountry, "").tostring()
                        isJoined    = ::isInArray(countryName, joinedCountries)
                      }
                    })(amountByCountry, joinedCountries)
                  )
    }
  }

  function updateCountriesList()
  {
    local obj = scene.findObject("div_before_text")
    if (!::checkObj(obj))
      return

    local cuntriesByTeams = descItem.getCountriesByTeams()
    local amountByCountry = descItem.getArmyGroupsAmountByCountries()
    local joinedCountries = descItem.getMyClanCountries()

    local view = {
      side1 = mapCountriesToView(::getTblValue(::SIDE_1, cuntriesByTeams, {}), amountByCountry, joinedCountries)
      side2 = mapCountriesToView(::getTblValue(::SIDE_2, cuntriesByTeams, {}), amountByCountry, joinedCountries)
      vsText = ::loc("country/VS") + "\n "
    }
    local data = ::handyman.renderCached("gui/worldWar/wwOperationCountriesInfo", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }
}
