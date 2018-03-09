//Darg Flutter\Functional Framework
//experimental framework to simplify making of layout
local mergeElements = require("darg/dff/library.nut").mergeElements

local textS = function(text, style={}) {
  return mergeElements({rendObj = ROBJ_STEXT text=text}, style, ["rendObj","text"])
}

local text = textS

local textD = function(text, style={}) {
  return mergeElements({rendObj = ROBJ_DTEXT text=text}, style, ["rendObj","text"])
}

local textArea = function(text, style={}) {
  return mergeElements({rendObj = ROBJ_TEXTAREA behavior=Behaviors.TextArea text=text}, style, ["rendObj","text"], ["behavior"])
}

local imgNine = function(image, style={}) {
  return mergeElements({rendObj = ROBJ_9RECT image=image size=flex()}, style, ["rendObj","image"])
}

local imgH = function(image, style={}) {
  return {rendObj = ROBJ_IMAGE image=image size=[flex(),SIZE_TO_CONTENT]}.__update(style) //TODO: ignore image and rendObj fields
}

local img = function(image, style={}) {
  return {rendObj = ROBJ_IMAGE image=image size=SIZE_TO_CONTENT}.__update(style) //TODO: ignore image and rendObj fields
}

local imgV = function(image, style={}) {
  return {rendObj = ROBJ_IMAGE image=image size=[flex(),SIZE_TO_CONTENT]}.__update(style)
}


/*
local size = function(size, ...) {
}

local width = function(width, ...) {
}

local height = function(height, ...) {
}

local margin = function(margin, ...) {
}

local padding = function(height, ...) {
}
*/

local center = function(...) {
  return {children=vargv, size = flex(), halign = HALIGN_CENTER, valign=VALIGN_MIDDLE}
}

local halign_center = function(...) {
  return {children=vargv, size = [flex(), SIZE_TO_CONTENT], halign = HALIGN_CENTER}
}

local halign_left = function(...) {
  return {children=vargv, size = [flex(), SIZE_TO_CONTENT], halign = HALIGN_LEFT}
}

local halign_right = function(...) {
  return {children=vargv, size = [flex(), SIZE_TO_CONTENT], halign = HALIGN_RIGHT}
}

local valign_middle = function(...) {
  return {children=vargv, size = [SIZE_TO_CONTENT, flex()], valign = VALIGN_MIDDLE}
}

local valign_top = function(...) {
  return {children=vargv, size = [SIZE_TO_CONTENT, flex()], valign = VALIGN_TOP}
}

local valign_bottom = function(...) {
  return {children=vargv, size = [SIZE_TO_CONTENT, flex()], valign = VALIGN_BOTTOM}
}


local elem = function(elem, ...) {
  local children = elem?.children ?? []
  local add_children = []
  local default_style = {}//{flow = FLOW_HORIZONTAL size = SIZE_TO_CONTENT}
  foreach (v in vargv) {
    add_children.append(v)
  }
  if (type(children) in ["table","class","function"] ) {
    children = [children]
  } else {
    children = []
  }
  children.extend(add_children)
  
  return default_style.__update(elem).__update({children=children})
}

local box = function(elem_, ...) {
  return elem(elem_.__update({rendObj = ROBJ_BOX size=flex()}), vargv)
}

local frame = function(elem_, ...) {
  return elem(elem_.__update({rendObj = ROBJ_FRAME size=flex()}), vargv)
}

local elemFlex = function(elem_, ...) {
  return elem(elem_.__update({size=flex()}), vargv)
}

local elemH = function(elem, ...) {
  local children = elem?.children ?? []
  local add_children = []
  local default_style = {flow = FLOW_HORIZONTAL size = flex() }
  foreach (v in vargv) {
    add_children.append(v)
  }
  if (type(children) in ["table","class","function"] ) {
    children = [children]
  } else {
    children = []
  }
  children.extend(add_children)
  
  return default_style.__update(elem).__update({children=children})
}

local elemV = function(elem, ...) {
  local children = elem?.children ?? []
  local add_children = []
  local default_style = {size = flex() flow = FLOW_VERTICAL }
  foreach (v in vargv) {
    add_children.append(v)
  }
  if (type(children) in ["table","class","function"] ) {
    children = [children]
  } else {
    children = []
  }
  children.extend(add_children)
  return default_style.__update(elem).__update({children=children})
}

local export = {
  text     = text
  textS    = textS
  textD    = textD
  textArea = textArea
  imgNine  = imgNine
  img      = img
  imgH     = imgH
  imgV     = imgV
  elem     = elem
  elemH     = elemH
  elemV     = elemV
  box = box
  frame = frame
  elemFlex = elemFlex

  red = Color(255,0,0)
  blue = Color(0,0,255)
  green = Color(0,255,0)
  magenta = Color(255,0,255)
  yellow = Color(255,255,0)
  cyan = Color(0,255,255)
  gray = Color(128,128,128)
  lightgray = Color(192,192,192)
  darkgray = Color(64,64,64)
  black = Color(0,0,0)
  white = Color(255,255,255)
}

return export