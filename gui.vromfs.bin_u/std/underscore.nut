/*
     underscore.js inspired functional paradigm extensions for squirrel
     library is self contained - no extra dependecies, no any game or app specific dependencies
     ALL functions in this library do not mutate data
*/
/*******************************************************************************
 ******************** Collections handling (array of tables) *******************
 ******************************************************************************/

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
  the reduce function for table */

local function reduceTbl(table, iteratee, memo = null) {
  foreach (key,value in table)
    memo = iteratee(key, value, memo)
  return memo
}

/**
 * Looks through each value in the @data, returning the first one that passes
 * a truth test @predicate, or null if no value passes the test. The function
 * returns as soon as it finds an acceptable element, and doesn't traverse
 * the entire data.
 * @reverseOrder work only with arrays.
 */
local function search(data, predicate, reverseOrder = false) {
  if (!reverseOrder || ::type(data) != "array") {
    foreach(value in data)
      if (predicate(value))
        return value
    return null
  }

  for (local i = data.len() - 1; i >= 0; i--)
    if (predicate(data[i]))
      return data[i]
  return null
}

/**
 * Merges together the values of each of the arrays (or tables) with the values
 * at the corresponding position. Useful when you have separate
 * data sources that are coordinated through matching array indexes.
 if function provided in arguments than it would be used as return_dataset[idx] = func(dataset_1[idx],dataset_2[idx]), for all datasets
 otherwise it would return [dataset_1[idx],dataset_2[idx],...dataset_n[idx]]
 */
local function zip(...) {
  local func = search(vargv, @(v) ::type(v)=="function")
  local datasets = vargv.filter(@(i,val) ::type(val)=="array")
  ::assert(datasets.len()>1, "zip can work only with two or more datasources")
  local res = datasets[0].map(@(v) [v])
  if (func == null) {
    for (local i = 1; i < datasets.len(); ++i)
      foreach (idx, v in res)
        v.append(datasets[i]?[idx])
  } else {
    res = clone datasets[0]
    for (local i = 1; i < datasets.len(); ++i)
      foreach (idx, v in res)
        res[idx]=func(v, datasets[i]?[idx])
  }
  return res
}

/*******************************************************************************
 ****************************** Table handling *********************************
 ******************************************************************************/

/**
 * keys return an array of keys of specified table
 */
local function keys(table) {
  if (typeof table == "array"){
    local res = ::array(table.len())
    foreach (i, k in res)
      res[i]=i
    return res
  }
  local res = []
  foreach (k, v in table)
    res.append(k)
  return res
}

/**
 * Return all of the values of the table's properties.
 */
local function values(data) {
  if (typeof data == "array")
    return clone data
  local res = []
  foreach (val in data)
    res.append(val)
  return res
}

/**
 * Convert a table into a list of [key, value] pairs.
 */
local function pairs(table) {
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
local function invert(table) {
  local res = {}
  foreach (key, val in table)
    res[val] <- key
  return res
}

/**
 * Create new table which have all keys from both tables (or just first table,
   if addParams=true), and for each key maps value func(tbl1Value, tbl2Value)
 * If value not exist in one of table it will be pushed to func as defValue
 */
local function tablesCombine(tbl1, tbl2, func=null, defValue = null, addParams = true) {
  local res = {}
  if (func == null)
    func = function (val1, val2) {return val2}
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
 * Returns the index at which value can be found in the array, or -1 if value
 * is not present in the array
 * <defaultIndex> is index tp return when value not found in the given array
 */
local function searchIndex(arr, predicate, defaultIndex = -1) {
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

// * Returns random element of the given array, rand should be function that return int
local function chooseRandom(arr, randfunc) {
  if (arr.len()==0)
    return null
  return arr[randfunc() % arr.len()]
}

local function shuffle(arr, randfunc) {
  local res = clone arr
  local size = res.len()
  local j
  local v
  for (local i = size - 1; i > 0; i--)
  {
    j = randfunc() % (i + 1)
    v = res[j]
    res[j] = res[i]
    res[i] = v
  }
  return res
}

return {
  reduceTbl = reduceTbl
  search = search
  zip = zip
  keys = keys
  values = values
  pairs = pairs
  invert = invert
  tablesCombine = tablesCombine
  chooseRandom = chooseRandom
  searchIndex = searchIndex
  safeIndex = safeIndex
  last = last
  shuffle = shuffle
}