local string=require("string")
local math=require("math")

//pairs list taken from http://www.ibm.com/support/knowledgecenter/ssw_ibm_i_72/nls/rbagslowtoupmaptable.htm
const CASE_PAIR_LOWER = "abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿāăąćĉċčďđēĕėęěĝğġģĥħĩīĭįıĳĵķĺļľŀłńņňŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷźżžƃƅƈƌƒƙơƣƥƨƭưƴƶƹƽǆǉǌǎǐǒǔǖǘǚǜǟǡǣǥǧǩǫǭǯǳǵǻǽǿȁȃȅȇȉȋȍȏȑȓȕȗɓɔɗɘəɛɠɣɨɩɯɲɵʃʈʊʋʒάέήίαβγδεζηθικλμνξοπρστυφχψωϊϋόύώϣϥϧϩϫϭϯабвгдежзийклмнопрстуфхцчшщъыьэюяёђѓєѕіїјљњћќўџѡѣѥѧѩѫѭѯѱѳѵѷѹѻѽѿҁґғҕҗҙқҝҟҡңҥҧҩҫҭүұҳҵҷҹһҽҿӂӄӈӌӑӓӕӗәӛӝӟӡӣӥӧөӫӯӱӳӵӹաբգդեզէըթժիլխծկհձղճմյնշոչպջռսվտրցւփքօֆაბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰჱჲჳჴჵḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹἀἁἂἃἄἅἆἇἐἑἒἓἔἕἠἡἢἣἤἥἦἧἰἱἲἳἴἵἶἷὀὁὂὃὄὅὑὓὕὗὠὡὢὣὤὥὦὧᾀᾁᾂᾃᾄᾅᾆᾇᾐᾑᾒᾓᾔᾕᾖᾗᾠᾡᾢᾣᾤᾥᾦᾧᾰᾱῐῑῠῡⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
const CASE_PAIR_UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮIĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŹŻŽƂƄƇƋƑƘƠƢƤƧƬƯƳƵƸƼǄǇǊǍǏǑǓǕǗǙǛǞǠǢǤǦǨǪǬǮǱǴǺǼǾȀȂȄȆȈȊȌȎȐȒȔȖƁƆƊƎƏƐƓƔƗƖƜƝƟƩƮƱƲƷΆΈΉΊΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩΪΫΌΎΏϢϤϦϨϪϬϮАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЁЂЃЄЅІЇЈЉЊЋЌЎЏѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾӁӃӇӋӐӒӔӖӘӚӜӞӠӢӤӦӨӪӮӰӲӴӸԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՎՏՐՑՒՓՔՕՖႠႡႢႣႤႥႦႧႨႩႪႫႬႭႮႯႰႱႲႳႴႵႶႷႸႹႺႻႼႽႾႿჀჁჂჃჄჅḀḂḄḆḈḊḌḎḐḒḔḖḘḚḜḞḠḢḤḦḨḪḬḮḰḲḴḶḸḺḼḾṀṂṄṆṈṊṌṎṐṒṔṖṘṚṜṞṠṢṤṦṨṪṬṮṰṲṴṶṸṺṼṾẀẂẄẆẈẊẌẎẐẒẔẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸἈἉἊἋἌἍἎἏἘἙἚἛἜἝἨἩἪἫἬἭἮἯἸἹἺἻἼἽἾἿὈὉὊὋὌὍὙὛὝὟὨὩὪὫὬὭὮὯᾈᾉᾊᾋᾌᾍᾎᾏᾘᾙᾚᾛᾜᾝᾞᾟᾨᾩᾪᾫᾬᾭᾮᾯᾸᾹῘῙῨῩⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ"
local INVALID_INDEX = -1

local rootTable = getroottable()
local intRegExp = null
local floatRegExp = null
local stripTagsConfig = null
/**
 * Joins array elements into a string with the glue string between each element.
 * This function is a reverse operation to g_string.split()
 * @param {string[]} pieces - The array of strings to join.
 * @param {string}   glue - glue string.
 * @return {string} - String containing all the array elements in the same order,
 *                    with the glue string between each element.
 */
// Reverse operation to split()
local function implode(pieces = [], glue = "") {
  return pieces.filter(@(index,val) val != "" && val != null).reduce(@(prev, cur) prev + glue + cur) ?? ""
}

