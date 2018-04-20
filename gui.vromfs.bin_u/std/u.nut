const FLT_EPSILON = 0.0000001192092896
/**
 * u is a set of utility functions
 */

local rootTable = getroottable()
local split = rootTable?.split
  ?? require("string")?.split
  ?? function(str,sep) {
       throw("no split of string library exist")
       return str
     }

local customIsEqual = {}
local customIsEmpty = {}

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
local dagorClasses =
{
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
  Point3 = {
    isEqual = @(val1, val2) val1.x == val2.x && val1.y == val2.y && val1.z == val2.z
    isEmpty = @(val) !val.x && !val.y && !val.z
  }
  Color4 = {
    isEqual = @(val1, val2) val1.r == val2.r && val1.g == val2.g && val1.b == val2.b && val1.a == val2.a
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

/*******************************************************************************
 ******************** Collections handling (array of tables) *******************
 ******************************************************************************/

/**
 * Produces a new array of values by mapping each value in list through a
 * transformation function (iteratee(value, key, list)).
 */
local function map(list, func)
{
  return mapAdvanced(list, (@(func) function(val, ...) { return func(val) })(func))
}

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


/**
 * Reduce boils down a list of values into a single value.
 * Memo is the initial state of the reduction, and each successive
 * step of it should be returned by iteratee. The iteratee is passed
 * four arguments: the memo, then the value and index (or key) of the
 * iteration, and finally a reference to the entire list.
 *
 * If no memo is passed to the initial invocation of reduce,
 * the iteratee is not invoked on the first element of the list.
 * The first element is instead passed as the memo in the
 * invocation of the iteratee on the next element in the list.
 */
local function reduce(list, iteratee, memo = null) {
  foreach (item in list)
    memo = iteratee(item, memo)

  return memo
}


/**
 * Looks through each value in the @list, returning the first one that passes
 * a truth test @predicate, or null if no value passes the test. The function
 * returns as soon as it finds an acceptable element, and doesn't traverse
 * the entire list.
 * @reverseOrder work only with arrays.
 */
local function search(list, predicate, reverseOrder = false) {
  if (!reverseOrder || !isArray(list))
  {
    foreach(value in list)
      if (predicate(value))
        return value
    return null
  }

  for (local i = list.len() - 1; i >= 0; i--)
    if (predicate(list[i]))
      return list[i]
  return null
}

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

/**
 * Merges together the values of each of the arrays (or tables) with the values
 * at the corresponding position. Useful when you have separate
 * data sources that are coordinated through matching array indexes.
 */
local function zip(...) {
  local res = map(vargv[0], @(v) [v])
  for (local i = 1; i < vargv.len(); ++i)
    foreach (idx, v in res)
      v.append(vargv[i]?[idx])
  return res
}

/*******************************************************************************
 ****************************** Table handling *********************************
 ******************************************************************************/

/**
 * keys return an array of keys of specified table
 */
local function keys(table)
{
  if (typeof table != "table")
    return []

  local keys = []
  foreach (k, v in table)
    keys.append(k)
  return keys
}

/**
 * Return all of the values of the table's properties.
 */
local function values(table)
{
  local res = []
  foreach (val in table)
    res.append(val)
  return res
}

/**
 * Convert a table into a list of [key, value] pairs.
 */
local function pairs(table)
{
  local res = []
  foreach (key, val in table)
    res.append([key, val])
  return res
}

/**
 * Returns a copy of the table where the keys have become the values and the
 * values the keys. For this to work, all of your table's values should be
 * unique and string serializable.
 */
local function invert(table)
{
  local res = {}
  foreach (key, val in table)
    res[val] <- key
  return res
}

/**
 * Return a copy of the table, filtered to only have values for the whitelisted
 * keys (or array of valid keys). Alternatively accepts a predicate indicating
 * which keys to pick.
 * pick can filter with function (value, key, table), with array, or set of
 * separate strings (each as a separate argument)
 */
local function pick(table, ... /*keys*/)
{
  local res = {}
  if (table == null)
    return res

  if (isFunction(vargv[0]))
  {
    foreach (key, val in table)
      if (vargv[0](value, key, obj)) res[key] <- val
  }
  else
  {
    local keys = []
    if (isArray(vargv[0]))
      keys = vargv[0]
    else
      for (local i = 0; i < vargv.len(); i++)
        keys.append(vargv[i])

    foreach (key in keys)
      if (key in table)
        res[key] <- table[key]
  }
  return res
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

/**
 * Create new table which have all keys from both tables (or just first table,
   if skipSecondTable=true), and for each key maps value func(tbl1Value, tbl2Value)
 * If value not exist in one of table it will be pushed to func as defValue
 */
local function tablesCombine(tbl1, tbl2, func, defValue = null, addParams = true)
{
  local res = {}
  foreach(key, value in tbl1)
    res[key] <- func(value, tbl2?[key] ?? defValue)
  if (!addParams)
    return res
  foreach(key, value in tbl2)
    if (!(key in res))
      res[key] <- func(defValue, value)
  return res
}

/**
 * Create new table which have keys, replaced from keysEqual table.
 * deepLevel param set deep of recursion for replace keys in tbl childs
*/
local function keysReplace(tbl, keysEqual, deepLevel = -1)
{
  local res = {}
  local newValue = null
  foreach(key, value in tbl)
  {
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
 * Returns first not null result of @getter function applied to @dataArray item
 * Returns @defValue when nothing found
 */
local function getFirstFound(dataArray, getter, defValue = null)
{
  local result = null
  foreach (data in dataArray)
  {
    result = getter(data)
    if(result != null)
      break
  }
  return result ?? defValue
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
local function last(arr, n = 1)
{
  if (arr.len() >= n && n > 0)
    return arr[arr.len() - n]
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
}

// * Returns random element of the given array
local function chooseRandom(arr)
{
  if (!arr.len())
    return null
  return arr[::math.rnd() % arr.len()]
}

local function chooseRandomNoRepeat(arr, prevIdx)
{
  if (prevIdx < 0)
    return chooseRandom(arr)
  if (!arr.len())
    return null
  if (arr.len() == 1)
    return arr[0]

  local nextIdx = ::math.rnd() % (arr.len() - 1)
  if (nextIdx >= prevIdx)
    nextIdx++
  return arr[nextIdx]
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

local function setTblValueByArrayPath(pathArray, tbl, value) {
  foreach(idx, key in pathArray) {
    if (idx == pathArray.len()-1)
      tbl[key]<-value
    else {
      if (!(key in tbl))
        tbl[key] <- {}
      tbl = tbl[key]
    }
  }
}

local function setTblValueByPath(path, tbl, value, separator = ".") {
  if (type(path) == "string") {
    path = split(path, separator)
  }
  if (type(path) == "array")
    setTblValueByArrayPath(keys, tbl, value)
  else 
    tbl[path] <- value
}

local function getTblValueByPath(table, path, separator = ".") {
  if (type(path) == "string") {
    path = split(path, separator)
  }
  assert(type(path)=="array", "Path should be array or string with separator")
  local ret = table
  foreach(i,p in path) {
    if (ret==null)
      return null
    ret = ret?[p]
  }
  return ret
}

local export = {
  appendOnce = appendOnce
  chooseRandom = chooseRandom
  chooseRandomNoRepeat = chooseRandomNoRepeat
  mapAdvanced = mapAdvanced
  getFirstFound = getFirstFound
  search = search
  indexBy = indexBy
  zip = zip
  searchIndex = searchIndex
  getFirstFound = getFirstFound
  removeFrom = removeFrom
  extend = extend
  tablesCombine = tablesCombine
  registerClass = registerClass
  keysReplace = keysReplace
  copy = copy
  isEqual = isEqual
  isEmpty = isEmpty
  pick = pick
  last = last
  safeIndex=safeIndex
  invert = invert
  pairs = pairs
  values = values
  keys = keys
  setTblValueByPath = setTblValueByPath
  getTblValueByPath = getTblValueByPath
//obsolete?
  map = map
  reduce = reduce 
  filter = filter
}

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
