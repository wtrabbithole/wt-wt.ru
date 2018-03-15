//pairs list taken from http://www.ibm.com/support/knowledgecenter/ssw_ibm_i_72/nls/rbagslowtoupmaptable.htm
const CASE_PAIR_LOWER = "abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿāăąćĉċčďđēĕėęěĝğġģĥħĩīĭįıĳĵķĺļľŀłńņňŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷźżžƃƅƈƌƒƙơƣƥƨƭưƴƶƹƽǆǉǌǎǐǒǔǖǘǚǜǟǡǣǥǧǩǫǭǯǳǵǻǽǿȁȃȅȇȉȋȍȏȑȓȕȗɓɔɗɘəɛɠɣɨɩɯɲɵʃʈʊʋʒάέήίαβγδεζηθικλμνξοπρστυφχψωϊϋόύώϣϥϧϩϫϭϯабвгдежзийклмнопрстуфхцчшщъыьэюяёђѓєѕіїјљњћќўџѡѣѥѧѩѫѭѯѱѳѵѷѹѻѽѿҁґғҕҗҙқҝҟҡңҥҧҩҫҭүұҳҵҷҹһҽҿӂӄӈӌӑӓӕӗәӛӝӟӡӣӥӧөӫӯӱӳӵӹաբգդեզէըթժիլխծկհձղճմյնշոչպջռսվտրցւփքօֆაბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰჱჲჳჴჵḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹἀἁἂἃἄἅἆἇἐἑἒἓἔἕἠἡἢἣἤἥἦἧἰἱἲἳἴἵἶἷὀὁὂὃὄὅὑὓὕὗὠὡὢὣὤὥὦὧᾀᾁᾂᾃᾄᾅᾆᾇᾐᾑᾒᾓᾔᾕᾖᾗᾠᾡᾢᾣᾤᾥᾦᾧᾰᾱῐῑῠῡⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
const CASE_PAIR_UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮIĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŹŻŽƂƄƇƋƑƘƠƢƤƧƬƯƳƵƸƼǄǇǊǍǏǑǓǕǗǙǛǞǠǢǤǦǨǪǬǮǱǴǺǼǾȀȂȄȆȈȊȌȎȐȒȔȖƁƆƊƎƏƐƓƔƗƖƜƝƟƩƮƱƲƷΆΈΉΊΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩΪΫΌΎΏϢϤϦϨϪϬϮАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЁЂЃЄЅІЇЈЉЊЋЌЎЏѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾӁӃӇӋӐӒӔӖӘӚӜӞӠӢӤӦӨӪӮӰӲӴӸԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՎՏՐՑՒՓՔՕՖႠႡႢႣႤႥႦႧႨႩႪႫႬႭႮႯႰႱႲႳႴႵႶႷႸႹႺႻႼႽႾႿჀჁჂჃჄჅḀḂḄḆḈḊḌḎḐḒḔḖḘḚḜḞḠḢḤḦḨḪḬḮḰḲḴḶḸḺḼḾṀṂṄṆṈṊṌṎṐṒṔṖṘṚṜṞṠṢṤṦṨṪṬṮṰṲṴṶṸṺṼṾẀẂẄẆẈẊẌẎẐẒẔẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸἈἉἊἋἌἍἎἏἘἙἚἛἜἝἨἩἪἫἬἭἮἯἸἹἺἻἼἽἾἿὈὉὊὋὌὍὙὛὝὟὨὩὪὫὬὭὮὯᾈᾉᾊᾋᾌᾍᾎᾏᾘᾙᾚᾛᾜᾝᾞᾟᾨᾩᾪᾫᾬᾭᾮᾯᾸᾹῘῙῨῩⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ"

local INVALID_INDEX = -1

local rootTable = getroottable()
local intRegExp = null
local floatRegExp = null
local stripTagsConfig = null

