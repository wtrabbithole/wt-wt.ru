local random = require("dagor.random")

local rnd_seed = @() random.uint_noise1D(random.grnd(), random.get_rnd_seed()) //setting new rnd

local Rand = class{
  _seed = null
  _count = null
  maxrnd = ((1<<32)-1)

  constructor(seed=null) {
    _seed = seed ?? rnd_seed()
    _count = 0
  }

  function setseed(seed=null) {
    _seed = seed ?? rnd_seed()
    _count = 0
  }

  function rfloat(start=0.0, end=1.0){
    _count += 1
    local start_ = ::min(end,start)
    local end_ = ::max(end,start)
    return ::clamp((random.uint_noise1D(_seed, _count).tofloat()/maxrnd*(end_-start_) + start_).tofloat(), start_, end_)
  }

  function rint(start=0, end = null) {
    _count += 1
    if (end== null && start==0)
      return ::uint_noise1D(_seed, _count)
    else {
      local start_ = ::min(end,start)
      local end_ = ::max(end,start)

      return ::clamp((random.uint_noise1D(_seed, _count).tofloat()/maxrnd*(end_-start_+1) + start).tointeger(), start_, end_)
    }
  }

  function testfloat(){
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
}

return Rand