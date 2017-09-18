const GOLDEN_RATIO = 1.618034

function min(a, b) { return (a < b)? a : b }
function max(a, b) { return (a > b)? a : b }
function minByAbs(a, b) { return (fabs(a) < fabs(b))? a : b }
function maxByAbs(a, b) { return (fabs(a) > fabs(b))? a : b }


function clamp(value, min, max)
{
  return (value < min) ? min : (value > max) ? max : value
}

//round @value to valueble @digits amount
// roundToDigits(1.23, 2) = 1.2
// roundToDigits(123, 2) = 120
function roundToDigits(value, digits)
{
  if (value==0) return value
  local log = log10(fabs(value))
  local mul = pow(10, floor(log)-digits+1)
  return mul*floor(0.5+value.tofloat()/mul)
}

//round @value by @roundValue
//round_by_value(1.56, 0.1) = 1.6
function round_by_value(value, roundValue)
{
  return floor(value.tofloat() / roundValue + 0.5) * roundValue
}


function number_of_set_bits(i)
{
  i = i - ((i >> 1) & (0x5555555555555555));
  i = (i & 0x3333333333333333) + ((i >> 2) & 0x3333333333333333);
  return (((i + (i >> 4)) & 0xF0F0F0F0F0F0F0F) * 0x101010101010101) >> 56;
}


function is_bit_set(bitMask, bitIdx)
{
  return (bitMask & 1 << bitIdx) > 0
}

function change_bit(bitMask, bitIdx, value)
{
  return (bitMask & ~(1 << bitIdx)) | (value? (1 << bitIdx) : 0)
}

function change_bit_mask(bitMask, bitMaskToSet, value)
{
  return (bitMask & ~bitMaskToSet) | (value? bitMaskToSet : 0)
}

/**
* Linear interpolation of f(value) where:
* f(valueMin) = resMin
* f(valueMax) = resMax
*/
function lerp(valueMin, valueMax, resMin, resMax, value)
{
  if (valueMin == valueMax)
    return 0.5 * (resMin + resMax)
  return resMin + (resMax - resMin) * (value - valueMin) / (valueMax - valueMin)
}

/*
* return columns amount for the table with <total> same size items
* with a closer table size to golden ratio
* <widthToHeight> is a item size ratio (width / height)
*/
function calc_golden_ratio_columns(total, widthToHeight = 1.0)
{
  local rows = (sqrt(total.tofloat() / GOLDEN_RATIO * widthToHeight) + 0.5).tointeger() || 1
  return ceil(total.tofloat() / rows).tointeger()
}