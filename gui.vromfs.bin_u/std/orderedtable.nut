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
    if (typeof table == "instance" && table.getattributes(null)?.name == "OrderedTable") {
      __sorted_keys = clone table.__sorted_keys
      __value = clone table.__value
    } else if (typeof table == "table" && table.len()<2) {
      __value = clone table
      foreach (k,v in table)
        __sorted_keys.append(k)
    } else {
      ::assert (false, "OrderedTable can be initialized only with ordered tables")
    }
  }
  _get = function(idx){
    return __value[idx]
  }

  _set = function(idx,val){
    if ( idx in this.__value)
      __value[idx]=val
    else
      return null
  }
  _newslot = function(key,value) {
    __sorted_keys.append(key)
    __value.rawset(key,value)
  }

  _delslot = function(key) {
    delete __value.key
    __sorted_keys.remove(__sorted_keys.find(key))
  }

  remove = function(key) {
    delete __value.key
    __sorted_keys.remove(__sorted_keys.find(key))
  }

  __insert_idx = function(key, value, idx) {
    if (key in  __value)
      assert(false, "key %s already exists"%key)
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
      assert(false, "key %s already exists"%key)
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
      assert(false, "key %s already exists"%key)
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
    ::assert (((typeof table == "table" && table.len()<2) || (typeof table =="instance" && table.getattributes(null)?.name=="OrderedTable")), "update can be done only with ordered tables")
    foreach (k,v in table) {
      if (!(k in __value)) {
        __value[k]<-v
        __sorted_keys.append(k)
      }
      else
        __value[k]=v
    }
  }
  filter = function(func){
    local ret = OrderedTable()
    foreach (k,v in __value) {
      if(func(k,v))
        ret[k]<-v
    }
    return ret
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