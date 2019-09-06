local Unit = ::require("scripts/unit/unit.nut")

::all_units <- {}
::show_aircraft <- null

::g_script_reloader.registerPersistentData("initOptionsGlobals", ::getroottable(),
  [ "all_units", "show_aircraft"])

//remap all units to new class on scripts reload
foreach(name, unit in ::all_units)
  ::all_units[name] = Unit({}).setFromUnit(unit)
if (::show_aircraft)
  ::show_aircraft = ::all_units?[::show_aircraft.name]

function init_options()
{
  if (::measure_units.len() > 0 && (::g_login.isAuthorized() || ::disable_network()))
    return

  local stepStatus
  foreach(action in ::init_options_steps)
    do {
      stepStatus = action()
    } while (stepStatus == PT_STEP_STATUS.SUSPEND)
}

function init_all_units()
{
  ::all_units.clear()
  local all_units_array = ::gather_and_build_aircrafts_list()
  foreach (unitTbl in all_units_array)
  {
    local unit = Unit(unitTbl)
    ::all_units[unit.name] <- unit
  }
}

function update_all_units()
{
  ::update_shop_countries_list()
  ::countUsageAmountOnce()
  ::generateUnitShopInfo()

  dagor.debug("update_all_units called, got "+::all_units.len()+" items");
}

function update_shop_countries_list()
{
  local shopBlk = ::get_shop_blk()
  ::shopCountriesList = []
  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
  {
    local tblk = shopBlk.getBlock(tree)
    local country = tblk.getBlockName()
    if (!::is_country_visible(country))
      continue

    ::shopCountriesList.append(country)
  }
}

::usageAmountCounted <- false
function countUsageAmountOnce()
{
  if (usageAmountCounted)
    return

  local statsblk = ::get_global_stats_blk()
  if (!statsblk["aircrafts"])
    return

  local shopStatsAirs = []
  local shopBlk = ::get_shop_blk()

  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
  {
    local tblk = shopBlk.getBlock(tree)
    for (local page = 0; page < tblk.blockCount(); page++)
    {
      local pblk = tblk.getBlock(page)
      for (local range = 0; range < pblk.blockCount(); range++)
      {
        local rblk = pblk.getBlock(range)
        for (local a = 0; a < rblk.blockCount(); a++)
        {
          local airBlk = rblk.getBlock(a)
          local stats = statsblk["aircrafts"][airBlk.getBlockName()]
          if (stats && stats["flyouts_factor"])
            shopStatsAirs.append(stats["flyouts_factor"])
        }
      }
    }
  }

  if (shopStatsAirs.len() <= ::usageRating_amount.len())
    return

  shopStatsAirs.sort(function(a,b)
  {
    if(a > b) return 1
    else if(a<b) return -1
    return 0;
  })

  for(local i = 0; i<::usageRating_amount.len(); i++)
  {
    local idx = ::floor((i+1).tofloat() * shopStatsAirs.len() / (::usageRating_amount.len()+1) + 0.5)
    ::usageRating_amount[i] = (idx==shopStatsAirs.len()-1)? shopStatsAirs[idx] : 0.5 * (shopStatsAirs[idx] + shopStatsAirs[idx+1])
  }
  usageAmountCounted = true
}

