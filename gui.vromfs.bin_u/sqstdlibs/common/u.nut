const FLT_EPSILON = 0.0000001192092896
/**
 * u is a set of utility functions
 */

::u <- {
  customIsEqual = {}
  customIsEmpty = {}
}

/**
 * Add type checking functions such as isArray()
 */
foreach (typeName in ["integer", "int64", "float", "string", "null",
                      "bool", "array", "table", "function",
                      "class", "instance", "generator",
                      "userdata", "thread", "weakref"])
{
  local funcName = "is" + typeName.slice(0, 1).toupper() + typeName.slice(1)
  ::u[funcName] <- (@(typeName) function (arg) {
    return typeof arg == typeName
  })(typeName)
}

/*******************************************************************************
 **************************** Custom Classes register **************************
 ******************************************************************************/

/*
  register instance class to work with u.is<className>, u.isEqual,  u.isEmpty
*/
function u::registerClass(className, classRef, isEqualFunc = null, isEmptyFunc = null)
{
  local funcName = "is" + className.slice(0, 1).toupper() + className.slice(1)
  ::u[funcName] <- @(value) value instanceof classRef

  if (isEqualFunc)
    customIsEqual[classRef] <- isEqualFunc
  if (isEmptyFunc)
    customIsEmpty[classRef] <- isEmptyFunc
}

