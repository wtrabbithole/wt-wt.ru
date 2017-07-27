  //pairs list taken from http://www.ibm.com/support/knowledgecenter/ssw_ibm_i_72/nls/rbagslowtoupmaptable.htm
const CASE_PAIR_LOWER = "abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿāăąćĉċčďđēĕėęěĝğġģĥħĩīĭįıĳĵķĺļľŀłńņňŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷźżžƃƅƈƌƒƙơƣƥƨƭưƴƶƹƽǆǉǌǎǐǒǔǖǘǚǜǟǡǣǥǧǩǫǭǯǳǵǻǽǿȁȃȅȇȉȋȍȏȑȓȕȗɓɔɗɘəɛɠɣɨɩɯɲɵʃʈʊʋʒάέήίαβγδεζηθικλμνξοπρστυφχψωϊϋόύώϣϥϧϩϫϭϯабвгдежзийклмнопрстуфхцчшщъыьэюяёђѓєѕіїјљњћќўџѡѣѥѧѩѫѭѯѱѳѵѷѹѻѽѿҁґғҕҗҙқҝҟҡңҥҧҩҫҭүұҳҵҷҹһҽҿӂӄӈӌӑӓӕӗәӛӝӟӡӣӥӧөӫӯӱӳӵӹաբգդեզէըթժիլխծկհձղճմյնշոչպջռսվտրցւփքօֆაბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰჱჲჳჴჵḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹἀἁἂἃἄἅἆἇἐἑἒἓἔἕἠἡἢἣἤἥἦἧἰἱἲἳἴἵἶἷὀὁὂὃὄὅὑὓὕὗὠὡὢὣὤὥὦὧᾀᾁᾂᾃᾄᾅᾆᾇᾐᾑᾒᾓᾔᾕᾖᾗᾠᾡᾢᾣᾤᾥᾦᾧᾰᾱῐῑῠῡⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
const CASE_PAIR_UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮIĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŹŻŽƂƄƇƋƑƘƠƢƤƧƬƯƳƵƸƼǄǇǊǍǏǑǓǕǗǙǛǞǠǢǤǦǨǪǬǮǱǴǺǼǾȀȂȄȆȈȊȌȎȐȒȔȖƁƆƊƎƏƐƓƔƗƖƜƝƟƩƮƱƲƷΆΈΉΊΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩΪΫΌΎΏϢϤϦϨϪϬϮАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЁЂЃЄЅІЇЈЉЊЋЌЎЏѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾӁӃӇӋӐӒӔӖӘӚӜӞӠӢӤӦӨӪӮӰӲӴӸԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՎՏՐՑՒՓՔՕՖႠႡႢႣႤႥႦႧႨႩႪႫႬႭႮႯႰႱႲႳႴႵႶႷႸႹႺႻႼႽႾႿჀჁჂჃჄჅḀḂḄḆḈḊḌḎḐḒḔḖḘḚḜḞḠḢḤḦḨḪḬḮḰḲḴḶḸḺḼḾṀṂṄṆṈṊṌṎṐṒṔṖṘṚṜṞṠṢṤṦṨṪṬṮṰṲṴṶṸṺṼṾẀẂẄẆẈẊẌẎẐẒẔẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸἈἉἊἋἌἍἎἏἘἙἚἛἜἝἨἩἪἫἬἭἮἯἸἹἺἻἼἽἾἿὈὉὊὋὌὍὙὛὝὟὨὩὪὫὬὭὮὯᾈᾉᾊᾋᾌᾍᾎᾏᾘᾙᾚᾛᾜᾝᾞᾟᾨᾩᾪᾫᾬᾭᾮᾯᾸᾹῘῙῨῩⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ"