/**
 * Joins array elements into a string with the glue string between each element.
 * Like implode(), but doesn't skip empty strings, so it is lossless
 * and safe for packing string data into a string, when empty sub-strings are important.
 * This function is a reverse operation to g_string.split()
 * @param {string[]} pieces - The array of strings to join.
 * @param {string}   glue - glue string.
 * @return {string} - String containing all the array elements in the same order,
 *                    with the glue string between each element.
 */
local function join(pieces, glue="") {
  return pieces.reduce(@(prev, cur) prev + glue + cur) ?? ""
}

/**
 * Splits a string into an array of sub-strings.
 * Like Squirrel split(), but doesn't skip empty strings, so it is lossless
 * and safe for extracting string data from a string, when empty sub-strings are important.
 * This function is a reverse operation to g_string.join()
 * @param {string} joined - The string to split.
 * @param {string} glue - glue string.
 * @return {string[]} - Array of sub-strings.
 */
local function split(joined, glue, isIgnoreEmpty = false) {
  local pieces = []
  local joinedLen = joined.len()
  if (!joinedLen)
    return pieces
  local glueLen = glue.len()
  local start = 0
  while (start <= joinedLen) {
    local end = joined.find(glue, start)
    if (end == null)
      end = joinedLen
    if (!isIgnoreEmpty || start != end)
      pieces.append(joined.slice(start, end))
    start = end + glueLen
  }
  return pieces
}

if ("regexp2" in rootTable) {
  intRegExp = ::regexp2(@"^-?\d+$")
  floatRegExp  = ::regexp2(@"^-?\d+\.?\d*$")
  stripTagsConfig = [
    {
      re2 = ::regexp2("~")
      repl = "~~"
    }
    {
      re2 = ::regexp2("\"")
      repl = "~\""
    }
    {
      re2 = ::regexp2("\r")
      repl = "~r"
    }
    {
      re2 = ::regexp2("\n")
      repl = "~n"
    }
    {
      re2 = ::regexp2("\'")
      repl = "~\'"
    }
  ]
} else  if ("regexp" in rootTable) {
  intRegExp = ::regexp(@"^-?(\d+)$")
  floatRegExp  = ::regexp(@"^-?(\d+)(\.?)(\d*)$")
  stripTagsConfig = [
    {
      re2 = ::regexp(@"~")
      repl = "~~"
    }
    {
      re2 = ::regexp("\"")
      repl = "~\""
    }
    {
      re2 = ::regexp(@"\r")
      repl = "~r"
    }
    {
      re2 = ::regexp(@"\n")
      repl = "~n"
    }
    {
      re2 = ::regexp(@"\'")
      repl = "~\'"
    }
  ]
}

local defTostringParams = {
  maxdeeplevel = 4
  compact=true
  tostringfunc= {
    compare=function(val) {return false}
    tostring=@(val) val.tostring()
  }
  separator = " "
  indentOnNewline = "  "
  newline="\n"
  splitlines = true
  showArrIdx=false
}
local function func_tostring(func,compact) {
  local info = func.getinfos()
  local out = ""
  if (!info.native) {
    local params = info.parameters.slice(1)
    if (params.len()>0)
      params=params.reduce(@(res, curval) res.tostring() + ", " + curval)
    else
      params = ""
    local fname = "" + info.name
    if (fname.find("(null : 0x0") != null || fname.find("null") !=null)
      fname = "@"
    if (!compact)
      out += "(func): " + info.src + " "
    out += fname +"("
    if (!compact)
      out += params
    out += ")"
  } else if (info.native) {
    out += "(nativefunc): " + info.name

  } else {
    out += func.tostring()
  }
  return out
}

local simple_types = ["string", "float", "bool", "integer","null"]
local function_types = ["function", "generator", "thread"]