function clamp(value, min, max) { //copied from math to no expose new dependency. clamp\min\max should be in language or system stdlibrary
  return (value < min) ? min : (value > max) ? max : value
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

local function tostring_any(input) {
  if (::type(input) != "userdata"){
    return input.tostring()
  }
  else
    return "#USERDATA#"
}

local function tostring_r(input, indent = "  ", maxdeeplevel = null) {
  local out = ""
  local deeplevel = 0
  local table_types = ["class","table","instance"]
  local simple_types = ["string", "float", "bool", "integer"]
  local complex_types = ["userdata","weakreference"]
  local function_types = ["function", "generator", "thread"]
  local rawtypes = []
  rawtypes.extend(complex_types)
  rawtypes.extend(simple_types)

  local func_tostring = function(func) {
    local info = func.getinfos()
    local out = ""
    if (!info.native) {
      local params = info.parameters.reduce(@(res, curval) res.tostring() + ", " + curval)
      local fname = "" + info.name
      if (fname.find("(null : 0x0") != null)
        fname = "@"
      out += "(function): " + info.src + ",(" + fname + ") arguments(" + params + ")"
    } else if (info.native) {
      out += "(nativefunction): " + info.name

    } else {
      out += func.tostring()
    }
    return out
  }

  local sub_tostring_r = function(input, indent, curdeeplevel, maxdeeplevel = null, arrayElem = false, separator = "\n") {
    local out = ""
    if (maxdeeplevel != null && curdeeplevel == maxdeeplevel)
      return out
    foreach (key, value in input) {
      if (simple_types.find(::type(value)) != null && function_types.find(::type(value)) != -1) {
        out += separator
        if (!arrayElem) {
           out += indent + tostring_any(key) +  " = "
        }
        out += value.tostring()
      }
      else if (function_types.find(::type(value)) != null &&
        function_types.find(::type(value)) != -1) {
        out += separator
        if (!arrayElem) {
           out += indent + tostring_any(key) +  " = "
        }
        out += func_tostring(value)
      }
      else if (["null"].find(::type(value)) != null) {
        out += separator
        if (!arrayElem) {
           out += indent + tostring_any(key) +  " = "
        }
        out += "null"
      }
      else if (::type(value) == "array" && function_types.find(::type(value)) != -1) {
        out += separator
        if (!arrayElem) {
          out += indent + key.tostring() +  " = "
        }
        out += "[" + callee()(value, indent + "  ", curdeeplevel+1, maxdeeplevel=maxdeeplevel, true, " ") + " ]"
      }
      else if (table_types.find(::type(value)) != null && table_types.find(::type(value)) != -1) {
        out += "\n" + indent
        if (!arrayElem) {
          out += tostring_any(key) +  " = "
        }
        out += "{" + callee()(value, indent + "  ", curdeeplevel+1, maxdeeplevel) + "\n" + indent + "}"
        if (arrayElem)
          out += "\n"
      }
      else {
        out += "\n" + indent
        if (!arrayElem) {
          out += tostring_any(key) +  " = "
        }
        out += tostring_any(value) + "\n"
      }
    }
    
    return out
  }
  if (table_types.find(::type(input)) != null && table_types.find(::type(input)) != -1) {
    out += input.tostring() + " { "
    out += sub_tostring_r(input, indent, 0, maxdeeplevel, false,"\n")
    out += "\n}"
  } else if (::type(input)=="array"){
    out += input.tostring() + " ["
    out += sub_tostring_r(input, "  ", 0, maxdeeplevel, true, " ")
    if (out.slice(-1) != "\n")
      out += " "
    out += "]"
  } else {
    out += sub_tostring_r([input], "", 0, maxdeeplevel, true, "")
  }

  return out +"\n"
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

//remove start and end spaces and line breaks from @str
local function clearBorderSymbolsMultiline(str) {
  return ::clearBorderSymbols(str, [" ", 0x0A.tochar(), 0x0D.tochar()])
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
  return pieces.filter(@(index,val) val != "").reduce(@(prev, cur) prev + glue + cur) ?? ""
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
local function join(pieces, glue) {
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
local function split(joined, glue) {
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
    pieces.append(joined.slice(start, end))
    start = end + glueLen
  }
  return pieces
}

local function replaceSym(str, from, to) {
  if (!str)
    return ""
  local str2 = []
  foreach (sym in str) {
    if (sym == from)
      sym = to
    str2.append(sym.tochar())
  }
  return join(str2, "")
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
  local utf8Str = utf8(str)
  local strLength = utf8Str.charCount()
  if (symbolsNum <= 0 || symbolsNum >= strLength)
    return utf8Str.strtr(CASE_PAIR_LOWER, CASE_PAIR_UPPER)
  return utf8(utf8Str.slice(0, symbolsNum)).strtr(CASE_PAIR_LOWER, CASE_PAIR_UPPER) +
   utf8Str.slice(symbolsNum, strLength)
}

local function utf8ToLower(str) {
  return utf8(str).strtr(CASE_PAIR_UPPER, CASE_PAIR_LOWER)
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
  if ((id.len() > pLen) && (id.slice(0, pLen) == prefix))
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


//  presize is a round presize (like 0.01).
//  value can be received by round_by_value from math.nut, or same
local function roundedFloatToString(value, presize)
{
  if (presize >= 1)
  {
    local res = (value / presize).tointeger().tostring()
    for(local p = presize; p > 1; p /= 10)
      res += "0" //we no need float trash below presize
    return res //we no need e+8 in the big numbers too
  }
  return ::format("%." + (-log10(presize).tointeger()) + "f", value)
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

local function stripTags(str) {
  if (!str || !str.len())
    return ""
  if (stripTagsConfig == null)
    assert(stripTagsConfig != null, "stripTags is not working without regexp")
  foreach(test in stripTagsConfig)
    str = test.re2.replace(test.repl, str)
  return str
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
  clearBorderSymbolsMultiline = clearBorderSymbolsMultiline
  toUpper = toUpper
  implode = implode
  join = join
  split = split
  isStringInteger = isStringInteger
  isStringFloat = isStringFloat
  replaceSym = replaceSym
  intToUtf8Char = intToUtf8Char
  utf8ToUpper = utf8ToUpper
  utf8ToLower = utf8ToLower
  hexStringToInt = hexStringToInt
  cutPrefix = cutPrefix
  intToStrWithDelimiter = intToStrWithDelimiter
  roundedFloatToString = roundedFloatToString
  stripTags = stripTags
  tostring_any  = tostring_any
  tostring_r = tostring_r
}

return export
