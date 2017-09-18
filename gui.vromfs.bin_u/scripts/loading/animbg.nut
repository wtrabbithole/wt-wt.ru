/* Data in config (gui.blk/loading_bg)

loading_bg
{
  //full layers list
  login_layer_a1:r = 2.0
  login_layer_b1:r = 2.0
  login_layer_c1:r = 2.0

  beforeLogin {  //ovverride chances before login
    default_chance:r=0  //default chance for all layers
    login_layer_r1:r = 2.0
  }

  tencent {  //override chances for tencent. applied after languages
    //default_chance:r=2.0
    login_layer_g1:r = 0
    login_layer_k1:r = 0

    beforeLogin {
      default_chance:r=0
      login_layer_q1:r = 2.0
    }
  }

  language {  //override chances by languages
    langsInclude  {
      lang:t="English"
      lang:t="Russian"
    }
    langsExclude {
      lang:t="English"
      lang:t="Russian"
    }
    //all languages if no langsInclude or langsExclude set

    platformInclude {
      platform:t="win32"
      platform:t="win64"
    }
    platformExclude {
      platform:t="win32"
      platform:t="win64"
    }
    //all platforms if no platformInclude or platformExclude set

    login_layer_g1:r = 0

    beforeLogin {
      default_chance:r=0
      login_layer_q1:r = 2.0
    }
  }
}
*/

local time = require("scripts/time.nut")

::g_anim_bg <- {
  bgList = {}
  bgListBeforeLogin = {}
  lastBg = ""
  inited = false

  defaultValueKey = "default_chance"
  beforeLoginBlockKey = "beforeLogin"

  debugLastModified = null
}

function g_anim_bg::load(animBgBlk = "", obj = null)
{
  initOnce()

  if (!obj)
    obj = ::get_cur_gui_scene()["animated_bg_picture"]
  if (!::checkObj(obj) || !bgList.len())
    return

  local curBgList = getCurBgList()
  if (animBgBlk!="")
    lastBg = animBgBlk
  else
    if (::g_login.isLoggedIn() || lastBg=="") //no change bg during first load
    {
      local sum = 0.0
      foreach(name, value in curBgList)
        sum += value
      sum = ::math.frnd() * sum
      foreach(name, value in curBgList)
      {
        lastBg = name
        sum -= value
        if (sum <= 0)
          break
      }
    }

  local animBgFile = getLastBgFileName()
  if (!::check_blk_images_by_file(animBgFile))
  {
    removeFromBgLists(lastBg)
    lastBg = ""
    load("", obj)
    return
  }

  obj.getScene().replaceContent(obj, animBgFile, this)
  debugLastModified = null
}

function g_anim_bg::getLastBgFileName()
{
  return lastBg.len() ? "config/loadingbg/" + lastBg + ".blk" : ""
}

function g_anim_bg::getCurBgList()
{
  return !::g_login.isLoggedIn() ? bgListBeforeLogin : bgList
}

function g_anim_bg::removeFromBgLists(name)
{
  if (name in bgList)
    delete bgList[name]
  if (name in bgListBeforeLogin)
    delete bgListBeforeLogin[name]
}

function g_anim_bg::reset()
{
  inited = false
}

function g_anim_bg::initOnce()
{
  if (inited)
    return
  inited = true

  bgList.clear()
  bgListBeforeLogin.clear()

  local blk = ::configs.GUI.get()

  local bgBlk = blk.loading_bg
  if (!bgBlk)
    return

  applyBlkToAllBgLists(bgBlk)

  local curLang = ::g_language.getLanguageName()
  foreach(langBlk in bgBlk % "language")
    if (::u.isDataBlock(langBlk))
      applyBlkByLang(langBlk, curLang)

  local presetBlk = bgBlk[::get_country_flags_preset()]
  if (::u.isDataBlock(presetBlk))
    applyBlkToAllBgLists(presetBlk)

  validateBgList(bgList)
  validateBgList(bgListBeforeLogin)
}

function g_anim_bg::applyBlkByLang(langBlk, curLang)
{
  local langsInclude = langBlk.langsInclude
  local langsExclude = langBlk.langsExclude
  if (::u.isDataBlock(langsInclude)
      && !::isInArray(curLang, langsInclude % "lang"))
    return
  if (::u.isDataBlock(langsExclude)
      && ::isInArray(curLang, langsExclude % "lang"))
    return

  local platformInclude = langBlk.platformInclude
  local platformExclude = langBlk.platformExclude
  if (::u.isDataBlock(platformInclude)
      && !::isInArray(::target_platform, platformInclude % "platform"))
    return
  if (::u.isDataBlock(platformExclude)
      && ::isInArray(::target_platform, platformExclude % "platform"))
   return

  ::dagor.assertf(!!(langsExclude || langsInclude || platformInclude || platformExclude),
    "AnimBG: Found block without language or platform permissions. it always override defaults.")

  applyBlkToAllBgLists(langBlk)
}

function g_anim_bg::applyBlkToAllBgLists(blk)
{
  applyBlkToBgList(bgList, blk)
  applyBlkToBgList(bgListBeforeLogin, blk)
  local beforeLoginBlk = blk[beforeLoginBlockKey]
  if (::u.isDataBlock(beforeLoginBlk))
    applyBlkToBgList(bgListBeforeLogin, beforeLoginBlk)
}

function g_anim_bg::applyBlkToBgList(list, blk)
{
  local defValue = blk[defaultValueKey]
  if (defValue != null)
    foreach(key, value in list)
      list[key] = defValue

  for (local i = 0; i < blk.paramCount(); i++)
    list[blk.getParamName(i)] <- blk.getParamValue(i)

  //to not check name for each added param
  if (defaultValueKey in list)
    delete list[defaultValueKey]
}

function g_anim_bg::validateBgList(list)
{
  local keys = ::u.keys(list)
  foreach(key in keys)
  {
    local validValue = ::to_float_safe(list[key], 0)
    if (validValue > 0.0001)
      list[key] = validValue
    else
      delete list[key]
  }
}

function g_anim_bg::onEventSignOut(p)
{
  lastBg = ""
}

function g_anim_bg::onEventGameLocalizationChanged(p)
{
  reset()
}

function g_anim_bg::enableDebugUpdate()
{
  local timerObj = ::get_cur_gui_scene()["debug_timer_update"]
  if (!::checkObj(timerObj))
    return false

  timerObj.setUserData(::g_anim_bg)
  return true
}

function g_anim_bg::onDebugTimerUpdate(obj, dt)
{
  local fileName = getLastBgFileName()
  if (!fileName.len())
    return
  local modified = ::get_file_modify_time(fileName)
  if (!modified)
    return

  modified = time.getFullTimeTable(modified)
  if (!debugLastModified)
  {
    debugLastModified = modified
    return
  }

  if (!time.cmpDate(debugLastModified, modified))
    return

  debugLastModified = modified
  load(lastBg)
}

function g_anim_bg::debugLoading(animBgBlk = "")
{
  ::gui_start_loading()
  load(animBgBlk)
  enableDebugUpdate()
}

::subscribe_handler(::g_anim_bg)