local function tostring_any(input, tostringfunc=null, compact=true) {
  local typ = ::type(input)
  if (tostringfunc!=null) {
    if (type(tostringfunc) == "table")
      tostringfunc = [tostringfunc]
    else if (type(tostringfunc) == "array") {
      foreach (tf in tostringfunc){
        if (tf?.compare != null && tf.compare(input)){
          return tf.tostring(input)
        }
      }
    }
  }
  else if (function_types.find(typ)!=null){
    return func_tostring(input,compact)
  }
  else if (typ == "string"){
    if(input=="")
      return "''"
    if(compact)
      return input
    return "'" + input + "'"
  }
  else if (typ == "null"){
    return "null"
  }
  else if (typ == "float" && input == input.tointeger().tofloat() && !compact){
    return input.tostring()+".0"
  }
  else if (typ=="instance"){
    return input.tostring()
  }
  else if (typ == "userdata"){
    return "#USERDATA#"
  }
  else if (typ == "weakreference"){
    return "#WEAKREF#"
  }
  else
    return input.tostring()
}
local table_types = ["table","class","instance"]
local function tostring_r(input, params=defTostringParams) {
  local out = ""
  local newline = params?.newline ?? defTostringParams.newline
  local maxdeeplevel = params?.maxdeeplevel ?? defTostringParams.maxdeeplevel
  local separator = params?.separator ?? defTostringParams.separator
  local showArrIdx = params?.showArrIdx ?? defTostringParams.showArrIdx
  local tostringfunc = params?.tostringfunc
  local indentOnNewline = params?.indentOnNewline ?? defTostringParams.indentOnNewline
  local splitlines = params?.splitlines ?? defTostringParams.splitlines
  local compact = params?.compact ?? defTostringParams.compact
  local deeplevel = 0
  local tostringfuncs = [
    {
      compare = @(val,typ) simple_types.find(typ) != null
      tostring = @(val) tostring_any(val, null, compact)
    }
    {
      compare = @(val,typ) (typ=="table" && val.len()==0 )
      tostring = @(val) "{}"
    }
    {
      compare = @(val,typ) typ=="array" && val.len()==0
      tostring = @(val) "[]"
    }
    {
      compare = @(val,typ) function_types.find(typ)!=null
      tostring = @(val) tostring_any(val, null, compact)
    }
    {
      compare = @(val,typ) (typ=="instance" && val?.tostring && val?.tostring?() && val?.tostring?().find("(instance : 0x")!=0)
      tostring = @(val) val.tostring()
    }
  ]
  local function tostringLeaf(val) {
    local typ =::type(val)
    if (tostringfunc!=null) {
      if (type(tostringfunc) == "table")
        tostringfunc = [tostringfunc]
      foreach (tf in tostringfunc)
        if (tf.compare(val))
          return [true, tf.tostring(val)]
    }
    foreach (cmp in tostringfuncs)
      if (cmp.compare(val,typ))
        return [true,cmp.tostring(val)]
    return [false, null]
  }

  local function openSym(value) {
    local typ = ::type(value)
    if (typ=="array")
      return "["
    if (typ=="class") {
      local className = value.getattributes(null)?.name
      if (!compact)
        className = implode(["class", className]," ")
      return implode([className, "{"]," ")
    }
    else if (typ=="instance") {
      local className = ""
      if (value?.getclass)
         className = value?.getclass().getattributes(null)?.name
      if (!compact)
        className = implode(["inst", className]," ")
      return implode([className,"{"]," ")
    }
    else
      return "{"
  }
  local function closeSym(value) {
    local typ = ::type(value)
    if (typ=="array")
      return "]"
    else
      return "}"
  }
  local function idxStr(i) {
    if (showArrIdx)
      return (compact) ? i + " = " : "["+i+"] = "
    else
      return ""
  }
  local arrSep = separator
  if (!splitlines) {
    newline = " "
    indentOnNewline = ""
  }
  local function sub_tostring_r(input, indent, curdeeplevel, arrayElem = false, separator = newline, arrInd=null) {
    if (arrInd==null)
      arrInd=indent
    local out = ""
    foreach (key, value in input) {
      local typ = ::type(value)
      local isArray = typ=="array"
      local tostringLeafv=tostringLeaf(value)
      if (tostringLeafv[0]) {
        if (!arrayElem) {
          out += separator
          out += indent + tostring_any(key) +  " = "
        }
        out += tostringLeafv[1]
        if (arrayElem && key!=input.len()-1)
          out += separator
      }
      else if (maxdeeplevel != null && curdeeplevel == maxdeeplevel && !tostringLeafv[0]) {
        local brOp = openSym(value)
        local brCl = closeSym(typ)
        if (!arrayElem)
          out += newline + indent + tostring_any(key, null, compact) +  " = "
        else if (arrayElem && showArrIdx) {
          out += tostring_any(key) +  " = "
        }
        out += brOp +"..." + brCl
      }
      else if (isArray && !showArrIdx) {
        if (!arrayElem)
          out += newline + indent + tostring_any(key, null, compact) +  " = "
        out += "[" + callee()(value, indent + indentOnNewline, curdeeplevel+1, true, arrSep, indent) + "]"
        if (arrayElem && key!=input.len()-1)
          out += separator
      }
      else if (table_types.find(typ) != null || (isArray && showArrIdx )) {
        local brOp = openSym(value)
        local brCl = closeSym(typ)
        out += newline + indent
        if (!arrayElem) {
          out += tostring_any(key,null, compact) +  " = "
        }
        out += brOp + callee()(value, indent + indentOnNewline, curdeeplevel+1) + newline + indent + brCl
        if (arrayElem && key==input.len()-1 ){
          out += newline+arrInd
        }
        else if (arrayElem && key<input.len()-1 && table_types.find(type(input[key+1]))!=0){
          out += newline+indent
        }
      }
    }
    return out
  }
  return sub_tostring_r([input], "", 0,true)
}


