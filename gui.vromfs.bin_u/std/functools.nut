/*
+ partial:
  partial(f(x,y,z), 1) == @(y,z) f(1,y,z)
  partial(f(x,y,z), 1, 2) == @(z) f(1,2,z)
  partial(f(x,y,z), 1, 2, 3) == @() f(1,2,3) or f(1,2,3)
*/
local function partial(func, ...){
  assert(::type(func) == "function", "partial can be applied only to functions as first arguments")
  local infos = func.getfuncinfos()
  local argsnum = infos.parameters.len()-1
  local isvargved = infos.varargs==1
  local pargs = vargv
  local pargslen = pargs.len()
  if ( (pargslen == argsnum) && !isvargved) {
    return function(){
      return func.acall([null].extend(pargs))
    }
  }
  if ( (pargslen <= argsnum) || isvargved) {
    return function(...){
      return func.acall([null].extend(pargs).extend(vargv))
    }
  }
  assert(false, "function '{0}' cannot be partial with more arguments({1}) that it accepts({2})".subst(infos.name, pargslen, argsnum))
  return func
}

/*
 kwarg function:
  foo(x,y,z)
  kwarg(foo)==@(p) (foo(p?.x, p?.y, p?.z))
  foo(x,y,z=2)
  kwarg(foo)==@(p) (foo(p?.x, p?.y, p?.z ?? 2))
*/
local function kwarg(func){
  assert(::type(func) == "function", "partial can be applied only to functions as first arguments")
  local infos = func.getfuncinfos()
  local funcargs = infos.parameters.slice(1)
  local defargs = infos.defparams
  local argsnum = funcargs.len()
  local isvargved = infos.varargs==1
  local kfuncargs = {}
  local mandatoryparams = []
  local defparamsStartFrom = argsnum-defargs.len()
  foreach (idx, arg in funcargs) {
    if (idx >= defparamsStartFrom) {
      kfuncargs[arg] <- defargs[idx-defparamsStartFrom]
    }
    else{
      kfuncargs[arg] <-null
      mandatoryparams.append(arg)
    }
  }
  return !isvargved
    ? function(params=kfuncargs){
        assert(["table", "class","instance"].find(typeof(params))!=null, "param of function can be only hashable (table, class, instance), found:'{0}'".subst(typeof(params)))
        local keys = params.keys()
        local nonManP = mandatoryparams.filter(@(p) keys.find(p) == null)
        assert(nonManP.len()==0, "not all mandatory parameters provided: {0}".subst(nonManP.len()==1 ? "'{0}'".subst(nonManP[0]) : nonManP.reduce(@(a,b) "{0},'{1}'".subst(a,b))))
        params = kfuncargs.__merge(params)
        local posarguments = funcargs.map(@(kv) params[kv])
        return func.acall([this].extend(posarguments))
      }
    : function(params, ...){
        assert(["table", "class","instance"].find(typeof(params))!=null, "param of function can be only hashable (table, class, instance), found:'{0}'".subst(typeof(params)))
        local keys = params.keys()
        local nonManP = mandatoryparams.filter(@(p) keys.find(p) == null)
        assert(nonManP.len()==0, "not all mandatory parameters provided: {0}".subst(nonManP.len()==1 ? "'{0}'".subst(nonManP[0]) : nonManP.reduce(@(a,b) "{0},'{1}'".subst(a,b))))
        local posarguments = funcargs.map(@(kv) params[kv])
        return func.acall([this].extend(posarguments).extend(vargv))
      }
}

/*
 kwpartial
  local function foo(a,b,c){(a+b)*c}
  partial(foo, {b=3})(1,5) == (1+3)*5
  partial(foo, {b=3}, 2)(5) == (2+3)*5
*/
local function kwpartial(func, partparams, ...){
  assert(::type(func) == "function", "partial can be applied only to functions as first arguments")
  assert(["table", "class","instance"].find(typeof(partparams))!=null, "kwpartial second argument of function can be only hashable (table, class, instance)")
  local infos = func.getfuncinfos()
  local funcargs = infos.parameters.slice(1)
//  local defargs = infos.defparams
  local argsnum = funcargs.len()
  local posfuncargs = {}
  local partvargs = vargv
  foreach (p, v in partparams){
    local posidx = funcargs.find(p)
    if (posidx == null)
      continue
    posfuncargs[posidx] <- v
  }
  return function(...){
    local curargs = partvargs.extend(vargv)
    assert(curargs.len()+posfuncargs.len()>=argsnum, "not enough arguments provided for function '{0}' to call".subst(infos?.name))
    local finalargs = []
    local provArgIdx = 0
    for (local i=0; i<argsnum; i++) {
      if (i in posfuncargs) {
        finalargs.append(posfuncargs[i])
      }
      else {
        finalargs.append(curargs[provArgIdx])
        provArgIdx++
      }
    }
    return func.acall([this].extend(finalargs))
  }
}

