/*
  this is ordered table type class
  Unfortunately It is impossible to implement orderedTable with methamethods of table, cause tables has no metamethods for _nexti
  Usage is simple
  local otable = require("orderedtable.nut")
  local table = otable()
  table.a<-1
  table._<-1
  table.__update({aa=1,bb=1})
  foreach (k,v in table)
    print(""+k+" = " +v +"\n") //will print in the same order they added
  print(table.a)//1
  print(table.missedfield)//error
*/

local function _filter_func(func, params_num=null) {
  //return is function with (index,value,collection)
  ::assert(::type(func)==::type(callee()))
  switch (max(func.getinfos()?.parameters-1, params_num ?? 3)) {
    case 1:
      return @(value, index, collection) func(val)
    case 2:
      return @(value, index, collection) func(index, val)
    case 3:
      return func
    default:
      ::assert(false, "non correct function for filter")
  }
}

local function _map_func(func) {
  //return is function with (index,value,collection)
  ::assert(::type(func)==::type(callee()))
  switch (func.getinfos()?.parameters-1) {
    case 1:
      return @(value, index, collection) func(value)
    case 2:
      return @(index, value, collection) func(value, index)
    case 3:
      return func
    default:
      ::assert(false, "non correct function for map")
  }
}

local OrderedTable
OrderedTable = class </ name = "OrderedTable" />{
  __sorted_keys = null
  __value = null
  __curval = null
  static __classname = "ordered table"
  constructor(table=null){
    __sorted_keys = []
    __curval = 0
    __value = {}
    if (table==null)
      return
    if (table instanceof OrderedTable) {
      this.__sorted_keys = clone table.__sorted_keys
      this.__value = clone table.__value
    } else if (::type(table) == "table" && table.len()<2) {
      this.__value = clone table
      foreach (k,v in table)
        this.__sorted_keys.append(k)
    } else if (::type(table) == ::type([])) {
      foreach (elem in table){
        ::assert(::type(elem)==::type({}) && elem.len()==1, "you can initialize ordered table only with array consisting of tables with one key value pair")
        foreach (k,v in elem) {
          ::assert (!(k in this.__value), "not unique key for table")
          this.__sorted_keys.append(k)
          this.__value.__update(elem)
        }
      }
    } else {
      ::assert (false, "OrderedTable can be initialized only with ordered tables")
    }
  }

  _get = function(idx){
    return this.__value[idx]
  }

  _set = function(idx,val){
    if ( idx in this.__value)
      this.__value[idx]=val
    else
      return null
  }
  _newslot = function(key,value) {
    this.__sorted_keys.append(key)
    this.__value.rawset(key,value)
  }

  _delslot = function(key) {
    delete __value.key
    this.__sorted_keys.remove(__sorted_keys.find(key))
  }

  remove = function(key) {
    delete __value.key
    __sorted_keys.remove(__sorted_keys.find(key))
  }

  __insert_idx = function(key, value, idx) {
    if (key in  __value)
      ::assert(false, "key %s already exists"%key)
    else {
      __value[key]=value
      if (idx == null)
        __sorted_keys.append(key)
      else
        __sorted_keys.insert(idx, key)
    }
  }

  __insert_after = function(key, value, key_after) {
    if (key in  __value)
      ::assert(false, "key %s already exists"%key)
    else {
      local idx = __sorted_keys.find(key_after) ?? __sorted_keys.len()-1
      idx +=1
      if (idx<len-1)
        __sorted_keys.insert(idx, key)
      else
        __sorted_keys.append(key)
      __value[key] = value
    }
  }

  __insert_before = function(key, value, key_before) {
    if (key in  __value)
      ::assert(false, "key %s already exists"%key)
    else {
      __sorted_keys.insert(__sorted_keys.find(key_before) ?? __sorted_keys.len(), key)
      __value[key] = value
    }
  }

  __find_idx = function(key) {
    return __sorted_keys.find(key)
  }

  find = function(value) {
    local key = null
    foreach (k,v in __value) {
      if (v == value) {
        key = k
        break
      }
    }
    return key
  }

  tostring = @() null

  _nexti = function(previdx) {
    if (previdx==null) {
      __curval = 0
      return __sorted_keys[0]
    }
    else {
      __curval += 1
      return __sorted_keys?[__curval] ?? null
    }
  }

  __update = function(table){
    ::assert(((::type(table) == ::type({})) && table.len()<2) || (::type(table) == ::type([])) || (table instanceof this.getclass()), "update can be done only with ordered tables")
    local function updateKey(table){
      foreach (k,v in table) {
        if (!(k in __value)) {
          __value[k]<-v
          __sorted_keys.append(k)
        }
        else
          __value[k]=v
      }
    }
    if (::type(table)==::type([])) {
      foreach (a in table){
        updateKey(a)
      }
    }
    else
      updateKey(a)
  }

  filter = function(func){
    local f = _filter_func(func,2)
    local ret = this.getclass()()
    foreach (k,v in __value) {
      if(f(k,v))
        ret[k]<-v
    }
    return ret
  }
  map = function(func){
    local f = _map_func(func)
    local ret = []
    foreach (k in __sorted_keys) {
      ret.append(f(__value[k], k, __sorted_keys))
    }
  }

}

/*
local function test() {
  local table = OrderedTable()
  table.a<-1
  table._<-1
  table.__update({aa=1})
  foreach (k,v in table)
    print(""+k+" = " +v +"\n") //will print in the same order they added
  print(table.a+"\n")//1
  try {
    print(table.missedfield)//error
  } catch(e) {
    local err
    if ((err = e.find("the index 'missedfield' does not exist")==null))
      throw(e)
  }
}
*/
return OrderedTable