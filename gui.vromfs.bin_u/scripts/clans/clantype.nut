::g_clan_type <- {
  types = []
}

function g_clan_type::_getCreateCost()
{
  local blk = ::get_warpoints_blk()
  local cost = ::Cost()
  cost.gold = blk[::clan_get_gold_cost_param_name(code)] || 0
  cost.wp = blk[::clan_get_wp_cost_param_name(code)] || 0
  return cost
}

function g_clan_type::_getPrimaryInfoChangeCost()
{
  local blk = ::get_warpoints_blk()
  local cost = ::Cost()
  if (!::clan_get_admin_editor_mode())
  {
    cost.gold = blk[::clan_get_primary_info_gold_cost_param_name(code)] || 0
    cost.wp = blk[::clan_get_primary_info_wp_cost_param_name(code)] || 0
  }
  return cost
}

function g_clan_type::_getSecondaryInfoChangeCost()
{
  local blk = ::get_warpoints_blk()
  local cost = ::Cost()
  if (!::clan_get_admin_editor_mode())
  {
    cost.gold = blk[::clan_get_secondary_info_gold_cost_param_name(code)] || 0
    cost.wp = blk[::clan_get_secondary_info_wp_cost_param_name(code)] || 0
  }
  return cost
}

function g_clan_type::_checkTagText(tagText)
{
  if (tagText.find(start) != 0 || tagText.len() < end.len())
    return false
  return tagText.slice(-end.len()) == end
}

function g_clan_type::_getTagLengthLimit()
{
  return ::clan_get_tag_length_limit(code)
}

function g_clan_type::_isDescriptionChangeAllowed()
{
  return ::clan_is_desc_allowed_for_type(code)
}

function g_clan_type::_isAnnouncementAllowed()
{
  return ::clan_is_announcement_allowed_for_type(code)
}

function g_clan_type::_isRoleAllowed(roleCode)
{
  return ::clan_is_role_allowed_for_type(roleCode, code)
}

function g_clan_type::_getTypeName()
{
  return ::clan_type_to_string(code)
}

function g_clan_type::_isEnabled()
{
  return getCreateCost().gold != -1
}

function g_clan_type::_getNextType()
{
  local nextType = ::g_clan_type.getTypeByCode(nextTypeCode)
  if (nextType == ::g_clan_type.UNKNOWN || !::g_clan_type.isUpgradeAllowed(this, nextType))
    return ::g_clan_type.UNKNOWN
  return nextType
}

function g_clan_type::_getNextTypeUpgradeCost()
{
  return ::g_clan_type.getUpgradeCost(this, getNextType())
}

function g_clan_type::_canUpgradeMembers(current_limit)
{
  return ::clan_get_members_upgrade_cost(code, current_limit) >= 0
}

function g_clan_type::_getMembersUpgradeCost(current_limit)
{
  return ::Cost(0, ::max(0, ::clan_get_members_upgrade_cost(code, current_limit)))
}

function g_clan_type::_getMembersUpgradeStep()
{
  return ::clan_get_members_upgrade_step(code)
}

::g_clan_type_cache <- {
  byCode = {}
}

::g_clan_type.template <- {
  _createCost = null
  _primaryInfoChangeCost = null
  _secondaryInfoChangeCost = null
  _upgradeCost = null
  _tagDecorators = null

  minMemberCountToWWar = 1

  /** Returns cost of clan creation. */
  getCreateCost = ::g_clan_type._getCreateCost

  /** Returns cost of changing clan name or tag. */
  getPrimaryInfoChangeCost = ::g_clan_type._getPrimaryInfoChangeCost

  /** Returns cost of changing clan motto. */
  getSecondaryInfoChangeCost = ::g_clan_type._getSecondaryInfoChangeCost

  /** Returns maximum clan tag length. */
  getTagLengthLimit = ::g_clan_type._getTagLengthLimit

  /** Returns true if description change is allowed. */
  isDescriptionChangeAllowed = ::g_clan_type._isDescriptionChangeAllowed

  /** Returns true id announcements is allowed. */
  isAnnouncementAllowed = ::g_clan_type._isAnnouncementAllowed

  /** Checks if specified role (by code) is allowed. */
  isRoleAllowed = ::g_clan_type._isRoleAllowed

  /** Returns name clan type (not some clan name). */
  getTypeName = ::g_clan_type._getTypeName

  /** Returns localized clan type name. */
  getTypeNameLoc = @() ::loc("clan/clan_type/" + ::clan_type_to_string(code))

  /** If clan type creation is allowed. */
  isEnabled = ::g_clan_type._isEnabled

  /**
   * Next type upgrade-wise. Returns UNKNOWN
   * clan type if upgrade is not available.
   */
  getNextType = ::g_clan_type._getNextType

  /** Returns cost of upgrade to next clan type. */
  getNextTypeUpgradeCost = ::g_clan_type._getNextTypeUpgradeCost

  /** Returns true if members upgrade is possible */
  canUpgradeMembers = ::g_clan_type._canUpgradeMembers

  /** Returns cost of members upgrade */
  getMembersUpgradeCost = ::g_clan_type._getMembersUpgradeCost

  /** Returns members upgrade step */
  getMembersUpgradeStep = ::g_clan_type._getMembersUpgradeStep
}

::g_enum_utils.addTypesByGlobalName("g_clan_type", {
  NORMAL = {
    code = ::ECT_NORMAL // 0
    color = "activeTextColor"
    nextTypeCode = ::ECT_UNKNOWN
  }
  BATTALION = {
    code = ::ECT_BATTALION // 1
    color = "battalionSquadronColor"
    nextTypeCode = ::ECT_NORMAL
    minMemberCountToWWar = 10
  }
  UNKNOWN = {
    code = ::ECT_UNKNOWN // -1
    color = "activeTextColor"
    nextTypeCode = ::ECT_UNKNOWN
  }
})

function g_clan_type::getTypeByCode(code)
{
  return ::g_enum_utils.getCachedType("code", code, ::g_clan_type_cache.byCode,
                                       ::g_clan_type, ::g_clan_type.UNKNOWN)
}

function g_clan_type::getTypeByName(typeName)
{
  local code = ::string_to_clan_type(typeName)
  return getTypeByCode(code)
}

function g_clan_type::isUpgradeAllowed(oldType, newType)
{
  return ::clan_is_upgrade_allowed(oldType.code, newType.code)
}

function g_clan_type::getUpgradeCost(oldType, newType)
{
  local blk = ::get_warpoints_blk()
  local cost = ::Cost()
  if (!::clan_get_admin_editor_mode())
  {
    cost.gold = blk[::clan_get_upgrade_gold_cost_param_name(oldType.code, newType.code)] || 0
    cost.wp = blk[::clan_get_upgrade_wp_cost_param_name(oldType.code, newType.code)] || 0
  }
  return cost
}
