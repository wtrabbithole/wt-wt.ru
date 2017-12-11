g_cached_files_table <- {}

function cached_is_existing_image(fn, assertText = null)
{
  if (is_gui_webcache_enabled()) // images always "exist" when gui webcache enabled
    return true;

  if (!(fn in g_cached_files_table))
  {
    g_cached_files_table[fn] <- is_existing_file(fn, false)
    if (!g_cached_files_table[fn] && assertText)
      ::dagor.assertf(false, ::format(assertText, fn))
  }
  return g_cached_files_table[fn]
}

function check_image_exist(img, assertText = null)
{
  if (img == "")
    return true

  img = regexp2("\\?P1$").replace("", img)
  img = regexp2("\\?x1ac$").replace("", img)

  if (regexp2("^#[^\\s]+#[^\\s]").match(img)) //skin
  {
    local skinName = regexp2("^#|#[^\\s]+").replace("", img)
    return ::cached_is_existing_image(skinName + ".ta.bin", assertText)
  }

  img = regexp2("^#").replace("", img)
  if (regexp2("[^\\s].jpg$").match(img))
    return ::cached_is_existing_image(img, assertText)

  return ::cached_is_existing_image(img + ".ddsx", assertText)
}

function check_blk_images(blk, assertText = null)
{
  foreach(tag in ["background-image", "foreground-image"])
    foreach(img in (blk % tag))
      if (typeof(img) == "string")
        if (!::check_image_exist(img, assertText))
          return false

  local totalBlocks = blk.blockCount()
  for(local i = 0; i < totalBlocks; i++)
    if (!::check_blk_images(blk.getBlock(i), assertText))
      return false
  return true
}

function check_blk_images_by_file(fileName)
{
  local blk = ::DataBlock()
  if (!blk.load(fileName))
  {
    ::dagor.assertf(false, "Error: cant load loading bg: " + fileName)
    return false
  }
  return ::check_blk_images(blk, "Error: cant load image %s for " + fileName)
}