/**
 * Retrieves a substring from the string. The substring starts and ends at a specified indexes.
 * Like Python operator slice.
 * @param {string}  str - Input string.
 * @param {integer} start - Substring start index. If it is negative, the returned string will
 *                          start at the start'th character from the end of input string.
 * @param {integer} [end] - Substring end index.  If it is negative, the returned string will
 *                          end at the end'th character from the end of input string.
 * @return {string} - substring, or on error - part of substring or empty string.
 */
local function slice(str, start = 0, end = null) {
  str = str || ""
  local total = str.len()
  if (start < 0)
    start += total
  start = clamp(start, 0, total)
  if (end == null)
    end = total
  else if (end < 0)
    end += total
  end = clamp(end, start, total)
  return str.slice(start, end)
}

/**
 * Retrieves a substring from the string. The substring starts at a specified index
 * and has a specified length.
 * Like PHP function substr().
 * @param {string}  str - Input string.
 * @param {integer} start - Substring start index. If it is negative, the returned string will
 *                          start at the start'th character from the end of input string.
 * @param {integer} [length] - Substring length. If it is negative, the returned string will
 *                             end at the end'th character from the end of input string.
 * @return {string} - substring, or on error - part of substring or empty string.
 */
local function substring(str, start = 0, length = null) {
  local end = length
  if (length != null && length >= 0)
  {
    str = str || ""
    local total = str.len()
    if (start < 0)
      start += total
    start = clamp(start, 0, total)
    end = start + length
  }
  return slice(str, start, end)
}

/**
 * Determines whether the beginning of the string matches a specified substring.
 * Like C# function String.StartsWith().
 * @param {string}  str - Input string.
 * @param {string}  value - Matching substring.
 * @return {boolean}
 */
local function startsWith(str, value) {
  str = str || ""
  value = value || ""
  return slice(str, 0, value.len()) == value
}

/**
 * Determines whether the end of the string matches the specified substring.
 * Like C# function String.EndsWith().
 * @param {string}  str - Input string.
 * @param {string}  value - Matching substring.
 * @return {boolean}
 */
local function endsWith(str, value) {
  str = str || ""
  value = value || ""
  return slice(str, - value.len()) == value
}

/**
 * Reports the index of the first occurrence in the string of a specified substring.
 * Like C# function String.IndexOf().
 * @param {string}  str - Input string.
 * @param {string}  value - Searching substring.
 * @param {integer} [startIndex=0] - Search start index.
 * @return {integer} - index, or -1 if not found.
 */
local function indexOf(str, value, startIndex = 0) {
  str = str || ""
  value = value || ""
  local idx = str.find(value, startIndex)
  return idx != null ? idx : INVALID_INDEX
}

/**
 * Reports the index of the last occurrence in the string of a specified substring.
 * Like C# function String.LastIndexOf().
 * @param {string}  str - Input string.
 * @param {string}  value - Searching substring.
 * @param {integer} [startIndex=0] - Search start index.
 * @return {integer} - index, or -1 if not found.
 */
local function lastIndexOf(str, value, startIndex = 0) {
  str = str || ""
  value = value || ""
  local idx = INVALID_INDEX
  local curIdx = startIndex - 1
  local length = str.len()
  while (curIdx < length - 1) {
    curIdx = str.find(value, curIdx + 1)
    if (curIdx == null)
      break
    idx = curIdx
  }
  return idx
}

/**
 * Reports the index of the first occurrence in the string of any substring in a specified array.
 * Like C# function String.IndexOfAny().
 * @param {string}   str - Input string.
 * @param {string[]} anyOf - Array of substrings to search for.
 * @param {integer}  [startIndex=0] - Search start index.
 * @return {integer} - index, or -1 if not found.
 */
local function indexOfAny(str, anyOf, startIndex = 0) {
  str = str || ""
  anyOf = anyOf || [ "" ]
  local idx = INVALID_INDEX
  foreach (value in anyOf) {
    local curIdx = indexOf(str, value, startIndex)
    if (curIdx != INVALID_INDEX && (idx == INVALID_INDEX || curIdx < idx))
      idx = curIdx
  }
  return idx
}

