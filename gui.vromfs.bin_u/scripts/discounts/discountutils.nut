local personalDiscount = ::require("scripts/discounts/personalDiscount.nut")

//you can use array in any path part - in result will be max discount from them.
function getDiscountByPath(path, blk = null, idx = 0)
{
  if (blk == null)
    blk = get_price_blk()
  local result = {
    maxDiscount = 0
  }
  ::invoke_multi_array(path, (@(blk, result) function (array) {
    local block = ::get_blk_by_path_array(array, blk)
    local discountValue = ::getTblValue("discount", block, 0)
    result.maxDiscount = ::max(result.maxDiscount, discountValue)
    local personalDiscountValue = personalDiscount.getDiscountByPath(array)
    result.maxDiscount = ::max(result.maxDiscount, personalDiscountValue)
  })(blk, result))
  return result.maxDiscount
}

function get_max_weaponry_discount_by_unitName(unitName = "")
{
  if (unitName == "")
    return 0

  local discount = 0
  local priceBlk = ::get_price_blk()
  if (priceBlk.aircrafts && priceBlk.aircrafts[unitName])
  {
    local unitTable = priceBlk.aircrafts[unitName]
    if (unitTable.weapons)
      foreach(name, table in unitTable.weapons)
        if (!::shop_is_weapon_purchased(unitName, name))
        {
          discount = ::max(discount, ::getTblValue("discount", table, 0))
          discount = ::max(discount, ::item_get_personal_discount_for_weapon(unitName, name))
        }

    if (unitTable.mods)
      foreach(name, table in unitTable.mods)
        if (!::shop_is_modification_purchased(unitName, name))
        {
          discount = ::max(discount, ::getTblValue("discount", table, 0))
          discount = ::max(discount, ::item_get_personal_discount_for_mod(unitName, name))
        }

    if (unitTable.spare)
      discount = ::max(discount, ::getTblValue("discount", unitTable.spare, 0))
  }
  return discount
}

//You can use array of airNames - in result will be max discount from them.
function showAirDiscount(obj, airName, group=null, groupValue=null, fullUpdate=false)
{
  local path = ["aircrafts", airName]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  local discount = getDiscountByPath(path)
  ::showCurBonus(obj, discount, group? group : "buy", true, fullUpdate)
}

function showUnitDiscount(obj, unitOrGroup)
{
  local discount = ::isUnitGroup(unitOrGroup)
    ? ::g_discount.getGroupDiscount(unitOrGroup.airsGroup)
    : ::g_discount.getUnitDiscount(unitOrGroup)
  ::showCurBonus(obj, discount, "buy")
}

function showDiscount(obj, name, group=null, groupValue=null, fullUpdate=false)
{
  local path = [name]
  if (group)
    path.append(group)
  if (groupValue)
    path.append(groupValue)
  local discount = getDiscountByPath(path)
  ::showCurBonus(obj, discount, name, true, fullUpdate)
}