local function filterFunctions(func) {
  return typeof(func) =="function"
}

// pipe:
//  pipe(f,g) =  @(x) f(g(x))
local function pipe(...){
  local args = vargv.filter(filterFunctions)
  assert(args.len() == vargv.len() && args.len()>0, "pipe should be called with functions")

  local numarg = args[0].getfuncinfos().parameters.len()-1
  local isvargved = args[0].getfuncinfos().varargs==1
  assert(numarg == 1 && !isvargved, "pipe cannot be applied to vargv function call or multiarguments function call")
  return function(x){
    foreach(v in args)
      x = v(x)
    return x
  }
}

// compose (reverse to pipe):
//  compose(f,g) =  @(x) g(f(x))
local function compose(...){
  local args = vargv.filter(filterFunctions).reverse()
  assert(args.len() == vargv.len() && args.len()>0, "compose should be called with functions")

  local numarg = args[0].getfuncinfos().parameters.len()-1
  local isvargved = args[0].getfuncinfos().varargs==1
  assert(numarg == 1 && !isvargved, "compose cannot be applied to vargv function call or multiarguments function call")
  return function(x){
    foreach(v in args)
      x = v(x)
    return x
  }
}

/*
 (un)curry:
  cf = curry(f) == @(x) @(y) @(z) f(x,y,z)
  f(x,y,z) = cf(x)(y)(z)
  cf(x) == @(y) @(z) f(x,y,z)
  local get = curry(function(property, object){ return object?[property] })
  local map = curry(function(fn, value){ return value.map(fn) })

  local objects = [{ id = 1 }, { id = 2 }, { id = 3 }]
  local getIDs = map(get("id"))

  log(objects.map(get("id"))) //= [1, 2, 3]
  log(objects.map(@(v) v?.id)) //= [1, 2, 3]
  log(getIDs(objects)) //= [1, 2, 3]

also our curry is (un)curry - so
local sum = curry(@(a,b,c) a+b+c)
sum(1)(2)(3) == sum(1)(2,3) == sum(1,2,3) == sum(1,2)(3)
unfortunately returning function are now use vargv, instead of rest of parameters (the same issue goes to partial)
*/
local function curry(fn) {
  local arity = fn.getfuncinfos().parameters.len()-1

  return function f1(...) {
    local args = vargv
    if (args.len() >= arity) {
      return fn.acall([this].extend(args))
    } else {
      local fone = f1
      return function(...) {
        local moreArgs = vargv
        local newArgs = clone args
        newArgs.extend(moreArgs)
        return fone.acall([this].extend(newArgs))
      }
    }
  }
}

/**
* memoize(function, [hashFunction])
  Memoizes a given function by caching the computed result. Useful for speeding up slow-running computations.
  If passed an optional hashFunction, it will be used to compute the hash key for storing the result, based on the arguments to the original function.
  The default hashFunction just uses the first argument to the memoized function as the key.
*/

local function memoize(func, hashfunc=null){
  local cache = {}
  local cache_for_null = {}
  local parameters = func.getfuncinfos().parameters.slice(0)
  assert(parameters.len()>0)
  hashfunc = hashfunc ?? function(...) {
    return vargv[0]
 }
  local function memoizedfunc(...){
    local args = [null].extend(vargv)
    local hash = hashfunc.pacall(args)
    if (hash == null){
      //index cannot be null. use different cach to avoid collision
      cache = cache_for_null
      hash = 0
    }
    if (hash in cache) {
      return cache[hash]
    }
    local result = func.pacall(args)
    cache[hash] <- result
    return result
  }
  return memoizedfunc
}


return {
  partial = partial
  pipe = pipe
  compose = compose
  kwarg = kwarg
  kwpartial = kwpartial
  curry = curry
  memoize = memoize
}