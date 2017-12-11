local makeSlotName = function (original_name, prefix, postfix) {
  local slotName = prefix.len() ? prefix + original_name.slice(0, 1).toupper() + original_name.slice(1) : original_name
  return slotName + postfix
}

local makeUpdateState = @(state_object) function (new_value) { state_object.update(new_value) }
local makeUpdateArrayState = @(state_array) function (idx, new_value) { state_array[idx].update(new_value)}
local generate = function (options) {
  local prefix = options?.prefix ?? ""
  local postfix = options?.postfix ?? ""

  foreach (stateName, stateObject in options.stateTable) {
    ::interop[ makeSlotName(stateName, prefix, postfix) ] <- makeUpdateState(stateObject)
  }
}

return generate