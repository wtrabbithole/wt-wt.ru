class ::gui_handlers.FavoriteUnlocksListView extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/unlocks/favoriteUnlocksList.blk"
  isPrimaryFocus = false
  curFavoriteUnlocksBlk = null

  listContainer = null

  unlocksListIsValid = false

  function initScreen()
  {
    scene.setUserData(this)
    curFavoriteUnlocksBlk = ::DataBlock()
    listContainer = scene.findObject("favorite_unlocks_list")
    updateList()
  }

  function updateList()
  {
    if ( ! ::checkObj(listContainer))
      return

    if( ! unlocksListIsValid)
      curFavoriteUnlocksBlk.setFrom(::g_unlocks.getFavoriteUnlocks())

    local total = ::max(listContainer.childrenCount(), curFavoriteUnlocksBlk.blockCount())
    for(local i = 0; i < total; i++)
    {
      if(i >= listContainer.childrenCount())
        guiScene.createElementByObject(listContainer,
          "gui/profile/unlockItemSimplified.blk", "frameBlock", this)
      fillUnlockInfo(curFavoriteUnlocksBlk.getBlock(i), listContainer.getChild(i))
    }

    showSceneBtn("no_favorites_txt",
      ! (curFavoriteUnlocksBlk.blockCount() && listContainer.childrenCount()))
    unlocksListIsValid = true
  }

  function fillUnlockInfo(unlockBlk, unlockObj)
  {
    unlockObj.show(!!unlockBlk)
    if( ! unlockBlk)
      return

    local unlockConfig = ::build_conditions_config(unlockBlk)
    ::build_unlock_desc(unlockConfig)

    local title = ::g_unlock_view.fillUnlockTitle(unlockConfig, unlockObj)
    ::g_unlock_view.fillUnlockImage(unlockConfig, unlockObj)
    ::g_unlock_view.fillUnlockProgressBar(unlockConfig, unlockObj)
    ::g_unlock_view.fillReward(unlockConfig, unlockObj)

    local closeBtn = unlockObj.findObject("removeFromFavoritesBtn")
    if(::checkObj(closeBtn))
      closeBtn.unlockId = unlockBlk.id

    local chapterAndGroupText = []
    if(unlockBlk.chapter)
      chapterAndGroupText.push(::loc("unlocks/chapter/" + unlockBlk.chapter))
    if( ! ::u.isEmpty(unlockBlk.group))
      chapterAndGroupText.push(::loc("unlocks/group/" + unlockBlk.group))
    if (chapterAndGroupText.len())
      chapterAndGroupText = "(" + ::g_string.implode(chapterAndGroupText, ", ") + ")"
    else
      chapterAndGroupText = ""

    local tooltipArr = [::colorize("unlockHeaderColor", title),
      chapterAndGroupText, ::getTblValue("stagesText", unlockConfig, "")]
    tooltipArr.push(::UnlockConditions.getConditionsText(unlockConfig.conditions,
      unlockConfig.showProgress ? unlockConfig.curVal : null, unlockConfig.maxVal))
    unlockObj.tooltip =  ::g_string.implode(tooltipArr, "\n")  }

  function onEventFavoriteUnlocksChanged(params)
  {
    unlocksListIsValid = false
    doWhenActiveOnce("updateList")
  }

  function onEventProfileUpdated(params)
  {
    doWhenActiveOnce("updateList")
  }

  function onRemoveUnlockFromFavorites(obj)
  {
    ::g_unlocks.removeUnlockFromFavorites(obj.unlockId)
  }
}
