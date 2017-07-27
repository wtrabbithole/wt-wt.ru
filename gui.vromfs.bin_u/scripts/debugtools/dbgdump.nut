/**
 *  dbg_dump it tool for debugging complex scripts, which have
 *  a lot of different states, which takes a lot of time and
 *  efforts to achieve.
 *  It makes it easy to create and restore environment state
 *  dumps (selected global functions and global variables).
 *  Dumps are stored in BLK files (one file per state), so can be
 *  easily loaded at any time. And can be edited manually, if needed.
 *
 *  API
 *
 *  ::dbg_dump.save(filename, list)
 *    Dumps a list of global functions (args and return values)
 *    and global variables into a BLK dump file.
 *      @param {string} filename - Blk filename for dump. The file
 *        is stored in gameOnline directory.
 *      @param {array}  list - An array of global functions and
 *        global variables to be stored in dump.
 *    Supported 'list' array elements format:
 *      @example "name"
 *      @example { id = "name" }
 *        If "name" is global variable, will store its value to file.
 *        If "name" is global function, will call it, and store
 *        its return value as return value for empty args set.
 *      @example { id = "name", value = anything }
 *        If 'value' is defined, it will be stored as 'id' variable
 *        value (or as 'id' function return value, if 'id' is existing
 *        global function).
 *        No function call will be made if 'value' is defined.
 *        Also, if 'value' is function itself, it will be called without params
 *        to get its return result as 'value'.
 *      @example { id = "name", args = [array, of, args] }
 *        If 'args' is defined and 'id' is function, 'args' will be
 *        stored as (one of possible) function args set.
 *        Function will be called with given 'args' and its return
 *        value will be stored as return value for given args set.
 *      @example { id = "name", args = [array, of, args], value = anything }
 *        Same as above, but without function call, because 'value'
 *        will be stored as return value for given args set.
 *
 *  ::dbg_dump.load(filename, needUnloadPrev)
 *    Applies global functions and global variables from the dump file.
 *    Global variables in environment are replaced by its state from dump.
 *    Global functions in environment are replaced by fake functions,
 *    which acts like this:
 *    If it gets (one of the) exactly same input args set, as stored
 *    in dump, it returns corresponding return value from dump.
 *    Else it calls the original function, and returns what it have returned.
 *      @param {string} filename - Blk file name of saved dump.
 *      @param {bool}   needUnloadPrev (true) - Call unload() before
 *        loading, to revert all environment changes of previuos load() calls.
 *
 *  ::dbg_dump.loadFuncs(functions, needUnloadPrev)
 *    Acts like load(), but loads global functions from the given table.
 *    This method should be used in combination with load(), for overriding some
 *    global functions with custom functions, in cases, when saving those functions
 *    in a dump file is too expensive or impossible.
 *      @param {table} functions - Table of functions, where keys are global function names.
 *      @param {bool}   needUnloadPrev (true) - Same meaning as in load() params.
 *
 *  ::dbg_dump.unload()
 *    Reverts all environment changes made by load() calls, by restoring
 *    the original global functions and global variables.
 *
 *  ::dbg_dump.isLoaded()
 *    Tells if there are environment changes made by load() calls.
 *      @return {bool}
 *
 *  ::dbg_dump.getOriginal(id)
 *    Returns an original (not overridden) value of global function or global variable.
 *    Primarily for getting access to an original functions from within fake functions
 *    loaded via loadFuncs().
 *      @param {string} id - Name of global function or variable.
 *      @return {anything} - The original global function or variable.
 *
 *  ::dbg_dump.dataToBlk(data)
 *    Converts data of any supported type to data type prepared for
 *    writing to DataBlock. Can add some metadata.
 *      @param {null|bool|integer|int64|float|string|array|table|DataBlock} data - Data
 *        to be prepared for writing to DataBlock.
 *      @return {bool|integer|int64|float|string|DataBlock} - Data
 *        prepared for writing to DataBlock.
 *
 *  ::dbg_dump.blkToData(blk)
 *    Converts data read from DataBlock to it's original data type. Strips all metadata.
 *      @param {bool|integer|int64|float|string|DataBlock} blk - Data
 *        read from DataBlock.
 *      @return {null|bool|integer|int64|float|string|array|table|DataBlock} -
 *        Data in its original state.
 *
 */

::dbg_dump <- {
  [PERSISTENT_DATA_PARAMS] = ["backup"]
  backup = null
}

::g_script_reloader.registerPersistentDataFromRoot("dbg_dump")

function dbg_dump::save(filename, list)
{
  local rootTable = ::getroottable()
  local blk = ::DataBlock()
  foreach (item in list)
  {
    item = ::u.isString(item) ? { id = item } : item
    local id = ::getTblValue("id", item)
    if (!(id in rootTable) && !("value" in item))
      continue
    local subject = (id in rootTable) ? rootTable[id] : null
    local isFunction = ::u.isFunction(subject)
    local args = ::getTblValue("args", item, [])
    local value = (isFunction && !("value" in item)) ? getFuncResult(subject, args) : ::getTblValue("value", item, subject)
    if (::u.isFunction(value))
      value = value()
    if (isFunction)
    {
      local caseBlk = dataToBlk({ result = value })
      if (args.len())
        caseBlk["args"] <- dataToBlk(args)
      if (!blk[id])
        blk[id] <- dataToBlk({ __function = true })
      blk[id]["case"] <- caseBlk
    }
    else
      blk[id] <- dataToBlk(value)
  }
  return blk.saveToTextFile(filename)
}