/*
  try to register standard dagor classes
*/
foreach (className, config in
{
  DataBlock = {
    isEmpty = @(val) !val.paramCount() && !val.blockCount()
    isEqual = function(val1, val2)
    {
      if (val1.paramCount() != val2.paramCount() || val1.blockCount() != val2.blockCount())
        return false

      for (local i = 0; i < val1.paramCount(); i++)
        if (val1.getParamName(i) != val2.getParamName(i) || val1.getParamValue(i) != val2.getParamValue(i))
          return false
      for (local i = 0; i < val1.blockCount(); i++)
      {
        local b1 = val1.getBlock(i)
        local b2 = val2.getBlock(i)
        if (b1.getBlockName() != b2.getBlockName() || !::u.isEqual(b1, b2))
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
        if (!::u.isEqual(val1[i], val2[i]))
          return false
      return true
    }
  }
})
{
  if (!(className in ::getroottable()))
    continue
  ::u.registerClass(className, ::getroottable()[className],
    ("isEqual" in config) && config.isEqual,
    ("isEmpty" in config) && config.isEmpty
  )
}

/*******************************************************************************
 ******************** Collections handling (array of tables) *******************
 ******************************************************************************/

/**
 * Produces a new array of values by mapping each value in list through a
 * transformation function (iteratee(value, key, list)).
 */
function u::map(list, func)
{
  return mapAdvanced(list, (@(func) function(val, ...) { return func(val) })(func))
}

function u::mapAdvanced(list, iteratee)
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
function u::reduce(list, iteratee, memo = null)
{
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
function u::search(list, predicate, reverseOrder = false)
{
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
function u::filter(list, predicate)
{
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
function u::indexBy(array, iteratee)
{
  local res = {}
  if (::u.isString(iteratee))
  {
    foreach (idx, val in array)
      res[val[iteratee]] <- val
  }
  else if (::u.isFunction(iteratee))
  {
    foreach (idx, val in array)
      res[iteratee(val, idx, array)] <- val
  }

  return res
}

/*******************************************************************************
 ****************************** Table handling *********************************
 ******************************************************************************/

/**
 * keys return an array of keys of specified table
 */
function u::keys(table)
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
function u::values(table)
{
  local res = []
  foreach (val in table)
    res.append(val)
  return res
}

/**
 * Convert a table into a list of [key, value] pairs.
 */
function u::pairs(table)
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
function u::invert(table)
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
function u::pick(table, ... /*keys*/)
{
  local res = {}
  if (table == null)
    return res

  if (::u.isFunction(vargv[0]))
  {
    foreach (key, val in table)
      if (vargv[0](value, key, obj)) res[key] <- val
  }
  else
  {
    local keys = []
    if (::u.isArray(vargv[0]))
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
function u::isEmpty(val)
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
function u::isEqual(val1, val2)
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
function u::extend(destination, ... /*sources*/)
{
  for (local i = 0; i < vargv.len(); i++)
    foreach (key, val in vargv[i])
    {
      local v = val
      if (::u.isArray(val) || ::u.isTable(val))
        v = ::u.extend(::u.isArray(val) ? [] : {}, val)

      ::u.isArray(destination)
        ? destination.append(v)
        : destination[key] <- v
    }

  return destination
}

/**
 * Recursevly copy all fields of obj to the new instance of same type and
 * returns it.
 */
function u::copy(obj)
{
  if (obj == null)
    return null

  if (::u.isDataBlock(obj))
  {
    local res = ::DataBlock()
    res.setFrom(obj)
    local name = obj.getBlockName()
    if (name)
      res.changeBlockName(name)
    return res
  }

  if (!::u.isArray(obj) && !::u.isTable(obj))
    return clone obj

  return ::u.extend(::u.isArray(obj) ? [] : {}, obj)
}

/**
 * Create new table which have all keys from both table, and for each key maps
 * value func(tbl1Value, tbl2Value)
 * If value not exist in one of table it will be pushed to func as defValue
 */
function u::tablesCombine(tbl1, tbl2, func, defValue = null)
{
  local res = {}
  foreach(key, value in tbl1)
    res[key] <- func(value, ::getTblValue(key, tbl2, defValue))
  foreach(key, value in tbl2)
    if (!(key in res))
      res[key] <- func(defValue, value)
  return res
}

/**
 * Create new table which have keys, replaced from keysEqual table.
 * deepLevel param set deep of recursion for replace keys in tbl childs
*/
function u::keysReplace(tbl, keysEqual, deepLevel = -1)
{
  local res = {}
  local newValue = null
  foreach(key, value in tbl)
  {
    if (::u.isTable(value) && deepLevel != 0)
      newValue = ::u.keysReplace(value, keysEqual, deepLevel - 1)
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
function u::removeFrom(data, value)
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
 * Save get value from @tablesArray (array of sources)
 * by @pathsArray (array of paths) with ::getTblValueByPath
 * @return first not null value or @defValue
 */
function u::getFirstFound(pathsArray, tablesArray, defValue = null)
{
  local result = null
  foreach (table in tablesArray)
    foreach (path in pathsArray)
    {
      result = ::getTblValueByPath(path, table, null)
      if(result != null)
        return result
    }
  return defValue
}

/*******************************************************************************
 ****************************** Array handling *********************************
 ******************************************************************************/

/**
 * Returns the index at which value can be found in the array, or -1 if value
 * is not present in the array
 * <defaultIndex> is index tp return when value not found in the given array
 */
function u::searchIndex(arr, predicate, defaultIndex = -1)
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
function u::last(arr, n = 1)
{
  if (arr.len() >= n && n > 0)
    return arr[arr.len() - n]
}

// * Returns random element of the given array
function u::chooseRandom(arr)
{
  if (!arr.len())
    return null
  return arr[::math.rnd() % arr.len()]
}

function u::chooseRandomNoRepeat(arr, prevIdx)
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

//save get value from table, array, or instance by @key
//return @defValue if @key dosnt exist in @tbl
function getTblValue(key, tbl, defValue = null)
{
  return (key in tbl)? tbl[key] : defValue
}

//save get value from table, array, or instance by @path string separated by @separator
//return @defValue if @path not complete in @tbl
function getTblValueByPath(path, tbl, defValue = null, separator = ".")
{
  if (path == "")
    return defValue
  if (path.find(separator) == null)
    return ::getTblValue(path, tbl, defValue)
  local keys = ::split(path, separator)
  return ::get_tbl_value_by_path_array(keys, tbl, defValue)
}

//save get value from table, array, or instance by @pathArray
//return @defValue if @pathArray not complete in @tbl
function get_tbl_value_by_path_array(pathArray, tbl, defValue = null)
{
  foreach(key in pathArray)
    tbl = ::getTblValue(key, tbl, defValue)
  return tbl
}

function append_once(v, arr, skipNull = false)
{
  if ((!skipNull || v != null) && arr.find(v) < 0)
    arr.append(v)
}
