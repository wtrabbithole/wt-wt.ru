/* Data in config (gui.blk/loading_bg)

loading_bg
{
  reserveBg:t='login_layer_c1' //layer loaded behind current to be visible while current images not full loaded

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

local fileCheck = require("scripts/clientState/fileCheck.nut")

local createBgData = @() {
  list = {}
  reserveBg = ""
}

::g_anim_bg <- {
  bgDataBeforeLogin = createBgData()
  bgDataAfterLogin = createBgData()
  lastBg = ""
  inited = false

  RESERVE_BG_KEY = "reserveBg"
  DEFAULT_VALUE_KEY = "default_chance"
  BLOCK_BEFORE_LOGIN_KEY = "beforeLogin"

  isDebugMode = false
  debugLastModified = -1
}

function g_anim_bg::load(animBgBlk = "", obj = null)
{
  initOnce()

  if (!obj)
    obj = ::get_cur_gui_scene()["animated_bg_picture"]
  if (!::check_obj(obj))
    return

  local curBgData = getCurBgData()
  local curBgList = curBgData.list
  if (!curBgList.len())
    return

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

  local bgBlk = loadBgBlk(lastBg)
  if (!bgBlk)
  {
    lastBg = ""
    load("", obj)
    return
  }

  if (!isDebugMode && !fileCheck.isAllBlkImagesPrefetched(bgBlk)
    && curBgData.reserveBg.len())
    bgBlk = loadBgBlk(curBgData.reserveBg) || bgBlk

  obj.getScene().replaceContentFromDataBlock(obj, bgBlk, this)
  debugLastModified = -1
}

function g_anim_bg::getFullFileName(name)
{
  return "config/loadingbg/" + name + ".blk"
}

function g_anim_bg::loadBgBlk(name)
{
  local res = ::DataBlock()
  if (!res.load(getFullFileName(name)))
  {
    res = null
    removeFromBgLists(name)
    ::dagor.assertf(false, "Error: cant load login bg blk: " + getFullFileName(name))
  }
  return res
}

function g_anim_bg::getLastBgFileName()
{
  return lastBg.len() ? getFullFileName(lastBg) : ""
}

function g_anim_bg::getCurBgData()
{
  return !::g_login.isLoggedIn() ? bgDataBeforeLogin : bgDataAfterLogin
}

function g_anim_bg::removeFromBgLists(name)
{
  foreach(data in [bgDataAfterLogin, bgDataBeforeLogin])
  {
    if (name in data.list)
      delete data.list[name]
    if (data.reserveBg == name)
      data.reserveBg = ""
  }
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

  bgDataAfterLogin.list.clear()
  bgDataBeforeLogin.list.clear()

  local blk = ::configs.GUI.get()

  local bgBlk = blk.loading_bg
  if (!bgBlk)
    return

  applyBlkToAllBgData(bgBlk)

  local curLang = ::g_language.getLanguageName()
  foreach(langBlk in bgBlk % "language")
    if (::u.isDataBlock(langBlk))
      applyBlkByLang(langBlk, curLang)

  local presetBlk = bgBlk[::get_country_flags_preset()]
  if (::u.isDataBlock(presetBlk))
    applyBlkToAllBgData(presetBlk)

  validateBgData(bgDataAfterLogin)
  validateBgData(bgDataBeforeLogin)
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

  applyBlkToAllBgData(langBlk)
}

function g_anim_bg::applyBlkToAllBgData(blk)
{
  applyBlkToBgData(bgDataAfterLogin, blk)
  applyBlkToBgData(bgDataBeforeLogin, blk)
  local beforeLoginBlk = blk[BLOCK_BEFORE_LOGIN_KEY]
  if (::u.isDataBlock(beforeLoginBlk))
    applyBlkToBgData(bgDataBeforeLogin, beforeLoginBlk)
}

function g_anim_bg::applyBlkToBgData(bgData, blk)
{
  local list = bgData.list

  local defValue = blk[DEFAULT_VALUE_KEY]
  if (defValue != null)
    foreach(key, value in list)
      list[key] = defValue

  if (::u.isString(blk[RESERVE_BG_KEY]))
    bgData.reserveBg = blk[RESERVE_BG_KEY]

  for (local i = 0; i < blk.paramCount(); i++)
  {
    local value = blk.getParamValue(i)
    if (::is_numeric(value))
      list[blk.getParamName(i)] <- value
  }

  //to not check name for each added param
  if (DEFAULT_VALUE_KEY in list)
    delete list[DEFAULT_VALUE_KEY]
}

function g_anim_bg::validateBgData(bgData)
{
  local list = bgData.list
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
  local modified = ::get_file_modify_time_sec(fileName)
  if (modified < 0)
    return

  if (debugLastModified < 0)
  {
    debugLastModified = modified
    return
  }

  if (debugLastModified == modified)
    return

  debugLastModified = modified
  load(lastBg)
}

//animBgBlk == null - swith debug mode off.
function g_anim_bg::debugLoading(animBgBlk = "")
{
  isDebugMode = animBgBlk != null
  if (!isDebugMode)
    return
  ::gui_start_loading()
  load(animBgBlk)
  enableDebugUpdate()
}

::subscribe_handler(::g_anim_bg)
