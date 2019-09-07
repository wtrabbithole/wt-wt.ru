global enum Layers {
  Default
  Tooltip
  Inspector
}

global const LINE_WIDTH = 1.6

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
