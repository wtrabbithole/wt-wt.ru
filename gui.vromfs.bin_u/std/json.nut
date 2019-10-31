local json = require("json")
local io = require("io")
/*
  todo: better return Monad Result
*/
local callableTypes = ["function","table","instance"]
local function isCallable(v) {
  return callableTypes.indexof(::type(v)) != null && (v.getfuncinfos() != null)
}

local function defSaveJsonFile(file_path, data){
  ::assert(::type(data) == "string", "data should be string")
  local file = io.file(file_path, "wt+")
  file.writestring(data)
  file.close()
  return true
}

local defParamsSave = {pretty_print=true, logger=null, save_text_file = defSaveJsonFile}
local function save(file_path, data, params = defParamsSave) {
  local pretty_print = params?.pretty_print ?? defParamsSave.pretty_print
  local save_text_file = params?.save_text_file ?? defParamsSave.save_text_file
  local logger = params?.logger ?? defParamsSave.logger
  ::assert(isCallable(save_text_file), "save_text_file should be Callable")
  ::assert(::type(file_path)=="string", "file_path should be string")
  ::assert(logger== null || isCallable(logger), @() "logger should be Callable or null, got {0}".subst(::type(logger)))
  ::assert(["function","class","instance","generator"].indexof(::type(data))==null)
  try {
    data = json.to_string(data, pretty_print)
    local res = save_text_file(file_path, data)
    if (res){
      logger?("file:{0} saved".subst(file_path))
      return true
    }
    else {
      logger?("file:{0} was not saved!".subst(file_path))
      return null
    }
  }
  catch(e) {
    logger?("error in saving data", e)
    return null
  }
}

local function defLoadTextFileFunc(file_path){
  local file = io.file(file_path, "rt+")
  local jsonfile = file.readblob(file.len())
  file.close()
  return jsonfile.tostring()
}
local defParamsLoad = {logger=null, load_text_file = defLoadTextFileFunc}
local function load(file_path, params = defParamsLoad) {
  ::assert(::type(file_path)=="string", "file_path should be string")
  local logger = params?.logger ?? defParamsLoad.logger
  local load_text_file = params?.load_text_file ?? defParamsLoad.load_text_file
  ::assert(isCallable(load_text_file), "load_text_file should be Callable")
  ::assert(isCallable(logger) || logger==null, @() "logger should be Callable or null, got {0}".subst(::type(logger)))
  try {
    local jsontext = load_text_file(file_path)
    return json.parse(jsontext)
  }
  catch(e) {
    logger?("error in loading data", e)
    return null
  }
}
return json.__merge({
  save = save
  load = load
})