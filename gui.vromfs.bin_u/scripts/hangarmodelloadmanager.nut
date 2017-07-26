enum HangarModelLoadState
{
  LOADING
  LOADED
}

/**
 * This class incapsulates hangar model loading.
 */
class HangarModelLoadManager
{
  _isLoading = false

  constructor()
  {
    ::g_script_reloader.registerPersistentData("HangarModelLoadManager", this, ["_isLoading"])
  }

  function getLoadState()
  {
    // First check covers case when model was loaded from within C++.
    // Flag "_isLoading" covers model loading from Squirrel.
    return ::hangar_get_loaded_unit_name() == "" || _isLoading
      ? HangarModelLoadState.LOADING
      : HangarModelLoadState.LOADED
  }

  function loadModel(modelName)
  {
    _isLoading = true
    hangar_load_model(modelName)
    ::broadcastEvent("HangarModelLoading")
  }

  function _onHangarModelLoaded()
  {
    _isLoading = false
    ::broadcastEvent("HangarModelLoaded")
  }
}

::hangar_model_load_manager <- HangarModelLoadManager()

/** This method is called from within C++. */
function on_hangar_model_loaded()
{
  ::hangar_model_load_manager._onHangarModelLoaded()
}
