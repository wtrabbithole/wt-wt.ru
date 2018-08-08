local u = require("std/u.nut")

/**
 * Contains all utility functions related to creation
 * of and managing in-game type enumerations.
 */

local assertOnce = function(uniqId, errorText) { throw(errorText) }

local function getPropValue(propName, typeObject)
{
  local value = typeObject?[propName]

  // Calling 'value()' instead of 'typeObject[propName]()'
  // caused function to be called in a wrong environment.
  return u.isFunction(value) ? typeObject[propName]() : value
}

//caseSensitive work only with string propValues
local function getCachedType(propName, propValue, cacheTable, enumTable, defaultVal, caseSensitive = true)
{
  if (!caseSensitive)
  {
    if (u.isString(propValue))
      propValue = propValue.tolower()
    else
    {
      assertOnce("bad propValue type",
        "enums: Bad value type for getCachedType with no caseSensitive:\n" +
        "propName = " + propName + ", propValue = " + propValue + ", propValueType = " + (typeof propValue))
      return defaultVal
    }
  }

  local val = cacheTable?[propValue]
  if (val != null)
    return val
  if (cacheTable.len())
    return defaultVal

  if (!("types" in enumTable))
  {
    assertOnce("!types",
      ::format("Unable to get cached enum by property: '%s'. No 'types' array found.", propName))
    enumTable.types <- []
  }

  foreach (typeTbl in enumTable.types)
  {
    if (!u.isTable(typeTbl))
      continue

    local valueArr = getPropValue(propName, typeTbl)
    if (!u.isArray(valueArr))
      valueArr = [valueArr]
    foreach (value in valueArr)
    {
      if (!caseSensitive)
        if (u.isString(value))
          value = value.tolower()
        else
        {
          assertOnce("bad value type",
            "enums: Bad value in type for no caseSensitive cache:\n" +
            "propName = " + propName + ", propValue = " + value + ", propValueType = " + (typeof value))
          continue
        }

      cacheTable[value] <- typeTbl
    }
  }
  return cacheTable?[propValue] ?? defaultVal
}

local function addType(enumTable, typeTemplate, typeName, typeDefinition)
{
  local type = enumTable?[typeName] ?? {} //to not brake links on exist types
  type.clear()
  if (typeTemplate)
    foreach(key, value in typeTemplate)
      type[key] <- value

  foreach (key, value in typeDefinition)
    type[key] <- value

  enumTable[typeName] <- type

  local types = enumTable?.types
  if (u.isArray(types))
    u.appendOnce(type, types)
  else
  {
    assertOnce(
      "Not found types array",
      ::format("Unable to find 'types' array in enum table (type: %s).", typeName))
  }
  return type
}

local function addTypes(enumTable, typesToAdd, typeConstructor = null, addTypeNameKey = null )
{
  local typeTemplate = enumTable?.template
  foreach (typeName, typeDefinition in typesToAdd)
  {
    local type = addType(enumTable, typeTemplate, typeName, typeDefinition)
    if (addTypeNameKey)
      type[addTypeNameKey] <- typeName
    if (typeConstructor != null)
      typeConstructor.call(type)
  }
}

local function collectAndRegisterTypes(enumTableName, enumTable, typesToAdd)
{
  if (!(PERSISTENT_DATA_PARAMS in enumTable))
    enumTable[PERSISTENT_DATA_PARAMS] <- []
  local persistentList = enumTable[PERSISTENT_DATA_PARAMS]
  foreach(typeName, data in typesToAdd)
  {
    u.appendOnce(typeName, persistentList)
    if (!(typeName in enumTable))
      enumTable[typeName] <- null
  }

  ::g_script_reloader.registerPersistentData("enumUtils/" + enumTableName, enumTable, persistentList)
}

//registerForScriptReloader = true - register types to not brake links on types on reload scripts
local function addTypesByGlobalName(enumTableName, typesToAdd, typeConstructor = null, addTypeNameKey = null,
                                registerForScriptReloader = true)
{
  local enumTable = ::getroottable()?[enumTableName]
  if (!u.isTable(enumTable))
  {
    assertOnce("not found enum table", "enums: not found enum table '" + enumTableName + "'")
    return
  }

  if (!("g_script_reloader" in ::getroottable()))
    registerForScriptReloader = false

  if (registerForScriptReloader)
    collectAndRegisterTypes(enumTableName, enumTable, typesToAdd)

  addTypes(enumTable, typesToAdd, typeConstructor, addTypeNameKey)
}

return {
  getCachedType = getCachedType
  addTypes = addTypes
  addTypesByGlobalName = addTypesByGlobalName

  setAssertFunction = @(func) assertOnce = func  //void func(uniqId, assertText)
}