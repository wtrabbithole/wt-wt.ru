::shop_gui_handler <- null
::last_shop_unit_type <- null

/*
shopData = [
  { name = "country_japan"
    pages = [
      { name = "type_fighter"
        airList - table readed from blk need to generate a tree. remove after tree generation
                  [[{air, reqAir}, ...], ...]
        tree = [
          [1, "",    "la5", ...]  //rank, range1 aircraft, range2 aircraft, ...
          [1, "la6", "",    ...]
        ]
        lines = [ { air, line }, ...]
      }
      ...
    ]
  }
  ...
]
*/

function after_buy_aircraft_modal()
{
  foreach(handler in [::top_menu_handler, ::current_base_gui_handler])
    if (handler && "afterBuyAircraftModal" in handler)
      handler.afterBuyAircraftModal.call(handler)
}

function is_shop_loaded()
{
  return ::handlersManager.isHandlerValid(::shop_gui_handler)
}

function gui_start_shop(sceneObj=null)
{
  if (::is_shop_loaded())
    return

  ::shop_gui_handler = ::handlersManager.loadHandler(::gui_handlers.ShopMenuHandler, { scene = sceneObj })
  return ::shop_gui_handler
}

function gui_start_shop_research(config)
{
  ::gui_start_modal_wnd(::gui_handlers.ShopCheckResearch, config)
}

