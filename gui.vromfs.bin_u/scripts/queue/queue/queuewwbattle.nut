class ::queue_classes.WwBattle extends ::queue_classes.Base
{
  function init()
  {
    name = ::getTblValue("operationId", params, "") + "_" + ::getTblValue("battleId", params, "")
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
}