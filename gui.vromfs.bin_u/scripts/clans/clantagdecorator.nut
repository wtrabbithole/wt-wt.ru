::g_clan_tag_decorator <- {


  function getDecorators(args)
  {
    local decoratorsList = []

    if ("clanType" in args)
      decoratorsList.extend(getDecoratorsForClanType(args.clanType))

    if ("rewardsList" in args)
      decoratorsList.extend(getDecoratorsForClanDuelRewards(args.rewardsList))

    return decoratorsList
  }


  function getDecoratorsForClanType(clanType)
  {
    local blk = ::get_warpoints_blk()
    local block = blk[::clan_get_decorators_block_name(clanType.code)]

    return getDecoratorsInternal(block)
  }


  function getDecoratorsForClanDuelRewards(rewardsList)
  {
    local blk = ::get_warpoints_blk()
    local result = []

    if (!blk.regaliaTagDecorators)
      return result

    blk = blk.regaliaTagDecorators

    local decoratorLists = []
    foreach (reward in rewardsList)
      decoratorLists.append(getDecoratorsInternal(blk[reward], true))
    decoratorLists.sort(@(a, b) b.len() <=> a.len())

    foreach (list in decoratorLists)
      foreach (decorator in list)
        if (!::u.search(result, @(d) d.id == decorator.id))
          result.append(decorator)

    return result
  }


  /**
   * Return array of ClanTagDecorator's
   * @deocratorsBlk - datablock in format:
   * {
   *   decor:t='<start><end>'; //start and end have equal lenght
   *
   *   ...
   * }
   */
  function getDecoratorsInternal(decoratorsBlk, free = false)
  {
    local decorators = []

    if (decoratorsBlk != null)
      foreach (decoratorString in decoratorsBlk % "decor")
        decorators.push(ClanTagDecorator(decoratorString, free))

    return decorators
  }
}


class ClanTagDecorator
{
  id = null
  start = null
  end = null
  free = false

  constructor(decoratorString, freeChange)
  {
    local halfLength = (0.5 * decoratorString.len()).tointeger()
    id = decoratorString
    start = decoratorString.slice(0, halfLength)
    end = decoratorString.slice(halfLength)
    free = freeChange
  }

  function checkTagText(tagText)
  {
    if (tagText.find(start) != 0 || tagText.len() < end.len())
      return false
    return tagText.slice(-end.len()) == end
  }
}
