function dlog(...)
{
  for (local i = 0; i < vargv.len(); i++)
  {
    dagor.debug("DLOG: " + vargv[i])
    dagor.screenlog("" + vargv[i])
  }
}

function can_be_readed_as_datablock(blk) //can be overrided by dataBlockAdapter
{
  return (typeof(blk) == "instance" && blk instanceof ::DataBlock)
}

function debugTableData(info, recursionLevel = 4, addStr = "", showBlockBrackets = true, silentMode = false, printFn = null)
{
  if (printFn == null)
    printFn = silentMode ? ::print : ::dagor.debug;

  if (addStr=="" && !silentMode)
    printFn("DD: START")

  local prefix = silentMode ? "" : "DD: ";

  if (info == null)
    printFn(prefix + "null");
  else
  {
    local data = info;
    local type = typeof(data)

    if (::can_be_readed_as_datablock(info))
    {
      local blockName = (info.getBlockName()!="")? info.getBlockName()+" " : ""
      if (showBlockBrackets)
        printFn(prefix+addStr+blockName+"{")
      local addStr2 = addStr + (showBlockBrackets? "  " : "")
      for (local i = 0; i < info.paramCount(); i++)
      {
        local name = info.getParamName(i)
        local val = info.getParamValue(i)
        local type = " "
        if (val == null) { val = "null" }
        else if (typeof(val)=="integer") type = ":i"
        else if (typeof(val)=="int64") type = ":i64"
        else if (typeof(val)=="float") { type = ":r"; val = val.tostring() + (val % 1 ? "" : ".0") }
        else if (typeof(val)=="bool") type = ":b"
        else if (typeof(val)=="string") { type = ":t"; val = "'" + val + "'" }
        else if (val instanceof ::Point2) { type = ":p2"; val = ::format("%s, %s", val.x.tostring(), val.y.tostring()) }
        else if (val instanceof ::Point3) { type = ":p3"; val = ::format("%s, %s, %s", val.x.tostring(), val.y.tostring(), val.z.tostring()) }
        else if (val instanceof ::Color4) { type = ":c";  val = ::format("%d, %d, %d, %d", 255 * val.r, 255 * val.g, 255 * val.b, 255 * val.a) }
        else if (val instanceof ::TMatrix) { type = ":m"
          local arr = []
          for (local i = 0; i < 4; i++)
            arr.append("[" + ::implode([ val[i].x, val[i].y, val[i].z ], ", ") + "]")
          val = "[" + ::implode(arr, " ") + "]"
        }
        else val = ::toString(val)
        printFn(prefix+addStr2+name+type+"= " + val)
      }
      for (local i = 0; i < info.blockCount(); i++)
        if (recursionLevel)
          ::debugTableData(info.getBlock(i), recursionLevel - 1, addStr2, true, silentMode, printFn)
        else
          printFn(prefix+addStr2 + info.getBlock(i).getBlockName() + " = ::DataBlock()")
      if (showBlockBrackets)
        printFn(prefix+addStr+"}")
    }
    else if (typeof(info)=="array" || typeof(info)=="table")
    {
      foreach(id, data in info)
      {
        local type = typeof(data)
        local idText = (typeof(id) == "string")? "'" + id + "'" : ::toString(id) //in table can be row 65 and '65' at the same time
        if (type=="array" || type=="table" || (type=="instance" && (data instanceof ::DataBlock)))
        {
          local openBraket = ((type=="array")? "[": ((type=="table")? "{" : "DataBlock {"))
          local closeBraket = ((type=="array")? "]":"}")
          if (recursionLevel)
          {
            printFn(prefix + addStr + idText + " = " + openBraket)
            ::debugTableData(data, recursionLevel - 1, addStr+"  ", false, silentMode, printFn)
            printFn(prefix+addStr+closeBraket)
          }
          else
          {
            local length = (type=="array" || type=="table") ? data.len() : (data.paramCount() + data.blockCount())
            printFn(prefix + addStr + idText + " = " + openBraket + (length ? "..." : "") + closeBraket)
          }
        }
        else if (type=="instance")
          printFn(prefix+addStr+idText+" = " + ::toString(data, ::min(1, recursionLevel), addStr))
        else if (type=="string")
          printFn(prefix+addStr+idText+" = '" + data + "'")
        else if (type=="float")
          printFn(prefix+addStr+idText+" = " + data + (data % 1 ? "" : ".0"))
        else if (type=="int64")
          printFn(prefix+addStr+idText+" = " + data + "L")
        else if (type=="null")
          printFn(prefix+addStr+idText+" = null")
        else
          printFn(prefix+addStr+idText+" = " + data)
      }
    }
    else if (typeof(info)=="instance")
      printFn(prefix + addStr + toString(info, ::min(1, recursionLevel), addStr)) //not decrease recursion because it current instance
    else
    {
      if (type=="string")
        printFn(prefix + addStr + "'" + data + "'")
      else if (type=="float")
        printFn(prefix + addStr + data + (data % 1 ? "" : ".0"))
      else if (type=="int64")
        printFn(prefix + addStr + data + "L")
      else if (type=="null")
        printFn(prefix + addStr + "null")
      else
        printFn(prefix + addStr + data)
    }
  }
  if (addStr=="" && !silentMode)
    printFn("DD: DONE.")
}