::init_options_steps <- [
  ::init_all_units,
  ::update_all_units,
  function() { return ::update_aircraft_warpoints(10) }

  function() {
    ::tribunal.init()
    ::game_mode_maps.clear() //to refreash maps on demand
    ::dynamic_layouts.clear()
    ::crosshair_icons.clear()
    ::crosshair_colors.clear()
  }

  function()
  {
    local blk = ::DataBlock("config/encyclopedia.blk")
    ::encyclopedia_data = []
    local defSize = [blk.getInt("image_width", 10), blk.getInt("image_height", 10)]
    for (local chapterNo = 0; chapterNo < blk.blockCount(); chapterNo++)
    {
      local blkChapter = blk.getBlock(chapterNo)
      local name = blkChapter.getBlockName()

      if (::is_vendor_tencent() && name == "history")
        continue

      local chapterDesc = {}
      chapterDesc.id <- name
      chapterDesc.articles <- []
      for (local articleNo = 0; articleNo < blkChapter.blockCount(); articleNo++)
      {
        local blkArticle = blkChapter.getBlock(articleNo)
        local showPlatform = blkArticle.showPlatform
        local hidePlatform = blkArticle.hidePlatform

        if ((showPlatform && showPlatform != ::target_platform)
            || (hidePlatform && hidePlatform == ::target_platform))
          continue

        local articleDesc = {}
        articleDesc.id <- blkArticle.getBlockName()

        if (::is_vietnamese_version() && ::isInArray(articleDesc.id, ["historical_battles", "realistic_battles"]))
          continue

        articleDesc.haveHint <- blkArticle.getBool("haveHint",false)

        if (blkArticle.images)
        {
          local imgList = blkArticle.images % "image"
          if (imgList.len() > 0)
          {
            articleDesc.images <- imgList
            articleDesc.imgSize <- [blkArticle.getInt("image_width", defSize[0]),
                                    blkArticle.getInt("image_height", defSize[1])]
          }
        }
        chapterDesc.articles.append(articleDesc)
      }
      ::encyclopedia_data.append(chapterDesc)
    }
  }

  function()
  {
    local blk = ::DataBlock("config/measureUnits.blk")
    ::measure_units = []
    for (local i = 0; i < blk.blockCount(); i++)
    {
      local blkUnits = blk.getBlock(i)
      local units = []
      for (local j = 0; j < blkUnits.blockCount(); j++)
      {
        local blkUnit = blkUnits.getBlock(j)
        local unit = {
          name = blkUnit.getBlockName()
          round = blkUnit.getInt("round", 0)
          koef = blkUnit.getReal("koef", 1.0)
          roundAfter = blkUnit.getPoint2("roundAfter", Point2(0,0))
        }
        units.append(unit)
      }
      ::measure_units.append(units)
    }
  }

  function()
  {
    local blk = ::configs.GUI.get()

    ::init_bullet_icons(blk)

    foreach(name in ["bullets_locId_by_caliber", "modifications_locId_by_caliber"])
      getroottable()[name] = blk[name]? (blk[name] % "ending") : []

    if (typeof blk.unlocks_punctuation_without_space == "string")
      ::unlocks_punctuation_without_space = blk.unlocks_punctuation_without_space

    ::LayersIcon.initConfigOnce(blk)
  }

  function()
  {
    local blk = ::DataBlock("config/hud.blk")
    if (!blk.crosshair)
      return

    local crosshairs = blk.crosshair % "pictureTpsView"
    foreach (crosshair in crosshairs)
      ::crosshair_icons.append(crosshair)
    local colors = blk.crosshair % "crosshairColor"
    foreach (colorBlk in colors)
      ::crosshair_colors.append({
        name = colorBlk.name
        color = colorBlk.color
      })
  }

  function()
  {
    local blk = ::DataBlock("config/gameplay.blk")
    ::reload_cooldown_time = {}
    local cooldown_time = blk.reloadCooldownTimeByCaliber
    if (!cooldown_time)
      return

    foreach (time in cooldown_time % "time")
      ::reload_cooldown_time[time.x] <- time.y
  }

  function()
  {
    ::load_player_exp_table()
    ::init_prestige_by_rank()
  }

  function()
  {
    local blk = ::DataBlock("config/postFxOptions.blk")
    if (blk.lut_list)
    {
      ::lut_list = []
      ::lut_textures = []
      foreach(lut in (blk.lut_list % "lut"))
      {
        ::lut_list.append("#options/" + lut.getStr("id", ""))
        ::lut_textures.append(lut.getStr("texture", ""))
      }
      ::check_cur_lut_texture()
    }
  }

  function()
  {
    ::broadcastEvent("InitConfigs")
  }
]
