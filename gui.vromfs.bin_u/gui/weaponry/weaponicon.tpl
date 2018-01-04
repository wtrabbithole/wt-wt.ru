css-hier-invalidate:t="yes"
modIcon{
  id:t='icon'
  size:t='1@modIcoSize,1@modIcoSize'
  pos:t='0,0';
  position:t='relative'
  input-transparent:t="yes"
  css-hier-invalidate:t="yes"

  wallpaper{
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    size:t='pw, ph';
    css-hier-invalidate:t='yes'
    pattern{type:t='bright_texture';}
  }
  img{
    id:t='image'
    size:t='pw-2@weaponIconPadding,ph-2@weaponIconPadding'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
  }
  itemWinkBlock { buttonWink { _transp-timer:t='0';} }
  tdiv{
    id:t='bullets'
    size:t='pw-2@weaponIconPadding,ph-2@weaponIconPadding'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    css-hier-invalidate:t="yes"
  }
  warningIcon { id:t='warning_icon' }
  box {
    pos:t='ph-w-1@weaponIconPadding, ph-h-1@weaponIconPadding';
    position:t='absolute'
    max-width:t='pw';
    overflow:t='hidden'
    text {
      id:t='amount'
      smallFont:t='yes'
      text:t=''
      auto-scroll:t='medium'
    }
  }
}