class ::gui_handlers.ShopMenuHandler extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/shop/shopInclude.blk"
  sceneNavBlkName = "gui/shop/shopNav.blk"
  keepLoaded = true
  boughtVehiclesCount = null
  totalVehiclesCount = null

  curCountry = null
  curPage = ""
  curAirName = ""
  curPageGroups = null
  groupChooseObj = null
  skipOpenGroup = true
  repairAllCost = 0
  availableFlushExp = 0
  brokenList = null
  _timer = 0.0

  shopData = null
  slotbarActions = [ "research", "buy", "take", "weapons", "showroom", "rankinfo", "testflight", "crew", "info", "repair" ]
  actionsPrefix = "on"
  needUpdateSlotbar = false
  needUpdateSquadInfo = false
  shopResearchMode = false
  setResearchManually = true
  lastPurchase = null

  showModeList = null
  curDiffCode = -1

  navBarObj = null
  navBarGroupObj = null

  unitActionsListTimer = null

  function initScreen()
  {
    if (!curAirName.len())
    {
      curCountry = ::get_profile_info().country
      local unit = ::getAircraftByName(::hangar_get_current_unit_name())
      if (unit && unit.shopCountry == curCountry)
        curAirName = unit.name
    }

    skipOpenGroup = true

    scene.findObject("shop_timer").setUserData(this)
    brokenList = []

    navBarObj = scene.findObject("nav-help")

    initShowMode(navBarObj)
    loadFullAircraftsTable(curAirName)

    selectSlotbarCountry() //select slotbarcountry will call fillAircraftsList
    skipOpenGroup = false
  }

  function isSceneActive()
  {
    return base.isSceneActive()
           && (wndType != handlerType.CUSTOM || ::top_menu_shop_active)
  }

  function getMainFocusObj()
  {
    return scene.findObject("shop_items_list")
  }

  function getMainFocusObj2()
  {
    return scene.findObject("show_mode")
  }

  function loadFullAircraftsTable(selAirName = "")
  {
    shopData = []

    local blk = ::get_shop_blk()

    local totalCountries = blk.blockCount()
    local selAir = getAircraftByName(selAirName)
    local selAirCountry = ::getUnitCountry(selAir)
    local selAirType = ::get_es_unit_type(selAir)
    for(local c = 0; c < totalCountries; c++)  //country
    {
      local cblk = blk.getBlock(c)
      local countryData = {
        name = cblk.getBlockName()
        pages = []
      }

      if (selAir && selAir.shopCountry == countryData.name)
        curCountry = countryData.name

      local totalPages = cblk.blockCount()
      for(local p = 0; p < totalPages; p++)
      {
        local pblk = cblk.getBlock(p)
        local pageData = {
          name = pblk.getBlockName()
          airList = []
          tree = null
          lines = []
        }
        local selected = false

        local totalRanges = pblk.blockCount()
        for(local r = 0; r < totalRanges; r++)
        {
          local rblk = pblk.getBlock(r)
          local rangeData = []
          local totalAirs = rblk.blockCount()

          for(local a = 0; a < totalAirs; a++)
          {
            local airBlk = rblk.getBlock(a)
            local airData = { name = airBlk.getBlockName() }
            local air = getAircraftByName(airBlk.getBlockName())
            if (air)
            {
              selected = selected || (::get_es_unit_type(air) == selAirType && ::getUnitCountry(air) == selAirCountry)

              if (!checkUnitShowInShop(air))
                continue

              airData.air <- air
              air.rank <- airBlk.rank ? airBlk.rank : 0
              airData.rank <- air.rank
            }
            else  //aircraft group
            {
              airData.airsGroup <- []
              local groupTotal = airBlk.blockCount()
              for(local ga = 0; ga < groupTotal; ga++)
              {
                local gAirBlk = airBlk.getBlock(ga)
                air = getAircraftByName(gAirBlk.getBlockName())
                if (!checkUnitShowInShop(air))
                  continue
                air.rank <- gAirBlk.rank? gAirBlk.rank : 0
                if (!("rank" in airData))
                  airData.rank <- air.rank
                air.group <- airData.name
                airData.airsGroup.append(air)
                selected = selected || (::get_es_unit_type(air) == selAirType && ::getUnitCountry(air) == selAirCountry)
              }
              if (airData.airsGroup.len()==0)
                continue

              airData.image <- airBlk.image
            }
            if (airBlk.reqAir!=null) airData.reqAir <- airBlk.reqAir
              rangeData.append(airData)
          }
          if (rangeData.len() > 0)
            pageData.airList.append(rangeData)
        }
        if (selected)
        {
          curCountry = countryData.name
          curPage = pageData.name
        }

        if (pageData.airList.len() > 0)
          countryData.pages.append(pageData)
      }
      if (countryData.pages.len() > 0)
        shopData.append(countryData)
    }
  }

  function checkUnitShowInShop(unit)
  {
    if (unit == null)
      return false
    if (::isTank(unit) && !::check_feature_tanks())
      return false
    if (!::checkUnitHideFeature(unit))
      return false
    return ::is_unit_visible_in_shop(unit)
  }

  function getReqAirPosInArray(reqName, arr)
  {
    foreach(r, row in arr)
      foreach(c, item in row)
        if (item && typeof item != "integer" && reqName == item.name)
          return [r, c]
    return null
  }

  //returns an array of positions of each rank in page and each vertical section in page
  function calculateRanksAndSectionsPos(page)
  {
    local res = array(::max_country_rank + 1, 0)

    local sectionsPos = page.airList.len() ? [0, page.airList.len()] : [ 0 ]
    local foundPremium = false

    for (local range = 0; range < page.airList.len(); range++)
    {
      local rangeRanks = array(::max_country_rank + 1, 0)
      local branches = getBranchesTbl(page.airList[range])

      foreach(branch in branches)
      {
        foreach(airItem in branch)
          rangeRanks[airItem.rank]++
        foreach(rankNum, rank in rangeRanks)
          if (res[rankNum] < rank)
            res[rankNum] = rank

        if (!foundPremium)
          foreach(airItem in branch)
            if (("air" in airItem) && (::isUnitSpecial(airItem.air) || ::isUnitGift(airItem.air)))
            {
              if (range)
                sectionsPos.insert(1, range)
              foundPremium = true
              break
            }
      }
    }
    //summ absolute height fr each rank
    for (local i = res.len() - 1; i >= 0; i--)
    {
      local rankStartPos = 0
      local j = 0
      while (j <= i)
      {
        rankStartPos += res[j]
        j++
      }
      res[i] = rankStartPos
    }

    local sectionsResearchable = array(sectionsPos.len() - 1, true)
    if (foundPremium && sectionsResearchable.len())
      sectionsResearchable[sectionsResearchable.len() - 1] = false

    return {
      ranksHeight = res
      sectionsPos = sectionsPos
      sectionsResearchable = sectionsResearchable
    }
  }

  function generateTreeData(page)
  {
    if (page.tree != null) //already generated
      return page

    page.lines = []
    page.tree = []

    if (!("airList" in page) || !page.airList)
      return page

    local ranksAndSections = calculateRanksAndSectionsPos(page)
    page.ranksHeight <- ranksAndSections.ranksHeight
    page.sectionsPos <- ranksAndSections.sectionsPos
    page.sectionsResearchable <- ranksAndSections.sectionsResearchable
    local treeSize = page.ranksHeight[page.ranksHeight.len() - 1]
    page.tree.resize(treeSize, null)
    foreach(idx, ar in page.tree)
      page.tree[idx] = []

    for (local range = 0; range < page.airList.len(); range++)
    {
      local rangeData = page.airList[range]
      local branches = getBranchesTbl(rangeData)
      local rangeTree = array(treeSize, null)
      foreach(idx, ar in rangeTree)
        rangeTree[idx] = []

      foreach(bIdx, branch in branches)
      {
        local headPos = null
        if (bIdx != 0 && ("reqAir" in branch[0]))
          headPos = getReqAirPosInArray(branch[0].reqAir, rangeTree)
        local config = makeTblByBranch(branch, page.ranksHeight, headPos ? headPos[0] : null)
          //config.offset, config.tbl
        local firstCol = getGoodBranchPos(rangeTree, config.tbl, config.offset, headPos)

        //merge branch to tree
        local treeWidth = 0
        foreach(item in config.tbl)
          if (treeWidth < firstCol + item.len())
            treeWidth = firstCol + item.len()
        if (treeWidth < rangeTree[0].len())
          treeWidth = rangeTree[0].len()

        for(local i = 0; i < rangeTree.len(); i++)
        {
          if (rangeTree[i].len() < treeWidth)
            rangeTree[i].resize(treeWidth, null)

          local addRowIdx = i - config.offset
          if (addRowIdx in config.tbl)
          {
            local addRow = config.tbl[addRowIdx]
            foreach(j, item in addRow)
              if (item != null)
              {
                if (rangeTree[i][j + firstCol] != null)
                  dagor.debug("GP: try to fill not empty cell!!!!! ")
                rangeTree[i][j + firstCol] = item
              }
          }
        }
        //branch merged
      }

      //merge rangesTbl into tree and fill range lines
      foreach(r, row in page.tree)
        page.tree[r].extend(rangeTree[r])
    }

    //clear empty last lines
    local emptyLine = true
    for(local idx = page.tree.len() - 1; idx > 0; idx--)
    {
      foreach(i, air in page.tree[idx])
        if (air)
        {
          emptyLine = false
          break
        }
      if (emptyLine)
        page.tree.remove(idx)
      else
        break
    }
/*
    //debug
    local testText = "GP: full table:"
    foreach(row in page.tree)
      foreach(idx, item in row)
      {
        testText += ((idx==0)? "\n":"")
        if (item==null)
          testText+=" "
        else
        if (typeof(item)=="integer") testText += "."
        else testText += "A"
      }
    dagor.debug(testText + "\n done.")
*/
    //fill Lines and clear table
    fillLinesInPage(page)

    page.rawdelete("airList")
    return page
  }

  function fillLinesInPage(page, first = true, reqAirs=null)
  {
    if (!reqAirs)
      reqAirs = {} //airName = [{ air, pos }]

    for(local i = page.tree.len() - 1; i >= 0; i--)
      for(local j = page.tree[i].len() - 1; j >= 0; j--)
      {
        if(page.tree[i][j] == null)
          continue
        if(typeof(page.tree[i][j]) == "integer")
          page.tree[i][j] = null
        else
        {
          local air = page.tree[i][j]
          if (air.name in reqAirs)
          {
            foreach(req in reqAirs[air.name])
              page.lines.append({
                air = req.air,
                line = [i, j, req.pos[0], req.pos[1]]
                group = [::isUnitGroup(air), ::isUnitGroup(req.air)]
              })
            reqAirs.rawdelete(air.name)
          }
          if (first && "shopReqName" in air)
            if (air.shopReqName in reqAirs)
              reqAirs[air.shopReqName].append({ air = air, pos = [i,j] })
            else
              reqAirs[air.shopReqName] <- [{ air = air, pos = [i,j] }]
        }
      }
    if (reqAirs.len() > 0 && first)
      fillLinesInPage(page, false, reqAirs)
  }

  function getGoodBranchPos(tree, branch, offset, headerPos)
  {
    //branch.
    if (headerPos)
    {
      if (checkBranchPos(tree, branch, headerPos[0], headerPos[1]))
        return headerPos[1]  //best place for header

      local colOffset = 0
      local pos = 0
      do
      {
        colOffset = -colOffset + ((colOffset<=0)? 1 : 0)
        pos = colOffset + headerPos[1]
        if ((pos in tree[0]) && checkBranchPos(tree, branch, offset, pos))
          return pos
      } while (pos < tree[0].len())
    }
    else
      for(local col=0; col<tree[0].len(); col++)
        if (checkBranchPos(tree, branch, offset, col))
          return col
    return tree[0].len()
  }

  function checkBranchPos(tree, branch, row, col)
  {
    for(local i = 0; i < branch.len(); i++)
    {
      local max = branch[i].len()
      if (max > tree[i+row].len() - col)
        max = tree[i+row].len()-col
      for(local j = 0; j < max; j++)
        if (tree[i+row][j+col] != null && branch[i][j] != null)
          return false
    }
    return true
  }

  function makeTblByBranch(branch, ranksHeight, headRow = null)
  {
    if (branch.len() < 1)
      return null

    local res = {
      offset = (headRow != null) ? headRow : 0/*branch[0].air.rank //for rowIdx==rank*/
      tbl = []
    }
    //if (headRow!=null)
    //  res.tbl.append([null])  //place for headAir in rowIdx==rank generation

    local prevAir = null
    local tblWidth = 0
    foreach(idx, item in branch)
    {
      local reqName = null
      local curAir = ::isUnitGroup(item) ? item : item.air
      local reqGroup = false
      if ("reqAir" in item)
        prevAir = getAircraftByName(item.reqAir)
      if (prevAir)
      {
        if (::isUnitGroup(prevAir))
          reqGroup = true
        curAir.shopReqName <- prevAir.name
        curAir.isReqGroup <- reqGroup
      }

      //Line branch generation
      if (ranksHeight[curAir.rank - 1] > res.tbl.len())
        res.tbl.resize(ranksHeight[curAir.rank - 1], [])
      res.tbl.append([curAir])
      prevAir = curAir

      //Branch generation by row==rank
      /*local row = ((item.rank <= ::max_country_rank) ? item.rank : ::max_country_rank)
      row -= res.offset
      if (row < 0)
        row = 0
      if (res.tbl.len() > row)
      {
        if (idx == 0 && row == 0)
          res.tbl[0][0] = curAir
        else
          res.tbl[row].append(curAir)
      }
      else
        for(local i = res.tbl.len(); i <= row; i++)
          res.tbl.append([(i == row)? curAir : 1]) //integer mean line
      if (res.tbl[row].len() > tblWidth)
        tblWidth = res.tbl[row].len()
      */
    }

    /* //Offset for wide branches  (like in generation rowIdx==rank)
    local lastOffset = 0
    for(local i=res.tbl.len()-1; i>=0; i--)
    {
      local row = res.tbl[i]
      local offset = (0.5*(tblWidth-row.len())+0.5*(1-row.len()%2)).tointeger()
      if (row.len()==1 && row[0]!=null && typeof(row[0])=="integer")
        offset=lastOffset

      for(local j=0; j<offset; j++)
        row.insert(0, null)
      lastOffset = offset
    }
    res.tbl[0].resize(tblWidth, null)
    */
    return res
  }

  function getBranchesTbl(rangeData)
  {
    local branches = []

    if (rangeData.len() < 2)
      return [rangeData]

    local addCount = {}
    local brIdxTbl = {}
    local rankK = 0.0 //the longer the tree is more important than a branched

    local maxCountId = rangeData.len() - 1
    for(local i = rangeData.len() - 1; i >= 0; i--)
    {
      local item = rangeData[i]
      item.childs <- 0
      item.used <- false
      item.header <- i == 0
      if ((i<rangeData.len() - 1) && !("reqAir" in rangeData[i + 1]))
        item.childs += rangeData[i + 1].childs + (1 + rankK * rangeData[i + 1].rank)
      if (item.name in addCount)
        item.childs += addCount.rawdelete(item.name)
      if ("reqAir" in item)
        if (item.reqAir == "")
          item.header = true
        else
        {
          addCount[item.reqAir] <- item.childs + (1 + rankK*item.rank) + ((item.reqAir in addCount) ? addCount[item.reqAir] : 0)
          if (item.reqAir in brIdxTbl)
            brIdxTbl[item.reqAir].append(i)
          else
            brIdxTbl[item.reqAir] <- [i]
        }

      if (item.childs > rangeData[maxCountId].childs)
        maxCountId = i
    }

    appendBranches(rangeData, maxCountId, branches, brIdxTbl)
    for(local i = rangeData.len() - 1; i >= 0; i--)
      if (rangeData[i].header)
        appendBranches(rangeData, i, branches, brIdxTbl)
/*
    //test debug!
    local test = "GP: branches:"
    foreach(b in branches)
      foreach(idx, item in b)
        test += ((idx==0)? "\n" : ", ") + item.air.name + " ("+item.air.rank+","+item.childs+")"
                 + (("reqAir" in item)? "("+item.reqAir+")":"")
    dagor.debug(test)
*/
    return branches
  }

  function appendBranches(rangeData, headIdx, branches, brIdxTbl, prevItem=null)
  {
    if (rangeData[headIdx].used)
      return

    if (prevItem!=null)
      rangeData[headIdx].reqAir <- prevItem.name

    local headers = []
    local curBranch = []
    local idx = headIdx
    do {
      local item = rangeData[idx]
      item.used = true
      curBranch.append(item)

      local next = (item.name in brIdxTbl)? brIdxTbl[item.name] : []
      if (idx < rangeData.len()-1 && !("reqAir" in rangeData[idx+1]))
        next.append(idx+1)
      if (next.len()==0)
        idx=-1
      else if (rangeData[next[0]].used)
        ::dagor.fatal("Cycled requirements in shop!!!  look at " + rangeData[next[0]].name)
      else if (next.len()==1)
          idx=next[0]
      else
      {
        idx = next[next.len()-1]
        for(local i=next.len()-2; i>=0; i--)
          if (rangeData[next[i]].childs > rangeData[idx].childs
              || (rangeData[next[i]].childs == rangeData[idx].childs && rangeData[next[i]].rank > rangeData[idx].rank))
            idx = next[i]
        foreach(id in next)
          if (id!=idx)
            headers.append({prevItem = item, id=id})
      }
    } while (idx >= 0)

    if (branches.len()>0 && curBranch.len()==1
        && (!("reqAir" in curBranch[0]) || curBranch[0].reqAir==""))
    {  //for line branch generation. NoReq aircrafts extends previous branch.
      local placeFound = false
      foreach(bIdx, bItem in branches[branches.len()-1])
        if (("reqAir" in bItem) && bItem.reqAir=="" && bItem.rank >= curBranch[0].rank)
        {
          branches[branches.len()-1].insert(bIdx, curBranch[0])
          placeFound = true
          break
        }
      if (!placeFound)
        branches[branches.len()-1].extend(curBranch)
    } else
      branches.append(curBranch)
    for(local h=headers.len()-1; h>=0; h--)
      appendBranches(rangeData, headers[h].id, branches, brIdxTbl, headers[h].prevItem)
  }

  function getCurTreeData()
  {
    foreach(cData in shopData)
      if (cData.name == curCountry)
      {
        foreach(pageData in cData.pages)
          if (pageData.name == curPage)
            return generateTreeData(pageData)
        if (cData.pages.len()>0)
        {
          curPage = cData.pages[0].name
          return generateTreeData(cData.pages[0])
        }
      }

    curCountry = shopData[0].name
    curPage = shopData[0].pages[0].name
    return generateTreeData(shopData[0].pages[0])
  }

  function countFullRepairCost()
  {
    repairAllCost = 0
    foreach(cData in shopData)
      if (cData.name == curCountry)
        foreach(pageData in cData.pages)
        {
          local treeData = generateTreeData(pageData)
          foreach(rowArr in treeData.tree)
            for(local col = 0; col < rowArr.len(); col++)
              if (rowArr[col])
              {
                local air = rowArr[col]
                if (::isUnitGroup(air))
                {
                  foreach(gAir in air.airsGroup)
                    if (gAir.isUsable() && ::shop_get_aircraft_hp(gAir.name) < 1.0)
                    repairAllCost += ::wp_get_repair_cost(gAir.name)
                }
                else if (air.isUsable() && ::shop_get_aircraft_hp(air.name) < 1.0)
                  repairAllCost += ::wp_get_repair_cost(air.name)
              }
        }
  }

  function getItemStatusData(item, checkAir="")
  {
    local res = {
      shopReq = checkAirShopReq(item)
      own = true
      partOwn = false
      broken = false
      checkAir = checkAir == item.name
    }

    if (::isUnitGroup(item))
    {
      foreach(air in item.airsGroup)
      {
        local isOwn = ::isUnitBought(air)
        res.own = res.own && isOwn
        res.partOwn = res.partOwn || isOwn
        res.broken = res.broken || ::isUnitBroken(air)
        res.checkAir = res.checkAir || checkAir == air.name
      }
    }
    else
    {
      res.own = ::isUnitBought(item)
      res.partOwn = res.own
      res.broken = ::isUnitBroken(item)
    }
    return res
  }

  function fillAircraftsList(curName = "")
  {
    if (!::checkObj(scene))
      return
    local tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return

    updateBoughtVehiclesCount()
    ::last_shop_unit_type = getCurPageUnitType()
    ::update_gamercards()

    if (curName=="")
      curName = curAirName

    local curRow = -1
    local curCol = -1

    local data = ""
    local treeData = getCurTreeData()
    local unitItems = []
    brokenList = []

    fillBGLines(treeData)
    guiScene.setUpdatesEnabled(false, false);
    foreach(row, rowArr in treeData.tree)
    {
      local rowData = ""
      for(local col = 0; col < rowArr.len(); col++)
        if (!rowArr[col])
          rowData += "td { inactive:t='yes' } "
        else
        {
          local item = rowArr[col]
          local config = getItemStatusData(item, curName)
          if (config.checkAir || (curRow < 0))
          {
            curRow = row
            curCol = col
          }
          if (config.broken)
            brokenList.append(item)
          local params = getUnitItemParams(item)
          rowData += ::build_aircraft_item(item.name, item, params)
          unitItems.append({ id = item.name, unit = item, params = params })
        }
      data += format("tr { %s }\n", rowData)
    }
    guiScene.replaceContentFromText(tableObj, data, data.len(), this)
    foreach (unitItem in unitItems)
    {
      local obj = tableObj.findObject(unitItem.id)
      local unit = ::isUnitGroup(unitItem.unit) ? ::getAircraftByName(obj.primaryUnitId) : unitItem.unit
      ::fill_unit_item_timers(obj, unit, unitItem.params)
    }

    updateDiscountIcons()

    guiScene.setUpdatesEnabled(true, true)
    ::gui_bhv.columnNavigator.selectCell(tableObj, curRow, curCol, false)

    updateButtons()
  }

  function updateDiscountIcons()
  {
    if (!::checkObj(scene))
      return

    local tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return

    local treeData = getCurTreeData()
    foreach (row, rowArr in treeData.tree)
      for (local col = 0; col < rowArr.len(); col++)
      {
        local air = rowArr[col]
        if (!air)
          continue

        ::showUnitDiscount(tableObj.findObject(air.name+"-discount"), air)

        local bonusData = air.name
        if (::isUnitGroup(air))
          bonusData = ::u.map(air.airsGroup, function(unit) { return unit.name })
        ::showAirExpWpBonus(tableObj.findObject(air.name+"-bonus"), bonusData)
      }
  }

  function onEventDiscountsDataUpdated(params = {})
  {
    updateDiscountIconsOnTabs()
    updateDiscountIcons()
    updateDiscountSlotsPriceText()
  }

  function updateDiscountSlotsPriceText()
  {
    local tableObj = scene.findObject("shop_items_list")
    local treeData = getCurTreeData()
    foreach (row, rowArr in treeData.tree)
    {
      local units = ::u.filter(rowArr, function (item) { return item && !::isUnitGroup(item) })
      foreach (unit in units)
      {
        local params = getUnitItemParams(unit)
        local priceText = ::get_unit_item_price_text(unit, params)
        local shopAirObj = tableObj.findObject(unit.name)
        if (::checkObj(shopAirObj))
        {
          local priceObj = shopAirObj.findObject("bottom_item_price_text")
          if (::checkObj(priceObj))
            priceObj.setValue(priceText)
        }
      }
    }
  }

  function updateButtons()
  {
    updateRepairAllButton()
  }

  function showNavButton(id, show)
  {
    ::showBtn(id, show, navBarObj)
    if (::checkObj(navBarGroupObj))
      ::showBtn(id, show, navBarGroupObj)
  }

  function updateRepairAllButton()
  {
    if (brokenList.len() > 0)
      countFullRepairCost()

    local show = brokenList.len() > 0 && repairAllCost > 0
    showNavButton("btn_repairall", show)
    if (!show)
      return

    local locText = ::loc("mainmenu/btnRepairAll")
    ::placePriceTextToButton(navBarObj, "btn_repairall", locText, repairAllCost)
    ::placePriceTextToButton(navBarGroupObj, "btn_repairall", locText, repairAllCost)
  }

  function onEventOnlineShopPurchaseSuccessful(params)
  {
    doWhenActiveOnce("fillAircraftsList")
  }

  function onEventSlotbarPresetLoaded(p)
  {
    doWhenActiveOnce("fillAircraftsList")
  }

  function onUpdate(obj, dt)
  {
    _timer -= dt
    if (_timer > 0)
      return
    _timer += 1.0

    checkBrokenUnitsAndUpdateThem()
    updateRepairAllButton()
  }

  function checkBrokenUnitsAndUpdateThem()
  {
    for(local i = brokenList.len() - 1; i >= 0; i--)
    {
      if (i >= brokenList.len()) //update unit item is not instant, so broken list can change at that time by other events
        continue

      local unit = brokenList[i]
      if (checkBrokenListStatus(unit))
        checkUnitItemAndUpdate(unit)
    }
  }

  function getLineStatus(air)
  {
    local config = getItemStatusData(air)

    if (config.own || config.partOwn)
      return "owned"
    else if (!config.shopReq)
      return "locked"
    return ""
  }
