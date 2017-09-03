::tribunal <- {
  maxComplaintCount = 10
  minComplaintCount = 5
  complainReasons = ["FOUL", "ABUSE", "TEAMKILL", "SPAM"]
  maxDaysToCheckComplains = 10

  maxComplaintsFromMe = 5

  complaintsData = null
  lastDaySaveParam = "tribunalLastCheckDay"

  function init()
  {
    local sBlk = ::get_game_settings_blk()
    local blk = sBlk && sBlk.tribunal
    if (!blk)
      return

    foreach(p in ["maxComplaintCount", "minComplaintCount", "maxDaysToCheckComplains", "maxComplaintsFromMe"])
      if (blk[p] != null)
        ::tribunal[p] = blk[p]
  }

  function checkComplaintCounts()
  {
    if (!::has_feature("Tribunal"))
      return

    ::tribunal.complaintsData = get_player_complaint_counts()
    local isNeedComplaintNotify = ::getTblValue("is_need_complaint_notify", ::tribunal.complaintsData)
    if (isNeedComplaintNotify)
    {
      ::tribunal.showComplaintMessageBox(::tribunal.complaintsData)
    }
  }

  function canComplaint()
  {
    if (!::has_feature("Tribunal"))
      return true

    ::tribunal.complaintsData = get_player_complaint_counts()
    if (complaintsData && complaintsData.complaint_count_own >= maxComplaintsFromMe)
    {
      local text = ::format(::loc("charServer/complaintsLimitExpired"), maxComplaintsFromMe)
      ::showInfoMsgBox(text, "tribunal_msg_box")
      return false
    }
    return true
  }

  function showComplaintMessageBox(data)
  {
    if (!data)
      return

    local complaintsToMe = ::getTblValue("complaint_count_other", data)
    if (!complaintsToMe)
      return

    local complaintsCount = 0
    local textReasons = ""
    foreach(reason in complainReasons)
    {
      local count = ::getTblValue(reason, complaintsToMe, 0)
      if (!count)
        continue

      complaintsCount += count
      textReasons += ::loc("charServer/ban/reason/" + reason) + "\n"
    }

    local text = ""
    if (complaintsCount < maxComplaintCount)
      text = ::loc("charServer/complaintToYou")
    else
      text = ::loc("charServer/complaintToYouMoreThen")

    text = ::format(text, min(complaintsCount, maxComplaintCount))

    text += "\n" + textReasons
    ::showInfoMsgBox(text, "tribunal_msg_box")
  }
}
