local Rand = require("std/rand.nut")
local math = require("math")
local flex = ::flex
local hdpx = ::hdpx

local FLOW_PARAMS = {
  part = { size = [hdpx(10), hdpx(10)], rendObj = ROBJ_SOLID, color = ::Color(100, 10, 10, 150) } //table or function that return table
  emitterSize = [hdpx(20), hdpx(20)]
  seed = null //when null, will be generated self seed
  key = null //when null, key will be seed
  lifeTime = [1.5, 2.5]
  spawnPeriod = 0.2 //0 = all at once
  totalParts = 0 //0 = unlimited
  moveSpeed = [100.0, 200.0]
  moveSpeedAngle = [85, 95] //degree
  moveEasing = Linear
  rotation = [0, 0]
  rotationSpeed = [0, 0]
  opacityEasing = CosineFull //null = no opacity animation
  isInvert = false
  onPartDestroy = @(partIdx) null
}

local defParams = {num=30,emitter_sz=[hdpx(200),hdpx(100)], part=null}
local function baseParticles(params=defParams){
  local rand = Rand(params?.seed)
  local rnd_a = @(range) rand.rfloat(range[0],range[1])
  local function rnd2(range){
    local r = rnd_a(range)
    return [r,r]
  }
  local verbose = params?.debug ?? false
  local particles=[]
  local part = {transform={pivot=[0.5,0.5]}}.__merge(params?.part ?? {})
  local emitter_sz= params?.emitter_sz ?? defParams.emitter_sz
  local rotEndSpr = params?.rotEndSpr ?? 180
  local rotStartSpr = params?.rotStartSpr ?? 80
  local scaleEndRange = params?.scaleTo ?? [1.2,0.8]
  local scaleStartRange = params?.scaleTo ?? [0.5,0.8]
  local duration = params?.duration ?? [0.5,1.5]
  local key = params?.key ?? rand._seed
  local numParams = params?.num ?? defParams.num
  local emitterParams = params?.emitterParams ?? {}
  for (local i=0; i<numParams; i++) {
    local scaleTo = rnd2(scaleEndRange)
    local partW = part?.size[0] ?? hdpx(10)
    local partH = part?.size[1] ?? hdpx(10)
    local partMax = ::min(partH,partW)*2/3
    local partMin = ::max(partH,partW)/3
    local posTo = [rnd_a([0-partMin,emitter_sz[0]-partMax]), rnd_a([0-partMin,emitter_sz[1]-partMax])]
    local rotateTo = rnd_a([-rotEndSpr,rotEndSpr])
    local animations = [
      { prop=AnimProp.scale, from=rnd2(scaleStartRange), to=scaleTo, duration=rnd_a(duration), play=true, easing=OutCubic }
      { prop=AnimProp.rotate, from=rnd_a([-rotStartSpr,rotStartSpr])+rotateTo, to=rotateTo, duration=rnd_a(duration), play=true, easing=OutCubic}
      { prop=AnimProp.translate, from=[emitter_sz[0]/2,emitter_sz[1]/2], to=posTo, duration=rnd_a(duration), play=true, easing=OutCubic }
    ]

    local p = part.__merge({
      transform = {
        scale = scaleTo
        rotate = rotateTo
        translate = posTo
      }
      animations=animations
      key = key
    })
    particles.append(p)
  }
  if (verbose)
    particles.extend([
      {rendObj=ROBJ_FRAME size=flex()}
      {rendObj=ROBJ_SOLID size=[1,8] hplace=HALIGN_CENTER vplace=VALIGN_MIDDLE}
      {rendObj=ROBJ_SOLID size=[8,1] hplace=HALIGN_CENTER vplace=VALIGN_MIDDLE}
    ])
  return emitterParams.__merge({
    size = emitter_sz
    key = key
    children = particles
  })
}

local function flowPart(idx, lifeTime, p) {
  local part = p.part
  if (typeof(part) == "function")
    part = part()

  local pos1 = [p.emitterSize[0] * p.rand.rfloat(-0.5, 0.5),
                p.emitterSize[1] * p.rand.rfloat(-0.5, 0.5)]
  local angle = p.randA(p.moveSpeedAngle)
  local dist = p.randA(p.moveSpeed) * lifeTime
  local pos2 = [pos1[0] - dist * math.cos(math.PI * angle / 180), pos1[1] + dist * math.sin(math.PI * angle / 180)]

  if (p.isInvert) {
    local t = pos1
    pos1 = pos2
    pos2 = t
  }

  local animations = [
    { prop=AnimProp.translate, from=[pos1[0] - pos2[0], pos1[1] - pos2[1]], to=[0, 0], duration = lifeTime, easing = p.moveEasing, play = true }
  ]

  if (p.opacityEasing != null)
    animations.append({ prop = AnimProp.opacity, from = 0.0, to = 1.0, duration = lifeTime, easing = p.opacityEasing, play = true, loop = true })

  local rotation = p.randA(p.rotation)
  local rotationSpeed = p.randA(p.rotationSpeed)
  if (rotationSpeed != 0)
    animations.append({ prop = AnimProp.rotate, from = rotation, to = rotation + 360, duration = 360.0 / rotationSpeed, play = true, loop = true })

  return part.__merge({
    pos = pos2
    key = p.key + idx
    transform = { rotate = rotation }
    animations = animations
  })
}

local flowPartByKey = {} //to not recreate same particles on parent reload when key is set.
local function flow(p = FLOW_PARAMS) {
  if (p.key != null && flowPartByKey?[p.key])
    return flowPartByKey?[p.key]

  p = FLOW_PARAMS.__merge(p)
  if (p.spawnPeriod == 0 && p.totalParts == 0) {
    ::assert(false, "Particles: Flow: can't spawn unlimited parts at once (spawnPeriod and totalParts can't be zero at once)")
    return {}
  }

  p.rand <- Rand(p.seed)
  p.randA <- @(range) p.rand.rfloat(range[0],range[1])
  p.key = p.key ?? p.rand._seed

  p.curParts <- []
  p.partsCreated <- 0
  p.partsNeeded <- ::Watched(p.spawnPeriod > 0 ? 1 : p.totalParts)
  p.partsRemoved <- ::Watched(0)

  local emitterUi = function() {
    for(p.partsCreated; p.partsCreated < p.partsNeeded.value; p.partsCreated++) {
      local idx = p.partsCreated
      local lifeTime = p.randA(p.lifeTime)
      p.curParts.append({
        idx = idx
        ui = flowPart(idx, lifeTime, p)
      })
      ::gui_scene.setTimeout(lifeTime, function() {
        foreach(i, part in p.curParts)
          if (idx == part.idx) {
            p.onPartDestroy(idx)
            p.curParts.remove(i)
            p.partsRemoved(p.partsRemoved.value + 1)
            break
          }
      })
    }
    return {
      watch = [p.partsNeeded, p.partsRemoved]
      size = [0, 0]
      onDetach = function() {
        if (flowPartByKey?[p.key])
          delete flowPartByKey[p.key]
      }
      vplace = VALIGN_MIDDLE
      hplace = HALIGN_CENTER
      children = p.curParts.map(@(c) c.ui)
    }
  }

  if (p.spawnPeriod > 0)
    ::gui_scene.setInterval(p.spawnPeriod, function() {
      p.partsNeeded(p.partsNeeded.value + 1)
      if (p.totalParts && p.partsNeeded.value >= p.totalParts)
        ::gui_scene.clearTimer(::callee())
    })

  if (p.key != null)
    flowPartByKey[p.key] <- emitterUi
  return emitterUi
}

return {
  baseParticles = baseParticles
  flow = flow
}