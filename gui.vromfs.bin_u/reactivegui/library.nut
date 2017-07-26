function Picture(name) {
  local p = ::PictureHolder()
  p.init(name)
  return p
}


function max(a,b) {
  return a>b ? a : b
}


function min(a,b) {
  return a<b ? a : b
}

function clamp(v, minv, maxv) {
  return (v < minv) ? minv : (v > maxv) ? maxv : v;
}

enum Layers {
  Default
  Tooltip
  Inspector
}
