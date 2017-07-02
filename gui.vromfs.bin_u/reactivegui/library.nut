function max(a,b) {
  return a>b ? a : b
}


function min(a,b) {
  return a<b ? a : b
}

function clamp(v, minv, maxv) {
  return (v < minv) ? minv : (v > maxv) ? maxv : v;
}

::get_value <- @(key, source, defValue = null) (key in source) ? source[key] : defValue

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


//////////////////////////////compatibility////////////////////////////////////


function apply_compatibilities(comp_table)
{
  local rootTable = getroottable()
  local constTable = getconsttable()
  foreach(key, value in comp_table)
    if (!(key in rootTable) && !(key in constTable))
      rootTable[key] <- value
}

::apply_compatibilities({
  perform_cross_call = function (...) { return null }
})
