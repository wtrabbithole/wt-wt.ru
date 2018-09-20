local string = require("string.nut")

local function testFunction(func, tests=[], shouldPass=true, testname = null) {
  local a = string.isStringInteger
  local funcname = testname ?? func.getinfos().name
  foreach (test in tests) {
    local testname = test?.name ?? test
    local testres = test?.res ?? shouldPass
    local testarg = test?.arg ?? test
    local failed = false
    try{
      if (testres != func(test))
        failed = true
    }
    catch(e) {
      failed = !shouldPass
    }
    if (failed)
      print("test for func: " + funcname + " failed. Func argument: " + testname + "\n")
  }
}

testFunction(string.isStringInteger, [12,-12,"12312","-123123","-0"], true)
testFunction(string.isStringInteger, ["2.2","-2.2","2.0","2.",-2.0,2.2,"as","12a","12a3"], false)
testFunction(string.isStringFloat, ["-123543.2","123","-123","123.0","0","-0","1","2",5,-12, 12.2,-12.2], true)
testFunction(string.isStringFloat, ["-123543.2.2","a123","--123","12s3.0","123.-2","as",["-0"],{a="1"}], false)
