local random = require("dagor.random")
local cdate = (require_optional("system")?.date ?? @(date=null,format=null) {sec=0, min=0, hour=0, day=0, month=0, year=0, wday=0, yday=0})()
local _default_seed = random.get_rnd_seed() + cdate.sec + cdate.min*60 + cdate.yday*86400
local position = 0
local new_rnd_seed = function(){//setting new rnd
  position++
  return random.uint_noise1D(position, _default_seed)
}

local DEFAULT_MAX_INT_RAND = 32767
const maxrndfloat = 16777215.0 // float can only hold 23-bits integers without data loss
const maxrndfloatmask = 16777215 // (1<24)-1
local maxnoiseint = 0xffffffff // 32 bits
local function randint_uniform(lo, hi, rand) { // returns random int in range [lo,hi], closed interval
  local n = hi - lo + 1
  ::assert(n != 0)
  local maxx = maxnoiseint - (maxnoiseint % n)
  local x
  do
  {
    x = rand()
  } while (x >= maxx)
  return lo + (x % n)
}
local Rand = class{
  _seed = null
  _count = null

  constructor(seed=null) {
    _seed = seed ?? new_rnd_seed()
    _count = 0
  }

  function setseed(seed=null) {
    _seed = seed ?? new_rnd_seed()
    _count = 0
  }

  function rfloat(start=0.0, end=1.0){ // return float in range [start,end)
    _count += 1
    local start_ = ::min(end,start)
    local end_ = ::max(end,start)
    local runit = (random.uint_noise1D(_seed, _count) & maxrndfloatmask) / maxrndfloat // [0,1]
    return runit * (end_-start_) + start_
  }

  function _rfloat(seed, start=0.0, end=1.0, count=null){ // return float in range [start,end)
    if (::type(seed)=="table") {
      local params = seed
      start=params?.start ?? start
      end=params?.end ?? end
      seed = params.seed
      count = params?.count ?? count
    }
    local start_ = ::min(end,start)
    local end_ = ::max(end,start)
    local runit = (random.uint_noise1D(seed, count ?? seed) & maxrndfloatmask) / maxrndfloat // [0,1]
    return runit * (end_-start_) + start_
  }

  function _rint(seed, start=0, end=DEFAULT_MAX_INT_RAND, count=null){ // return int in range [start, end], i.e. inclusive
    if (::type(seed)=="table") {
      local params = seed
      start=params?.start ?? start
      end=params?.end ?? end
      seed = params.seed
      count = params?.count ?? count
    }
    return randint_uniform(::min(end,start), ::max(end,start), @() random.uint_noise1D(seed, count ?? seed))
  }

  function rint(start=0, end = null) { // return int in range [start, end], i.e. inclusive
    _count += 1
    if (end==null && start==0)
      return random.uint_noise1D(_seed, _count)
    else {
      end = end ?? DEFAULT_MAX_INT_RAND
      return randint_uniform(::min(end,start), ::max(end,start), @() random.uint_noise1D(_seed, _count))
    }
  }

  grnd = random.grnd
  gauss_rnd = random.gauss_rnd
  uint_noise1D = random.uint_noise1D
}

function testfloat(){
  local rand = Rand()
  local res = {}
  for (local i=0;i<100000;i++){
    local v = rand.rfloat(0,100)
    v = ((v*100).tointeger()/100).tointeger()
    if (res?[v] != null)
      res[v]=res[v]+1
    else
      res[v]<-1
  }
  return(res)
}

return Rand
