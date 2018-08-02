local enums = ::require("sqStdlibs/helpers/enums.nut")

local results = {
  types = []
}

results.template <- {
  id = "" //used from type name
  checkOrder = -1
  checkParams = @(params) false
}

local checkOrder = 0
enums.addTypes(results, {
  RICOCHETED = {
    checkOrder = checkOrder++
    checkParams = @(params) params?.lower?.ricochet == ::CHECK_PROT_RICOCHET_GUARANTEED
    color = "minorTextColor"
    loc = "hitcamera/result/ricochet"
    infoSrc = [ "lower", "upper" ]
    params = [ "ricochetProb" ]
  }
  POSSIBLEEFFECTIVE = {
    checkOrder = checkOrder++
    checkParams = @(params) params?.lower?.effectiveHit &&
      params?.lower?.ricochet == ::CHECK_PROT_RICOCHET_POSSIBLE ||
      params?.upper?.effectiveHit
    color = "cardProgressTextBonusColor"
    loc = "protection_analysis/result/possible_effective"
    infoSrc = [ "lower", "upper" ]
    params = [ "penetratedArmor", "parts" ]
  }
  EFFECTIVE = {
    checkOrder = checkOrder++
    checkParams = @(params) params?.lower?.effectiveHit &&
      params?.lower?.ricochet != ::CHECK_PROT_RICOCHET_POSSIBLE
    color = "goodTextColor"
    loc = "protection_analysis/result/effective"
    infoSrc = [ "lower", "upper" ]
    params = [ "penetratedArmor", "parts" ]
  }
  NOTPENETRATED = {
    checkOrder = checkOrder++
    checkParams = @(params) params?.max?.effectiveHit &&
      (params?.max?.penetratedArmor?.generic || params?.max?.penetratedArmor?.cumulative)
    color = "badTextColor"
    loc = "protection_analysis/result/not_penetrated"
    infoSrc = [ "max" ]
    params = [ "penetratedArmor", "ricochetProb" ]
  }
  INEFFECTIVE = {
    checkOrder = checkOrder++
    checkParams = @(params) true
    color = "minorTextColor"
    loc = "protection_analysis/result/ineffective"
    infoSrc = [ "max" ]
    params = [ "ricochetProb" ]
  }
}, null, "id")
results.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

results.getResultTypeByParams <- function(params)
{
  foreach (t in types)
    if (t.checkParams(params))
      return t
  return INEFFECTIVE
}

return results
