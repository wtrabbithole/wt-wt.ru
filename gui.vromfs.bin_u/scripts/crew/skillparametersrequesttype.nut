local enums = ::require("std/enums.nut")
::g_skill_parameters_request_type <- {
  types = []
}

function g_skill_parameters_request_type::_getParameters(crewId)
{
  local cacheUid = getCachePrefix() + "Current"
  local res = ::g_crew_short_cache.getData(crewId, cacheUid)
  if (res)
    return res

  local values = getValues()
  res = ::calc_crew_parameters(crewId, values)
  ::g_crew_short_cache.setData(crewId, cacheUid, res)
  return res
}

function g_skill_parameters_request_type::_getValues()
{
  return {}
}

function g_skill_parameters_request_type::_getSelectedParameters(crewId)
{
  local cacheUid = getCachePrefix() + "Selected"
  local res = ::g_crew_short_cache.getData(crewId, cacheUid)
  if (res)
    return res

  local values = getValues()
  // Filling values request object with selected values if not set already.
  foreach (memberData in ::crew_skills)
  {
    local valueMemberName = memberData.id
    if (!(valueMemberName in values))
        values[valueMemberName] <- {}
    foreach (skillData in memberData.items)
    {
      local valueSkillName = skillData.name
      if (valueSkillName in values[valueMemberName])
        continue

      if ("newValue" in skillData)
        values[valueMemberName][valueSkillName] <- skillData.newValue
    }
  }
  res = ::calc_crew_parameters(crewId, values)
  ::g_crew_short_cache.setData(crewId, cacheUid, res)
  return res
}

function g_skill_parameters_request_type::_getCachePrefix()
{
  return "skillParamRqst" + typeName
}

::g_skill_parameters_request_type.template <- {
  getParameters = ::g_skill_parameters_request_type._getParameters
  getValues = ::g_skill_parameters_request_type._getValues
  getSelectedParameters = ::g_skill_parameters_request_type._getSelectedParameters

  getCachePrefix = ::g_skill_parameters_request_type._getCachePrefix
}

enums.addTypesByGlobalName("g_skill_parameters_request_type", {

  CURRENT_VALUES = {}

  BASE_VALUES = {
    getValues = function ()
    {
      local skillsBlk = ::get_skills_blk()
      local calcBlk = skillsBlk.crew_skills_calc
      if (calcBlk == null)
        return {}

      local values = {}
      foreach (valueMemberName, memberBlk in calcBlk)
      {
        values[valueMemberName] <- {}
        foreach (valueSkillName, skillBlk in memberBlk)
        {
          // Gunner's count is maxed-out as a base value.
          // Everything else is zero'ed.
          local value = 0
          if (valueMemberName == "gunner" && valueSkillName == "members")
            value = ::g_crew_skills.getMaxSkillValue("gunner", "members")
          values[valueMemberName][valueSkillName] <- value
        }
      }
      values.specialization <- ::g_crew_spec_type.BASIC.code
      return values
    }
  }

  CURRENT_VALUES_NO_SPEC_AND_LEADERSHIP = {
    getValues = function ()
    {
      return {
        specialization = ::g_crew_spec_type.BASIC.code

        gunner = {
          // This skill is same as leadership
          // but related to aircraft unit type.
          members = ::g_crew_skills.getMaxSkillValue("gunner", "members")
        }

        commander = {
          // This skill affects only tank unit type.
          leadership = 0
        }
      }
    }
  }

  CURRENT_VALUES_NO_LEADERSHIP = {
    getValues = function ()
    {
      return {
        // This skill is same as leadership
        // but related to aircraft unit type.
        gunner = {
          members = ::g_crew_skills.getMaxSkillValue("gunner", "members")
        }

        // This skill affects only tank unit type.
        commander = { leadership = 0 }
      }
    }
  }

  MAX_VALUES = {
    getValues = function ()
    {
      local skillsBlk = ::get_skills_blk()
      local calcBlk = skillsBlk.crew_skills_calc
      if (calcBlk == null)
        return {}

      local values = {}
      foreach (valueMemberName, memberBlk in calcBlk)
      {
        values[valueMemberName] <- {}
        foreach (valueSkillName, skillBlk in memberBlk)
        {
          local value = ::g_crew_skills.getMaxSkillValue(valueMemberName, valueSkillName)
          values[valueMemberName][valueSkillName] <- value
        }
      }
      local maxSpecType = ::g_crew_spec_type.types.top().code
      values.specialization <- maxSpecType
      return values
    }
  }
}, null, "typeName")
