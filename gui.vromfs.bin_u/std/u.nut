/**
 * u is a set of utility functions, trashbin
 it also provide export for underscore.nut
 */

local rootTable = getroottable()
local split = rootTable?.split
  ?? require("string")?.split
  ?? function(str,sep) {
       throw("no split of string library exist")
       return str
     }
local rnd = rootTable?.math?.rnd
  ?? require("math")?.rand
  ?? function() {
       throw("no math library exist")
       return 0
     }

local customIsEqual = {}
local customIsEmpty = {}

/**
 * Looks through each value in the list, returning an array of all the values
 * that pass a truth test (predicate).
 */
local function filter(list, predicate) {
  local res = []
  foreach (element in list)
    if (predicate(element))
      res.append(element)
  return res
}

/**
 * Produces a new array of values by mapping each value in list through a
 * transformation function (iteratee(value, key, list)).
 */
local function mapAdvanced(list, iteratee)
{
  if (typeof(list) == "array")
  {
    local res = []
    for (local i = 0; i < list.len(); ++i)
      res.push(iteratee(list[i], i, list))
    return res
  }
  if (typeof(list) == "table" || isDataBlock(list))
  {
    local res = {}
    foreach (key, val in list)
      res[key] <- iteratee(val, key, list)
    return res
  }
  return []
}

local function map(list, func)
{
  return mapAdvanced(list, (@(func) function(val, ...) { return func(val) })(func))
}


/*******************************************************************************
 **************************** Custom Classes register **************************
 ******************************************************************************/

/*
  register instance class to work with u.is<className>, u.isEqual,  u.isEmpty
*/
local function registerClass(className, classRef, isEqualFunc = null, isEmptyFunc = null) {
  local funcName = "is" + className.slice(0, 1).toupper() + className.slice(1)
  this[funcName] <- function(value)
  {
    if (value instanceof classRef)
      return true
    if ("dagor2" in rootTable && className in ::dagor2)
      return value instanceof dagor2[className]
    return false
  }

  if (isEqualFunc)
    customIsEqual[classRef] <- isEqualFunc
  if (isEmptyFunc)
    customIsEmpty[classRef] <- isEmptyFunc
}

/*
  try to register standard dagor classes
*/
local dagorClasses = {
  DataBlock = {
    isEmpty = @(val) !val.paramCount() && !val.blockCount()
    isEqual = function(val1, val2)
    {
      if (val1.paramCount() != val2.paramCount() || val1.blockCount() != val2.blockCount())
        return false

      for (local i = 0; i < val1.paramCount(); i++)
        if (val1.getParamName(i) != val2.getParamName(i) || ! isEqual(val1.getParamValue(i), val2.getParamValue(i)))
          return false
      for (local i = 0; i < val1.blockCount(); i++)
      {
        local b1 = val1.getBlock(i)
        local b2 = val2.getBlock(i)
        if (b1.getBlockName() != b2.getBlockName() || !isEqual(b1, b2))
          return false
      }
      return true
    }
  }
  Point2 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y
    isEmpty = @(val) !val.x && !val.y
  }
  IPoint2 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y
    isEmpty = @(val) !val.x && !val.y
  }
  Point3 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z
    isEmpty = @(val) !val.x && !val.y && !val.z
  }
  IPoint3 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z
    isEmpty = @(val) !val.x && !val.y && !val.z
  }
  Point4 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z && val1.w == val2.w
    isEmpty = @(val) !val.x && !val.y && !val.z && !val.w
  }
  Color4 = {
    isEqual = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b && val1.a == val2.a
  }
  Color3 = {
    isEqual = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b
  }
  TMatrix = {
    isEqual = function(val1, val2)
    {
      for (local i = 0; i < 4; i++)
        if (!isEqual(val1[i], val2[i]))
          return false
      return true
    }
  }
}


/**
 * Return true if specified obj (@table, @array, @string, @datablock) is empty
 */
local function isEmpty(val)
{
  if (!val)
    return true

  if (isArray(val) || isString(val) || isTable(val))
    return val.len() == 0

  if (isInstance(val))
  {
    foreach(classRef, func in customIsEmpty)
      if (val instanceof classRef)
        return func(val)
    return false
  }

  return true
}

/*
 * Return true if object or it's values are all equal to checking value
**/
local function isEqual(val1, val2)
{
  if (typeof(val1) != typeof(val2))
    return false
  if (isArray(val1) || isTable(val1))
  {
    if (val1.len() != val2.len())
      return false
    foreach(key, val in val1)
    {
      if (!(key in val2))
        return false
      if (!isEqual(val, val2[key]))
        return false
    }
    return true
  }

  if (isInstance(val1) && isInstance(val2))
  {
    foreach(classRef, func in customIsEqual)
      if (val1 instanceof classRef && val2 instanceof classRef)
        return func(val1, val2)
    return false
  }

  return val1 == val2
}

/**
 * Copy all of the properties in the source objects over to the destination
 * object, and return the destination object. It's in-order, so the last source
 * will override properties of the same name in previous arguments.
 */
local function extend(destination, ... /*sources*/)
{
  for (local i = 0; i < vargv.len(); i++)
    foreach (key, val in vargv[i])
    {
      local v = val
      if (isArray(val) || isTable(val))
        v = extend(isArray(val) ? [] : {}, val)

      isArray(destination)
        ? destination.append(v)
        : destination[key] <- v
    }

  return destination
}

/**
 * Recursevly copy all fields of obj to the new instance of same type and
 * returns it.
 */
local function copy(obj)
{
  if (obj == null)
    return null

  if (isArray(obj) || isTable(obj))
    return extend(isArray(obj) ? [] : {}, obj)

  //!!FIX ME: Better to make clone method work with datablocks, or move it to custom methods same as isEqual
  if ("isDataBlock" in this && isDataBlock(obj))
  {
    local res = ::DataBlock()
    res.setFrom(obj)
    local name = obj.getBlockName()
    if (name)
      res.changeBlockName(name)
    return res
  }

  return clone obj
}

