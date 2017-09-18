const PERSISTENT_DATA_PARAMS = "PERSISTENT_DATA_PARAMS"

if (!("g_script_reloader" in ::getroottable()))
  ::g_script_reloader <- {
    USED_SCRIPTS = ["sqStdLibs/scriptReloader/scriptReloaderStorage.nut"]
    isInReloading = false

    storagesList = {}
    loadedScripts = {} //table only for faster search

    modifyPath = ("script_reloader_modify_path" in ::getroottable())
                 ? ::script_reloader_modify_path
                 : function(path) { return path }
  }

function g_script_reloader::loadOnce(scriptPath)
{
  if (scriptPath in loadedScripts)
    return false
  return _runScript(scriptPath)
}

function g_script_reloader::loadIfExist(scriptPath)
{
  if (scriptPath in loadedScripts)
    return false
  local isExist = ::dd_file_exist(scriptPath)
  loadedScripts[scriptPath] <- isExist
  if (isExist)
    return _runScript(scriptPath)
  return false
}

function g_script_reloader::_runScript(scriptPath)
{
  loadedScripts[scriptPath] <- true
  local res = ::dagor.runScript(modifyPath(scriptPath))
  ::dagor.assertf(res, "Scripts reloader: failed to load script " + scriptPath)
  return res
}

foreach(scriptPath in ::g_script_reloader.USED_SCRIPTS)
  ::g_script_reloader.loadOnce(scriptPath)

//all persistent data will restore after reload script on call this function
//storageId - uniq id where to save storage. you can use here handler or file name to avoid same id from other structures
//context - structure to save/load data from
//paramsArray - array of params id to take/set to current context
function g_script_reloader::registerPersistentData(storageId, context, paramsArray)
{
  if (storageId in storagesList)
    storagesList[storageId].switchToNewContext(context, paramsArray)
  else
    storagesList[storageId] <- ::ScriptReloaderStorage(context, paramsArray)
}

//structureId - context will be taken from root table by structure id
//              storageid = structureId
//ParamsArrayId - will be takenFromContext
function g_script_reloader::registerPersistentDataFromRoot(structureId, paramsArrayId = PERSISTENT_DATA_PARAMS)
{
  if (!(structureId in ::getroottable()))
    return ::dagor.assertf(false, "g_script_reloader: not found structure " + structureId + " in root table to register data")

  local context = ::getroottable()[structureId]
  if (!(paramsArrayId in context))
    return ::dagor.assertf(false, "g_script_reloader: not found paramsArray " + paramsArrayId + " in " + structureId)

  registerPersistentData(structureId, context, context[paramsArrayId])
}

function g_script_reloader::reload(scriptPathOrStartFunc)
{
  isInReloading = true
  saveAllDataToStorages()
  loadedScripts.clear()

  if (typeof(scriptPathOrStartFunc) == "function")
    scriptPathOrStartFunc()
  else if (typeof(scriptPathOrStartFunc) == "string")
    loadOnce(scriptPathOrStartFunc)
  else
    ::dagor.assertf(res, "Scripts reloader: bad reload param type " + scriptPathOrStartFunc)

  if ("broadcastEvent" in ::getroottable())
    ::broadcastEvent("ScriptsReloaded")
  isInReloading = false
  return "Reload success" //for feedbek on console command
}

function g_script_reloader::saveAllDataToStorages()
{
  foreach(storage in storagesList)
    storage.saveDataToStorage()
}