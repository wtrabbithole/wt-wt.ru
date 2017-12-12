local u = require("sqStdLibs/common/u.nut")

/**
 * Contains all utility functions related to creation
 * of and managing in-game type enumerations.
 */
::g_enum_utils <- {}

//caseSensitive work only with string propValues
function g_enum_utils::getCachedType(propName, propValue, cacheTable, enumTable, defaultVal, caseSensitive = true)
{
  if (!caseSensitive)
  {
    if (u.isString(propValue))
      propValue = propValue.tolower()
    else
    {
      assertOnce("bad propValue type",
        "g_enum_utils: Bad value type for getCachedType with no caseSensitive:\n" +
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

    local value = getPropValue(propName, typeTbl)
    if (!caseSensitive)
      if (u.isString(value))
        value = value.tolower()
      else
      {
        assertOnce("bad value type",
          "g_enum_utils: Bad value in type for no caseSensitive cache:\n" +
          "propName = " + propName + ", propValue = " + value + ", propValueType = " + (typeof value))
        continue
      }

    cacheTable[value] <- typeTbl
  }
  return cacheTable?[propValue] ?? defaultVal
}

function g_enum_utils::addType(enumTable, typeTemplate, typeName, typeDefinition)
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
    ::dagor.assertf(
      false,
      ::format("Unable to find 'types' array in enum table (type: %s).", typeName))
  }
  return type
}

function g_enum_utils::addTypes(enumTable, typesToAdd, typeConstructor = null, addTypeNameKey = null )
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

//registerForScriptReloader = true - register types to not brake links on types on reload scripts
function g_enum_utils::addTypesByGlobalName(enumTableName, typesToAdd, typeConstructor = null, addTypeNameKey = null,
                                registerForScriptReloader = true)
{
  local enumTable = ::getroottable()?[enumTableName]
  if (!u.isTable(enumTable))
  {
    ::dagor.assertf(false, "g_enum_utils: not found enum table '" + enumTableName + "'")
    return
  }

  if (!("g_script_reloader" in ::getroottable()))
    registerForScriptReloader = false
    
  if (registerForScriptReloader)
    collectAndRegisterTypes(enumTableName, enumTable, typesToAdd)

  addTypes(enumTable, typesToAdd, typeConstructor, addTypeNameKey)
}

function g_enum_utils::collectAndRegisterTypes(enumTableName, enumTable, typesToAdd)
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

function g_enum_utils::getPropValue(propName, typeObject)
{
  local value = typeObject?[propName]

  // Calling 'value()' instead of 'typeObject[propName]()'
  // caused function to be called in a wrong environment.
  return u.isFunction(value) ? typeObject[propName]() : value
}

function g_enum_utils::assertOnce(id, errorText)
{
  if ("script_net_assert_once" in ::getroottable())
    ::script_net_assert_once(id, errorText)
}