/*
  * Find and remove {value} from {data} (table/array) once
  * return true if found
*/
local function removeFrom(data, value)
{
  if (isArray(data))
  {
    local idx = data.find(value)
    if (idx >= 0)
    {
      data.remove(idx)
      return true
    }
  }
  else if (isTable(data))
  {
    foreach(key, val in data)
      if (val == value)
      {
        delete data[key]
        return true
      }
  }
  return false
}

/**
 * Create new table which have keys, replaced from keysEqual table.
 * deepLevel param set deep of recursion for replace keys in tbl childs
*/
local function keysReplace(tbl, keysEqual, deepLevel = -1) {
  local res = {}
  local newValue = null
  foreach(key, value in tbl) {
    if (isTable(value) && deepLevel != 0)
      newValue = keysReplace(value, keysEqual, deepLevel - 1)
    else
      newValue = value

    if (key in keysEqual)
      res[keysEqual[key]] <- newValue
    else
      res[key] <- newValue
  }

  return res
}

/**
 * Given a array, and an iteratee function that returns a key for each
 * element in the array (or a property name), returns an object with an index
 * of each item.
 */
local function indexBy(array, iteratee) {
  local res = {}
  if (isString(iteratee))
  {
    foreach (idx, val in array)
      res[val[iteratee]] <- val
  }
  else if (isFunction(iteratee))
  {
    foreach (idx, val in array)
      res[iteratee(val, idx, array)] <- val
  }

  return res
}

/*******************************************************************************
 ****************************** Array handling *********************************
 ******************************************************************************/

/**
 * Returns the index at which value can be found in the array, or -1 if value
 * is not present in the array
 * <defaultIndex> is index tp return when value not found in the given array
 */
local function searchIndex(arr, predicate, defaultIndex = -1)
{
  foreach (index, item in arr)
    if (predicate(item))
      return index
  return defaultIndex
}

/**
 * Returns the last element of an array. Passing n will return the last n
 * elements of the array.
 */
local function last(collection, n = 1) {
  if (collection.len() >= n && n > 0)
    return collection[collection.len() - n]
  return null
}

/**
 * Safely returns the element of an array. Passing negative number will return element from end. 
 * If number is more than length array will return last one (first one for negative)
 */
local function safeIndex(arr, n) {
  if (n > arr.len()-1 && n >= 0)
    return arr[arr.len()-1]
  if (arr.len() > n && n >= 0)
    return arr[n]
  if (-n >= arr.len() && n < 0)
    return arr[0]
  if (arr.len() >= -n && n < 0)
    return arr[arr.len() + n]
  return null
}

local function max(arr, iteratee = null)
{
  local result = null
  if (!arr)
    return result

  if (!iteratee)
    iteratee = @(val) (typeof(val) == "integer" || typeof(val) == "float") ? val : null

  local lastMaxValue = null
  foreach (data in arr)
  {
    local value = iteratee(data)
    if (lastMaxValue != null && value <= lastMaxValue)
      continue

    lastMaxValue = value
    result = data
  }

  return result
}

local function min(arr, iteratee = null)
{
  local newIteratee = null
  if (!iteratee)
    newIteratee = @(val) (typeof(val) == "integer" || typeof(val) == "float") ? -val : null
  else
  {
    newIteratee = function(val) {
      local value = iteratee(val)
      return value != null ? -value : null
    }
  }

  return max(arr, newIteratee)
}

local function appendOnce(v, arr, skipNull = false, customIsEqualFunc = null)
{
  if(skipNull && v == null)
    return

  if (customIsEqualFunc)
  {
    foreach (obj in arr)
      if (customIsEqualFunc(obj, v))
        return
  }
  else if (arr.find(v) != null)
    return

  arr.append(v)
}

local underscore = require("underscore.nut")

local chooseRandom = @(arr) underscore.chooseRandom(arr, rnd)
local shuffle = @(arr) underscore.shuffle(arr, rnd)

local function chooseRandomNoRepeat(arr, prevIdx) {
  if (prevIdx < 0)
    return chooseRandom(arr)
  if (!arr.len())
    return null
  if (arr.len() == 1)
    return arr[0]

  local nextIdx = rand() % (arr.len() - 1)
  if (nextIdx >= prevIdx)
    nextIdx++
  return arr[nextIdx]
}

local export = underscore.__merge({
  appendOnce = appendOnce
  chooseRandom = chooseRandom
  chooseRandomNoRepeat = chooseRandomNoRepeat
  shuffle = shuffle
  min = min
  max = max
  mapAdvanced = mapAdvanced
  indexBy = indexBy
  searchIndex = searchIndex
  removeFrom = removeFrom
  extend = extend
  registerClass = registerClass
  keysReplace = keysReplace
  copy = copy
  isEqual = isEqual
  isEmpty = isEmpty
  last = last
  safeIndex=safeIndex
//obsolete?
  map = map
  filter = filter
})

/**
 * Add type checking functions such as isArray()
 */
local internalTypes = ["integer", "int64", "float", "string", "null",
                      "bool", "array", "table", "function",
                      "class", "instance", "generator",
                      "userdata", "thread", "weakref"]
foreach (typeName in internalTypes) {
  local funcName = "is" + typeName.slice(0, 1).toupper() + typeName.slice(1)
  export[funcName] <- (@(typeName) @(arg) typeof arg == typeName)(typeName)
}

foreach (className, config in dagorClasses)
  if (className in rootTable)
    export.registerClass(className, rootTable[className], config?.isEqual, config?.isEmpty)

return export
