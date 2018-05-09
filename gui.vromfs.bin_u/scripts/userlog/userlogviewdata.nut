local time = require("scripts/time.nut")

function update_repair_cost(units, repairCost)
{
  local idx = 0
  while (("cost"+idx) in units) {
    local cost = ::getTblValue("cost"+idx, units, 0)
    if (cost>0)
      repairCost.rCost += cost
    else
      repairCost.notEnoughCost -= cost
    idx++
  }
}

function get_userlog_view_data(log)
{
  local res = {
    name = "",
    time = time.buildDateTimeStr(log.time, true)
    tooltip = ""
    logImg = null
    logImg2 = null
  }
  local logName = getLogNameByType(log.type)
  local priceText = ::Cost(("wpCost" in log) ? log.wpCost : 0,
    ("goldCost" in log) ? log.goldCost : 0).tostring()
  if (priceText!="")  priceText = " ("+priceText+")"

  local imgFormat = "img {size:t='%s'; background-image:t='%s'; margin-right:t='0.01@scrn_tgt;'} "
  local textareaFormat = "textareaNoTab {id:t='description'; width:t='pw'; text:t='%s'} "

  if (log.type == ::EULT_SESSION_START ||
      log.type == ::EULT_EARLY_SESSION_LEAVE ||
      log.type == ::EULT_SESSION_RESULT)
  {
    if (("country" in log) && ::checkCountry(log.country, "userlog EULT_SESSION_"))
      res.logImg2 = ::get_country_icon(log.country)

    local mission = get_mission_name(log.mission, log)
    if ("eventId" in log && !::events.isEventRandomBattlesById(log.eventId))
    {
      local locName = ""

      if ("eventLocName" in log)
       locName = log.eventLocName
      else
       locName = "events/" + log.eventId + "/name"
      logName = "event/" + logName
      mission = ::loc(locName, log.eventId)
    }

    local nameLoc = "userlog/"+logName
    if (log.type==::EULT_EARLY_SESSION_LEAVE)
      res.logImg = "#ui/gameuiskin#log_leave"
    else
      if (log.type==::EULT_SESSION_RESULT)
      {
        nameLoc += log.win? "/win":"/lose"
        res.logImg = "#ui/gameuiskin#" + (log.win? "log_win" : "log_lose")
      }
    res.name = format(::loc(nameLoc), mission)

    local desc = ""
    local wp = ::getTblValue("wpEarned", log, 0) + ::getTblValue("baseTournamentWp", log, 0)
    local gold = ::getTblValue("goldEarned", log, 0) + ::getTblValue("baseTournamentGold", log, 0)
    local xp = ::getTblValue("xpEarned", log, 0)
    local earnedText = ::Cost(wp, gold, xp).toStringWithParams({isWpAlwaysShown = true})
    if (earnedText!="")
    {
      earnedText = ::loc("ui/colon") + "<color=@activeTextColor>" + earnedText + "</color>"
      desc += ((desc!="")? "\n":"") + ::loc("userlog/earned") + earnedText
    }

    if (log.type == ::EULT_SESSION_RESULT && ("activity" in log))
    {
      local activity = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(log.activity)
      desc += "\n" + ::loc("conditions/activity") + ::loc("ui/colon") + activity
    }

    if (("friendlyFirePenalty" in log) && log.friendlyFirePenalty != 0)
    {
      desc += "\n" + ::loc("debriefing/FriendlyKills") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" +
        ::Cost(log.friendlyFirePenalty).toStringWithParams({isWpAlwaysShown = true}) + "</color>"
      wp += log.friendlyFirePenalty
    }

    if (("nRespawnsWp" in log) && log.nRespawnsWp != 0)
    {
      desc += "\n" + ::loc("debriefing/MultiRespawns") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" +
        ::Cost(log.nRespawnsWp).toStringWithParams({isWpAlwaysShown = true}) + "</color>"
      wp += log.nRespawnsWp
    }

    if ("aircrafts" in log)
    {
      local aText = ""
      foreach(air in log.aircrafts)
        if (air.value < 1.0)
          aText += ((aText!="")? ", ":"") + ::getUnitName(air.name)// + format(" (%d%%)", (100.0*air.value).tointeger())
      if (aText!="")
        desc += "\n" + ::loc("userlog/broken_airs") + ::loc("ui/colon") + aText
    }

    if ("spare" in log)
    {
      local aText = ""
      foreach(air in log.spare)
        if (air.value > 0)
        {
          aText += ((aText!="")? ", ":"") + ::getUnitName(air.name)
          if (air.value > 1)
            aText += format(" (%d)", air.value.tointeger())
        }
      if (aText!="")
        desc += "\n" + ::loc("userlog/used_spare") + ::loc("ui/colon") + aText
    }

    local containerLog = ::getTblValue("container", log)

    local freeRepair = ("aircrafts" in log) && log.aircrafts.len() > 0
    local repairCost = {rCost = 0, notEnoughCost = 0}
    local aircraftsRepaired = ::getTblValue("aircraftsRepaired", containerLog)
    if (aircraftsRepaired)
      update_repair_cost(aircraftsRepaired, repairCost);

    local unitsRepairedManually = ::getTblValue("manuallySpentRepairCost", log)
    if (unitsRepairedManually)
      update_repair_cost(unitsRepairedManually, repairCost);

    if (repairCost.rCost>0)
    {
      desc += "\n" + ::loc("shop/auto_repair_cost") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" + ::Cost(-repairCost.rCost).toStringWithParams({isWpAlwaysShown = true}) + "</color>"
      wp -= repairCost.rCost
      freeRepair = false
    }
    if (repairCost.notEnoughCost!=0)
    {
      desc += "\n" + ::loc("shop/auto_repair_failed") + ::loc("ui/colon")
      desc += "<color=@warningTextColor>(" +
        ::Cost(repairCost.notEnoughCost).toStringWithParams({isWpAlwaysShown = true}) + ")</color>"
      freeRepair = false
    }

    if (freeRepair && ("autoRepairWasOn" in log) && log.autoRepairWasOn)
    {
      desc += "\n" + ::loc("shop/auto_repair_free")
    }

    local wRefillWp = ::getTblValue("wpCostWeaponRefill", containerLog, 0)
    local wRefillGold = ::getTblValue("goldCostWeaponRefill", containerLog, 0)
    if (wRefillWp || wRefillGold)
    {
      desc += "\n" + ::loc("shop/auto_buy_weapons_cost") + ::loc("ui/colon")
      desc += "<color=@activeTextColor>" + ::Cost(-wRefillWp, -wRefillGold).tostring() + "</color>"
      wp -= wRefillWp
      gold -= wRefillGold
    }

    local rp = 0
    if ("rpEarned" in log)
    {
      local descUnits = ""
      local descMods = ""

      local idx = 0
      while (("aname"+idx) in log.rpEarned)
      {
        local unitId = log.rpEarned["aname"+idx]
        local modId = (("mname"+idx) in log.rpEarned) ? log.rpEarned["mname"+idx] : null
        local mrp = log.rpEarned["mrp"+idx]

        local fromExcessRP = ("merp" + idx) in log.rpEarned ? log.rpEarned["merp" + idx] : 0
        rp += mrp + fromExcessRP

        local title = ::getUnitName(unitId) + (modId ? (" - " + ::getModificationName(getAircraftByName(unitId), modId)) : "")
        local item = "\n" + title + ::loc("ui/colon") + "<color=@activeTextColor>" +
          ::Cost().setRp(mrp).tostring() + "</color>"

        if (fromExcessRP > 0)
          item += " + " + ::loc("userlog/excessExpEarned") + ::loc("ui/colon") +
            "<color=@activeTextColor>" + ::Cost().setRp(fromExcessRP).tostring() + "</color>"

        if (!modId)
          descUnits += item
        else
          descMods += item

        idx++
      }

      if (descUnits.len())
        desc += "\n\n<color=@activeTextColor>" + ::loc("debriefing/researched_unit") + ::loc("ui/colon") + "</color>" + descUnits
      if (descMods.len())
        desc += "\n\n<color=@activeTextColor>" + ::loc("debriefing/research_list") + ::loc("ui/colon") + "</color>" + descMods
    }

    if (::getTblValue("haveTeamkills", log, false))
      desc += ((desc!="")? "\n\n":"") + "<color=@activeTextColor>" + ::loc("debriefing/noAwardsCaption") + "</color>"

    local usedItems = []

    if ("affectedBoosters" in log)
    {
      local affectedBoosters = log.affectedBoosters
      // Workaround for a bug (duplicating 'affectedBoosters' blocks),
      // which doesn't even exist on Production. Please remove it after ~ 2015-09-25:
      if (type(affectedBoosters) == "array")
        affectedBoosters = affectedBoosters.top()

      local activeBoosters = ::getTblValue("activeBooster", affectedBoosters, [])
      if (type(activeBoosters) == "table")
        activeBoosters = [ activeBoosters ]

      if (activeBoosters.len() > 0)
        foreach(effectType in ::BoosterEffectType)
        {
          local boostersArray = []
          foreach(idx, block in activeBoosters)
          {
            local item = ::ItemsManager.findItemById(block.itemId)
            if (item && effectType.checkBooster(item))
              boostersArray.append(item)
          }

          if (boostersArray.len())
            usedItems.append(::ItemsManager.getActiveBoostersDescription(boostersArray, effectType))
        }

      if (usedItems.len())
        desc += "\n\n" + ::colorize("activeTextColor", ::loc("debriefing/used_items") + ::loc("ui/colon")) +
          "\n" + ::g_string.implode(usedItems, "\n")
    }


    if ("tournamentResult" in log)
    {
      local now = ::getTblValue("newStat", log.tournamentResult)
      local was = ::getTblValue("oldStat", log.tournamentResult)
      local lbDiff = ::leaderboarsdHelpers.getLbDiff(now, was)
      local items = []
      foreach (lbFieldsConfig in ::events.eventsTableConfig)
      {
        if (!(lbFieldsConfig.field in now))
          continue

        items.append(::getLeaderboardItemView(lbFieldsConfig,
                                                 now[lbFieldsConfig.field],
                                                 ::getTblValue(lbFieldsConfig.field, lbDiff, null)))
      }
      local lbStatsBlk = ::getLeaderboardItemWidgets({ items = items })
      if (!("descriptionBlk" in res))
        res.descriptionBlk <- ""
      res.descriptionBlk += ::format("tdiv { width:t='pw'; flow:t='h-flow'; %s }", lbStatsBlk)
    }

    local totalText = res.tooltip = (log.type==::EULT_SESSION_RESULT)? ::loc("debriefing/total") : ::loc("userlog/interimResults")
    totalText = "<color=@userlogColoredText>" + totalText + ::loc("ui/colon") + "</color>"

    local total = ::Cost(wp, gold, xp, rp).toStringWithParams({isWpAlwaysShown = true})
    totalText += "<color=@activeTextColor>" + total + "</color>"

    desc += "\n\n" + totalText
    res.tooltip += ::loc("ui/colon") + "<color=@activeTextColor>" + total + "</color>"

    if (log.type == ::EULT_SESSION_RESULT || log.type == ::EULT_EARLY_SESSION_LEAVE)
    {
      local ecSpawnScore = ::getTblValue("ecSpawnScore", log, 0)
      if (ecSpawnScore > 0)
        desc += "\n" + "<color=@userlogColoredText>" + ::loc("debriefing/total/ecSpawnScore") +  ::loc("ui/colon") + "</color>"
                + "<color=@activeTextColor>" + ecSpawnScore + "</color>"
      local wwSpawnScore = log?.wwSpawnScore ?? 0
      if (wwSpawnScore > 0)
        desc += "\n"
          + ::colorize("@userlogColoredText", ::loc("debriefing/total/wwSpawnScore")
            + ::loc("ui/colon"))
          + ::colorize("@activeTextColor", wwSpawnScore)
    }

    if (desc!="")
      res.description <- desc

    local exp = "xpFirstWinInDayMul" in log? log["xpFirstWinInDayMul"] : 1.0
    local wp = "wpFirstWinInDayMul" in log? log["wpFirstWinInDayMul"] : 1.0

    if(exp > 1.0 || wp > 1.0)
      res["log_bonus"] <- getBonus(exp, wp, "item", "Log")

    if (::has_feature("ServerReplay"))
      if (::getTblValue("dedicatedReplay", log, false))
      {
        if (!("descriptionBlk" in res))
          res.descriptionBlk <- ""
        res.descriptionBlk += ::get_link_markup(::loc("mainmenu/btnViewServerReplay"),
                                                ::loc("url/serv_replay", {roomId = log.roomId}), "Y")
      }
  }
  else if (log.type==::EULT_AWARD_FOR_PVE_MODE)
  {
    if ("country" in log)
      if (::checkCountry(log.country, "userlog EULT_AWARD_FOR_PVE_MODE, " + log.mission))
        res.logImg2 = ::get_country_icon(log.country)

    local nameLoc = "userlog/" + logName
    local nameLocPostfix = ""
    local win = ("win" in log) && log.win

    if ("spectator" in log)
    {
      res.logImg = "#ui/gameuiskin#player_spectator"
      nameLocPostfix = " " + ::loc("multiplayer/team_won") + ::loc("ui/colon")
        + (win ? ::g_team.A.getNameInPVE() : ::g_team.B.getNameInPVE())
    }
    else
    {
      res.logImg = "#ui/gameuiskin#" + (win? "log_win" : "log_lose")
      nameLoc += win? "/win":"/lose"
    }

    local mission = ::get_mission_name(log.mission, log)
    res.name = ::loc(nameLoc, { mode = ::loc("multiplayer/"+log.mode+"Mode"), mission = mission }) + nameLocPostfix

    local desc = ""
    local earnedText = ::Cost(log?.wpEarned ?? 0, 0, 0, log?.xpEarned ?? 0)
      .toStringWithParams({isWpAlwaysShown = true})
    if (earnedText!="")
    {
      earnedText = ::loc("debriefing/total") + ::loc("ui/colon") + earnedText
      desc += ((desc!="")? "\n":"") + earnedText
    }
    if (desc!="")
    {
      res.description <- desc
      res.tooltip = desc
    }
  } else
  if (log.type==::EULT_BUYING_AIRCRAFT)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#log_buy_aircraft"
    local country = ::getShopCountry(log.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_REPAIR_AIRCRAFT)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#log_repair_aircraft"
    local country = ::getShopCountry(log.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_REPAIR_AIRCRAFT_MULTI)
  {
    if (("postSession" in log) && log.postSession)
      logName += "_auto"
    local totalCost = 0
    local desc = ""
    local idx = 0
    local country = ""
    local oneCountry = true
    while (("aname"+idx) in log) {
      if (desc!="") desc+="\n"
      local airName = log["aname"+idx]
      desc += ::getUnitName(airName) + ::loc("ui/colon") +
        ::Cost(log["cost"+idx]).toStringWithParams({isWpAlwaysShown = true})
      totalCost += log["cost"+idx]
      if (oneCountry)
      {
        local c = ::getShopCountry(airName)
        if (idx==0)
          country = c
        else
          if (country!=c)
            oneCountry = false
      }
      idx++
    }
    priceText = ::Cost(totalCost).tostring()
    if (priceText!="")  priceText = " ("+priceText+")"
    res.name = ::loc("userlog/"+logName) + priceText
    if (desc!="")
    {
      res.description <- desc
      res.tooltip = desc
    }
    res.logImg = "#ui/gameuiskin#log_repair_aircraft"
    if (oneCountry && ::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_BUYING_WEAPON || log.type==::EULT_BUYING_WEAPON_FAIL)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#" + ((log.type==::EULT_BUYING_WEAPON)? "log_buy_weapon" : "log_refill_weapon_no_money")
    if (("wname" in log) && ("aname" in log))
    {
      res.description <- ::getWeaponNameText(log.aname, false, log.wname, ", ")
      if ("count" in log && log.count > 1)
        res.description += " x" + log.count
      res.tooltip = res.description
    }
  } else
  if (log.type==::EULT_BUYING_WEAPONS_MULTI)
  {
    local auto = !("autoMode" in log) || log.autoMode
    if (auto)
      res.name = ::loc("userlog/buy_weapons_auto") + priceText
    else
      res.name = format(::loc("userlog/buy_weapon"), log.rawin("aname0") ? ::getUnitName(log.aname0) : "") + priceText

    res.description <- ""
    local idx = 0
    local airDesc = {}
    do {
      local desc = ""

      if(log.rawin("aname"+idx) && log.rawin("wname"+idx))
      {
        desc = ::getWeaponNameText(log["aname"+idx], false, log["wname"+idx], ", ")
        local wpCost = 0
        local goldCost = 0
        if(log.rawin("wcount"+idx))
        {
          if(log.rawin("wwpCost"+idx))
            wpCost = log["wwpCost"+idx]
          if(log.rawin("wgoldCost"+idx))
            goldCost = log["wgoldCost"+idx]

          desc += " x" + log["wcount"+idx] + " " +::Cost(wpCost, goldCost).tostring()
        }
        if (log["aname"+idx] in airDesc)
          airDesc[log["aname"+idx]] += "\n" + desc
        else
          airDesc[log["aname"+idx]] <- desc
      }

      idx++
    } while (("wname"+idx) in log)

    if (auto)
    {
      idx = 0
      do {
        local desc = ""
        if(log.rawin("maname"+idx) && log.rawin("mname"+idx))
        {
          desc += ::getModificationName(getAircraftByName(log["maname"+idx]), log["mname"+idx])
          local wpCost = 0
          local goldCost = 0
          if(log.rawin("mcount"+idx))
          {
            if(log.rawin("mwpCost"+idx))
              wpCost = log["mwpCost"+idx]
            if(log.rawin("mgoldCost"+idx))
              goldCost = log["mgoldCost"+idx]

            desc += " x" + log["mcount"+idx] + " " + ::Cost(wpCost, goldCost).tostring()
          }
          if (log["maname"+idx] in airDesc)
            airDesc[log["maname"+idx]] += "\n" + desc
          else
            airDesc[log["maname"+idx]] <- desc
          }
        idx++
      } while (("mname"+idx) in log)
    }

    foreach (aname, iname in airDesc)
    {
      if (res.description != "" )
        res.description += "\n\n"
      if (auto)
        res.description += ::colorize("activeTextColor", ::getUnitName(aname)) + ::loc("ui/colon") + "\n"
      res.description += iname
    }

    res.tooltip = res.description
    res.logImg = "#ui/gameuiskin#log_buy_weapon"
  } else
  if (log.type==::EULT_NEW_RANK)
  {
    if (("country" in log) && log.country!="common" && ::checkCountry(log.country, "EULT_NEW_RANK"))
    {
      res.logImg2 = ::get_country_icon(log.country)
      res.name = format(::loc("userlog/"+logName+"/country"), log.newRank.tostring())
    } else
    {
      res.logImg = "#ui/gameuiskin#prestige0"
      res.name = format(::loc("userlog/"+logName), log.newRank.tostring())
    }
  } else
  if (log.type==::EULT_BUYING_SLOT || log.type==::EULT_TRAINING_AIRCRAFT || log.type==::EULT_UPGRADING_CREW
      || log.type==::EULT_SPECIALIZING_CREW || log.type==::EULT_PURCHASINGSKILLPOINTS)
  {
    local crew = get_crew_by_id(log.id)
    local crewName = crew? (crew.idInCountry+1).tostring() : "?"
    local country = crew? crew.country : ("country" in log)? log.country : ""
    local airName = ("aname" in log)? ::getUnitName(log.aname) : ("aircraft" in log)? ::getUnitName(log.aircraft) : ""
    if (::checkCountry(country, "userlog EULT_*_CREW"))
      res.logImg2 = ::get_country_icon(country)
    res.logImg = "#ui/gameuiskin#log_crew"

    res.name = ::loc("userlog/"+logName,
                         { skillPoints = ::getCrewSpText(::getTblValue("skillPoints", log, 0)),
                           crewName = crewName,
                           unitName = airName
                         })
    res.name += priceText

    if (log.type==::EULT_UPGRADING_CREW)
    {
      ::load_crew_skills_once()
      local desc = ""
      local total = 0
      foreach(page in ::crew_skills)
        if ((page.id in log) && log[page.id].len()>0)
        {
          desc+=((desc!="")? "\n":"") + ::loc("crew/"+page.id) + ::loc("ui/colon")
          foreach(item in page.items)
            if (item.name in log[page.id])
            {
              desc+=((desc!="")? "\n":"") + ::nbsp + ::nbsp + "+" + log[page.id][item.name] +" "+ ::loc("crew/"+item.name)
              total += log[page.id][item.name]
            }
        }
      res.name += format(" (+%d %s)", total, ::loc("userlog/crewLevel"))
      if (desc!="")
      {
        res.description <- desc
        res.tooltip = desc
      }
    }
  } else
  if (log.type==::EULT_BUYENTITLEMENT)
  {
    local ent = ::get_entitlement_config(log.name)
    if ("cost" in log)
      ent["goldCost"] <- log.cost
    local costText = ::get_entitlement_price(ent)
    if (costText!="")
      costText = " (" + costText + ")"

    res.name = format(::loc("userlog/"+logName), ::get_entitlement_name(ent)) + costText
    res.logImg = "#ui/gameuiskin#log_online_shop"
  } else
  if (log.type == ::EULT_NEW_UNLOCK)
  {
    local config = build_log_unlock_data(log)

    res.name = config.title
    if (config.name!="")
      res.name += ::loc("ui/colon") + "<color=@userlogColoredText>" + config.name + "</color>"
    res.logImg = config.image
    if ("country" in log && ::checkCountry(log.country, "EULT_NEW_UNLOCK"))
      res.logImg2 = ::get_country_icon(log.country)

    local desc = ""
    if ("desc" in config)
    {
      desc = config.desc
      res.tooltip = config.desc
    }

    if ("unit" in log)
    {
      local unitName = ::getUnitName(log.unit, false)
      desc += ((desc=="")? "":"\n") + ::loc("userlog/used_vehicled") + ::loc("ui/colon") + unitName
    }

    if (config.rewardText != "")
    {
      res.name += ::loc("ui/parentheses/space", {text = config.rewardText})
      desc += ((desc=="")? "":"\n\n") + ::loc("challenge/reward") + " " + config.rewardText
    }

    if (desc != "")
      res.description <- desc

    if (("descrImage" in config) && config.descrImage!="")
    {
      local imgSize = ("descrImageSize" in config)? config.descrImageSize : "0.05sh, 0.05sh"
      res.descriptionBlk <- format(imgFormat, imgSize, config.descrImage)
    }
    if ((config.type == ::UNLOCKABLE_SLOT ||
         config.type == ::UNLOCKABLE_AWARD)
         && "country" in log)
      res.logImg2 = ::get_country_icon(log.country)

    if (config.type == ::UNLOCKABLE_SKILLPOINTS && config.image2 != "")
      res.logImg2 = config.image2
  } else
  if (log.type==::EULT_BUYING_MODIFICATION || log.type == ::EULT_BUYING_MODIFICATION_FAIL)
  {
    res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    res.logImg = "#ui/gameuiskin#" + ((log.type==::EULT_BUYING_MODIFICATION)? "log_buy_mods" : "log_refill_weapon_no_money")
    if (("mname" in log) && ("aname" in log))
    {
      res.description <- ::getModificationName(getAircraftByName(log.aname), log.mname)
      if ("count" in log && log.count > 1)
        res.description += " x" + log.count

      local xpEarnedText = ("xpEarned" in log)? ::Cost().setRp(log.xpEarned).tostring() : ""
      if (xpEarnedText!="")
      {
        xpEarnedText = ::loc("reward") + ::loc("ui/colon") + "<color=@activeTextColor>" + xpEarnedText + "</color>"
        res.description += ((res.description!="")? "\n":"") + xpEarnedText
      }
      res.tooltip = res.description
    }
  } else
  if (log.type==::EULT_BUYING_SPARE_AIRCRAFT)
  {
    local count = ::getTblValue("count", log, 1)
    if (count == 1)
      res.name = format(::loc("userlog/"+logName), ::getUnitName(log.aname)) + priceText
    else
      res.name = ::loc("userlog/"+logName+"/multiple", {
                     numSparesColored = ::colorize("userlogColoredText", count)
                     numSpares = count
                     unitName = ::colorize("userlogColoredText", ::getUnitName(log.aname))
                   }) + priceText
    res.logImg = "#ui/gameuiskin#log_buy_spare_aircraft"
    local country = ::getShopCountry(log.aname)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  } else
  if (log.type==::EULT_CLAN_ACTION)
  {
    res.logImg = "#ui/gameuiskin#log_clan_action"
    local info = {
      action = ::getTblValue("clanActionType", log, -1)
      clan = ("clanName" in log)? ::ps4CheckAndReplaceContentDisabledText(log.clanName) : ""
      player = ::getTblValue("initiatorNick", log, "")
      role = ("role" in log)? ::loc("clan/"+clan_get_role_name(log.role)) : ""
      status = ("enabled" in log) ? ::loc("clan/" + (log.enabled ? "opened" : "closed")) : ""
      tag = ::getTblValue("clanTag", log, "")
      tagOld = ::getTblValue("clanTagOld", log, "")
      clanOld = ("clanNameOld" in log)? ::ps4CheckAndReplaceContentDisabledText(log.clanNameOld) : ""
      sizeIncrease = ::getTblValue("sizeIncrease", log, -1)
    }
    local typeTxt = getClanActionName(info.action)
    res.name = ::loc("userlog/"+logName+"/"+typeTxt, info) + priceText

    if ("comment" in log && log.comment!="")
    {
      res.description <- ::loc("clan/userlogComment") + "\n" + ::ps4CheckAndReplaceContentDisabledText(::g_chat.filterMessageText(log.comment, false))
      res.tooltip = res.description
    }
  } else
  if (log.type==::EULT_BUYING_RESOURCE || log.type==::EULT_BUYING_UNLOCK)
  {
    local config = ::create_default_unlock_data()
    local resourceType = ""
    local decoratorType = null
    if (log.type==::EULT_BUYING_RESOURCE)
    {
      resourceType = log.resourceType
      config = ::get_decorator_unlock(log.resourceId, log.resourceType)
      decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
    }
    else if (log.type==::EULT_BUYING_UNLOCK)
    {
      config = build_log_unlock_data(log)
      resourceType = get_name_by_unlock_type(config.type)
    }

    res.name = format(::loc("userlog/"+logName+"/"+resourceType), config.name) + priceText

    local desc = ""
    if (decoratorType)
      desc = decoratorType.getLocDesc(config.id)

    if (!::u.isEmpty(desc))
      res.description <- desc

    res.logImg = config.image

    if (::getTblValue("descrImage", config, "") != "")
    {
      local imgSize = ::getTblValue("descrImageSize", config, "0.05sh, 0.05sh")
      res.descriptionBlk <- ::format(imgFormat, imgSize, config.descrImage)
    }
  }
  else if (log.type==::EULT_CHARD_AWARD)
  {
    local rewardType = ::getTblValue("rewardType", log, "")
    res.name = ::loc("userlog/" + rewardType)
    res.description <- ::loc("userlog/" + ::getTblValue("name", log, ""))

    local wp = log?.wpEarned ?? 0, gold = log?.goldEarned ?? 0, exp = log?.xpEarned ?? 0
    local reward = ::Cost(wp.tointeger(), gold.tointeger(), 0, exp.tointeger()).tostring()
    if (reward != "")
      res.description += " <color=@activeTextColor>" + reward + "</color>"

    local idx = 0
    local lineReward = ""
    while (("chardReward"+idx) in log)
    {
      local blk = log["chardReward"+idx]

      if ("country" in blk)
        lineReward += ::loc(blk.country) + ::loc("ui/colon")

      if ("name" in blk)
        lineReward += ::loc(blk.name)+" "

      if ("aname" in blk)
      {
        lineReward += ::getUnitName(blk.aname) + ::loc("ui/colon")
        if ("wname" in blk)
          lineReward += ::getWeaponNameText(blk.aname, false, blk.wname, ::loc("ui/comma")) + " "
        if ("mname" in blk)
          lineReward += ::getModificationName(getAircraftByName(blk.aname), blk.mname)+" "
      }

      local wp = blk?.wpEarned ?? 0,  gold = blk?.goldEarned ?? 0, exp = blk?.xpEarned ?? 0
      local reward = ::Cost(wp.tointeger(), gold.tointeger()).tostring()
      if (exp)
      {
        local changeLightToXP = blk?.name == ::MSG_FREE_EXP_DENOMINATE_OLD
        reward += ((reward!="")? ", ":"") + ( changeLightToXP ?
          (exp + " <color=@white>" + ::loc("mainmenu/experience/oldName") + "</color>")
          : ::Cost().setRp(exp.tointeger()).tostring())
      }

      lineReward += reward
      if (lineReward != "")
        lineReward += "\n"

      idx++
    }

    if ("clanDuelReward" in log)
    {
      local rewardBlk = log.clanDuelReward

      local difficultyStr = ::loc(::getTblValue("difficulty", rewardBlk, ""))
      lineReward += ::loc("difficulty_name") + " <color=@white>" + difficultyStr +
          "</color>\n"

      if ("era" in rewardBlk)
      {
        local era = rewardBlk.era
        lineReward += ::loc("userLog/clanDuelRewardRank") + " <color=@white>" + era +
            "</color>\n"
      }

      local clanPlace = ::getTblValue("clanPlace", rewardBlk, -1)

      local clanRating = ::getTblValue("clanRating", rewardBlk, -1)

      //show rating only for place reward due for rating-reward rating showed in header
      if (clanPlace > 0)
        lineReward += ::loc("userLog/clanDuelRewardClanRating") + " <color=@white>" + clanRating +
            "</color>\n"

      local equalClanPlacesCount = ::getTblValue("equalClanPlacesCount", rewardBlk, -1)
      if (equalClanPlacesCount > 1)
      {
        lineReward += ::loc("userLog/clanDuelRewardEqualClanPlaces") + " <color=@white>" +
            (equalClanPlacesCount - 1) + "</color>\n"
      }

      res.description = ""
      local rewardCurency = ::Cost(wp, gold, exp).tostring()
      if (rewardCurency != "")
        res.description += ::loc("reward") + ::loc("ui/colon") + " " + ::colorize("activeTextColor", rewardCurency)

      //We don't want ~100 localization strings like "Your squadron took Nth place.".
      //So we left unique localizations only for top 3.
      if (clanPlace > 3)
        res.name = ::loc("userlog/ClanSeasonRewardPlaceN", {place = clanPlace.tostring()})
      else if (clanPlace > 0)
        res.name = ::loc("userlog/ClanSeasonRewardPlace" + clanPlace.tostring())
      else if (clanRating > 0)
        res.description = ::loc("userlog/ClanRewardRatingReached", {rating = clanRating.tostring()})


      local place = ::getTblValue("place", rewardBlk, -1)
      if (place > 0)
        lineReward += ::loc("userLog/clanDuelRewardPlace") + " <color=@white>" + place +
            "</color>\n"

      local rating = round(rewardBlk.rating);
      lineReward += ::loc("userLog/clanDuelRewardRating") + " <color=@white>" + rating +
            "</color>\n"

      local equalPlacesCount = ::getTblValue("equalPlacesCount", rewardBlk, -1)
      if (equalPlacesCount > 1)
      {
        lineReward += ::loc("userLog/clanDuelRewardEqualPlaces") + " <color=@white>" +
            (equalPlacesCount - 1) + "</color>\n"
      }

      local config = {
        locId = "clan_duel_reward"
        subType = ps4_activity_feed.CLAN_DUEL_REWARD
      }
      local customConfig = {
        gold = gold
        place = place
        blkParamName = "CLAN_DUEL_REWARD"
      }

      ::prepareMessageForWallPostAndSend(config, customConfig, bit_activity.PS4_ACTIVITY_FEED)

      if ("resource" in rewardBlk)
      {
        //after convertation from DataBlk to table array with 1 element bocomes
        //table. So we normalize data format.
        if (::u.isTable(rewardBlk.resource))
          rewardBlk.resource = [clone rewardBlk.resource]

        local resourcesImagesMarkup = ""
        for (local i = 0; i < rewardBlk.resource.len(); ++i)
        {
          local unlock = ::get_decorator_unlock(
            rewardBlk.resource[i].resourceId,
            rewardBlk.resource[i].resourceType
          )

          if (!::u.isEmpty(unlock.desc))
          {
            if (!("description" in  res))
              res.description <- ""
            else
              res.description += "\n\n"
            res.description += unlock.desc
          }

          res.logImg = unlock.image

          if (::getTblValue("descrImage", unlock, "") != "")
          {
            local imgSize = ::getTblValue("descrImageSize", unlock, "0.05sh, 0.05sh")
            resourcesImagesMarkup += ::format(imgFormat, imgSize, unlock.descrImage)
          }
        }

        if (resourcesImagesMarkup.len())
        {
          resourcesImagesMarkup = "tdiv { flow:t='h-flow'; width:t='pw';" + resourcesImagesMarkup + "}"
          res.descriptionBlk <- resourcesImagesMarkup
        }
      }

    }

    if (rewardType == "EveryDayLoginAward")
    {
      local prefix = "trophy/"
      local pLen = prefix.len()
      res.name += ::loc("ui/parentheses/space", {
            text = ::colorize("userlogColoredText", ::loc("enumerated_day", {
                number = ::getTblValue("progress", log, 0) + (::getTblValue("daysFor0", log, 0)-1)
              }))})

      local name = log.chardReward0.name
      local itemId = (name.len() > pLen && name.slice(0, pLen) == prefix) ? name.slice(pLen) : name
      local item = ::ItemsManager.findItemById(itemId)
      if (item)
        lineReward = ::colorize("activeTextColor", item.getName())
      res.logImg = ::items_classes.Trophy.typeIcon
      res.descriptionBlk <- ::get_userlog_image_item(item)
    }
    else if (::isInArray(rewardType, ["WagerStageWin", "WagerStageFail", "WagerWin", "WagerFail"]))
    {
      local itemId = ::getTblValue("id", log)
      local item = ::ItemsManager.findItemById(itemId)
      if (item)
      {
        if (::isInArray(rewardType, ["WagerStageWin", "WagerStageFail"]))
          res.name += ::loc("ui/colon") + ::colorize("userlogColoredText", item.getName())
        else
          res.name = ::loc("userlog/" + rewardType, {wagerName = ::colorize("userlogColoredText", item.getName())})

        local desc = []
        desc.append(::loc("items/wager/numWins", { numWins = ::getTblValue("numWins", log), maxWins = item.maxWins }))
        desc.append(::loc("items/wager/numFails", {numFails = ::getTblValue("numFails", log), maxFails = item.maxFails}))

        res.logImg = "#ui/gameuiskin#unlock_achievement"
        res.description += (res.description == ""? "" : "\n") + ::g_string.implode(desc, "\n")
        res.descriptionBlk <- ::get_userlog_image_item(item)
      }
    }
    else if (rewardType == "TournamentReward")
    {
      local result = ::getTournamentRewardData(log)
      local desc = []
      foreach(rewardBlk in result)
        desc.append(::EventRewards.getConditionText(rewardBlk))

      lineReward = ::EventRewards.getTotalRewardDescText(result)
      res.description = ::g_string.implode(desc, "\n")
      res.name = ::loc("userlog/" + rewardType, {
                         name = ::colorize("userlogColoredText", ::events.getNameByEconomicName(::getTblValue("name", log)))
                       })
    }

    if (lineReward != "")
      res.description += (res.description == ""? "" : "\n") + lineReward
  } else
  if (log.type==::EULT_ADMIN_ADD_GOLD || log.type==::EULT_ADMIN_REVERT_GOLD)
  {
    local comment="", goldAdd=0, goldBalance=0
    if ("comment" in log)
      comment = log.comment
    if ("goldAdd" in log)
      goldAdd = log.goldAdd
    if ("goldBalance" in log)
      goldBalance = log.goldBalance

    local suffix = (goldAdd >= 0) ? "/positive" : "/negative"
    res.name = ::loc("userlog/"+logName+suffix, { gold = ::Cost(0, abs(goldAdd)).toStringWithParams({isGoldAlwaysShown = true}),
      balance = ::getGpPriceText(goldBalance, true) })
    res.description <- comment  // not localized
  }
  else if(log.type == ::EULT_BUYING_SCHEME)
  {
    res.description <- ::getUnitName(log.unit) + priceText
  }
  else if (log.type == ::EULT_OPEN_ALL_IN_TIER)
  {
    local locTbl = {
      unitName = ::getUnitName(log.unit)
      tier = ::get_roman_numeral(log.tier)
      exp = 0
    }

    local desc = ""
    if ("expToInvUnit" in log && "resUnit" in log)
    {
      locTbl.resUnitExpInvest <- ::Cost().setRp(log.expToInvUnit).tostring()
      locTbl.resUnitName <- ::getUnitName(log.resUnit)
      desc = "\n" + ::loc("userlog/"+logName+"/resName", locTbl)
      locTbl.exp += log.expToInvUnit
    }

    if ("expToExcess" in log)
    {
      locTbl.expToExcess <- ::Cost().setRp(log.expToExcess).tostring()
      desc += "\n" + ::loc("userlog/"+logName+"/excessName", locTbl)
      locTbl.exp += log.expToExcess
    }

    locTbl.exp = ::Cost().setRp(locTbl.exp).tostring()
    res.name <- ::loc("userlog/"+logName+"/name", locTbl)
    res.description <- ::loc("userlog/"+logName+"/desc", locTbl) + desc

    local country = ::getShopCountry(log.unit)
    if (::checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)
  }
  else if (log.type == ::EULT_BUYING_MODIFICATION_MULTI)
  {
    if ("maname0" in log)
      res.name = format(::loc("userlog/"+logName), ::getUnitName(getTblValue("maname0", log, ""))) + priceText
    else
      res.name = format(::loc("userlog/"+logName), "")
    res.logImg = "#ui/gameuiskin#" + "log_buy_mods"

    res.description <- ""
    local idx = 0
    local airDesc = {}

    idx = 0
    do {
      local desc = ""
      if(log.rawin("maname"+idx) && log.rawin("mname"+idx))
      {
        desc += ::getModificationName(getAircraftByName(log["maname"+idx]), log["mname"+idx])
        local wpCost = 0
        local goldCost = 0
        if(log.rawin("mcount"+idx))
        {
          if(log.rawin("mwpCost"+idx))
            wpCost = log["mwpCost"+idx]
          if(log.rawin("mgoldCost"+idx))
            goldCost = log["mgoldCost"+idx]

          desc += " x" + log["mcount"+idx] + " " +::Cost(wpCost, goldCost).tostring()
        }
        if (log["maname"+idx] in airDesc)
          airDesc[log["maname"+idx]] += "\n" + desc
        else
          airDesc[log["maname"+idx]] <- desc
      }
      idx++
    } while (("mname"+idx) in log)

    foreach (aname, iname in airDesc)
    {
      if (res.description != "" )
        res.description += "\n\n"
      res.description += ::colorize("activeTextColor", ::getUnitName(aname)) + ::loc("ui/colon") + "\n"
      res.description += iname
    }
    res.tooltip = res.description
  } else if (log.type == ::EULT_OPEN_TROPHY)
  {
    local itemId = log?.itemDefId || log?.id || ""
    local item = ::ItemsManager.findItemById(itemId)

    if (item)
    {
      logName = item?.userlogOpenLoc ?? logName

      local usedText = ::loc("userlog/" + logName + "/short")
      local rewardText = ::trophyReward.getRewardText(log)
      local reward = ::loc("reward") + ::loc("ui/colon") + rewardText

      res.name = usedText + " " + ::colorize("activeTextColor", item.getName()) + " " + ::loc("ui/parentheses/space", { text = reward })
      res.logImg = item.typeIcon

      res.descriptionBlk <- ::format(textareaFormat, ::g_string.stripTags(usedText) + ::loc("ui/colon"))
      res.descriptionBlk += item.getNameMarkup()
      res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon")))
      res.descriptionBlk += ::trophyReward.getRewardsListViewData(log)
    }
    else
      res.name = ::loc("userlog/"+logName, { trophy = ::loc("userlog/no_trophy"),
        reward = ::loc("userlog/trophy_deleted") })

    /*
    local prizes = ::trophyReward.getRewardList(log)
    if (prizes.len() == 1) //!!FIX ME: need to move this in PrizesView too
    {
      local prize = prizes[0]
      local prizeType = ::trophyReward.getRewardType(prize)

      if (::isInArray(prizeType, [ "gold", "warpoints", "exp", "entitlement" ]))
      {
        local color = prizeType == "entitlement" ? "userlogColoredText" : "activeTextColor"
        local title = ::colorize(color, rewardText)
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon") + title))
      }
      else if (prizeType == "item")
      {
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon")))
        res.descriptionBlk += ::get_userlog_image_item(::ItemsManager.findItemById(prize.item))
      }
      else if (prizeType == "unlock" && ::getTblValue("unlockType", log) == "decal")
      {
        local title = ::colorize("userlogColoredText", rewardText)
        local config = ::build_log_unlock_data({ id = log.unlock })
        local imgSize = ::getTblValue("descrImageSize", config, "0.05sh, 0.05sh")
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon") + title))
        res.descriptionBlk += format(imgFormat, imgSize, config.descrImage)
      }
      else
      {
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon")))
        res.descriptionBlk += ::PrizesView.getPrizesListView(prizes)
      }
    }
    else
    {
        res.descriptionBlk += ::format(textareaFormat, ::g_string.stripTags(::loc("reward") + ::loc("ui/colon")))
        res.descriptionBlk += ::PrizesView.getPrizesListView(prizes)
    }
    */
  }
  else if (log.type == ::EULT_BUY_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local locId = "userlog/" + logName + ((log.count > 1) ? "/multiple" : "")
    res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     price = ::Cost(log.cost * log.count, log.costGold * log.count).tostring()
                     amount = log.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item, {type = log.type})
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
  }
  else if (log.type == ::EULT_NEW_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local locId = "userlog/" + logName + ((log.count > 1) ? "/multiple" : "")
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
    res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     amount = log.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item, { count = log.count })
  }
  else if (log.type == ::EULT_ACTIVATE_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
    res.name = ::loc("userlog/" + logName, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                   })
    if ("itemType" in log && log.itemType == "wager")
    {
      local wager = 0;
      local wagerGold = 0;

      if ("wager" in log)
        wager = log.wager

      if ("wagerGold" in log)
        wagerGold = log.wagerGold

      if (wager > 0 || wagerGold > 0)
        res.description <- ::loc("userlog/" + logName + "_desc/wager") + " " +
          ::Cost(wager, wagerGold).tostring()
    }
    res.descriptionBlk <- ::get_userlog_image_item(item)
  }
  else if (log.type == ::EULT_REMOVE_ITEM)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local reason = ::getTblValue("reason", log, "unknown")
    local locId = "userlog/" + logName + "/" + reason
    if (reason == "replaced")
    {
      local replaceItemId = ::getTblValue("replaceId", log, "")
      local replaceItem = ::ItemsManager.findItemById(replaceItemId)
      res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     replacedItemName = ::colorize("userlogColoredText", replaceItem ? replaceItem.getName() : "")
                   })
      res.descriptionBlk <- ::get_userlog_image_item(item) + ::get_userlog_image_item(replaceItem)
    }
    else
    {
      res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                   })
      res.descriptionBlk <- ::get_userlog_image_item(item)
    }
    local itemType = ::getTblValue("itemType", log, "")
    if (itemType == "universalSpare")
    {
      locId = "userlog/" + logName
      local unit =  ::getTblValue("unit", log)
      if (unit != null)
        res.logImg2 = ::get_country_icon(::getShopCountry(unit))
      local numSpares = ::getTblValue("numSpares", log, 1)
      res.name = ::loc(locId + "_name/universalSpare", {
                     numSparesColored = ::colorize("userlogColoredText", numSpares)
                     numSpares = numSpares
                     unitName = (unit != null ? ::colorize("userlogColoredText", ::getUnitName(unit)) : "")
                   })
      res.descriptionBlk <- ::format(textareaFormat,
                                ::g_string.stripTags(::loc(locId + "_desc/universalSpare") + ::loc("ui/colon")))
      res.descriptionBlk += item.getNameMarkup(numSpares,true)
    }
    else if (itemType == "wager")
    {
      local earned = ::Cost(::getTblValue("wpEarned", log, 0), ::getTblValue("goldEarned", log, 0))
      if (earned > ::zero_money)
        res.description <- ::loc("userlog/" + logName + "_desc/wager") + " " + earned.tostring()
    }
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
  }
  else if (log.type == ::EULT_INVENTORY_ADD_ITEM)
  {
    local itemDefId = log?.itemDefId ?? ""
    local item = ::ItemsManager.findItemById(itemDefId)
    local numItems = log?.quantity ?? 1
    local locId = "userlog/" + logName
    res.logImg = (item && item.getSmallIconName() ) || ::BaseItem.typeIcon
    res.name = ::loc(locId, {
      numItemsColored = ::colorize("userlogColoredText", numItems)
      numItems = numItems
      numItemsAdd = numItems
      itemName = (item && item.getName()) ? item.getName() : ""
    })
    res.descriptionBlk <- ::get_userlog_image_item(item)
  }
  else if (log.type == ::EULT_TICKETS_REMINDER)
  {
    res.name = ::loc("userlog/"+logName) + ::loc("ui/colon") +
        ::colorize("userlogColoredText", ::events.getNameByEconomicName(log.name))

    local desc = []
    if (::getTblValue("battleLimitReminder", log))
      desc.append(::loc("userlog/battleLimitReminder") + ::loc("ui/colon") + log.battleLimitReminder)
    if (::getTblValue("defeatCountReminder", log))
      desc.append(::loc("userlog/defeatCountReminder") + ::loc("ui/colon") + log.defeatCountReminder)
    if (::getTblValue("sequenceDefeatCountReminder", log))
      desc.append(::loc("userlog/sequenceDefeatCountReminder") + ::loc("ui/colon") + log.sequenceDefeatCountReminder)

    res.description <- ::g_string.implode(desc, "\n")
  }
  else if (log.type == ::EULT_BUY_BATTLE)
  {
    res.name = ::loc("userlog/"+logName) + ::loc("ui/colon") +
      ::colorize("userlogColoredText", ::events.getNameByEconomicName(log.tournamentName))

    local cost = ::Cost()
    cost.wp = ::getTblValue("costWP", log, 0)
    cost.gold = ::getTblValue("costGold", log, 0)
    res.description <- ::loc("events/battle_cost", {cost = cost.tostring()})
  }
  else if (log.type == ::EULT_CONVERT_EXPERIENCE)
  {
    local logId = "userlog/"+logName

    res.logImg = "#ui/gameuiskin#convert_xp"
    local unitName = log["unit"]
    local country = ::getShopCountry(unitName)
    if (checkCountry(country, "getShopCountry"))
      res.logImg2 = ::get_country_icon(country)

    local cost = ::Cost()
    cost.wp = ::getTblValue("costWP", log, 0)
    cost.gold = ::getTblValue("costGold", log, 0)
    local exp = ::getTblValue("exp", log, 0)

    res.description <- ::loc(logId+"/desc", {cost = cost.tostring(), unitName = ::getUnitName(unitName),
      exp = ::Cost().setFrp(exp).tostring()})
  }
  else if (log.type == ::EULT_SELL_BLUEPRINT)
  {
    local itemId = ::getTblValue("id", log, "")
    local item = ::ItemsManager.findItemById(itemId)
    local locId = "userlog/" + logName + ((log.count > 1) ? "/multiple" : "")
    res.name = ::loc(locId, {
                     itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
                     price = ::Cost(log.cost * log.count, log.costGold * log.count).tostring()
                     amount = log.count
                   })
    res.descriptionBlk <- ::get_userlog_image_item(item)
  }
  else if (::isInArray(log.type, [::EULT_PUNLOCK_ACCEPT,
                                  ::EULT_PUNLOCK_CANCELED,
                                  ::EULT_PUNLOCK_EXPIRED,
                                  ::EULT_PUNLOCK_NEW_PROPOSAL,
                                  ::EULT_PUNLOCK_ACCEPT_MULTI]))
  {
    local locNameId = "userlog/"+logName
    local descr = ""
    if ((log.type == ::EULT_PUNLOCK_ACCEPT_MULTI || log.type == ::EULT_PUNLOCK_NEW_PROPOSAL) && "new_proposals" in log)
    {
      descr = ::g_battle_tasks.generateUpdateDescription(log.new_proposals)
      local singleProposal = log.new_proposals.len() == 1
      if (singleProposal)
        locNameId = "userlog/battle_tasks_accept"
      else
      {
        res.description <- descr
        descr = ""
      }
    }

    local taskName = descr
    local logId = ::getTblValue("id", log, "")
    if (logId != "")
      taskName = ::g_battle_tasks.getBattleTaskLocIdFromUserlog(log, logId)

    res.name = ::loc(locNameId, {taskName = taskName})
    res.logImg = "#ui/gameuiskin#battle_tasks_easy"
  }
  else if (log.type == ::EULT_PUNLOCK_REROLL_PROPOSAL && "new_proposals" in log)
  {
    local text = ::g_battle_tasks.generateUpdateDescription(log.new_proposals)
    if (log.new_proposals.len() == 1)
      res.name = ::loc("userlog/"+logName, {taskName = text})
    else
      res.description <- text
    res.logImg = "#ui/gameuiskin#battle_tasks_easy"
  }
  else if (log.type == ::EULT_CONVERT_BLUEPRINTS)
  {
    local locId = "userlog/"+logName
    res.name = ::loc(locId, {
                     from = ::loc("userlog/blueprintpart_name/" + ::getTblValue("from", log, ""))
                     to = ::loc("userlog/blueprintpart_name/" + ::getTblValue("to", log, ""))
                   })

    res.description <- ::loc(locId+"/desc")

    foreach(unitName, unitData in log)
    {
      if (!("result" in unitData))
        continue

      local resItem = ::ItemsManager.findItemById(unitData.result)
      res.description += "\n" + ::loc(unitName+"_0") + ::loc("ui/colon") + ::get_userlog_image_item(resItem)
      local idx = 0
      while (("source"+idx) in unitData)
      {
        local srcItem = ::ItemsManager.findItemById(unitData["source"+idx])
        res.description += ::get_userlog_image_item(srcItem)
        idx++
      }
    }
  }
  else if (log.type == ::EULT_RENT_UNIT || log.type == ::EULT_RENT_UNIT_EXPIRED)
  {
    local unitName = ::getTblValue("unit", log)
    if (unitName)
    {
      res.name = ::loc("userlog/"+logName, {unitName = ::loc(unitName + "_0")})
      if (log.type == EULT_RENT_UNIT)
      {
        res.description <- ""
        if ("rentTimeSec" in log)
          res.description += ::loc("mainmenu/rent/rentTimeSec",
            {time = time.hoursToString(time.secondsToHours(log.rentTimeSec)) })
      }
    }
  }
  else if (log.type == ::EULT_EXCHANGE_WARBONDS)
  {
    local awardData = ::getTblValue("award", log)
    if (awardData)
    {
      local priceText = ::g_warbonds.getWarbondPriceText(
                          ::getTblValue("warbond", log),
                          ::getTblValue("stage", log),
                          ::getTblValue("cost", awardData, 0)
                        )

      local awardBlk = ::DataBlockAdapter(awardData)
      local awardType = ::g_wb_award_type.getTypeByBlk(awardBlk)
      res.name = awardType.getUserlogBuyText(awardBlk, priceText)
    }
  }
  else if (log.type == ::EULT_WW_START_OPERATION || log.type == ::EULT_WW_CREATE_OPERATION)
  {
    local locId = log.type == ::EULT_WW_CREATE_OPERATION ? "worldWar/userlog/createOperation"
                                                         : "worldWar/userlog/startOperation"
    local operation = ""
    if (::is_worldwar_enabled())
      operation = ::WwOperation.getNameTextByIdAndMapName(
        ::getTblValue("operationId", log),
        ::WwMap.getNameTextByMapName(::getTblValue("mapName", log))
      )
    res.name = ::loc(locId,
      {
        clan = ::getTblValue("name", log)
        operation = operation
      })
  }
  else if (log.type == ::EULT_WW_END_OPERATION)
  {
    local textLocId = "worldWar/userlog/endOperation/"
    textLocId += ::getTblValue("winner", log) ? "win" : "lose"
    local mapName = ::getTblValue("mapName", log)
    local opId = ::getTblValue("operationId", log)
    local earnedText = ::Cost(::getTblValue("wp", log, 0)).toStringWithParams({isWpAlwaysShown = true})
    res.name = ::loc(textLocId, {
      opId = opId, mapName = ::loc("worldWar/map/" + mapName), reward = earnedText })

    local statsWpText = ::Cost(::getTblValue("wpStats", log, 0)).toStringWithParams({isWpAlwaysShown = true})
    res.description <- ::loc("worldWar/userlog/endOperation/stats", { reward = statsWpText })
  }


  if (::getTblValue("description", res, "") != "")
  {
    local textDescriptionBlk = ::format("textareaNoTab {" +
      "id:t='description';" +
      "width:t='pw';" +
      "text:t='%s';" +
    "}",
    ::g_string.stripTags(res.description))

    if (!("descriptionBlk" in res))
      res.descriptionBlk <- ""

    res.descriptionBlk = textDescriptionBlk + res.descriptionBlk
  }

  //------------- when userlog not found or not full filled -------------//
  if (res.name=="")
    res.name = ::loc("userlog/"+logName)
  if (res.tooltip=="")
    res.tooltip = res.name
  return res
}