/**
 * Reports the index of the last occurrence in the string of any substring in a specified array.
 * Like C# function String.LastIndexOfAny().
 * @param {string}   str - Input string.
 * @param {string[]} anyOf - Array of substrings to search for.
 * @param {integer}  [startIndex=0] - Search start index.
 * @return {integer} - index, or -1 if not found.
 */
local function lastIndexOfAny(str, anyOf, startIndex = 0) {
  str = str || ""
  anyOf = anyOf || [ "" ]
  local idx = INVALID_INDEX
  foreach (value in anyOf)
  {
    local curIdx = lastIndexOf(str, value, startIndex)
    if (curIdx != INVALID_INDEX && (idx == INVALID_INDEX || curIdx > idx))
      idx = curIdx
  }
  return idx
}

//returns the number of entries of @substr in @str.
local function countSubstrings(str, substr) {
  local res = -1
  local findex = -1
  for(res; findex != null; res++) {
    findex = str.find(substr, ++findex)
  }
  return res
}

//Change case to upper for set up number of symbols
local function toUpper(string, symbolsNum = 0) {
  if (symbolsNum <= 0) {
    symbolsNum = string.len()
  }
  if (symbolsNum >= string.len()) {
    return string.toupper()
  }
  return slice(string, 0, symbolsNum).toupper() + slice(string, symbolsNum)
}


local function replace(str, from, to) {
  if (str == null || str == "")
    return ""
  local splitted = split(str,from)
  return join(splitted, to)
}

/*
  getroottable()["rfsUnitTest"] <- function()
  {
    local resArr = []
    local testValArray = [1.0, 12.0, 123.0, 6548.0, 72356.0, 120.0, 4300.0, 1234567.0]
    for(local presize = 1e+6; presize >= 1e-10; presize *= 0.1)
      resArr.append("presize " + presize + " -> "
        + implode(testValArray.map(@(val) roundedFloatToString(presize * val, presize)), ", "))
    return implode(resArr, "\n")
  }
  //presize 1e+06 -> 1000000, 12000000, 123000000, 6547000000, 72356000000, 120000000, 4300000000, 1234567000000
  //presize 0.001 -> 0.001, 0.012, 0.123, 6.548, 72.356, 0.120, 4.300, 1234.567
  //presize 1e-10 -> 0.0000000001, 0.0000000012, 0.0000000123, 0.0000006548, 0.0000072356, 0.0000000120, 0.0000004300, 0.0001234567'
*/

local function floatToStringRounded(value, presize) {
  if (presize >= 1) {
    local res = (value / presize).tointeger().tostring()
    for(local p = presize; p > 1; p /= 10)
      res += "0" //we no need float trash below presize
    return res //we no need e+8 in the big numbers too
  }
  return string.format("%." + (-math.log10(presize).tointeger()) + "f", value)
}

local function isStringInteger(str) {
  if (type(str) == "integer")
    return true
  if (type(str) != "string")
    return false
  if (intRegExp != null)
    return intRegExp.match(str)

  if (startsWith(str,"-"))
    str=str.slice(1)
  local ok = false
  try {
    ok = str.tointeger().tostring() == str
  }
  catch(e) {
    ok = false
  }
  return ok
}

local function isStringFloat(str, separator=".") {
  if (type(str) == "integer" || type(str) == "float")
    return true
  if (type(str) != "string")
    return false
  if (floatRegExp != null)
    return floatRegExp.match(str)
  if (startsWith(str,"-"))
    str=str.slice(1)
  local s_list = split(str,separator)
  if (s_list.len() > 3) 
    return false
  local ok = true
  foreach (s in s_list) {
    if (startsWith(s,"-"))
      ok = false
    try { ok = ok && str.tointeger().tostring() == str }
    catch(e) { ok = false }
  }
  return ok
}

local function toIntegerSafe(str, defValue = 0, needAssert = true)
{
  if (isStringInteger(str))
    return str.tointeger()
  if (needAssert)
    assert(false, "can't convert '" + str + "' to integer")
  return defValue
}

local function intToUtf8Char(c) {
  if (c <= 0x7F)
    return c.tochar()
  if (c <= 0x7FF)
    return (0xc0 + (c>>6)).tochar() + (0x80 + (c & 0x3F)).tochar()
  //if (c <= 0xFFFF)
  return (0xe0 + (c>>12)).tochar() + (0x80 + ((c>>6) & 0x3F)).tochar() + (0x80 + (c & 0x3F)).tochar()
}

