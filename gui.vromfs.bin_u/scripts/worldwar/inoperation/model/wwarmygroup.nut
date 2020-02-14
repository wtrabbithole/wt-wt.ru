class ::WwArmyGroup
{
  clanId               = ""
  name                 = ""
  supremeCommanderUid   = ""
  supremeCommanderNick = ""

  unitType = ::g_ww_unit_type.GROUND.code

  owner = null

  managerUids  = null
  observerUids = null
  activeManagerUids = null

  armyView = null

  actionCounts  = null
  armyManagers = null
  unupdatedCount = 0

  constructor(blk)
  {
    clanId               = ::getTblValue("clanId", blk, "").tostring()
    name                 = ::getTblValue("name", blk, "")
    supremeCommanderUid   = ::getTblValue("supremeCommanderUid", blk, "")
    supremeCommanderNick = ::getTblValue("supremeCommanderNick", blk, "")
    owner                = ::WwArmyOwner(blk.getBlockByName("owner"))
    armyManagers         = []
    managerUids          = blk.getBlockByName("managerUids") % "item"
    observerUids         = blk.getBlockByName("observerUids") % "item" || []
    updateActionCounts(blk.getBlockByName("managerStats"))
  }

  function clear()
  {
    clanId               = ""
    name                 = ""
    supremeCommanderUid   = ""
    supremeCommanderNick = ""

    owner = null

    managerUids  = null
    observerUids = null
    activeManagerUids = null

    actionCounts = null
    unupdatedCount = 0
  }

  function isValid()
  {
    return name.len() > 0 && owner && owner.isValid()
  }

  function getView()
  {
    if (!armyView)
      armyView = ::WwArmyView(this)
    return armyView
  }

  function isMyArmy(army)
  {
    return getArmyGroupIdx() == army.getArmyGroupIdx() &&
           getArmySide()     == army.getArmySide()     &&
           getArmyCountry()  == army.getArmyCountry()
  }

  function getGroupUnitType()
  {
    return unitType
  }


  function getFullName()
  {
    return ::format("%d %s", getArmyGroupIdx(), name)
  }

  function getCountryIcon(big = true)
  {
    return ::get_country_icon(getArmyCountry(), big)
  }

  function showArmyGroupText()
  {
    return true
  }

  function getClanTag()
  {
    return name
  }

  function getClanId()
  {
    return clanId
  }

  function isMySide(side)
  {
    return getArmySide() == side
  }

  function getArmyGroupIdx()
  {
    return owner.getArmyGroupIdx()
  }

  function getArmyCountry()
  {
    return owner.getCountry()
  }

  function getArmySide()
  {
    return owner.getSide()
  }

  function isBelongsToMyClan()
  {
    local myClanId = ::clan_get_my_clan_id()
    if (myClanId && myClanId == getClanId())
      return true

    return false
  }

  function getAccessLevel()
  {
    if (supremeCommanderUid == ::my_user_id_int64 || ::has_feature("worldWarMaster"))
      return WW_BATTLE_ACCESS.SUPREME

    if (owner.side == ::ww_get_player_side())
    {
      if (::isInArray(::my_user_id_int64, managerUids))
        return WW_BATTLE_ACCESS.MANAGER
      if (::isInArray(::my_user_id_int64, observerUids))
        return WW_BATTLE_ACCESS.OBSERVER
    }

    return WW_BATTLE_ACCESS.NONE
  }

  function hasManageAccess()
  {
    local accessLevel = getAccessLevel()
    return accessLevel == WW_BATTLE_ACCESS.MANAGER ||
           accessLevel == WW_BATTLE_ACCESS.SUPREME
  }

  function hasObserverAccess()
  {
    local accessLevel = getAccessLevel()
    return accessLevel == WW_BATTLE_ACCESS.OBSERVER ||
           accessLevel == WW_BATTLE_ACCESS.MANAGER ||
           accessLevel == WW_BATTLE_ACCESS.SUPREME
  }

  function updateActionCounts(blk)
  {
    if (!blk)
      return

    activeManagerUids = []
    actionCounts = {}
    foreach(mUid, inst in blk)
      if(inst)
      {
        activeManagerUids.append(mUid)
        actionCounts[mUid] <- inst?.actionsCount ?? 0
      }
    unupdatedCount = activeManagerUids.len()
  }
}
