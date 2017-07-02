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
