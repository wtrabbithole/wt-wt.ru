/*
 API:
 static create(config)
   config:
     scene (required) - object where need to create players lists
     teams (required) - list of teams (g_team) to show in separate columns
     room - room to gather members data (null == current SessionLobby room)
     columnsList - list of table columns to show

     onPlayerSelectCb(player) - callback on player select
     onPlayerDblClickCb(player) - callback on player double click
     onPlayerRClickCb(player) = callback on player RClick
*/


class ::gui_handlers.MRoomPlayersListWidget extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/mpLobby/playersList"

  teams = null
  room = null
  columnsList = ["team", "country", "name", "status"]

  onPlayerSelectCb = null
  onPlayerDblClickCb = null
  onPlayerRClickCb = null
  onTablesHoverChange = null

  playersInTeamTables = null
  focusedTeam = ::g_team.ANY
  isTablesInUpdate = false

  static TEAM_TBL_PREFIX = "players_table_"

  static function create(config)
  {
    if (!::getTblValue("teams", config) || !::check_obj(::getTblValue("scene", config)))
    {
      ::dagor.assertf(false, "cant create playersListWidget - no teams or scene")
      return null
    }
    return ::handlersManager.loadHandler(::gui_handlers.MRoomPlayersListWidget, config)
  }

  function getSceneTplView()
  {
    local view = {
      teamsAmount = teams.len()
      teams = []
    }

    local markupData = {
      tr_size = "pw, @baseTrHeight"
      trOnHover = "onPlayerHover"
      columns = {
        name = { width = "fw" }
      }
    }
    local maxRows = ::SessionLobby.getMaxMembersCount(room)
    foreach(idx, team in teams)
    {
      markupData.invert <- idx == 0  && teams.len() == 2
      view.teams.append(
      {
        isFirst = idx == 0
        tableId = getTeamTableId(team)
        content = ::build_mp_table([], markupData, columnsList, maxRows)
      })
    }
    return view
  }

  function initScreen()
  {
    setFullRoomInfo()
    playersInTeamTables = {}
    focusedTeam = teams[0]
    updatePlayersTbl()
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getSelectedPlayer()
  {
    local objTbl = getFocusedTeamTableObj()
    return objTbl && ::getTblValue(objTbl.getValue(), ::getTblValue(focusedTeam, playersInTeamTables))
  }

  function getSelectedRowPos()
  {
    local objTbl = getFocusedTeamTableObj()
    if(!objTbl)
      return null
    local rowNum = objTbl.getValue()
    if (rowNum < 0 || rowNum > objTbl.childrenCount())
      return null
    local rowObj = objTbl.getChild(rowNum)
    local topLeftCorner = rowObj.getPosRC()
    return [topLeftCorner[0], topLeftCorner[1] + rowObj.getSize()[1]]
  }



  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getTeamTableId(team)
  {
    return TEAM_TBL_PREFIX + team.id
  }

  function updatePlayersTbl()
  {
    isTablesInUpdate = true
    local playersList = ::SessionLobby.getMembersInfoList(room)
    foreach(team in teams)
      updateTeamPlayersTbl(team, playersList)
    isTablesInUpdate = false
    onPlayerSelect()
  }

  function updateTeamPlayersTbl(team, playersList)
  {
    local objTbl = scene.findObject(getTeamTableId(team))
    if (!::checkObj(objTbl))
      return

    local totalRows = objTbl.childrenCount()
    local teamList = team == ::g_team.ANY ? playersList
      : ::u.filter(playersList, @(p) p.team.tointeger() == team.code)
    ::set_mp_table(objTbl, teamList, { max_rows = totalRows })
    ::update_team_css_label(objTbl)

    for(local i = 0; i < totalRows; i++)
      objTbl.getChild(i).show(i < teamList.len())
    playersInTeamTables[team] <- teamList

    //update cur value
    if (teamList.len())
    {
      local curValue = objTbl.getValue()
      local validValue = ::clamp(curValue, 0, teamList.len())
      if (curValue != validValue)
        objTbl.setValue(validValue)
    }
  }

  function getFocusedTeamTableObj()
  {
    return getObj(getTeamTableId(focusedTeam))
  }

  function updateFocusedTeamByObj(obj)
  {
    focusedTeam = ::getTblValue(::getObjIdByPrefix(obj, TEAM_TBL_PREFIX), ::g_team, focusedTeam)
  }

  function onTableClick(obj)
  {
    updateFocusedTeamByObj(obj)
    onPlayerSelect()
  }

  function onTableSelect(obj)
  {
    if (isTablesInUpdate)
      return
    updateFocusedTeamByObj(obj)
    onPlayerSelect()
  }

  function onPlayerSelect()
  {
    if (onPlayerSelectCb)
      onPlayerSelectCb(getSelectedPlayer())
  }

  function onTableDblClick()    { if (onPlayerDblClickCb) onPlayerDblClickCb(getSelectedPlayer()) }
  function onTableRClick()      { if (onPlayerRClickCb)   onPlayerRClickCb(getSelectedPlayer()) }
  function onTableHover(obj)    { if (onTablesHoverChange) onTablesHoverChange(obj.id, obj.isHovered()) }

  function onPlayerHover(obj)
  {
    if (!::check_obj(obj) || !obj.isHovered())
      return
    local value = ::to_integer_safe(obj?.rowIdx, -1, false)
    local listObj = obj.getParent()
    if (listObj.getValue() != value && value >= 0 && value < listObj.childrenCount())
      listObj.setValue(value)
  }

  function onEventLobbyMembersChanged(p)
  {
    updatePlayersTbl()
  }

  function onEventLobbyMemberInfoChanged(p)
  {
    updatePlayersTbl()
  }

  function onEventLobbySettingsChange(p)
  {
    updatePlayersTbl()
  }

  function setFullRoomInfo()
  {
    if (!room)
      return
    local fullRoom = ::g_mroom_info.get(room.roomId).getFullRoomData()
    if (fullRoom)
      room = fullRoom
  }

  function onEventMRoomInfoUpdated(p)
  {
    if (room && p.roomId == room.roomId)
    {
      setFullRoomInfo()
      updatePlayersTbl()
    }
  }

  function moveMouse() {
    if (scene.childrenCount() > 0)
      ::move_mouse_on_child(scene.getChild(0), 0)
  }
}