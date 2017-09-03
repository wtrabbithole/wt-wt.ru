class ::gui_handlers.ClusterSelect extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  shouldBlurSceneBg = false
  parentObj = null
  align = null

  static function open(parent_obj, align)
  {
    local params = {
      parentObj = parent_obj
      align = align
    }
    ::handlersManager.loadHandler(::gui_handlers.ClusterSelect, params)
  }

  function initScreen()
  {
    if (!::checkObj(scene))
      return goBack()
    if (!::checkObj(parentObj))
      return goBack()
    if (::checkObj(guiScene["cluster_select"])) //duplicate protection
      return goBack()

    fill()
  }

  function fill()
  {
    local view = {
      clusters = getViewClusters()
    }

    local blk = ::handyman.renderCached(("gui/clusterSelect"), view)
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)

    local clusterMultiSelectObject = scene.findObject("cluster_multi_select")
    if (::checkObj(clusterMultiSelectObject))
    {
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(parentObj, align, scene.findObject("cluster_select"))
      local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
      clusterMultiSelectObject.setValue(clusterOpt.value)
      clusterMultiSelectObject.select()
    }
  }

  function getViewClusters()
  {
    local viewClusters = []
    local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
    foreach (idx, item in clusterOpt.items)
    {
      viewClusters.push({
        id = "cluster_item_" + idx
        value = idx
        text = item.text
      })
    }
    return viewClusters
  }

  function onClusterSelect(obj)
  {
    if (!checkObj(obj))
      return
    if (obj.getValue() <= 0)
      return
    local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
    ::set_option(::USEROPT_RANDB_CLUSTER, obj.getValue(), clusterOpt)
  }

  static function isOpenedFor(obj)
  {
    return ::checkObj(obj.findObject("cluster_select"))
  }
}
