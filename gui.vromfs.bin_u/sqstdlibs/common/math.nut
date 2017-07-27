function min(a, b) { return (a < b)? a : b }
function max(a, b) { return (a > b)? a : b }
function minByAbs(a, b) { return (fabs(a) < fabs(b))? a : b }
function maxByAbs(a, b) { return (fabs(a) > fabs(b))? a : b }


function clamp(value, min, max)
{
  return (value < min) ? min : (value > max) ? max : value
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