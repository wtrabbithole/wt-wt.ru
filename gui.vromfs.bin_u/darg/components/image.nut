local function image(image, params={}, addchildren = null) {

  local children = params?.children
  if (children && type(children) !="array")
    children = [children]
  if (addchildren && children) {
    if (type(addchildren)=="array")
      children.extend(addchildren)
    else
      children.append(addchildren)
  }

  if(type(image)=="string")
    image=Picture(image) //handle svg here!!

  return {
    rendObj = ROBJ_IMAGE
    image = image
    size=SIZE_TO_CONTENT
  }.__update(params).__update({children=children})
}

return image