class ::queue_classes.WwBattle extends ::queue_classes.Base
{
  function init()
  {
    name = getName(params)
  }

  function join(successCallback, errorCallback)
  {
    ::request_matching(
      "worldwar.join_battle",
      successCallback,
      errorCallback,
      params
    )
  }

  function leave(successCallback, errorCallback, needShowError = false)
  {
    leaveAll(successCallback, errorCallback, needShowError)
  }

  static function leaveAll(successCallback, errorCallback, needShowError = false)
  {
    ::request_matching(
      "worldwar.leave_battle",
      successCallback,
      errorCallback,
      null,
      { showError = needShowError }
    )
  }

  static function getName(params)
  {
    return ::getTblValue("operationId", params, "") + "_" + ::getTblValue("battleId", params, "")
  }

  static function getWWBattle()
  {
    local battleId = params?.battleId
    if (!battleId)
      return null

    return ::g_world_war.getBattleById(battleId)
  }
}