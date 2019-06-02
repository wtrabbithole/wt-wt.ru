div {
  size:t='sw, sh'
  pos:t='0, 0'
  position:t='root'

  behavior:t='button'
  behavior:t='accesskey'
  accessKey:t='Esc | J:B'

  on_click:t='close'
  on_r_click:t='close'
}

popup_menu {
  id:t='main_frame'
  cluster_select:t='yes'
  menu_align:t='<<align>>'
  pos:t='<<position>>'
  position:t='root'

  include "gui/commonParts/multiSelect"

  popup_menu_arrow{}
}