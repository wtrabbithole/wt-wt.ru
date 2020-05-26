return {
  INVALID = {
    name = "Invalid"
    armyId = ""
    esUnitType = ::ES_UNIT_TYPE_INVALID
    haveAnyUnitInCountry = @() false
  }

  AIRCRAFT = {
    name = "Aircraft"
    tag = "air"
    armyId = "aviation"
    esUnitType = ::ES_UNIT_TYPE_AIRCRAFT
    fontIcon = ::loc("icon/unittype/aircraft")
    testFlightIcon = "#ui/gameuiskin#slot_testflight.svg"
    testFlightName = "TestFlight"
    hudTypeCode = ::HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_air"
    missionSettingsAvailabilityFlag = "isAirplanesAllowed"
    isUsedInKillStreaks = true
    crewUnitType = ::CUT_AIRCRAFT
    hasAiGunners = true
    isAvailable = @() true
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable())
        return false
      if (!country)
        return true
      local countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return ::has_feature(countryShort + "AircraftsInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
    canShowProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisAircraft")
    canShowVisualEffectInProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisVisualEffect")
  }

  TANK = {
    name = "Tank"
    tag = "tank"
    armyId = "army"
    esUnitType = ::ES_UNIT_TYPE_TANK
    fontIcon = ::loc("icon/unittype/tank")
    testFlightIcon = "#ui/gameuiskin#slot_testdrive.svg"
    testFlightName = "TestDrive"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_tank"
    missionSettingsAvailabilityFlag = "isTanksAllowed"
    crewUnitType = ::CUT_TANK
    isAvailable = function() { return ::has_feature("Tanks") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !::check_tanks_available(true))
        return false
      if (!country)
        return true
      local countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return ::has_feature(countryShort + "TanksInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["mobility", "protection", "firepower"]
    isSkinAutoSelectAvailable = @() ::has_feature("SkinAutoSelect")
    canSpendGold = @() isAvailable() && ::has_feature("SpendGoldForTanks")
    canShowProtectionAnalysis = @() true
    canShowVisualEffectInProtectionAnalysis = @() false
  }

  SHIP = {
    name = "Ship"
    tag = "ship"
    armyId = "fleet"
    esUnitType = ::ES_UNIT_TYPE_SHIP
    fontIcon = ::loc("icon/unittype/ship")
    testFlightIcon = "#ui/gameuiskin#slot_test_out_to_sea.svg"
    testFlightName = "TestSail"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_ship"
    missionSettingsAvailabilityFlag = "isShipsAllowed"
    crewUnitType = ::CUT_SHIP
    hasAiGunners = true
    isAvailable = function() { return ::has_feature("Ships") }
    isVisibleInShop = function() { return isAvailable() && ::has_feature("ShipsVisibleInShop") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !::has_feature("ShipsFirstChoice"))
        return false
      if (!country)
        return true
      local countryShort = ::g_string.toUpper(::g_string.cutPrefix(country, "country_") ?? "", 1)
      return ::has_feature(countryShort + "ShipsInFirstCountryChoice")
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["seakeeping", "unsinkability", "firepower"]
    canSpendGold = @() isAvailable() && ::has_feature("SpendGoldForShips")
    canShowProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisShip")
    canShowVisualEffectInProtectionAnalysis = @() false
    bulletSetsQuantity = ::BULLETS_SETS_QUANTITY
  }

  HELICOPTER = {
    name = "Helicopter"
    tag = "helicopter"
    armyId = "helicopters"
    esUnitType = ::ES_UNIT_TYPE_HELICOPTER
    fontIcon = ::loc("icon/unittype/helicopter")
    testFlightIcon = "#ui/gameuiskin#slot_heli_testflight.svg"
    testFlightName = "TestFlight"
    hudTypeCode = ::HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_helicopter"
    missionSettingsAvailabilityFlag = "isHelicoptersAllowed"
    isUsedInKillStreaks = true
    crewUnitType = ::CUT_AIRCRAFT
    isAvailable = @() true
    isVisibleInShop = function() { return isAvailable() }
    isAvailableForFirstChoice = @(country = null) false
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
    canShowProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisAircraft")
    canShowVisualEffectInProtectionAnalysis = @() ::has_feature("DmViewerProtectionAnalysisVisualEffect")
  }
}