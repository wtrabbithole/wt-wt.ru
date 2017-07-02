class ::WwOperationModel
{
  armies = null

  function constructor()
  {
    armies = ::WwOperationArmies()
  }

  function update()
  {
    armies.statusUpdate()
  }
}