::g_string <- {
  INVALID_INDEX = -1

  intRegExp = regexp2(@"^-?\d+$")
  floatRegExp = regexp2(@"^-?\d+\.?\d*$")
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
function g_string::slice(str, start = 0, end = null)
{
  str = str || ""
  local total = str.len()
  if (start < 0)
    start += total
  start = ::clamp(start, 0, total)
  if (end == null)
    end = total
  else if (end < 0)
    end += total
  end = ::clamp(end, start, total)
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
function g_string::substring(str, start = 0, length = null)
{
  local end = length
  if (length != null && length >= 0)
  {
    str = str || ""
    local total = str.len()
    if (start < 0)
      start += total
    start = ::clamp(start, 0, total)
    end = start + length
  }
  return ::g_string.slice(str, start, end)
}

/**
 * Determines whether the beginning of the string matches a specified substring.
 * Like C# function String.StartsWith().
 * @param {string}  str - Input string.
 * @param {string}  value - Matching substring.
 * @return {boolean}
 */
function g_string::startsWith(str, value)
{
  str = str || ""
  value = value || ""
  return ::g_string.slice(str, 0, value.len()) == value
}

/**
 * Determines whether the end of the string matches the specified substring.
 * Like C# function String.EndsWith().
 * @param {string}  str - Input string.
 * @param {string}  value - Matching substring.
 * @return {boolean}
 */
function g_string::endsWith(str, value)
{
  str = str || ""
  value = value || ""
  return ::g_string.slice(str, - value.len()) == value
}

/**
 * Reports the index of the first occurrence in the string of a specified substring.
 * Like C# function String.IndexOf().
 * @param {string}  str - Input string.
 * @param {string}  value - Searching substring.
 * @param {integer} [startIndex=0] - Search start index.
 * @return {integer} - index, or -1 if not found.
 */
function g_string::indexOf(str, value, startIndex = 0)
{
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
function g_string::lastIndexOf(str, value, startIndex = 0)
{
  str = str || ""
  value = value || ""
  local idx = INVALID_INDEX
  local curIdx = startIndex - 1
  local length = str.len()
  while (curIdx < length - 1)
  {
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
function g_string::indexOfAny(str, anyOf, startIndex = 0)
{
  str = str || ""
  anyOf = anyOf || [ "" ]
  local idx = INVALID_INDEX
  foreach (value in anyOf)
  {
    local curIdx = ::g_string.indexOf(str, value, startIndex)
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
function g_string::lastIndexOfAny(str, anyOf, startIndex = 0)
{
  str = str || ""
  anyOf = anyOf || [ "" ]
  local idx = INVALID_INDEX
  foreach (value in anyOf)
  {
    local curIdx = ::g_string.lastIndexOf(str, value, startIndex)
    if (curIdx != INVALID_INDEX && (idx == INVALID_INDEX || curIdx > idx))
      idx = curIdx
  }
  return idx
}

//returns the number of entries of @substr in @str.
function g_string::countSubstrings(str, substr)
{
  local res = -1
  local findex = -1
  for(res; findex != null; res++)
    findex = str.find(substr, ++findex)
  return res
}

//remove start and end spaces and line breaks from @str
function g_string::clearBorderSymbolsMultiline(str)
{
  return ::clearBorderSymbols(str, [" ", 0x0A.tochar(), 0x0D.tochar()])
}

//Change case to upper for set up number of symbols
function g_string::toUpper(string, symbolsNum = 0)
{
  if (symbolsNum <= 0)
   symbolsNum = string.len()
  if (symbolsNum >= string.len())
    return string.toupper()
  return slice(string, 0, symbolsNum).toupper() + slice(string, symbolsNum)
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
function g_string::join(pieces, glue)
{
  local joined = ""
  foreach (piece in pieces)
    joined += (joined.len() ? glue : "") + piece
  return joined
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
function g_string::split(joined, glue)
{
  local pieces = []
  local joinedLen = joined.len()
  if (!joinedLen)
    return pieces
  local glueLen = glue.len()
  local start = 0
  while (start <= joinedLen)
  {
    local end = joined.find(glue, start)
    if (end == null)
      end = joinedLen
    pieces.append(joined.slice(start, end))
    start = end + glueLen
  }
  return pieces
}

function g_string::isStringInteger(str)
{
  return intRegExp.match(str)
}

function g_string::isStringFloat(str)
{
  return floatRegExp.match(str)
}

function g_string::replaceSym(str, from, to)
{
  if (!str)
    return ""
  local str2 = []
  foreach (sym in str)
  {
    if (sym == from)
      sym = to
    str2.append(sym.tochar())
  }
  return join(str2, "")
}

function g_string::intToUtf8Char(c)
{
  if (c <= 0x7F)
    return c.tochar()
  if (c <= 0x7FF)
    return (0xc0 + (c>>6)).tochar() + (0x80 + (c & 0x3F)).tochar()
  //if (c <= 0xFFFF)
  return (0xe0 + (c>>12)).tochar() + (0x80 + ((c>>6) & 0x3F)).tochar() + (0x80 + (c & 0x3F)).tochar()
}

function g_string::utf8ToUpper(str, symbolsNum = 0)
{
  if(str.len() < 1)
    return str
  local utf8Str = utf8(str)
  local strLength = utf8Str.charCount()
  if (symbolsNum <= 0 || symbolsNum >= strLength)
    return utf8Str.strtr(CASE_PAIR_LOWER, CASE_PAIR_UPPER)
  return utf8(utf8Str.slice(0, symbolsNum)).strtr(CASE_PAIR_LOWER, CASE_PAIR_UPPER) +
   utf8Str.slice(symbolsNum, strLength)
}

function g_string::utf8ToLower(str)
{
  return utf8(str).strtr(CASE_PAIR_UPPER, CASE_PAIR_LOWER)
}

function g_string::hexStringToInt(hexString)
{
  // Does the string start with '0x'? If so, remove it
  if (hexString.len() >= 2 && hexString.slice(0, 2) == "0x")
    hexString = hexString.slice(2)

  // Get the integer value of the remaining string
  local res = 0
  foreach (character in hexString)
  {
    local nibble = character - '0'
    if (nibble > 9)
      nibble = ((nibble & 0x1F) - 7)
    res = (res << 4) + nibble
  }

  return res
}