function dbg_dump::load(filename, needUnloadPrev = true)
{
  if (needUnloadPrev)
    unload()
  backup = backup || {}

  local rootTable = ::getroottable()
  local blk = ::DataBlock()
  if (!blk.load(filename))
    return false
  for (local b = 0; b < blk.blockCount(); b++)
  {
    local data = blk.getBlock(b)
    local id = data.getBlockName()
    if (!(id in backup))
      backup[id] <- ::getTblValue(id, rootTable, "__destroy")
    if (data.__function)
    {
      local cases = []
      foreach (c in (data % "case"))
        cases.append({ args = blkToData(c.args || []), result = blkToData(c.result) })
      local origFunc = ::u.isFunction(backup[id]) ? backup[id] : null

      rootTable[id] <- (@(cases, origFunc) function(...) {
        local args = []
        for (local i = 0; i < vargv.len(); i++)
          args.append(vargv[i])
        foreach (c in cases)
          if (::u.isEqual(args, c.args))
            return c.result
        return origFunc ? ::dbg_dump.getFuncResult(origFunc, args) : null
      })(cases, origFunc)
    }
    else
      rootTable[id] <- blkToData(data)
  }
  for (local p = 0; p < blk.paramCount(); p++)
  {
    local data = blk.getParamValue(p)
    local id = blk.getParamName(p)
    if (!(id in backup))
      backup[id] <- ::getTblValue(id, rootTable, "__destroy")
    rootTable[id] <- blkToData(data)
  }
  return true
}

function dbg_dump::loadFuncs(functions, needUnloadPrev = true)
{
  if (needUnloadPrev)
    unload()
  backup = backup || {}

  local rootTable = ::getroottable()
  foreach (id, func in functions)
  {
    if (!(id in backup))
      backup[id] <- ::getTblValue(id, rootTable, "__destroy")
    rootTable[id] <- func
  }
  return true
}

function dbg_dump::unload()
{
  if (!isLoaded())
    return false
  local rootTable = ::getroottable()
  foreach (id, v in backup)
  {
    if (v == "__destroy")
      rootTable.rawdelete(id)
    else
      rootTable[id] <- v
  }
  backup = null
  return true
}

function dbg_dump::isLoaded()
{
  return backup != null
}

function dbg_dump::getOriginal(id)
{
  if (backup && (id in backup))
    return (backup[id] != "__destroy") ? backup[id] : null
  return (id in ::getroottable()) ? ::getroottable()[id] : null
}

function dbg_dump::dataToBlk(data)
{
  local dataType = ::u.isDataBlock(data) ? "DataBlock" : type(data)
  switch (dataType)
  {
    case "null":
      return "__null"
    case "bool":
    case "integer":
    case "int64":
    case "float":
    case "string":
      return data
    case "array":
    case "table":
      local blk = ::DataBlock()
      local isArray = ::u.isArray(data)
      if (isArray)
        blk.__array <- true
      foreach(key, value in data)
        blk[(isArray ? "array" : "") + key] = dataToBlk(value)
      return blk
    case "DataBlock":
      local blk = ::DataBlock()
      blk.setFrom(data)
      blk.__datablock <- true
      return blk
    default:
      return "__unsupported " + ::toString(data)
  }
}

function dbg_dump::blkToData(blk)
{
  if (::u.isString(blk) && ::g_string.startsWith(blk, "__unsupported"))
  {
    return null
  }
  if (!::u.isDataBlock(blk))
  {
    return blk == "__null" ? null : blk
  }
  if (blk.__datablock)
  {
    local res = ::DataBlock()
    res.setFrom(blk)
    res.__datablock = null
    return res
  }
  if (blk.__array)
  {
    local res = []
    for (local i = 0; i < blk.blockCount() + blk.paramCount() - 1; i++)
      res.append(blkToData(blk["array" + i]))
    return res
  }
  local res = {}
  for (local b = 0; b < blk.blockCount(); b++)
  {
    local block = blk.getBlock(b)
    res[block.getBlockName()] <- blkToData(block)
  }
  for (local p = 0; p < blk.paramCount(); p++)
    res[blk.getParamName(p)] <- blkToData(blk.getParamValue(p))
  return res
}

function dbg_dump::getFuncResult(func, a = [])
{
  switch (a.len())
  {
    case 0: return func()
    case 1: return func(a[0])
    case 2: return func(a[0], a[1])
    case 3: return func(a[0], a[1], a[2])
    case 4: return func(a[0], a[1], a[2], a[3])
    case 5: return func(a[0], a[1], a[2], a[3], a[4])
    case 6: return func(a[0], a[1], a[2], a[3], a[4], a[5])
    case 7: return func(a[0], a[1], a[2], a[3], a[4], a[5], a[6])
    case 8: return func(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7])
    default: return null
  }
}
