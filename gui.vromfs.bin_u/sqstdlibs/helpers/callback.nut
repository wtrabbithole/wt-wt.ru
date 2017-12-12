local u = require("sqStdLibs/common/u.nut")
/**
 * Callback - wrapper for regular callback functions with context validation.
 *
 * Usage:
 *   Callback(callback_function(<up to 8 argumanet>) { ... }, context)
 *     @callback_function - function itself
 *     @context - callbacks environment. Root table is used by default
 *
 *   isValid()
 *     Return true if callback can be called
 *
 *   markInvalid()
 *     Callback may be set invalid manually
 *
 *   static function make(func, context = null)
 *     try to create Callback from anything. return null if failed.
 *     func - can be Callback, function, or string function name in context
 *
 * Context validations:
 *   If context specified it will be validated before calling. If context has
 *   function isValid(), result of this funtion will determine validity of
 *   Callback.
 */

local assertFunc = function(callback, errorText) { throw(errorText) }
local getDbgName = @(context) typeof context

local Callback = class
{
  refToContext = null
  hasContext = false
  callbackFn = null
  valid = true

  isToStringForDebug = true

  constructor(callback_function, context = null)
  {
    callbackFn = callback_function

    if (context)
      setContext(context)

    valid = true
  }

  function setContext(context)
  {
    callbackFn = callbackFn.bindenv(context)
    refToContext = context.weakref()
    hasContext = true
  }

  function isValid()
  {
    return isContextValid() && valid
  }

  function markInvalid()
  {
    valid = false
  }

  function getContextDbgName()
  {
    if (!hasContext)
      return "null"
    return getDbgName(refToContext)
  }

  function tostring()
  {
    return ::format("Callback( context = %s)", getContextDbgName())
  }

  /**
   * Check Call a callback function
   */
  function _call(origin_this, ...)
  {
    try
    {
      if (!isContextValid())
        return

      if (vargv.len() == 0)
        return callbackFn()
      if (vargv.len() == 1)
        return callbackFn(vargv[0])
      if (vargv.len() == 2)
        return callbackFn(vargv[0], vargv[1])
      if (vargv.len() == 3)
        return callbackFn(vargv[0], vargv[1], vargv[2])
      if (vargv.len() == 4)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3])
      if (vargv.len() == 5)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4])
      if (vargv.len() == 6)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4],
                          vargv[5])
      if (vargv.len() == 7)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4],
                          vargv[5], vargv[6])
      if (vargv.len() == 8)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4],
                          vargv[5], vargv[6], vargv[7])
    }
    catch (error)
    {
      assertFunc(this, error)
    }
  }

  /**
   * Check Call a callback function
   */
  function call(origin_this, ...)
  {
    try
    {
      if (!isContextValid())
        return

      if (vargv.len() == 0)
        return callbackFn()
      if (vargv.len() == 1)
        return callbackFn(vargv[0])
      if (vargv.len() == 2)
        return callbackFn(vargv[0], vargv[1])
      if (vargv.len() == 3)
        return callbackFn(vargv[0], vargv[1], vargv[2])
      if (vargv.len() == 4)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3])
      if (vargv.len() == 5)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4])
      if (vargv.len() == 6)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4],
                          vargv[5])
      if (vargv.len() == 7)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4],
                          vargv[5], vargv[6])
      if (vargv.len() == 8)
        return callbackFn(vargv[0], vargv[1], vargv[2], vargv[3], vargv[4],
                          vargv[5], vargv[6], vargv[7])
    }
    catch (error)
    {
      assertFunc(this, error)
    }
  }

  /***************************** Private methods ******************************/

  function isContextValid()
  {
    if (!hasContext)
      return true

    if (refToContext == null)
      return false

    if ("isValid" in refToContext)
      return refToContext.isValid()

    return true
  }
}

local function make(func, context = null)
{
  if (u.isCallback(func))
    return func
  if (typeof func == "function")
    return Callback(func, context)
  if (typeof func == "string" && (func in context) && typeof context[func] == "function")
    return ::Callback(context[func], context)
  return null
}

u.registerClass("Callback", Callback)

return {
  Callback = Callback
  setAssertFunction = @(func) assertFunc = func  //void func(callback, assertText)
  setContextDbgNameFunction = @(func) getDbgName = func  //string func(context)
  make = make
}