/*
  function findAircraftPos(tree, airName)
  {
    for(local row = 0; row < tree.len(); row++)
      for(local col = 0; col < tree[row].len() - 1; col++)
        if (tree[row][col+1] && (tree[row][col+1].name == airName))
          return [row, col]
    return null
  }
*/

  function createLine(r0, c0, r1, c1, status)
  {
    local lines = ""
    local arrowFormat = "shopArrow { type:t='%s'; size:t='%s, %s'; pos:t='%s, %s'; shopStat:t='" + status + "' } "
    local pad1 = "1@lines_pad"
    local pad2 = "1@lines_pad"

    if (c0 == c1)
    {//vertical
      lines += format(arrowFormat,
                 "vertical", //type
                 "1@modArrowWidth", //width
                 pad1 + " + " + pad2 + " + " + (r1 - r0 - 1) + "@shop_height", //height
                 (c0 + 0.5) + "@shop_width - 0.5@modArrowWidth", //posX
                 (r0 + 1) + "@shop_height - " + pad1 //posY
                )
    }
    else if (r0==r1)
    {//horizontal
      local interval1 = "1@lines_shop_interval"
      local interval2 = "1@lines_shop_interval"
      lines += format(arrowFormat,
                 "horizontal",  //type
                 (c1 - c0 - 1) + "@shop_width + " + interval1 + " + " + interval2, //width
                 "1@modArrowWidth", //height
                 (c0 + 1) + "@shop_width - " + interval1, //posX
                 (r0 + 0.5) + "@shop_height - 0.5@modArrowWidth" // posY
                )
    }
    else
    {//double
      local lh = 0
      local lineFormat = "shopLine { size:t='%s, %s'; pos:t='%s, %s'; shopStat:t='" + status + "' } "
      lines += format(lineFormat,
                       "2",
                       pad1 + " + " + lh + "@shop_height+1",
                       (c0 + 0.5) + "@shop_width",
                       (r0 + 1) + "@shop_height - " + pad1
                      )
      lines += format(lineFormat,
                      abs(c1-c0) + "@shop_width-2",
                      "2",
                      (0.5*(c0 + c1 + 1)) + "@shop_width - 50%w + 1",
                      (lh + r0 + 1) + "@shop_height-1")
      lines += format(lineFormat,
                      "2",
                      pad2 + " + " + (r1 - r0 - 1 - lh) + "@shop_height+1",
                      (c1 + 0.5) + "@shop_width",
                      (lh + r0 + 1) + "@shop_height-1")
    }

    return lines
  }

  function fillBGLines(treeData)
  {
    guiScene.setUpdatesEnabled(false, false)
    generateHeaders(treeData)
    generateBGPlates(treeData)
    generateTierArrows(treeData)
    generateAirAddictiveArrows(treeData)
    guiScene.setUpdatesEnabled(true, true)

    local contentWidth = scene.findObject("shopTable_air_rows").getSize()[0]
    local containerWidth = scene.findObject("shop_useful_width").getSize()[0]
    local pos = (contentWidth >= containerWidth)? "0" : "(pw-w)/2"
    scene.findObject("shop_items_pos_div").left = pos
  }

  function generateAirAddictiveArrows(treeData)
  {
    local tblBgObj = scene.findObject("shopTable_air_rows")
    local data = ""
    foreach(lc in treeData.lines)
    {
      fillAirReq(lc.air)
      data += createLine(lc.line[0], lc.line[1], lc.line[2], lc.line[3], getLineStatus(lc.air))
    }

    foreach(row, rowArr in treeData.tree) //check groups even they dont have requirements
      for(local col = 0; col < rowArr.len(); col++)
        if (::isUnitGroup(rowArr[col]))
          fillAirReq(rowArr[col])

    guiScene.replaceContentFromText(tblBgObj, data, data.len(), this)

    tblBgObj.width = treeData.tree[0].len() + "@shop_width"
  }

  function generateHeaders(treeData)
  {
    local obj = scene.findObject("tree_header_div")
    local data = ""
    local treeHeaderFormat = "modBlockHeader { text { text:t='%s'; width:t='pw'; top:t='ph/2-h/2' text-align:t='center'; position:t='absolute' } pos:t='%s, %s'; width:t='%s' } "

    local sectionsTotal = treeData.sectionsPos.len() - 1
    local totalWidth = guiScene.calcString("1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize", null)
    local itemWidth = guiScene.calcString("@shop_width", null)
    local extraW = "+" + ::max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2

    for (local s = 0; s < sectionsTotal; s++)
    {
      local isLeft = s == 0
      local isRight = s == sectionsTotal - 1

      local x = treeData.sectionsPos[s] + "@shop_width" + (isLeft ? "" : extraW) + "+1@modBlockTierNumHeight"
      local w = (treeData.sectionsPos[s + 1] - treeData.sectionsPos[s]) + "@shop_width" + (isLeft ? extraW : "") + (isRight ? extraW : "")

      local isResearchable = ::getTblValue(s, treeData.sectionsResearchable)
      local title = isResearchable ? "#shop/section/researchable" : "#shop/section/premium"
      data += ::format(treeHeaderFormat, title, x, "0", w)
    }
    data += "modBlockHeader { width:t='1@modBlockTierNumHeight' } "

    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function generateBGPlates(treeData)
  {
    local tblBgObj = scene.findObject("shopTable_air_plates")
    local data = ""
    local plateFormat = "shopRow {id:t='shop_tier_%s'; type:t='%s'; pos:t='%s, %s'; size:t='%s, %s'; tooltip:t=''; }"

    local tiersTotal = min(treeData.ranksHeight.len() - 1, treeData.tree.len())
    local sectionsTotal = treeData.sectionsPos.len() - 1

    local totalWidth = guiScene.calcString("1@slotbarWidthFull -1@modBlockTierNumHeight -1@scrollBarSize", null)
    local itemWidth = guiScene.calcString("@shop_width", null)
    local extraW = "+" + ::max(0, totalWidth - (itemWidth * treeData.sectionsPos[sectionsTotal])) / 2

    local treeHeaderHeight = "+1@buttonHeight"
    local extraHTop = "+1@shop_h_extra_first"
    local extraHBottom = "+1@shop_h_extra_last"

    for(local i = 0; i < tiersTotal; i++)
    {
      local isTop = i == 0
      local isBottom = i == tiersTotal - 1
      local tierNum = (i+1).tostring()
      local tierUnlocked = ::is_era_available(curCountry, i + 1, getCurPageEsUnitType())

      for(local s = 0; s < sectionsTotal; s++)
      {
        local isResearchable = ::getTblValue(s, treeData.sectionsResearchable)
        local tierType = tierUnlocked || !isResearchable ? "unlocked" : "locked"

        local isLeft = s == 0
        local isRight = s == sectionsTotal - 1

        local x = treeData.sectionsPos[s] + "@shop_width" + (isLeft ? "" : extraW)
        local y = treeData.ranksHeight[i] + "@shop_height" + treeHeaderHeight + (isTop ? "" : extraHTop)
        local w = (treeData.sectionsPos[s + 1] - treeData.sectionsPos[s]) + "@shop_width" + (isLeft ? extraW : "") + (isRight ? extraW : "")
        local h = (treeData.ranksHeight[i + 1] - treeData.ranksHeight[i]) + "@shop_height" + (isTop ? extraHTop : "") + (isBottom ? extraHBottom : "")
        data += ::format(plateFormat, tierNum, tierType, x, y, w, h)
      }
    }
    guiScene.replaceContentFromText(tblBgObj, data, data.len(), this)
  }

  function getRankProgressTexts(rank, ranksBlk = null)
  {
    if (!ranksBlk)
      ranksBlk = ::get_ranks_blk()

    local isEraAvailable = ::is_era_available(curCountry, rank, getCurPageEsUnitType())
    local tooltipPlate = ""
    local tooltipRank = ""
    local tooltipReqCounter = ""
    local reqCounter = ""

    if (isEraAvailable)
    {
      local unitsCount = boughtVehiclesCount[rank]
      local unitsTotal = totalVehiclesCount[rank]
      tooltipRank = ::loc("shop/age/tooltip") + ::loc("ui/colon") + ::colorize("userlogColoredText", ::get_roman_numeral(rank))
        + "\n" + ::loc("shop/tier/unitsBought") + ::loc("ui/colon") + ::colorize("userlogColoredText", ::format("%d/%d", unitsCount, unitsTotal))
    }
    else
    {
      local unitType = getCurPageEsUnitType()
      for (local prevRank = rank - 1; prevRank > 0; prevRank--)
      {
        local unitsCount = boughtVehiclesCount[prevRank]
        local unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(curCountry, unitType, prevRank, ranksBlk)
        local unitsLeft = max(0, unitsNeed - unitsCount)

        if (unitsLeft > 0)
        {
          local txtThisRank = ::colorize("userlogColoredText", ::get_roman_numeral(rank))
          local txtPrevRank = ::colorize("userlogColoredText", ::get_roman_numeral(prevRank))
          local txtUnitsNeed = ::colorize("badTextColor", unitsNeed)
          local txtUnitsLeft = ::colorize("badTextColor", unitsLeft)
          local txtCounter = ::format("%d/%d", unitsCount, unitsNeed)
          local txtCounterColored = ::colorize("badTextColor", txtCounter)

          local txtRankIsLocked = ::loc("shop/unlockTier/locked", { rank = txtThisRank })
          local txtNeedUnits = ::loc("shop/unlockTier/reqBoughtUnitsPrevRank", { prevRank = txtPrevRank, amount = txtUnitsLeft })
          local txtRankLockedDesc = ::loc("shop/unlockTier/desc", { rank = txtThisRank, prevRank = txtPrevRank, amount = txtUnitsNeed })
          local txtRankProgress = ::loc("shop/unlockTier/progress", { rank = txtThisRank }) + ::loc("ui/colon") + txtCounterColored

          if (prevRank == rank - 1)
          {
            reqCounter = txtCounter
            tooltipReqCounter = txtRankProgress + "\n" + txtNeedUnits
          }

          tooltipRank = txtRankIsLocked + "\n" + txtNeedUnits + "\n" + txtRankLockedDesc
          tooltipPlate = txtRankProgress + "\n" + txtNeedUnits

          break
        }
      }
    }

    return { tooltipPlate = tooltipPlate, tooltipRank = tooltipRank, tooltipReqCounter = tooltipReqCounter, reqCounter = reqCounter }
  }

  function generateTierArrows(treeData)
  {
    local data = ""
    local blk = ::get_ranks_blk()
    local pageUnitsType = getCurPageEsUnitType()

    for(local i = 1; i <= ::max_country_rank; i++)
    {
      local curEraPos = treeData.ranksHeight[i]
      local prevEraPos = treeData.ranksHeight[i-1]

      if (curEraPos == prevEraPos)
        continue

      local drawArrow = i > 1 && prevEraPos != treeData.ranksHeight[i-2]
      local isRankAvailable = ::is_era_available(curCountry, i, pageUnitsType)
      local status =  isRankAvailable ?  "owned" : "locked"

      local texts = getRankProgressTexts(i, blk)

      local arrowData = ""
      if (drawArrow)
      {
        arrowData = ::format("shopArrow { type:t='vertical'; size:t='1@modArrowWidth, %s@shop_height - 1@modBlockTierNumHeight';" +
                      "pos:t='0.5pw - 0.5w, %s@shop_height + 0.5@modBlockTierNumHeight';" +
                      "shopStat:t='%s'; modArrowPlate{ text:t='%s'; tooltip:t='%s'}}",
                    (treeData.ranksHeight[i-1] - treeData.ranksHeight[i-2]).tostring(),
                    treeData.ranksHeight[i-2].tostring(),
                    status,
                    texts.reqCounter,
                    ::stripTags(::tooltipColorTheme(texts.tooltipReqCounter))
                    )
      }

      data += ::format("modBlockTierNum { class:t='vehicleRanks' status:t='%s'; pos:t='0, %s@shop_height - 0.5h'; text:t='%s'; tooltip:t='%s'}",
                  status,
                  prevEraPos.tostring(),
                  ::loc("options/chooseUnitsRank/rank_" + i),
                  ::stripTags(::tooltipColorTheme(texts.tooltipRank)))

      data += arrowData

      local tierObj = scene.findObject("shop_tier_" + i.tostring())
      if (::checkObj(tierObj))
        tierObj.tooltip = ::tooltipColorTheme(texts.tooltipPlate)
    }

    local height = treeData.ranksHeight[treeData.ranksHeight.len()-1] + "@shop_height"
    local tierObj = scene.findObject("tier_arrows_div")
    tierObj.height = height
    guiScene.replaceContentFromText(tierObj, data, data.len(), this)

    scene.findObject("shop_items_scroll_div").height = height + " + 1@buttonHeight + 1@shop_h_extra_first + 1@shop_h_extra_last"
  }

  function updateBoughtVehiclesCount()
  {
    local bought = array(::max_country_rank + 1, 0)
    local total = array(::max_country_rank + 1, 0)
    local pageUnitsType = getCurPageEsUnitType()

    foreach(unit in ::all_units)
      if (unit.shopCountry == curCountry && pageUnitsType == ::get_es_unit_type(unit))
      {
        local isOwn = ::isUnitBought(unit)
        if (isOwn)
          bought[unit.rank]++
        if (isOwn || ::is_unit_visible_in_shop(unit))
          total[unit.rank]++
      }

    boughtVehiclesCount = bought
    totalVehiclesCount = total
  }

  function fillAirReq(item)
  {
    local req = true
    if ("shopReqName" in item)
      if (item.isReqGroup)
      {
        req = false
        foreach(air in ::all_units)
          if (("group" in air) && air.group == item.shopReqName && ::isUnitBought(air))
          {
            req = true
            break
          }
      }
      else
        req = ::isUnitBought(::getAircraftByName(item.shopReqName))
    if (::isUnitGroup(item))
      foreach(idx, air in item.airsGroup)
        air.shopReq <- req
    item.shopReq <- req
  }

  function getCurPageEsUnitType()
  {
    return getCurPageUnitType().esUnitType
  }

  function getCurPageUnitType()
  {
    return ::g_unit_type.getByArmyId(curPage)
  }

  function findUnitInGroupTableById(id)
  {
    if (::checkObj(groupChooseObj))
      return groupChooseObj.findObject("airs_table").findObject(id)

    return null
  }

  function findCloneGroupObjById(id)
  {
    if (::checkObj(groupChooseObj))
      return groupChooseObj.findObject("clone_td_" + id)

    return null
  }

  function findAirTableObjById(id)
  {
    if (::checkObj(scene))
      return scene.findObject("shop_items_list").findObject(id)

    return null
  }

  function getAirObj(unitName)
  {
    local airObj = findUnitInGroupTableById(unitName)
    if (::checkObj(airObj))
      return airObj

    return findAirTableObjById(unitName)
  }

  function getUnitCellObj(unitName)
  {
    local cellObj = findUnitInGroupTableById("td_" + unitName)
    if (::checkObj(cellObj))
      return cellObj

    return findAirTableObjById("td_" + unitName)
  }

  function checkUnitItemAndUpdate(unit)
  {
    if (!unit)
      return

    local unitObj = getUnitCellObj(unit.name)
    updateUnitItem(unit, unitObj)

    ::updateAirAfterSwitchMod(unit)

    if (::isGroupPart(unit))
      updateGroupItem(unit.group)
  }

  function updateUnitItem(unit, placeObj)
  {
    if (!::checkObj(placeObj))
      return

    local params = getUnitItemParams(unit)
    params.fullBlock = false

    local unitBlock = ::build_aircraft_item(unit.name, unit, params)
    guiScene.replaceContentFromText(placeObj, unitBlock, unitBlock.len(), this)
    ::fill_unit_item_timers(placeObj.findObject(unit.name), unit, params)
  }

  function updateGroupItem(groupName)
  {
    local block = getItemBlockFromShopTree(groupName)
    if (!block)
      return

    updateUnitItem(block, findCloneGroupObjById(groupName))
    updateUnitItem(block, findAirTableObjById("td_" + groupName))
  }

  function checkBrokenListStatus(unit)
  {
    if (!unit)
      return false

    local posNum = ::find_in_array(brokenList, unit)
    if (!getItemStatusData(unit).broken && posNum >= 0)
    {
      brokenList.remove(posNum)
      return true
    }

    return false
  }

  function getUnitItemParams(unit)
  {
    if (!unit)
      return {}

    local is_unit = !::isUnitGroup(unit)
    return {
             active         = true,
             actionsPrefix  = actionsPrefix,
             showInService  = true,
             fullGroupBlock = !is_unit
             mainActionFunc = is_unit? "onUnitMainFunc" : "",
             mainActionText = is_unit? getMainFunctionName(unit) : ""
             fullBlock      = true
             shopResearchMode = shopResearchMode
             forceNotInResearch = !setResearchManually
             flushExp = availableFlushExp
             showBR = ::has_feature("GlobalShowBattleRating")
             getEdiffFunc = getCurrentEdiff.bindenv(this)
             tooltipParams = { needShopInfo = true }
           }
  }

  function getCurAircraft(checkGroups = true, returnDefaultUnitForGroups = false)
  {
    if (!checkObj(scene))
      return null

    local tableObj = scene.findObject("shop_items_list")
    local tree = getCurTreeData().tree
    local curRow = tableObj.cur_row.tointeger()
    local curCol = tableObj.cur_col.tointeger()
    if ((tree.len() <= curRow) || (tree[curRow].len() <= curCol))
      return null

    local mainTblUnit = tree[curRow][curCol]
    if (!::isUnitGroup(mainTblUnit))
      return mainTblUnit

    if (checkGroups && ::checkObj(groupChooseObj))
    {
      tableObj = groupChooseObj.findObject("airs_table")
      local idx = tableObj.cur_row.tointeger()
      if (idx in mainTblUnit.airsGroup)
        return mainTblUnit.airsGroup[idx]
    }

    if (returnDefaultUnitForGroups)
      return getDefaultUnitInGroup(mainTblUnit)

    return mainTblUnit
  }

  function getDefaultUnitInGroup(unitGroup)
  {
    local airsList = ::getTblValue("airsGroup", unitGroup)
    return ::getTblValue(0, airsList)
  }

  function getItemBlockFromShopTree(itemName)
  {
    local tree = getCurTreeData().tree
    for(local i = 0; i < tree.len(); ++i)
      for(local j = 0; j < tree[i].len(); ++j)
      {
        local name = ::getTblValue("name", tree[i][j])
        if (!name)
          continue

        if (itemName == name)
          return tree[i][j]
      }

    return null
  }

  function onAircraftsPage()
  {
    local pagesObj = scene.findObject("shop_pages_list")
    if (pagesObj)
    {
      local pageIdx = pagesObj.getValue()
      if (pageIdx < 0 || pageIdx >= pagesObj.childrenCount())
        return
      curPage = pagesObj.getChild(pageIdx).id
    }
    fillAircraftsList()
  }

  function onCloseShop()
  {
    ::top_menu_handler.shopWndSwitch.call(::top_menu_handler, null)
  }

  function selectSlotbarCountry()
  {
    if (!::checkObj(scene))
      return

    local slotbar = getSlotbarScene()
    if (::checkObj(slotbar) && !(curSlotCountryId in ::crews_list && ::crews_list[curSlotCountryId].country == curCountry))
      foreach(idx, country in ::crews_list)
        if (country.country == curCountry)
        {
          local cObj = slotbar.findObject("slotbar-countries")
          if (cObj)
            cObj.setValue(idx)
          break
        }
    fillCountryInfo(scene.findObject("country-rank"), curCountry)
    fillPagesListBox()
  }

  function fillPagesListBox(unitType = null)
  {
    if (shopResearchMode)
    {
      fillAircraftsList()
      return
    }

    local pagesObj = scene.findObject("shop_pages_list")
    if (!::checkObj(pagesObj))
      return

    if (unitType == null)
      if (::last_shop_unit_type != null)
        unitType = ::last_shop_unit_type
      else
      {
        local unit = ::getAircraftByName(curAirName)
        if (unit)
          unitType = unit.unitType
        else
          unitType = ::g_unit_type.INVALID
      }

    local data = ""
    local curIdx = 0
    local countryData = ::u.search(shopData, (@(curCountry) function(country) { return country.name == curCountry})(curCountry))
    if (countryData)
    {
      local view = { tabs = [] }
      foreach(idx, page in countryData.pages)
      {
        local name = page.name
        view.tabs.append({
          id = name
          tabName = "#mainmenu/" + name
          discount = {
            discountId = getDiscountIconTabId(countryData.name, name)
          }
          navImagesText = ::get_navigation_images_text(idx, countryData.pages.len())
        })

        if (name == unitType.armyId)
          curIdx = idx
      }

      data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    }
    guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    updateDiscountIconsOnTabs()

    pagesObj.setValue(curIdx)
    if (curIdx == 0)
      onAircraftsPage() //need to fix this in listbox
  }

  function getDiscountIconTabId(country, unitType)
  {
    return country + "_" + unitType + "_discount"
  }

  function updateDiscountIconsOnTabs()
  {
    local pagesObj = scene.findObject("shop_pages_list")
    if (!::checkObj(pagesObj))
      return

    local shopBlk = ::get_shop_blk()
    foreach(country in shopData)
    {
      if (country.name != curCountry)
        continue

      foreach(idx, page in country.pages)
      {
        local tabObj = pagesObj.findObject(page.name)
        if (!::checkObj(tabObj))
          continue

        local discountObj = tabObj.findObject(getDiscountIconTabId(curCountry, page.name))
        if (!::checkObj(discountObj))
          continue

        local discountData = getDiscountByCountryAndArmyId(curCountry, page.name)

        local max = ::getTblValue("maxDiscount", discountData, 0)

        tabObj.tooltip = ::getTblValue("discountTooltip", discountData, "")
        discountObj.setValue(max > 0? ("-" + max + "%") : "")
      }
      break
    }
  }

  function getDiscountByCountryAndArmyId(country, armyId)
  {
    local airList = ::getTblValue("airList", ::visibleDiscountNotifications, {})
    local entitlementUnits = ::getTblValue("entitlementUnits", ::visibleDiscountNotifications, {})
    if (!airList.len() && !entitlementUnits.len())
      return null

    local unitType = ::g_unit_type.getByArmyId(armyId)
    local discountsList = {}
    foreach(unit in ::all_units)
      if (unit.unitType == unitType
          && unit.shopCountry == country)
      {
        local discount = ::g_discount.getUnitDiscount(unit)
        if (discount > 0)
          discountsList[unit.name + "_shop"] <- discount
      }

    return ::generateDiscountInfo(discountsList)
  }

  function openMenuForCurAir(obj)
  {
    local curAir = getCurAircraft()
    if (!("name" in curAir))
      return
    local curAirObj = obj.findObject(getCurAircraft().name)
    if (::checkObj(curAirObj))
      openUnitActionsList(curAirObj, true)
  }

  function onAircraftClick(obj)
  {
    checkSelectAirGroup()
    openMenuForCurAir(obj)
  }

  function checkSelectAirGroup(block = null, selectUnitName = "")
  {
    local item = block == null? getCurAircraft() : block
    if (skipOpenGroup || groupChooseObj || !item || !::isUnitGroup(item))
      return
    local silObj = scene.findObject("shop_items_list")
    if (!::checkObj(silObj))
      return
    local grObj = silObj.findObject(item.name)
    if (!::checkObj(grObj))
      return

    //choose aircraft from group window
    local tdObj = grObj.getParent()
    local tdPos = tdObj.getPosRC()
    local tdSize = tdObj.getSize()
    local leftPos = (tdPos[0] + tdSize[0] / 2) + " -50%w"

    local cellHeight = tdSize[1] || 86 // To avoid division by zero
    local screenHeight = ::screen_height()
    local safeareaHeight = guiScene.calcString("@rh", null)
    local safeareaBorderHeight = ::floor((screenHeight - safeareaHeight) / 2)
    local containerHeight = item.airsGroup.len() * cellHeight

    local topPos = tdPos[1]
    local heightOutOfSafearea = (topPos + containerHeight) - (safeareaBorderHeight + safeareaHeight)
    if (heightOutOfSafearea > 0)
      topPos -= ::ceil(heightOutOfSafearea / cellHeight) * cellHeight
    topPos = ::max(topPos, safeareaBorderHeight)

    groupChooseObj = guiScene.loadModal("", "gui/shop/shopGroup.blk", "massTransp", this)
    local placeObj = groupChooseObj.findObject("tablePlace")
    placeObj.left = leftPos.tostring()
    placeObj.top = topPos.tostring()

    groupChooseObj.group = item.name
    local tableDiv = groupChooseObj.findObject("slots_scroll_div")
    tableDiv.pos = "0,0"

    fillGroupObj(selectUnitName)
    fillGroupObjAnimParams(tdSize, tdPos)

    updateGroupObjNavBar()
  }

  function fillGroupObjAnimParams(tdSize, tdPos)
  {
    local animObj = groupChooseObj.findObject("tablePlace")
    if (!animObj)
      return
    local size = animObj.getSize()
    if (!size[1])
      return

    animObj["height-base"] = tdSize[1].tostring()
    animObj["height-end"] = size[1].tostring()

    //update anim fixed position
    local heightDiff = size[1] - tdSize[1]
    if (heightDiff <= 0)
      return

    local pos = animObj.getPosRC()
    local animStart = tdPos[1]
    local topPart = (tdPos[1] - pos[1]).tofloat() / heightDiff
    local animFixedY = tdPos[1] + topPart * tdSize[1]
    animObj.top = format("%d - %fh", animFixedY.tointeger(), topPart)
  }

  function updateGroupObjNavBar()
  {
    navBarGroupObj = groupChooseObj.findObject("nav-help-group")
    initShowMode(navBarGroupObj)
    updateButtons()
  }

  function fillGroupObjArrows(group)
  {
    local unitPosNum = 0
    local prevGroupUnit = null
    local lines = ""
    foreach(unit in group)
    {
      if (!unit)
        continue
      local reqUnit = ::getPrevUnit(unit)
      if (reqUnit  && prevGroupUnit
          && reqUnit.name == prevGroupUnit.name)
      {
        local status = ::isUnitBought(prevGroupUnit) || ::isUnitBought(unit)
                       ? ""
                       : "locked"
        lines += createLine(unitPosNum - 1, 0, unitPosNum, 0, status)
      }
      prevGroupUnit = unit
      unitPosNum++
    }
    return lines
  }

  function fillGroupObj(selectUnitName = "")
  {
    if (!::checkObj(scene) || !::checkObj(groupChooseObj))
      return

    local item = getCurAircraft(false)
    if (!item || !::isUnitGroup(item))
      return

    local gTblObj = groupChooseObj.findObject("airs_table")
    if (!::checkObj(gTblObj))
      return

    gTblObj["class"] = "shopTable"
    gTblObj.navigatorShortcuts = "yes"
    gTblObj.alwaysShowBorder = "yes"

    if (selectUnitName == "")
    {
      local groupUnit = getDefaultUnitInGroup(item)
      if (groupUnit)
        selectUnitName = groupUnit.name
    }
    fillUnitsInGroup(gTblObj, item.airsGroup, selectUnitName)

    local lines = fillGroupObjArrows(item.airsGroup)
    guiScene.appendWithBlk(groupChooseObj.findObject("arrows_nest"), lines, this)

    foreach(air in item.airsGroup)
      if (air)
      {
        ::showUnitDiscount(gTblObj.findObject(air.name+"-discount"), air)
        ::showAirExpWpBonus(gTblObj.findObject(air.name+"-bonus"), air.name)
        if (getItemStatusData(air).broken && !::isInArray(air, brokenList))
          brokenList.append(air)
      }
  }

  function fillUnitsInGroup(tblObj, airList, selectUnitName = "")
  {
    local data = ""
    local selected = tblObj.cur_row.tointeger()
    local unitItems = []
    for(local i = 0; i < airList.len(); i++)
    {
      if (selectUnitName == airList[i].name)
        selected = i

      local params = getUnitItemParams(airList[i])
      local unitBlk = ::build_aircraft_item(airList[i].name, airList[i], params)
      unitItems.append({ id = airList[i].name, unit = airList[i], params = params })
      data += ::format("tr { %s }\n", unitBlk)
    }

    guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    foreach (unitItem in unitItems)
      ::fill_unit_item_timers(tblObj.findObject(unitItem.id), unitItem.unit, unitItem.params)
    tblObj.select()
    ::gui_bhv.columnNavigator.selectCell(tblObj, selected, 0, false, false, false)
  }

  function onSceneActivate(show)
  {
    base.onSceneActivate(show)
    if (!show)
      destroyGroupChoose()
  }

  function onDestroy()
  {
    destroyGroupChoose()
  }

  function destroyGroupChoose(destroySpecGroupName = "")
  {
    if (!::checkObj(groupChooseObj)
        || (destroySpecGroupName != "" &&
            destroySpecGroupName == groupChooseObj.group))
      return

    guiScene.destroyElement(groupChooseObj)
    groupChooseObj=null
    updateButtons()
    ::broadcastEvent("ModalWndDestroy")
  }

  function destroyGroupChooseDelayed()
  {
    guiScene.performDelayed(this, destroyGroupChoose)
  }

  function onCancelSlotChoose(obj)
  {
    if (::checkObj(groupChooseObj))
      destroyGroupChooseDelayed()
  }

  function onRepairAll(obj)
  {
    local cost = ::Cost()
    cost.wp = repairAllCost

    if (!::check_balance_msgBox(cost))
      return

    taskId = ::shop_repair_all(curCountry, false)
    if (taskId < 0)
      return

    ::set_char_cb(this, slotOpCb)
    showTaskProgressBox()

    afterSlotOp = function()
    {
      showTaskProgressBox()
      checkBrokenUnitsAndUpdateThem()
      local curAir = getCurAircraft()
      lastPurchase = curAir
      needUpdateSlotbar = true
      needUpdateSquadInfo = true
      destroyProgressBox()
    }
  }

  function onEventUnitRepaired(params)
  {
    local unit = ::getTblValue("unit", params)

    if (checkBrokenListStatus(unit))
      checkUnitItemAndUpdate(unit)

    updateRepairAllButton()
  }

  function onEventSparePurchased(params)
  {
    if (!scene.isEnabled() || !scene.isVisible())
      return
    checkUnitItemAndUpdate(::getTblValue("unit", params))
  }

  function onEventModificationPurchased(params)
  {
    if (!scene.isEnabled() || !scene.isVisible())
      return
    checkUnitItemAndUpdate(::getTblValue("unit", params))
  }

  function onEventAllModificationsPurchased(params)
  {
    if (!scene.isEnabled() || !scene.isVisible())
      return
    checkUnitItemAndUpdate(::getTblValue("unit", params))
  }

  function onEventUpdateResearchingUnit(params)
  {
    local unitName = ::getTblValue("unitName", params, ::shop_get_researchable_unit_name(curCountry, getCurPageEsUnitType()))
    checkUnitItemAndUpdate(::getAircraftByName(unitName))
  }

  function onRepair(obj)
  {
    repairRequest(getCurAircraft());
  }

  function repairRequest(unit) {
    if (!unit)
      return
    showMsgBoxRepair(unit, (@(unit) function() { ::check_and_repair_unit(unit) })(unit))
  }

  function onSlotRepair(obj)
  {
    local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    local airName = ("aircraft" in crew)? crew.aircraft : ""
    repairRequest(getAircraftByName(airName))
  }

  function onTopMenuSlotRepair(obj)
  {
    if (!::top_menu_handler)
      return
    local crew = getSlotItem(::top_menu_handler.curSlotCountryId, ::top_menu_handler.curSlotIdInCountry)
    local airName = ("aircraft" in crew)? crew.aircraft : ""
    repairRequest(getAircraftByName(airName))
  }

  function onOpenOnlineShop(obj)
  {
    OnlineShopModel.showGoods({
      unitName = getCurAircraft().name
    })
  }

  function onBuy(obj)
  {
    local unit = getCurAircraft(true, true)
    if (!unit)
      return

    if (::canBuyUnitOnline(unit))
      ::OnlineShopModel.showGoods({ unitName = unit.name })
    else
      ::buyUnit(unit)
  }

  function onResearch(obj)
  {
    local unit = getCurAircraft()
    local unitName = unit.name
    local handler = this
    if (!unit || isUnitGroup(unit))
      return
    if (!::checkForResearch(unit))
      return

    ::researchUnit(unit)
  }

  function onConvert(obj)
  {
    local unit = getCurAircraft()
    if (!unit)
      return
    if(::isTank(unit) && !::has_feature("SpendGoldForTanks"))
    {
      msgBox("not_available_goldspend", ::loc("msgbox/tanksRestrictFromSpendGold"), [["ok", function () {}]], "ok")
      return
    }

    local unitName = unit.name
    local handler = this
    selectCellByUnitName(unitName)
    ::gui_modal_convertExp(unit, handler)
  }

  function getUnitNameByBtnId(id)
  {
    if (id.len() < 13)
      return ""
    return id.slice(13)
  }

  function onEventUnitResearch(params)
  {
    if (!::checkObj(scene))
      return

    local prevUnitName = ::getTblValue("prevUnitName", params)
    local unitName = ::getTblValue("unitName", params)

    if (prevUnitName && prevUnitName != unitName)
      checkUnitItemAndUpdate(::getAircraftByName(prevUnitName))

    local unit = ::getAircraftByName(unitName)
    updateResearchVariables()
    checkUnitItemAndUpdate(unit)

    selectCellByUnitName(unit)

    if (shopResearchMode && availableFlushExp <= 0)
    {
      ::buyUnit(unit)
      onCloseShop()
    }
  }

  function onEventUnitBought(params)
  {
    ::update_gamercards()

    local unitName = ::getTblValue("unitName", params)
    local unit = unitName ? ::getAircraftByName(unitName) : null
    if (!unit)
      return

    if (::getTblValue("receivedFromTrophy", params, false) && ::is_unit_visible_in_shop(unit))
    {
      doWhenActiveOnce("loadFullAircraftsTable")
      doWhenActiveOnce("fillAircraftsList")
      return
    }

    updateResearchVariables()
    fillAircraftsList(unitName)
    fillGroupObj()

    if (!isSceneActive())
      return

    if (!::checkIsInQueue() && !shopResearchMode)
      onTake(unit)
    else if (shopResearchMode)
      selectRequiredUnit()
  }

  function onEventUnitRented(params)
  {
    onEventUnitBought(params)
  }

  function selectCellByUnitName(unitName)
  {
    if (!unitName || unitName == "")
      return false

    if (!::checkObj(scene))
      return false

    local tree = getCurTreeData().tree
    local tableObj = scene.findObject("shop_items_list")
    if (!::checkObj(tableObj))
      return false

    foreach(rowIdx, row in tree)
      foreach(colIdx, item in row)
        if (::isUnitGroup(item))
        {
          foreach(groupItemIdx, groupItem in item.airsGroup)
            if (groupItem.name == unitName)
            {
              ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, tableObj, rowIdx, colIdx)
              if (::checkObj(groupChooseObj))
              {
                local groupTableObj = groupChooseObj.findObject("airs_table")
                ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, groupTableObj, groupItemIdx, groupTableObj.cur_col.tointeger())
              }
              return true
            }
        }
        else
        {
          if (item && item.name == unitName)
          {
            ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, tableObj, rowIdx, colIdx)
            return true
          }
        }
    return false
  }

  function onTake(unit = null)
  {
    local handler = this
    checkedCrewAirChange( (@(unit, handler) function () {
      local curUnit = unit ? unit : getCurAircraft()
      if (!curUnit || !curUnit.isUsable() || ::isUnitInSlotbar(curUnit))
        return

      ::gui_start_selecting_crew({
        unit = curUnit,
        unitObj = getAirObj(curUnit.name)
        cellClass = "shopClone"
        getEdiffFunc = getCurrentEdiff.bindenv(this)
      })
    })(unit, handler))
  }

  function onEventExpConvert(params)
  {
    doWhenActiveOnce("fillAircraftsList")
    fillGroupObj()
  }

  function onEventCrewTakeUnit(params)
  {
    foreach(param in ["unit", "prevUnit"])
    {
      local unit = ::getTblValue(param, params)
      if (!unit)
        continue

      checkUnitItemAndUpdate(unit)
    }

    destroyGroupChoose()
  }

  function onTestFlight(obj)
  {
    checkedCrewModify(function (){
      if (!::g_squad_utils.canJoinFlightMsgBox())
        return
      local air = getCurAircraft()
      if (!air)
        return
      if (air.testFlight == "")
        return
      ::show_aircraft = air
      ::test_flight_aircraft <- air
      ::gui_start_testflight()
    })
  }

  function onBack(obj)
  {
    save(false)
  }
  function afterSave()
  {
    goBack()
  }

  function onDoubleClick(obj)
  {
    onUnitMainFunc(obj)
  }

  function onUnitMainFunc(obj)
  {
    local unit = getCurAircraft()
    if (!unit || ::isUnitGroup(unit))
      return

    if (::isUnitBroken(unit))
      return onRepair(obj)
    if (::isUnitInSlotbar(unit))
      return ::open_weapons_for_unit(unit)
    if (unit.isUsable() && !::isUnitInSlotbar(unit))
      return onTake(unit)
    if (::canBuyUnitOnline(unit))
      return onOpenOnlineShop(obj)
    if (::canBuyUnit(unit))
      return onBuy(obj)
    if ((availableFlushExp > 0 || !setResearchManually) && (::canResearchUnit(unit) || ::isUnitInResearch(unit)))
      return onSpendExcessExp()
    if (::isUnitInResearch(unit) && ::has_feature("SpendGold"))
      return onConvert(obj)
    if (::checkForResearch(unit)) // Also shows msgbox about requirements for Research or Purchase
      return onResearch(obj)
  }

  function getMainFunctionName(unit)
  {
    if (::isUnitBroken(unit))
      return "#mainmenu/btnRepair"
    if (::isUnitInSlotbar(unit))
      return ""
    if (unit.isUsable() && !::isUnitInSlotbar(unit))
      return "#mainmenu/btnTakeAircraft"
    if (::canBuyUnit(unit) || ::canBuyUnitOnline(unit))
      return "#mainmenu/btnOrder"
    if ((availableFlushExp > 0 || !setResearchManually) && (::canResearchUnit(unit) || ::isUnitInResearch(unit)))
      return "#mainmenu/btnResearch"
    if (::isUnitInResearch(unit) && ::has_feature("SpendGold"))
      return "#mainmenu/btnConvert"
    if (!::isUnitUsable(unit) && !::isUnitGift(unit))
      return ::isUnitMaxExp(unit) ? "#mainmenu/btnOrder" : "#mainmenu/btnResearch"
    return ""
  }

  function onShowroom(obj)
  {
    local air = getCurAircraft()
    if (!air || ::isUnitGroup(air))
      return
    ::show_aircraft = air
    checkedCrewModify(function (){
      guiScene.performDelayed(this, function() {
        goForward(::gui_start_decals)
      })
    })
  }

  function onModifications(obj)
  {
    msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onWeapons(obj)
  {
    local air = getCurAircraft()
    if (!air)
      return
    ::open_weapons_for_unit(air)
  }

  function onInfo(obj)
  {
    local air = getCurAircraft()
    if (!air) return
    ::gui_start_aircraft_info(air.name)
  }

  function checkTag(aircraft, tag)
  {
    if (!tag) return true
    return isInArray(tag, aircraft.tags)
  }

  function onTopmenuCountry(country, forceUpdate = false, esUnitType = null)
  {
    if (country == curCountry && !forceUpdate)
      return
    foreach(idx, tree in shopData)
      if (tree.name == country)
      {
        skipOpenGroup = true
        local countriesObj = scene.findObject("shop_filters_list")
        if (countriesObj && countriesObj.getValue() != idx)
          countriesObj.setValue(idx)
        else
        {
          curCountry=country
          fillCountryInfo(scene.findObject("country-rank"), curCountry)
          local air = (country!=curCountry)? null : getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
          if (air)
            curAirName = air.name
          local unitType = esUnitType != null ? ::g_unit_type.getByEsUnitType(esUnitType) : null
          fillPagesListBox(unitType)
        }
        skipOpenGroup = false
        return
      }
  }

  function initShowMode(tgtNavBar)
  {
    local obj = tgtNavBar.findObject("show_mode")
    if (!::checkObj(obj))
      return

    local showModeRaw = ::load_local_account_settings("shopShowMode", -1)

    curDiffCode = -1
    showModeList = []
    foreach(diff in ::g_difficulty.types)
      if (diff.diffCode == -1 || !shopResearchMode && diff.isAvailable())
      {
        showModeList.append({
          text = diff.diffCode == -1 ? ::loc("options/auto") : ::colorize("warningTextColor", diff.getLocName())
          diffCode = diff.diffCode
          enabled = true
          textStyle = "textStyle:t='textarea';"
        })
        if (showModeRaw == diff.diffCode)
          curDiffCode = showModeRaw
      }

    if (showModeList.len() <= 2)
    {
      curDiffCode = -1
      obj.show(false)
      obj.enable(false)
      return
    }

    foreach (item in showModeList)
      item.selected <- item.diffCode == curDiffCode
    local view = {
      id = "show_mode"
      optionTag = "option"
      cb = "onChangeShowMode"
      options= showModeList
    }
    local data = ::handyman.renderCached("gui/options/spinnerOptions", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    updateShowModeTooltip(obj)
  }

  function updateShowModeTooltip(obj)
  {
    if (!::checkObj(obj))
      return
    local isAuto = curDiffCode == -1
    local adviceText = ::loc(isAuto ? "mainmenu/showModesInfo/advice" : "mainmenu/showModesInfo/warning", { automatic = ::loc("options/auto") })
    adviceText = ::colorize(isAuto ? "goodTextColor" : "warningTextColor", adviceText)
    obj["tooltip"] = ::loc("mainmenu/showModesInfo/tooltip") + "\n" + adviceText
  }

  _isShowModeInChange = false
  function onChangeShowMode(obj)
  {
    if (_isShowModeInChange)
      return
    if (!::checkObj(obj))
      return

    local value = obj.getValue()
    local item = ::getTblValue(value, showModeList)
    if (!item)
      return

    _isShowModeInChange = true
    local prevEdiff = getCurrentEdiff()
    curDiffCode = item.diffCode
    ::save_local_account_settings("shopShowMode", curDiffCode)

    foreach(tgtNavBar in [navBarObj, navBarGroupObj])
    {
      if (!::check_obj(tgtNavBar))
        continue

      local listObj = tgtNavBar.findObject("show_mode")
      if (!::check_obj(listObj))
        continue

      if (listObj.getValue() != value)
        listObj.setValue(value)
      updateShowModeTooltip(listObj)
    }

    if (prevEdiff != getCurrentEdiff())
    {
      updateSlotbarDifficulty()
      updateTreeDifficulty()
      fillGroupObj()
    }
    _isShowModeInChange = false
  }

  function getCurrentEdiff()
  {
    return curDiffCode == -1 ? ::get_current_ediff() : curDiffCode
  }

  function updateSlotbarDifficulty()
  {
    ::update_slotbar_difficulty(::top_menu_handler)
  }

  function updateTreeDifficulty()
  {
    if (!::has_feature("GlobalShowBattleRating"))
      return
    local curEdiff = getCurrentEdiff()
    local tree = getCurTreeData().tree
    foreach(row in tree)
      foreach(unit in row)
      {
        local unitObj = unit ? getUnitCellObj(unit.name) : null
        if (::checkObj(unitObj))
        {
          local obj = unitObj.findObject("rank_text")
          if (::checkObj(obj))
            obj.setValue(::get_unit_rank_text(unit, null, true, curEdiff))
        }
      }
  }

  function onAirHover(obj)
  {
    if (unitActionsListTimer != null)
      unitActionsListTimer.destroy()
    local handler = this
    unitActionsListTimer = Timer(obj, 1.0, (@(obj, slotbarActions, handler) function () {
      if (obj.isHovered())
      {
        local unit = ::getAircraftByName(obj.unit_name)
        local actions = ::get_unit_actions_list(unit, handler, handler.actionsPrefix, slotbarActions)

        ::gui_handlers.ActionsList(obj, actions)
      }
    })(obj, slotbarActions, handler))
  }

  function restoreFocus(checkPrimaryFocus = true)
  {
    if (!checkGroupObj())
      ::top_menu_handler.restoreFocus.call(::top_menu_handler, checkPrimaryFocus)
  }

  function onEventClosedUnitItemMenu(params)
  {
    if (!checkGroupObj())
      restoreFocus()
  }

  function checkGroupObj()
  {
    if (::checkObj(groupChooseObj))
    {
      local tableObj = groupChooseObj.findObject("airs_table")
      if (::checkObj(tableObj))
      {
        tableObj.select()
        return true
      }
    }
    return false
  }

  function onWrapUp(obj)
  {
    ::top_menu_handler.onWrapUp.call(::top_menu_handler, obj)
  }

  function onWrapDown(obj)
  {
    ::top_menu_handler.onWrapDown.call(::top_menu_handler, obj)
  }

  function onShopShow(show)
  {
    if (!show && ::checkObj(groupChooseObj))
      destroyGroupChoose()
    if (show)
      popDelayedActions()
  }

  function onUnitSelect() {}
  function selectRequiredUnit() {}
  function onSpendExcessExp() {}
  function updateResearchVariables() {}
}