function debug_show_all_clan_awards()
{
  if (!::is_dev_version)
    return
  local clanData = ::get_clan_info_table(::debug_get_clan_blk())
  local placeAwardsList = ::g_clans.getClanPlaceRewardLogData(clanData)
  local raitingAwardsList = ::g_clans.getClanRaitingRewardLogData(clanData)
  ::showUnlocksGroupWnd([
    {
      unlocksList = placeAwardsList,
      titleText = "debug_show_all_clan_place_awards"
    },
    {
      unlocksList = raitingAwardsList,
      titleText = "debug_show_all_clan_raiting_awards"
    }
  ])
}

function debug_get_clan_blk()
{
  return ::DataBlock("../prog/scripts/debugData/debugClan.blk")
}
