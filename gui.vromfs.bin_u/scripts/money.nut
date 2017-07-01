/*
  universal money format
  monye =
  {
    wp   = 0;
    gold = 0;
    frp  = 0; - free research points
    type = money_type.none; - cost or balance (defined in enum)
  }

  API

  EXPANDING
    When you add new noteble values, add their names ton __data_fields array.
    This need for optimize comparison.
*/

enum money_type {
  none,
  cost,
  balance
}

enum money_color {
  NEUTRAL  = 0,
  BAD      = 1,
  GOOD     = 2
}

::zero_money <- null //instance of Money, which equals zero.

::Money <- class {
  wp   = 0
  gold = 0
  frp  = 0
  rp   = 0
  type = money_type.none

  //privat
  __data_fields = ["gold", "wp", "frp", "rp"]

  function constructor(type_in = money_type.cost, wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0)
  {
    wp   = wp_in || 0
    gold = gold_in || 0
    frp  = frp_in || 0
    rp   = rp_in || 0
    type = type_in
  }
}

function Money::setFromTbl(tbl)
{
  if ("wp" in tbl)
    wp = tbl.wp || 0
  if ("gold" in tbl)
    gold = tbl.gold || 0
  if ("exp" in tbl)
    frp = tbl.exp || 0
  return this
}

function Money::isZero()
{
  return !wp && !gold && !frp && !rp
}

//Math methods
function Money::_add(that)
{
  local newClass = this.getclass()
  return newClass(this.wp + that.wp,
                  this.gold + that.gold,
                  this.frp + that.frp,
                  this.rp + that.rp)
}

function Money::_sub(that)
{
  local newClass = this.getclass()
  return newClass(this.wp - that.wp,
                  this.gold - that.gold,
                  this.frp - that.frp,
                  this.rp - that.rp)
}

function Money::multiply(multiplier)
{
  wp   = (multiplier * wp   + 0.5).tointeger()
  gold = (multiplier * gold + 0.5).tointeger()
  frp  = (multiplier * frp  + 0.5).tointeger()
  rp   = (multiplier * rp   + 0.5).tointeger()
  return this
}

function Money::__impl_cost_to_balance_cmp(balance, cost)
{
  local res = 0
  foreach (key in __data_fields)
  {
    if (cost[key] <= 0)
      continue
    if (balance[key] < cost[key])
      return -1
    if (balance[key] > cost[key])
      res = 1
  }
  return res
}

function Money::_cmp(that)
{
  if (this.type == money_type.balance && that.type == money_type.cost)
    return __impl_cost_to_balance_cmp(this, that)

  if (this.type == money_type.cost && that.type == money_type.balance)
    return __impl_cost_to_balance_cmp(that, this) * -1

  foreach(key in __data_fields)
    if (this[key] != that[key])
      return this[key] > that[key] ? 1 : -1
  return 0
}

//String methods
function Money::_tostring()
{
  return __impl_get_text()
}

function Money::getTextAccordingToBalance()
{
  return __impl_get_text(true, true)
}

function Money::getUncoloredText()
{
  return __impl_get_text(false)
}

function Money::getUncoloredWpText()
{
  return this.__impl_get_wp_text(false)
}

function Money::getColoredWpText()
{
  return this.__impl_get_wp_text(true)
}

function Money::getGoldText(colored, checkBalance)
{
  return this.__impl_get_gold_text(colored, checkBalance)
}

function Money::__check_color(value, colorIdx)
{
  if (colorIdx == money_color.BAD)
    return "<color=@badTextColor>" + value + "</color>"
  if (colorIdx == money_color.GOOD)
    return "<color=@goodTextColor>" + value + "</color>"
  return value
}

function Money::__get_wp_color_id()   { return money_color.NEUTRAL }
function Money::__get_gold_color_id() { return money_color.NEUTRAL }
function Money::__get_frp_color_id()  { return money_color.NEUTRAL }
function Money::__get_rp_color_id()   { return money_color.NEUTRAL }

function Money::__impl_get_wp_text(colored = true, checkBalance = false)
{
  local color_id = (checkBalance && colored)? __get_wp_color_id() : money_color.NEUTRAL
  return __check_color(wp, color_id) + ::loc(colored ? "warpoints/short/colored" : "warpoints/short")
}

function Money::__impl_get_gold_text(colored = true, checkBalance = false)
{
  local color_id = (checkBalance && colored)? __get_gold_color_id() : money_color.NEUTRAL
  return __check_color(gold, color_id) + ::loc(colored ? "gold/short/colored" : "gold/short")
}

function Money::__impl_get_frp_text(colored = true, checkBalance = false)
{
  local color_id = (checkBalance && colored)? __get_frp_color_id() : money_color.NEUTRAL
  return __check_color(frp, color_id) + ::loc(colored ? "currency/freeResearchPoints/sign/colored" : "currency/freeResearchPoints/sign")
}

function Money::__impl_get_rp_text(colored = true, checkBalance = false)
{
  local color_id = (checkBalance && colored)? __get_rp_color_id() : money_color.NEUTRAL
  return __check_color(rp, color_id) + ::loc(colored ? "currency/researchPoints/sign/colored" : "currency/researchPoints/sign")
}

function Money::__impl_get_text(colored = true, checkBalance = false,
                                showWp = false, showGold = false, showFrp = false, showRp = false)
{
  local text = ""
  if (gold != 0 || showGold)
    text += __impl_get_gold_text(colored, checkBalance)
  if (wp != 0 || showWp)
    text += ((text == "") ? "" : ", ") + __impl_get_wp_text(colored, checkBalance)
  if (frp != 0 || showFrp)
    text += ((text == "") ? "" : ", ") + __impl_get_frp_text(colored, checkBalance)
  if (rp != 0 || showRp)
    text += ((text == "") ? "" : ", ") + __impl_get_rp_text(colored, checkBalance)
  return text
}

class Balance extends Money
{
  type = money_type.balance

  function constructor(wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0)
  {
    base.constructor(money_type.balance, wp_in, gold_in, frp_in, rp_in)
  }

  function __get_color_id_by_value(value)
  {
    return (value < 0) ? money_color.BAD : (value > 0) ? money_color.GOOD : money_color.NEUTRAL
  }

  function __get_wp_color_id()   { return __get_color_id_by_value(wp) }
  function __get_gold_color_id() { return __get_color_id_by_value(gold) }
  function __get_frp_color_id()  { return __get_color_id_by_value(frp) }
  function __get_rp_color_id()   { return __get_color_id_by_value(rp) }
}

class Cost extends Money
{
  type = money_type.cost

  function constructor(wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0)
  {
    base.constructor(money_type.cost, wp_in, gold_in, frp_in, rp_in)
  }

  function __get_wp_color_id()
  {
    return ::get_cur_rank_info().wp >= wp ? money_color.NEUTRAL : money_color.BAD
  }

  function __get_gold_color_id()
  {
    return ::get_cur_rank_info().gold >= gold ? money_color.NEUTRAL : money_color.BAD
  }

  function __get_frp_color_id()
  {
    return ::get_cur_rank_info().exp >= frp ? money_color.NEUTRAL : money_color.BAD
  }
}

::zero_money = ::Money(money_type.none)
