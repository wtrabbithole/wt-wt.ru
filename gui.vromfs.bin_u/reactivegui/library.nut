::ROBJ_TEXT <- ROBJ_DTEXT // For smooth migration

enum Layers {
  Default
  Tooltip
  Inspector
}


::cross_call <- class {
  path = null

  constructor () {
    path = []
  }

  function _get(idx) {
    path.push(idx)
    return this
  }

  function _call(self, ...) {
    local args = [this]
    args.push(path)
    args.extend(vargv)
    local result = ::perform_cross_call.acall(args)
    path.clear()
    return result
  }
}()