function toString(val, recursion = 1, addStr = "")
{
  if (type(val) == "instance")
  {
    if (::can_be_readed_as_datablock(val))
    {
      local iv = []
      for (local i = 0; i < val.paramCount(); i++)
        iv.append("" + val.getParamName(i) + " = " + ::toString(val.getParamValue(i)))
      for (local i = 0; i < val.blockCount(); i++)
        iv.append("" + val.getBlock(i).getBlockName() + " = " + ::toString(val.getBlock(i)))
      return format("DataBlock { %s }", ::implode(iv, ", "))
    }
    else if (val instanceof ::Point2)
      return format("Point2(%s, %s)", val.x.tostring(), val.y.tostring())
    else if (val instanceof ::Point3)
      return format("Point3(%s, %s, %s)", val.x.tostring(), val.y.tostring(), val.z.tostring())
    else if (val instanceof ::Color4)
      return format("Color4(%d/255.0, %d/255.0, %d/255.0, %d/255.0)", 255 * val.r, 255 * val.g, 255 * val.b, 255 * val.a)
    else if (val instanceof ::TMatrix)
    {
      local arr = []
      for (local i = 0; i < 4; i++)
        arr.append(::toString(val[i]))
      return "TMatrix(" + ::implode(arr, ", ") + ")"
    }
    else if (::getTblValue("isToStringForDebug", val))
      return val.tostring()
    else if (val instanceof ::DaGuiObject)
      return val.isValid() ? ("DaGuiObject(tag = " + val.tag + ", id = " + val.id + " )") : "invalid DaGuiObject"
    else
    {
      local ret = ""
      if (val instanceof ::BaseGuiHandler)
        ret = ::format("BaseGuiHandler(sceneBlkName = %s)", ::toString(val.sceneBlkName))
      else if (("tostring" in val) && type(val.tostring) == "function")
        ret += ::format("instance: \"%s\"", val.tostring())
      else
        ret += "instance"

      if (recursion > 0)
        foreach (idx, v in val)
        {
          //!!FIX ME: better to not use \n in toString()
          //and make different view ways for debugTabledata and toString
          //or it make harder to read debugtableData result in log, also arrays in one string generate too long strings
          if (typeof(v) != "function")
          {
            local index = ::isInArray(type(idx), [ "float", "int64", "null" ]) ? ::toString(idx) : idx
            ret += "\n" + addStr + "  " + index + " = " + ::toString(v, recursion - 1, addStr + "  ")
          }
        }

      return ret;
    }
  }
  if (val == null)
    return "null"
  if (type(val) == "string")
    return format("\"%s\"", val)
  if (type(val) == "int64")
    return val + "L"
  if (type(val) == "float")
    return val.tostring() + (val % 1 ? "" : ".0")
  if (type(val) != "array" && type(val) != "table")
    return "" + val
  local isArray = type(val) == "array"
  local str = ""
  if (recursion > 0)
  {
    local iv = []
    foreach (i,v in val)
    {
      local index = !isArray && ::isInArray(type(i), [ "float", "int64", "null" ]) ? ::toString(i) : i
      iv.append("" + (isArray ? "[" + index + "]" : index) + " = " + ::toString(v, recursion - 1, ""))
    }
    str = ::implode(iv, ", ")
  } else
    str = val.len() ? "..." : ""
  return isArray ? ("[ " + str + " ]") : ("{ " + str + " }")
}