local function utf8ToUpper(str, symbolsNum = 0) {
  if(str.len() < 1)
    return str
  local utf8Str = ::utf8(str)
  local strLength = utf8Str.charCount()
  if (symbolsNum <= 0 || symbolsNum >= strLength)
    return utf8Str.strtr(CASE_PAIR_LOWER, CASE_PAIR_UPPER)
  return ::utf8(utf8Str.slice(0, symbolsNum)).strtr(CASE_PAIR_LOWER, CASE_PAIR_UPPER) +
   utf8Str.slice(symbolsNum, strLength)
}

local function utf8ToLower(str) {
  return ::utf8(str).strtr(CASE_PAIR_UPPER, CASE_PAIR_LOWER)
}

local function hexStringToInt(hexString) {
  // Does the string start with '0x'? If so, remove it
  if (hexString.len() >= 2 && hexString.slice(0, 2) == "0x")
    hexString = hexString.slice(2)

  // Get the integer value of the remaining string
  local res = 0
  foreach (character in hexString) {
    local nibble = character - '0'
    if (nibble > 9)
      nibble = ((nibble & 0x1F) - 7)
    res = (res << 4) + nibble
  }

  return res
}

//Return defValue when incorrect prefix
local function cutPrefix(id, prefix, defValue = null) {
  if (!id)
    return defValue

  local pLen = prefix.len()
  if ((id.len() >= pLen) && (id.slice(0, pLen) == prefix))
    return id.slice(pLen)
  return defValue
}

local function intToStrWithDelimiter(value, delimiter = " ", charsAmount = 3) {
  local res = value.tointeger().tostring()
  local negativeSignCorrection = value < 0 ? 1 : 0
  local idx = res.len()
  while (idx > charsAmount + negativeSignCorrection) {
    idx -= charsAmount
    res = res.slice(0, idx) + delimiter + res.slice(idx)
  }
  return res
}


local function stripTags(str) {
  if (!str || !str.len())
    return ""
  if (stripTagsConfig == null)
    assert(stripTagsConfig != null, "stripTags is not working without regexp")
  foreach(test in stripTagsConfig)
    str = test.re2.replace(test.repl, str)
  return str
}

local function pprint(...){
  //most of this code should be part of tostring_r probably - at least part of braking long lines
  local function findlast(str, substr, startidx=0){
    local ret = null
    for(local i=startidx; i<str.len(); i++) {
      local k = str.find(substr, i)
      if (k!=null) {
        i = k
        ret = k
     }
     else
       break;
    }
    return ret
  }
  if (vargv.len()<=1)
    print(tostring_r(vargv[0])+"\n")
  else {
    local a = vargv.map(@(i) tostring_r(i))
    local res = ""
    local prev_val_newline = false
    local len = 0
    local maxlen = 50
    foreach(k,i in a) {
      local l = findlast(i,"\n")
      if (l!=null)
        len = len + i.len()-l
      else
        len = len+i.len()
      if (k==0)
        res = i
      else if (prev_val_newline && len<maxlen)
        res = res.slice(0,-1)+" " + i
      else if (len>=maxlen){
        res = res+"\n  " + i
        len = i.len()
      }
      else
        res = res+" " + i

      if (i.slice(-1)=="\n" && len<maxlen)
        prev_val_newline = true
     else
       prev_val_newline = false
    }
    print(res)
    print("\n")
  }
}


local export = {
  INVALID_INDEX = INVALID_INDEX
  slice = slice
  substring = substring
  startsWith = startsWith
  endsWith = endsWith
  indexOf = indexOf
  lastIndexOf = lastIndexOf
  indexOfAny = indexOfAny
  lastIndexOfAny = lastIndexOfAny
  countSubstrings = countSubstrings
  implode = implode
  join = join
  split = split
  replace = replace
  floatToStringRounded = floatToStringRounded
  isStringInteger = isStringInteger
  isStringFloat = isStringFloat
  intToUtf8Char = intToUtf8Char
  toUpper = toUpper
  utf8ToUpper = utf8ToUpper
  utf8ToLower = utf8ToLower
  hexStringToInt = hexStringToInt
  cutPrefix = cutPrefix
  intToStrWithDelimiter = intToStrWithDelimiter
  stripTags = stripTags
  tostring_any  = tostring_any
  tostring_r = tostring_r
  pprint = pprint

  toIntegerSafe = toIntegerSafe
}

return export
