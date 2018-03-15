//------------------------------------------------------------------------------
::sysopt <- {
  mSettings = {}
  mQualityPresets = []
  mShared = {}
  mUiStruct = []
  mSkipUI = false
  mBlk = null
  mHandler = null
  mContainerObj = null
  mCfgStartup = {}
  mCfgApplied = {}
  mCfgInitial = {}
  mCfgCurrent = {}
  mScriptValid = true
  mValidationError = ""
  mMaintainDone = false
  mRowHeightScale = 1.0
}
//------------------------------------------------------------------------------
/*
  widgetType - type of the widget in UI ("list", "slider", "checkbox", "editbox", "tabs").
  def - default value in UI (it is not required, if there are getFromBlk/setToBlk functions).
  blk - path to variable in config.blk file structure (it is not required, if there are getFromBlk/setToBlk functions).
  restart - client restart is required to apply an option (e.g. no support in Renderer::onSettingsChanged() function).
  values - for string variables only, list of possible variable values in UI (for dropdown widget).
  items - optional, for string variables only, list of item titles in UI (for dropdown widget).
  min, max - for integer variables only, minimum and maximum variable values in UI (for slider widget).
  maxlength - for string/integer/float variables only, maximum variable value input length (for input field widget).
  onChanged - function, reaction to user changes in UI. This function can change multiple variables in UI.
  getFromBlk - function, imports value from config.blk, returns value in UI format.
  setToBlk - function, accepts value in UI format and exports it to BLK. Can change multiple variables in BLK.
  init - function, initializes the variable config section, for example, defines 'def' value and/or 'values' list.
  tooltipExtra - optional, text to be added to option tooltip.
*/
::sysopt.mSettings =
{
  resolution = { widgetType="list" def="1024 x 768" blk="video/resolution" restart=true
    init = function(blk, desc) {
      local curResolution = ::sysopt.mShared.getCurResolution(blk, desc)
      desc.values <- ::sysopt.mShared.getVideoModes(curResolution)
      desc.def <- curResolution
      desc.restart <- !::is_platform_windows
    }
  }
  mode = { widgetType="list" def="fullscreen" blk="video/mode" restart=true
    onChanged = "modeClick"
    init = function(blk, desc)
    {
      desc.values <- ["windowed"]
      if (::is_platform_windows)
        desc.values.append("fullscreenwindowed")
      if (!::is_vendor_tencent())
        desc.values.append("fullscreen")
      desc.def = desc.values.top()
      desc.restart <- !::is_platform_windows
    }
  }
  windowed = { widgetType="checkbox" def=false blk="video/windowed" restart=true
    onChanged = "modeClick"
    init = function(blk, desc) {
      desc.restart <- !::is_platform_windows
    }
  }
  vsync = { widgetType="list" def="vsync_off" blk="video/vsync" restart=true
    getFromBlk = function(blk, desc) {
      local vsync = ::get_blk_value_by_path(blk, "video/vsync", false)
      local adaptive = ::get_blk_value_by_path(blk, "video/adaptive_vsync", true)
      return (vsync && adaptive)? "vsync_adaptive" : (vsync)? "vsync_on" : "vsync_off"
    }
    setToBlk = function(blk, desc, val) {
      ::set_blk_value_by_path(blk, "video/vsync", val!="vsync_off")
      ::set_blk_value_by_path(blk, "video/adaptive_vsync", val=="vsync_adaptive")
    }
    init = function(blk, desc) {
      desc.values <- ::is_platform_windows ? [ "vsync_off", "vsync_on", "vsync_adaptive" ] : [ "vsync_off", "vsync_on" ]
    }
  }
  graphicsQuality = { widgetType="tabs" def="high" blk="graphicsQuality" restart=false
    values = [ "ultralow", "low", "medium", "high", "max", "movie", "custom" ]
    onChanged = "graphicsQualityClick"
  }
  anisotropy = { widgetType="list" def="2X" blk="graphics/anisotropy" restart=true
    values = [ "off", "2X", "4X", "8X", "16X" ]
    getFromBlk = function(blk, desc) {
      local anis = ::get_blk_value_by_path(blk, desc.blk, 2)
      return (anis==16)? "16X" : (anis==8)? "8X" : (anis==4)? "4X" : (anis==2)? "2X" : "off"
    }
    setToBlk = function(blk, desc, val) {
      local anis = (val=="16X")? 16 : (val=="8X")? 8 : (val=="4X")? 4 : (val=="2X")? 2 : 1
      ::set_blk_value_by_path(blk, desc.blk, anis)
    }
  }
  msaa = { widgetType="list" def="off" blk="directx/maxaa" restart=true
    values = [ "off", "on"]
    getFromBlk = function(blk, desc) {
      local msaa = ::get_blk_value_by_path(blk, desc.blk, 0)
      return (msaa>0)? "on" :"off"
    }
    setToBlk = function(blk, desc, val) {
      local msaa = (val=="on")? 2 : 0
      ::set_blk_value_by_path(blk, desc.blk, msaa)
    }
  }
  antialiasing = { widgetType="list" def="none" blk="video/postfx_antialiasing" restart=false
    values = ::is_opengl_driver() ? [ "none", "fxaa", "high_fxaa"] : [ "none", "fxaa", "high_fxaa", "low_taa", "high_taa", "ssaa4x" ]
    onChanged = "aaClick"
  }
  texQuality = { widgetType="list" def="high" blk="graphics/texquality" restart=true
    init = function(blk, desc) {
      local dgsTQ = ::get_dgs_tex_quality() // 2=low, 1-medium, 0=high.
      local configTexQuality = ::find_in_array(desc.values, ::getSystemConfigOption("graphics/texquality", "high"))
      local sysTexQuality = ::find_in_array([2, 1, 0], dgsTQ, configTexQuality)
      if (sysTexQuality == configTexQuality)
        return

      local restrictedValueName = ::sysopt.localize("texQuality", desc.values[sysTexQuality])
      local restrictedValueItem = {
        text = ::colorize("badTextColor", restrictedValueName + " **")
        textStyle = "textStyle:t='textarea';"
      }
      desc.items <- []
      foreach (index, item in desc.values)
        desc.items.append((index <= sysTexQuality) ? ::sysopt.localize("texQuality", item) : restrictedValueItem)
      desc.tooltipExtra <- ::colorize("badTextColor", "** " + ::loc("msgbox/graphicsOptionValueReduced/lowVideoMemory",
        { name = ::loc("options/texQuality"), value = restrictedValueName }))
    }
    values =   [ "low", "medium", "high" ]
  }
  shadowQuality= { widgetType="list" def="high" blk="graphics/shadowQuality" restart=false
    values = [ "ultralow", "low", "medium", "high", "ultrahigh" ]
  }
  backgroundScale = { widgetType="slider" def=2 min=0 max=2 blk="graphics/backgroundScale" restart=false
    blkValues = [ 0.7, 0.85, 1.0 ]
    getFromBlk = function(blk, desc) {
      local val = ::get_blk_value_by_path(blk, desc.blk, 1.0)
      if (::sysopt.getGuiValue("antialiasing") == "ssaa4x")
        val = 2.0
      return ::find_nearest(val, desc.blkValues)
    }
    setToBlk = function(blk, desc, val) {
      local res = ::getTblValue(val, desc.blkValues, desc.def)
      if (::sysopt.getGuiValue("antialiasing") == "ssaa4x")
        res = 2.0
      ::set_blk_value_by_path(blk, desc.blk, res)
    }
  }
  landquality = { widgetType="slider" def=0 min=0 max=4 blk="graphics/landquality" restart=false
    onChanged = "landqualityClick"
  }
  clipmapScale = { widgetType="slider" def=100 min=30 max=150 blk="graphics/clipmapScale" restart=false
    getFromBlk = function(blk, desc) { return (::get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  rendinstDistMul = { widgetType="slider" def=100 min=50 max=220 blk="graphics/rendinstDistMul" restart=false
    getFromBlk = function(blk, desc) { return (::get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  cloudsQuality = { widgetType="slider" def=1 min=0 max=2 blk="graphics/cloudsQuality" restart=false
    getFromBlk = function(blk, desc) { return (2 - ::get_blk_value_by_path(blk, desc.blk, 2-desc.def)).tointeger() }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, 2-val) }
  }
  panoramaResolution = { widgetType="slider" def=8 min=4 max=16 blk="graphics/panoramaResolution" restart=false
    getFromBlk = function(blk, desc) { return (::get_blk_value_by_path(blk, desc.blk, desc.def*256) / 256).tointeger() }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, val*256) }
  }
  fxDensityMul = { widgetType="slider" def=100 min=20 max=100 blk="graphics/fxDensityMul" restart=false
    getFromBlk = function(blk, desc) { return (::get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  physicsQuality = { widgetType="slider" def=3 min=0 max=5 blk="graphics/physicsQuality" restart=false
  }
  grassRadiusMul = { widgetType="slider" def=80 min=1 max=180 blk="graphics/grassRadiusMul" restart=false
    onChanged = "grassClick"
    getFromBlk = function(blk, desc) { return (::get_blk_value_by_path(blk, desc.blk, desc.def/100.0) * 100).tointeger() }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, val/100.0) }
  }
  grass = { widgetType="checkbox" def=true blk="render/grass" restart=false
  }
  enableSuspensionAnimation = { widgetType="checkbox" def=false blk="graphics/enableSuspensionAnimation" restart=true
  }
  alpha_to_coverage = { widgetType="checkbox" def=false blk="video/alpha_to_coverage" restart=false
  }
  tireTracksQuality = { widgetType="list" def="none" blk="graphics/tireTracksQuality" restart=false
    values = [ "none", "medium", "high", "ultrahigh" ]
    getFromBlk = function(blk, desc) {
      local val = ::get_blk_value_by_path(blk, desc.blk, 0)
      return ::getTblValue(val, desc.values, desc.def)
    }
    setToBlk = function(blk, desc, val) {
      local res = ::find_in_array(desc.values, val, 0)
      ::set_blk_value_by_path(blk, desc.blk, res)
    }
  }
  waterFoamQuality = { widgetType="list" def="high" blk="graphics/foamQuality" restart=false
    values = [ "none", "low", "medium", "high", "ultrahigh" ]
  }
  dirtSubDiv = { widgetType="list" def="high" blk="graphics/dirtSubDiv" restart=false
    values = [ "high", "ultrahigh" ]
    getFromBlk = function(blk, desc) {
      local val = ::get_blk_value_by_path(blk, desc.blk, 1)
      return (val==2)? "ultrahigh" : "high"
    }
    setToBlk = function(blk, desc, val) {
      local res = (val=="ultrahigh")? 2 : 1
      ::set_blk_value_by_path(blk, desc.blk, res)
    }
  }
  ssaoQuality = { widgetType="slider" def=0 min=0 max=2 blk="render/ssaoQuality" restart=false
    onChanged = "setSsaoQuality"
  }
  ssrQuality = { widgetType="slider" def=0 min=0 max=2 blk="render/ssrQuality" restart=false
    onChanged = "setSsrQuality"
  }
  waterReflectionTexDiv = { widgetType="slider" def=8 min=0 max=14 blk="graphics/waterReflectionTexDiv" restart=false
    getFromBlk = function(blk, desc) { return (16 - ::get_blk_value_by_path(blk, desc.blk, (16-desc.def))).tointeger() }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, 16 - val) }
  }
  waterRefraction = { widgetType="slider" def=1 min=0 max=2 blk="graphics/waterRefractionEnabledFor" restart=false
  }
  waterReflection = { widgetType="checkbox" def=true blk="render/waterReflection" restart=false
  }
  shadows = { widgetType="checkbox" def=true blk="render/shadows" restart=false
  }
  rendinstGlobalShadows = { widgetType="checkbox" def=true blk="render/rendinstGlobalShadows" restart=false
  }
  advancedShore = { widgetType="checkbox" def=false blk="graphics/advancedShore" restart=false
  }
  haze = { widgetType="checkbox" def=false blk="render/haze" restart=false
  }
  softFx = { widgetType="checkbox" def=true blk="render/softFx" restart=false
  }
  fxReflection = { widgetType="checkbox" def=true blk="render/fxReflection" restart=false
  }
  lastClipSize = { widgetType="checkbox" def=false blk="graphics/lastClipSize" restart=false
    getFromBlk = function(blk, desc) { return (::get_blk_value_by_path(blk, desc.blk, 4096) == 8192) }
    setToBlk = function(blk, desc, val) { ::set_blk_value_by_path(blk, desc.blk, (val ? 8192 : 4096)) }
  }
  lenseFlares = { widgetType="checkbox" def=false blk="graphics/lenseFlares" restart=false
  }
  jpegShots = { widgetType="checkbox" def=true blk="debug/screenshotAsJpeg" restart=false }
  compatibilityMode = { widgetType="checkbox" def=false blk="video/compatibilityMode" restart=true
    onChanged = "compatibilityModeClick"
  }
  foliageReprojection = { widgetType="checkbox" def=true blk="graphics/foliageReprojection" restart=false
  }
  displacementQuality = { widgetType="slider" def=1 min=0 max=2 blk="graphics/displacementQuality" restart=false
  }
  contactShadowsQuality = { widgetType="slider" def=0 min=0 max=2 blk="graphics/contactShadowsQuality" restart=false
  }
  staticShadowsOnEffects = { widgetType="checkbox" def=false blk="render/staticShadowsOnEffects" restart=false
  }
}
//------------------------------------------------------------------------------
/*
  compMode=true - option is enabled in GUI in Compatibility Mode. Otherwise it will be disabled.
*/
::sysopt.mQualityPresets = [
  {k="texQuality",           v={ultralow="low",low="medium",medium="high",high="high",  max="high",movie="high"}, compMode=true}
  {k="shadowQuality",        v={ultralow="ultralow",low="ultralow",medium="low",high="medium",max="high",movie="ultrahigh"}}
  {k="anisotropy",           v={ultralow="off",low="off",medium="2X", high="8X", max="16X",movie="16X"}, compMode=true}
  {k="rendinstGlobalShadows",v={ultralow=false,low=false,medium=false,high=true, max=true, movie=true}}
  {k="ssaoQuality",          v={ultralow=0,low=0,medium=0,high=1,max=2,movie=2}}
  {k="ssrQuality",           v={ultralow=0,low=0,medium=0,high=0,max=0,movie=1}}
  {k="contactShadowsQuality",v={ultralow=0,low=0,medium=0,high=0, max=1, movie=2}}
  {k="lenseFlares",          v={ultralow=false,low=false,medium=false,high=true ,max=true, movie=true}}
  {k="shadows",              v={ultralow=false,low=true,medium=true ,high=true ,max=true, movie=true}}
  {k="waterReflection",      v={ultralow=false,low=false,medium=true ,high=true ,max=true, movie=true}}
  {k="grass",                v={ultralow=false,low=false,medium=false,high=true ,max=true, movie=true}}
  {k="dirtSubDiv",           v={ultralow="high",low="high",medium="high",high="high", max="ultrahigh", movie="ultrahigh"}, compMode=true}
  {k="displacementQuality",  v={ultralow=0,low=0,medium=0,high=1, max=1, movie=2}}
  {k="tireTracksQuality"     v={ultralow="none",low="none",medium="medium", high="high", max="high", movie="ultrahigh"}, compMode=true}
  {k="waterFoamQuality"      v={ultralow="low",low="low",medium="medium", high="high", max="high", movie="high"}, compMode=true}
  {k="alpha_to_coverage",    v={ultralow=false,low=false,medium=false,high=false ,max=true, movie=true}}
  {k="msaa",                 v={ultralow="off",low="off",medium="off",high="off", max="off", movie="off"}, compMode=true, fullMode=false}
  {k="antialiasing",         v={ultralow="none",low="none",medium="fxaa", high="high_fxaa",
    max= ::is_opengl_driver() ? "high_fxaa" : "high_taa",movie= ::is_opengl_driver() ? "high_fxaa" : "high_taa"}}
  {k="enableSuspensionAnimation",v={ultralow=false,low=false,medium=false,high=false ,max=true, movie=true}}
  {k="haze",                 v={ultralow=false,low=false,medium=false,high=false ,max=true, movie=true}}
  {k="fxReflection",         v={ultralow=false,low=false,medium=false,high=false,max=true, movie=true}}
  {k="softFx",               v={ultralow=false,low=false,medium=true ,high=true ,max=true, movie=true}}
  {k="foliageReprojection",  v={ultralow=false,low=false,medium=false ,high=false ,max=true, movie=true}}
  {k="lastClipSize",         v={ultralow=false,low=false,medium=false,high=false,max=true, movie=true}, compMode=true}
  {k="landquality",          v={ultralow=0,low=0,medium=0 ,high=2,max=3,movie=4}}
  {k="rendinstDistMul",      v={ultralow=50,low=50,medium=85 ,high=100,max=130,movie=180}}
  {k="fxDensityMul",         v={ultralow=20,low=30,medium=75 ,high=80,max=95,movie=100}}
  {k="grassRadiusMul",       v={ultralow=10, low=10, medium=45,high=75,max=100,movie=135}}
  {k="backgroundScale",      v={ultralow=2, low=1, medium=2,high=2,max=2,movie=2}}
  {k="waterReflectionTexDiv",v={ultralow=4, low=6, medium=8,high=10,max=11,movie=12}}
  {k="waterRefraction",      v={ultralow=0, low=1, medium=1,high=1,max=2,movie=2}}
  {k="panoramaResolution",   v={ultralow=4,low=4,medium=6,high=8,max=10, movie=12}}
  {k="cloudsQuality",        v={ultralow=0,low=0,medium=1,high=1,max=1, movie=2}}
  {k="advancedShore",        v={ultralow=false,low=false,medium=false,high=false,max=true, movie=true}}
  {k="compatibilityMode",    v={ultralow=true,low=false,medium=false,high=false ,max=false, movie=false}, compMode=true}
  {k="physicsQuality",       v={ultralow=0, low=1, medium=2, high=3, max=4, movie=5}}
  {k="staticShadowsOnEffects", v={ultralow=false,low=false,medium=false,high=false,max=true, movie=true}}
]
//------------------------------------------------------------------------------
::sysopt.mShared =
{
  setQualityPreset = function(preset)
  {
    foreach (i in ::sysopt.mQualityPresets)
    {
      if (i.v.rawin(preset))
        ::sysopt.setGuiValue(i.k, i.v[preset])
      else if (i.v.rawin("medium"))
        ::sysopt.setGuiValue(i.k, i.v["medium"])
    }
  }

  setGraphicsQuality = function()
  {
    ::sysopt.mShared.modeClick()
    local quality = ::sysopt.getGuiValue("graphicsQuality", "high")
    if ((!::sysopt.mQualityPresets[0].v.rawin(quality)) && quality!="custom")
    {
      quality = ::sysopt.getGuiValue("compatibilityMode", false) ? "ultralow" : "high"
      ::sysopt.setGuiValue("graphicsQuality", quality)
    }
    if (quality=="custom")
    {
      return
    }
    else
    {
      ::sysopt.mShared.setQualityPreset(quality)
      ::sysopt.mShared.modeClick()
    }
  }

  graphicsQualityClick = function(silent=false)
  {
    local quality = ::sysopt.getGuiValue("graphicsQuality", "high")
    if (!silent && quality=="ultralow")
    {
      local ok_func = function() {
        ::sysopt.mShared.graphicsQualityClick(true)
        ::sysopt.updateGuiNavbar(true)
      }
      local cancel_func = function() {
        local quality = "low"
        ::sysopt.setGuiValue("graphicsQuality", quality)
        ::sysopt.mShared.graphicsQualityClick()
        ::sysopt.updateGuiNavbar(true)
      }
      ::sysopt.mHandler.msgBox("sysopt_compatibility", ::loc("msgbox/compatibilityMode"), [
          ["yes", ok_func],
          ["no", cancel_func],
        ], "no", { cancel_fn = cancel_func })
    }
    ::sysopt.mShared.setLandquality()
    ::sysopt.mShared.setGraphicsQuality()
    ::sysopt.mShared.setCompatibilityMode()
  }

  presetCheck = function()
  {
    local preset = ::sysopt.pickQualityPreset()
    ::sysopt.setGuiValue("graphicsQuality", preset)
  }

  modeClick = function()
  {
    local mode = ::sysopt.getGuiValue("mode", "fullscreen")
    ::sysopt.setGuiValue("windowed", (mode != "fullscreen"))
  }

  grassClick = function()
  {
    local grassRadiusMul = ::sysopt.getGuiValue("grassRadiusMul", 100)
    ::sysopt.setGuiValue("grass", (grassRadiusMul > 10))
  }

  setCompatibilityMode = function() {

    if (::sysopt.getGuiValue("compatibilityMode")) {
      ::sysopt.setGuiValue("backgroundScale",2)
      foreach (i in ::sysopt.mQualityPresets) {
        local enabled = ::getTblValue("compMode", i, false)
        ::sysopt.mShared.enableByCompMode(i.k, enabled)
      }
    } else {
      foreach (i in ::sysopt.mQualityPresets) {
        local enabled = ::getTblValue("fullMode", i, true)
        ::sysopt.mShared.enableByCompMode(i.k, enabled)
      }
      ::sysopt.setGuiValue("compatibilityMode", false)
    }
  }
  
  enableByCompMode = function(id, enable) {
    local desc = ::sysopt.getOptionDesc(id)
    local enabled = enable && ::getTblValue("enabled", desc, true)
    ::sysopt.enableGuiOption(id, enabled)
  }

  landqualityClick = function()
  {
    ::sysopt.mShared.setLandquality()
  }

  setLandquality = function()
  {
    local lq = ::sysopt.getGuiValue("landquality")
    local cs = (lq==0)? 50 : (lq==4)? 150 : 100
    ::sysopt.setGuiValue("clipmapScale",cs)
  }

  setSsaoQuality = function()
  {
    if (::sysopt.getGuiValue("ssaoQuality") == 0)
    {
      ::sysopt.setGuiValue("ssrQuality", 0)
    }
  }

  setSsrQuality = function()
  {
    if ((::sysopt.getGuiValue("ssrQuality") > 0) && (::sysopt.getGuiValue("ssaoQuality")==0))
      ::sysopt.setGuiValue("ssaoQuality",1)
  }

  aaClick = function()
  {
    if (::sysopt.getGuiValue("antialiasing") == "ssaa4x")
    {
      local okFunc = function() {
        ::sysopt.setGuiValue("backgroundScale", 2)
        ::sysopt.mShared.presetCheck()
        ::sysopt.updateGuiNavbar(true)
      }
      local cancelFunc = function() {
        local desc = ::sysopt.getOptionDesc("antialiasing")
        local restoreVal = desc.prevGuiValue || desc.def
        ::sysopt.setGuiValue("antialiasing", restoreVal)
        ::sysopt.mShared.presetCheck()
        ::sysopt.updateGuiNavbar(true)
      }
      ::sysopt.mHandler.msgBox("sysopt_ssaa4x", ::loc("msgbox/ssaa_warning"), [
          ["ok", okFunc],
          ["cancel", cancelFunc],
        ], "cancel", { cancel_fn = cancelFunc })
    }
  }

  compatibilityModeClick = function()
  {
    local isEnable = ::sysopt.getGuiValue("compatibilityMode")
    if (isEnable)
    {
      local ok_func = function() {
        ::sysopt.mShared.setCompatibilityMode()
        ::sysopt.mShared.presetCheck()
        ::sysopt.updateGuiNavbar(true)
      }
      local cancel_func = function() {
        ::sysopt.setGuiValue("compatibilityMode", false)
        ::sysopt.mShared.setCompatibilityMode()
        ::sysopt.mShared.presetCheck()
        ::sysopt.updateGuiNavbar(true)
      }
      ::sysopt.mHandler.msgBox("sysopt_compatibility", ::loc("msgbox/compatibilityMode"), [
          ["yes", ok_func],
          ["no", cancel_func],
        ], "no", { cancel_fn = cancel_func })
    }
    else
    {
    ::sysopt.mShared.setCompatibilityMode()
    }
  }

  getVideoModes = function(curResolution = null)
  {
    local minW = 1024
    local minH = 720

    local list = ::get_video_modes()
    list.append("auto");
    if (curResolution && ::find_in_array(list, curResolution) == -1)
      list.append(curResolution)

    local data = []
    foreach (resolution in list)
    {
      if (resolution == "auto")
      {
        data.append({
          resolution = resolution
          w = 0     // To be sorted first.
          h = 0
        })
      }
      else
      {
        local sides = split(resolution, "x")
        foreach (i, v in sides)
          sides[i] = strip(v).tointeger()
        if (sides[0] >= minW && sides[1] >= minH || resolution == curResolution)
          data.append({
            resolution = resolution
            w = sides[0]
            h = sides[1]
          })
      }
    }

    data.sort(function(a,b){
      if (a.w != b.w) return (a.w > b.w) ? 1 : -1
      if (a.h != b.h) return (a.h > b.h) ? 1 : -1
      return 0
    })

    local modes = []
    foreach (v in data)
      modes.append(v.resolution)
    return modes
  }

  getCurResolution = function(blk, desc)
  {
    local modes = ::sysopt.mShared.getVideoModes(null)
    local value = ::get_blk_value_by_path(blk, desc.blk, "")

    local isListed = ::find_in_array(modes, value) != -1
    if (isListed) // Supported system.
      return value

    local looksReliable = regexp2(@"^\d+ x \d+$").match(value)
    if (looksReliable) // Unsupported system. Or maybe altered by user, but somehow works.
      return value

    if (value == "auto")
      return value

    local screen = format("%d x %d", ::screen_width(), ::screen_height())
    return screen // Value damaged by user. Screen size can be wrong, but anyway, i guess user understands why it's broken.

    /*
    Can we respect get_video_modes() ?
      - It will work on all desktop computers (Windows, Mac OS, Linux) later, but currently, it works in Windows only, and it still returns an empty list in all other systems.

    Can we respect screen_width() and screen_height() ?
    Windows:
      - Fullscreen - YES. If the game resolution aspect ratio doesn't match the screen aspect ratio, image is visually distorted, but technically resolution values are correct.
      - Fullscreen window - NO. If the game resolution aspect ratio doesn't match the screen aspect ratio, the game resolution can be altered to match the screen aspect ratio (like 1680x1050 -> 1680x945).
      - Windowed - YES. Always correct, even if the window doesn't fit the screen.
    Mac OS:
      - Fullscreen - probably YES. There is only one fullscreen game resolution possible, the screen native resolution.
      - Windowed - probably NO. It's impossible to create a fixed size window in Mac OS X, all windows are freely resizable by user, always.
    Linux:
      - Unknown - in Linux, window resizability and ability to have a fullscreen option entirely depends on the selected window manager. It needs to be tested in Steam OS.
    Android, iOS, PlayStation 4:
      - Fullscreen - maybe YES. There can be aspect ratios non-standard for PC monitors.
    */
  }
}
//------------------------------------------------------------------------------
::sysopt.mUiStruct = [
  {
    container = "sysopt_top_left"
    items = [
      "resolution"
    ]
  }
  {
    container = "sysopt_top_middle"
    items = [
      "mode"
    ]
  }
  {
    container = "sysopt_top_right"
    items = [
      "vsync"
      ]
  }
  {
    container = "sysopt_graphicsQuality"
    id = "graphicsQuality"
  }
  {
    container = "sysopt_bottom_left"
    items = [
      "anisotropy"
      "msaa"
      "antialiasing"
      "texQuality"
      "shadowQuality"
      "backgroundScale"
      "cloudsQuality"
      "panoramaResolution"
      "landquality"
      "rendinstDistMul"
      "fxDensityMul"
      "grassRadiusMul"
      "ssaoQuality"
      "contactShadowsQuality"
      "ssrQuality"
      "waterReflectionTexDiv"
      "waterRefraction"
      "waterFoamQuality"
      "physicsQuality"
      "displacementQuality"
      "dirtSubDiv"
      "tireTracksQuality"
    ]
  }
  {
    container = "sysopt_bottom_right"
    items = [
      "shadows"
      "rendinstGlobalShadows"
      "staticShadowsOnEffects"
      "advancedShore"
      "fxReflection"
      "waterReflection"
      "haze"
      "softFx"
      "lastClipSize"
      "lenseFlares"
      "enableSuspensionAnimation"
      "alpha_to_coverage"
      "foliageReprojection"
      "jpegShots"
      "compatibilityMode"
    ]
  }
]
//------------------------------------------------------------------------------
function sysopt::canUseGraphicsOptions()
{
  return ::is_platform_pc && ::has_feature("GraphicsOptions")
}

function sysopt::init()
{
  local blk = ::DataBlock()
  blk.load(::get_config_name())

  foreach (id, desc in mSettings)
  {
    if ("init" in desc)
      desc.init(blk, desc)
    if (("onChanged" in desc) && type(desc.onChanged)=="string")
      desc.onChanged = (desc.onChanged in mShared) ? mShared[desc.onChanged] : null
    local uiType = ("def" in desc) ? type(desc.def) : null
    desc.uiType <- uiType
    desc.widgetId <- null
    desc.ignoreNextUiCallback <- false
    desc.prevGuiValue <- null
  }

  validateInternalConfigs()
}

function sysopt::configRead()
{
  mCfgInitial = {}
  mCfgCurrent = {}
  mBlk = ::DataBlock()
  mBlk.load(::get_config_name())

  foreach (id, desc in mSettings)
  {
    if ("init" in desc)
      desc.init(mBlk, desc)
    local value = ("getFromBlk" in desc) ? desc.getFromBlk(mBlk, desc) : ::get_blk_value_by_path(mBlk, desc.blk, desc.def)
    mCfgInitial[id] <- value
    mCfgCurrent[id] <- validateGuiValue(id, value)
  }

  if (!mCfgStartup.len())
    foreach (id, value in mCfgInitial)
      mCfgStartup[id] <- value

  if (!mCfgApplied.len())
    foreach (id, value in mCfgInitial)
      mCfgApplied[id] <- value
}

function sysopt::configWrite()
{
  if (! ::is_platform_pc)
    return;
  if (!mBlk) return
  foreach (id, _ in mCfgCurrent)
  {
    local value = getGuiValue(id)
    local desc = getOptionDesc(id)
    if ("setToBlk" in desc)
      desc.setToBlk(mBlk, desc, value)
    else
      ::set_blk_value_by_path(mBlk, desc.blk, value)
  }
  mBlk.saveToTextFile(::get_config_name())
}

function sysopt::configFree()
{
  mBlk = null
  mHandler = null
  mContainerObj = null
  mCfgInitial = {}
  mCfgCurrent = {}
}

function sysopt::localize(optionId, valueId)
{
  switch (optionId)
  {
    case "resolution":
    {
      if (valueId == "auto")
        return ::loc("options/auto")
      else
        return valueId
    }
    case "anisotropy":
    case "msaa":
      return ::loc("options/" + valueId)
    case "graphicsQuality":
    case "texQuality":
    case "shadowQuality":
    case "tireTracksQuality":
    case "waterFoamQuality":
    case "dirtSubDiv":
      if (valueId == "none")
        return ::loc("options/none")
      local txt = (valueId=="ultralow" || valueId=="min")? "ultra_low" : (valueId=="ultrahigh")? "ultra_high" : valueId
      return ::loc("options/quality_" + txt)
  }
  return ::loc(format("options/%s_%s", optionId, valueId), valueId)
}

function sysopt::updateGuiNavbar(show=true)
{
  local scene = mHandler && mHandler.scene
  if (!::checkObj(scene)) return

  local showText = show && isRestartPending()
  local showRestartButton = showText && canRestartClient()
  local applyText = ::loc((show && !showRestartButton && isHotReloadPending()) ? "mainmenu/btnApply" : "mainmenu/btnOk")

  local objNavbarRestartText = scene.findObject("restart_suggestion")
  if (::checkObj(objNavbarRestartText))
    objNavbarRestartText.show(showText)
  local objNavbarRestartButton = scene.findObject("btn_restart")
  if (::checkObj(objNavbarRestartButton))
    objNavbarRestartButton.show(showRestartButton)
  local objNavbarApplyButton = scene.findObject("btn_apply")
  if (::checkObj(objNavbarApplyButton))
    objNavbarApplyButton.setValue(applyText)
}

function sysopt::fillGuiOptions(containerObj, handler)
{
  if (!::checkObj(containerObj) || !handler) return
  local guiScene = containerObj.getScene()

  if (!mScriptValid)
  {
    local msg = ::loc("msgbox/internal_error_header") + "\n" + mValidationError
    local data = ::format("textAreaCentered { text:t='%s' size:t='pw,ph' }", ::g_string.stripTags(msg))
    guiScene.replaceContentFromText(containerObj.id, data, data.len(), handler)
    return
  }

  guiScene.setUpdatesEnabled(false, false)
  guiScene.replaceContent(containerObj, "gui/options/systemOptions.blk", handler)
  mContainerObj = containerObj
  mHandler = handler

  if (!::get_video_modes().len()) // Hiding resolution, mode, vsync.
  {
    local topBlockId = "sysopt_top"
    if (topBlockId in guiScene)
    {
      guiScene.replaceContentFromText(topBlockId, "", 0, handler)
      guiScene[topBlockId].height = 0
    }
  }

  configRead()
  local cb = "onSystemOptionChanged"
  foreach (section in mUiStruct)
  {
    if (! guiScene[section.container]) continue
    local isTable = ("items" in section)
    local ids = isTable ? section.items : [ section.id ]
    local data = ""
    foreach (id in ids)
    {
      local desc = getOptionDesc(id)
      desc.widgetId = "sysopt_" + id
      local option = ""
      switch (desc.widgetType)
      {
        case "checkbox":
          local config = {
            id = desc.widgetId
            value = mCfgCurrent[id]
            cb = cb
          }
          option = ::create_option_switchbox(config)
          break
        case "slider":
          option = ::create_option_slider(desc.widgetId, mCfgCurrent[id], cb, true, "slider", desc)
          break
        case "list":
          local raw = ::find_in_array(desc.values, mCfgCurrent[id])
          local customItems = ("items" in desc) ? desc.items : null
          local items = []
          foreach (index, valueId in desc.values)
            items.append(customItems ? customItems[index] : localize(id, valueId))
          option = ::create_option_combobox(desc.widgetId, items, raw, cb, true)
          break
        case "tabs":
          local raw = ::find_in_array(desc.values, mCfgCurrent[id])
          local items = []
          foreach (valueId in desc.values)
          {
            local warn = ::loc(format("options/%s_%s/comment", id, valueId), "")
            warn = warn.len() ? ("\n" + ::colorize("badTextColor", warn)) : ""

            items.append({
              text = localize(id, valueId)
              tooltip = ::loc(format("guiHints/%s_%s", id, valueId)) + warn
            })
          }
        option = ::create_option_row_listbox(desc.widgetId, items, raw, cb, isTable)
          break
        case "editbox":
          local raw = mCfgCurrent[id].tostring()
          option = ::create_option_editbox(desc.widgetId, raw, false, desc.maxlength)
          break
      }

      if (isTable)
      {
        local enable = ::getTblValue("enabled", desc, true) ? "yes" : "no"
        local requiresRestart = ::getTblValue("restart", desc, false)
        local tooltipExtra = ::getTblValue("tooltipExtra", desc)
        local label = ::g_string.stripTags(::loc("options/" + id) + (requiresRestart ? (::nbsp + "*") : (::nbsp + ::nbsp)))
        local tooltip = ::g_string.stripTags(::loc("guiHints/" + id)
          + (requiresRestart ? ("\n" + ::colorize("warningTextColor", ::loc("guiHints/restart_required"))) : "")
          + (tooltipExtra ? ("\n" + tooltipExtra) : "")
        )
        option = "tr { id:t='" + id + "_tr'; enable:t='" + enable +"' selected:t='no' size:t='pw, " + mRowHeightScale + "@baseTrHeight' overflow:t='hidden' tooltip:t=\"" + tooltip + "\";"+
          " td { width:t='0.5pw'; cellType:t='left'; overflow:t='hidden'; height:t='" + mRowHeightScale + "@baseTrHeight' optiontext {text:t='" + label + "'} }" +
          " td { width:t='0.5pw'; cellType:t='right';  height:t='" + mRowHeightScale + "@baseTrHeight' padding-left:t='@optPad'; " + option + " } }"
      }

      data += option
    }

    guiScene.replaceContentFromText(section.container, data, data.len(), handler)
  }

  guiScene.setUpdatesEnabled(true, true)
  onGuiLoaded()
}

function sysopt::getGuiWidget(id)
{
  if (!(id in mSettings)) { logError("sysopt.getGuiWidget()", "Option '"+id+"' is UNKNOWN. It must be added to sysopt.settings table."); return }
  local widgetId = getOptionDesc(id).widgetId
  local obj = (widgetId && ::checkObj(mContainerObj)) ? mContainerObj.findObject(widgetId) : null
  return ::checkObj(obj) ? obj : null
}

function sysopt::getOptionDesc(id)
{
  if (!(id in mSettings)) { logError("sysopt.getGuiWidget()", "Option '"+id+"' is UNKNOWN. It must be added to sysopt.settings table."); return }
  return mSettings[id]
}

function sysopt::getGuiValue(id, defVal=null)
{
  return (id in mCfgCurrent) ? mCfgCurrent[id] : defVal
}

function sysopt::setGuiValue(id, value, skipUI=false)
{
  value = validateGuiValue(id, value)
  mCfgCurrent[id] = value

  local obj = (skipUI || mSkipUI) ? null : getGuiWidget(id)
  if (obj)
  {
    local desc = getOptionDesc(id)
    local raw = null
    switch (desc.widgetType)
    {
      case "checkbox":
      case "slider":
        raw = value
        break
      case "list":
      case "tabs":
        raw = ::find_in_array(desc.values, value)
        break
      case "editbox":
        raw = value.tostring()
        break
    }
    if (raw != null && obj.getValue() != raw)
    {
      desc.ignoreNextUiCallback = desc.widgetType != "checkbox"
      obj.setValue(raw)
    }
  }
}

function sysopt::validateGuiValue(id, value)
{
  local desc = getOptionDesc(id)

  if (type(value) != desc.uiType)
  {
    logError("sysopt.validateGuiValue()", "Can't set '"+id+"'='"+value+"', value type is invalid.")
    return desc.def
  }
  switch (desc.widgetType)
  {
    case "checkbox":
      return value ? true : false
      break
    case "slider":
      if (value < desc.min || value > desc.max)
      {
        logError("sysopt.validateGuiValue()", "Can't set '"+id+"'='"+value+"', value is out of range.")
        return (value < desc.min) ? desc.min : desc.max
      }
      break
    case "list":
    case "tabs":
      if (::find_in_array(desc.values, value) == -1)
      {
        logError("sysopt.validateGuiValue()", "Can't set '"+id+"'='"+value+"', value is not in the allowed values list.")
        return desc.def
      }
      break
    case "editbox":
      if (value.tostring().len() > desc.maxlength)
      {
        logError("sysopt.validateGuiValue()", "Can't set '"+id+"'='"+value+"', value is too long.")
        return value
      }
      break
  }
  return value
}

function sysopt::enableGuiOption(id, state)
{
  if (mSkipUI) return
  local rowObj = ::checkObj(mContainerObj) ? mContainerObj.findObject(id + "_tr") : null
  if (::checkObj(rowObj)) rowObj.enable(state)
}

function sysopt::pickQualityPreset()
{
    local preset = "custom"

    mSkipUI = true
    local _cfgCurrent = mCfgCurrent
    local graphicsQualityDesc = getOptionDesc("graphicsQuality")
    foreach (presetId in graphicsQualityDesc.values)
    {
      if (presetId == "custom")
        continue
      mCfgCurrent = {}
      foreach (id, value in _cfgCurrent)
        mCfgCurrent[id] <- value
      mCfgCurrent["graphicsQuality"] = presetId
      mShared.graphicsQualityClick(true)
      local changes = checkChanges(mCfgCurrent, _cfgCurrent)
      if (!changes.needClientRestart && !changes.needEngineReload)
      {
        preset = presetId
        break
      }
    }
    mCfgCurrent = _cfgCurrent
    mSkipUI = false

    return preset
}

function sysopt::onGuiOptionChanged(obj)
{
  local widgetId = ::checkObj(obj) ? obj.id : null
  if (!widgetId) return
  local id = widgetId.slice(("sysopt_").len())

  local desc = getOptionDesc(id)
  if (!desc) return

  local curValue = ::getTblValue(id, mCfgCurrent)
  if (curValue == null)  //not inited or already cleared?
    return

  if (desc.ignoreNextUiCallback)
  {
    desc.ignoreNextUiCallback = false
    return
  }

  local value = null
  local raw = obj.getValue()
  switch (desc.widgetType)
  {
    case "checkbox":
      value = raw == true
      break
    case "slider":
      value = raw.tointeger()
      break
    case "list":
    case "tabs":
      value = desc.values[raw]
      break
    case "editbox":
      switch (desc.uiType)
      {
        case "integer":
          value = (regexp2(@"^\-?\d+$").match(strip(raw))) ? raw.tointeger() : null
          break
        case "float":
          value = (regexp2(@"^\-?\d+(\.\d*)?$").match(strip(raw))) ? raw.tofloat() : null
          break
        case "string":
          value = raw.tostring()
          break
      }
      if (value == null)
      {
        value = curValue
        setGuiValue(id, value, false)
      }
      break
  }

  if (value == curValue)
    return

  desc.prevGuiValue = curValue
  setGuiValue(id, value, true)
  if (("onChanged" in desc) && desc.onChanged)
    desc.onChanged()

  if (id != "graphicsQuality")
    mShared.presetCheck()
  updateGuiNavbar(true)
}

function sysopt::onGuiLoaded()
{
  if (!mScriptValid) return

  mShared.setGraphicsQuality()
  mShared.setCompatibilityMode()
  mShared.modeClick()
  mShared.presetCheck()

  updateGuiNavbar(true)
}

function sysopt::onGuiUnloaded()
{
  updateGuiNavbar(false)
}

function sysopt::checkChanges(config1, config2)
{
  local changes = {
    needSave = false
    needClientRestart = false
    needEngineReload = false
  }

  foreach (id, desc in mSettings)
  {
    local value1 = config1[id]
    local value2 = config2[id]
    if (value1 != value2)
    {
      changes.needSave = true

      local needApply = id != "graphicsQuality"
      if (needApply)
      {
        local requiresRestart = ::getTblValue("restart", desc)
        if (requiresRestart)
          changes.needClientRestart = true
        else
          changes.needEngineReload = true
      }
    }
  }

  return changes
}

function sysopt::configMaintain()
{
  if (mMaintainDone)
    return
  mMaintainDone = true
  if (!::is_platform_pc) return
  if (!mScriptValid) return

  if (::getSystemConfigOption("graphicsQuality", "high") == "user") // Need to reset
  {
    local isCompatibilityMode = ::getSystemConfigOption("video/compatibilityMode", false)
    ::setSystemConfigOption("graphicsQuality", isCompatibilityMode ? "ultralow" : "high")
  }

  configRead()

  mShared.setLandquality()
  mShared.setGraphicsQuality()
  mShared.setCompatibilityMode()
  mShared.modeClick()
  mShared.presetCheck()

  if (isSavePending())
  {
    dagor.debug("Graphics Settings validation. Saving repaired config.blk.")
    configWrite()
  }

  //if (!isRestartPending() && isHotReloadPending())
  //  applyRestartEngine()

  configFree()
}

function sysopt::onConfigApply()
{
  if (!mScriptValid) return
  if (!::checkObj(mContainerObj)) return

  mShared.presetCheck()
  onGuiUnloaded()

  if (isSavePending())
    configWrite()

  local restartPending = isRestartPending()
  if (!restartPending && isHotReloadPending())
    applyRestartEngine(isReloadSceneRerquired())

  local handler = mHandler
  configFree()

  if (restartPending && isClientRestartable())
  {
    local func_restart = function() {
      ::sysopt.applyRestartClient()
    }
    local cancel_func = function() {}

    if (canRestartClient())
    {
      local message = ::loc("msgbox/client_restart_required") + "\n" + ::loc("msgbox/restart_now")
      handler.msgBox("sysopt_apply", message, [
          ["restart", func_restart],
          ["no"],
        ], "restart", { cancel_fn = function(){} })
    }
    else
    {
      local message = ::loc("msgbox/client_restart_required")
      handler.msgBox("sysopt_apply", message, [
          ["ok"],
        ], "ok", { cancel_fn = function(){} })
    }
  }
}

function sysopt::applyRestartClient(forced=false)
{
  if (!isClientRestartable())
    return

  if (!forced && !canRestartClient())
  {
    ::showInfoMsgBox(::loc("msgbox/client_restart_rejected"), "sysopt_restart_rejected")
    return
  }

  dagor.debug("Graphics Settings changed. Restarting client.")
  ::save_profile(false)
  ::save_short_token()
  ::restart_game()
}

function sysopt::applyRestartEngine(reloadScene = false)
{
  mCfgApplied = {}
  foreach (id, value in mCfgCurrent)
    mCfgApplied[id] <- value

  dagor.debug("Graphics Settings changed. Resetting renderer.")
  ::on_renderer_settings_change()
  ::handlersManager.updateSceneBgBlur(true)

  if (reloadScene)
    ::handlersManager.markfullReloadOnSwitchScene()
}

function sysopt::isClientRestartable()
{
  return !::is_vendor_tencent()
}

function sysopt::canRestartClient()
{
  return isClientRestartable() && !(::is_in_loading_screen() || ::SessionLobby.isInRoom())
}

function sysopt::isRestartPending()
{
  return checkChanges(mCfgStartup, mCfgCurrent).needClientRestart
}

function sysopt::isHotReloadPending()
{
  return checkChanges(mCfgApplied, mCfgCurrent).needEngineReload
}

function sysopt::isReloadSceneRerquired()
{
  return mCfgApplied.resolution != mCfgCurrent.resolution || mCfgApplied.mode != mCfgCurrent.mode
}

function sysopt::isSavePending()
{
  return checkChanges(mCfgInitial, mCfgCurrent).needSave
}

function sysopt::logError(from="", msg="")
{
  local msg = format("[sysopt] ERROR %s: %s", from, msg)
  dagor.debug(msg)
  return msg
}

function sysopt::validateInternalConfigs()
{
  local errorsList = []
  foreach (id, desc in mSettings)
  {
    local widgetType = ::getTblValue("widgetType", desc)
    if (!isInArray(widgetType, ["list", "slider", "checkbox", "editbox", "tabs"]))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'widgetType' invalid or undefined."))
    if ((!("blk" in desc) || type(desc.blk) != "string" || !desc.blk.len()) && (!("getFromBlk" in desc) || !("setToBlk" in desc)))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'blk' invalid or undefined. It can be undefined only when both getFromBlk & setToBlk are defined."))
    if (("onChanged" in desc) && type(desc.onChanged) != "function")
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'onChanged' function not found in sysopt.shared."))

    local def = ::getTblValue("def", desc)
    if (def == null)
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Option '"+id+"' - 'def' undefined."))

    local uiType = desc.uiType
    switch (widgetType)
    {
      case "checkbox":
        if (def != null && uiType != "bool")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'widgetType'/'def' conflict."))
        break
      case "slider":
        if (def != null && uiType != "integer")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'widgetType'/'def' conflict."))
        local invalidVal = -1
        local min = ::getTblValue("min", desc, invalidVal)
        local max = ::getTblValue("max", desc, invalidVal)
        local safeDef = (def != null) ? def : invalidVal
        if (!("min" in desc) || !("max" in desc) || type(min) != uiType || type(max) != uiType
            || min > max || min > safeDef || safeDef > max )
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'min'/'def'/'max' conflict."))
        break
      case "list":
      case "tabs":
        if (def != null && uiType != "string")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'widgetType'/'def' conflict."))
        local values = ::getTblValue("values", desc, [])
        if (!values.len())
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'values' is empty or undefined."))
        if (def != null && values.len() && !isInArray(def, values))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'def' is not listed in 'values'."))
        break
      case "editbox":
        if (def != null && uiType != "integer" && uiType != "float" && uiType != "string")
          errorsList.append(logError("sysopt.validateInternalConfigs()",
                                     "Option '"+id+"' - 'widgetType'/'def' conflict."))
        local maxlength = ::getTblValue("maxlength", desc, -1)
        if (maxlength < 0 || (def != null && def.tostring().len() > maxlength))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Option '"+id+"' - 'maxlength'/'def' conflict."))
        break
    }
  }

  foreach (index, i in mQualityPresets)
  {
    local k = ::getTblValue("k", i)
    local v = ::getTblValue("v", i, {})
    if (!k || type(v)!="table" || !v.len())
      errorsList.append(logError("sysopt.validateInternalConfigs()",
       "Quality presets - 'qualityPresets' array index "+index+" contains invalid data."))
    if (k && !(k in mSettings))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Quality presets - k='"+k+"' is not found in 'settings' table."))
    if (type(v)=="table" && ("graphicsQuality" in mSettings) && ("values" in mSettings.graphicsQuality))
    {
      local qualityValues = mSettings.graphicsQuality.values
      foreach (qualityId, value in v)
      {
        if (!isInArray(qualityId, qualityValues))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Quality presets - k="+k+", graphics quality '"+qualityId+"' not exists."))
        if (value != validateGuiValue(k, value))
          errorsList.append(logError("sysopt.validateInternalConfigs()",
            "Quality presets - k="+k+", v."+qualityId+"='"+value+"' is invalid value for '"+k+"'."))
      }
    }
  }

  foreach (sectIndex, section in mUiStruct)
  {
    local container = ::getTblValue("container", section)
    local id = ::getTblValue("id", section)
    local items = ::getTblValue("items", section)
    if (!container || (!id && !items))
      errorsList.append(logError("sysopt.validateInternalConfigs()",
        "Array uiStruct - Index "+sectIndex+" contains invalid data."))
    local ids = items? items : id? [ id ] : []
    foreach (id in ids)
      if (!(id in mSettings))
        errorsList.append(logError("sysopt.validateInternalConfigs()",
          "Array uiStruct - Option '"+id+"' not found in 'settings' table."))
  }

  mScriptValid = !errorsList.len()
  if (::is_dev_version)
    mValidationError = ::g_string.implode(errorsList, "\n")
}

//------------------------------------------------------------------------------
::sysopt.init()
//------------------------------------------------------------------------------
