//based on https://werxltd.com/wp/2010/05/13/javascript-implementation-of-javas-string-hashcode-method/

local function stringhash(string) {
    ::assert(::type(string)=="string", @() $"hash by string requires type string, got: {::type(string)}")
    local hash = 0
    if (string.len() == 0) {
        return hash
    }
    for (local i = 0; i < string.len(); i++) {
        local char = string[i].tointeger()
        hash = ((hash<<5)-hash)+char
    }
    if (hash < 0)
      hash = -hash
    return hash
}
return stringhash