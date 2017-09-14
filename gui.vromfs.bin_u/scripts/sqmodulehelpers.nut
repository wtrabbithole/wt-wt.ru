/**
 * Fucntion require_native is wrapper function for require. It provides
 * fall back logic when required native module is not exist.
 * If native module failed to load, insted, load script moduel with
 * same API from nativeModuleCompatibility folder, to provide native
 * module back compatibility.
 * If fallback module has slots, missed in native module, they will
 * be added to result.
 */
function require_native(moduleName) {
  local module = require(moduleName, false) || {}
  local fallBack = require("nativeModuleCompatibility/" + moduleName + ".nut", false) || {}
  foreach (slotName, slot in fallBack) {
    if (!(slotName in module)) {
      module[slotName] <- slot
    }
  }
  return module
}
