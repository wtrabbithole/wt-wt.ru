div {
  size:t='sw, sh';
  position:t='root';
  pos:t='0, 0';
  behavior:t='button';
  on_click:t='goBack';
  on_r_click:t='goBack';
  input-transparent:t='yes';
  accessKey:t='Esc | J:B';
}

popup_menu {
  id:t='cluster_select';
  cluster_select:t='yes';
  menu_align:t='<<align>>';
  pos:t='<<position>>';
  position:t='root';
  total-input-transparent:t='yes';

  MultiSelect {
    id:t='cluster_multi_select';
    childsActivate:t='yes';
    flow:t='vertical';
    on_select:t='onClusterSelect';
    navigatorShortcuts:t='full';
    _on_cancel_edit:t='goBack';

    <<#clusters>>
      multiOption {
        id:t='<<id>>';
        behavior:t='textarea';
        value:t='<<value>>';
        on_wrap_up:t='onWrapUp';
        on_wrap_down:t='onWrapDown';
        shortcutActivate:t='J:A | Space';
        text:t='<<text>>';
        cluster_option:t='yes';

        CheckBoxImg {}
      }
    <</clusters>>
  }
  popup_menu_arrow{}
}

dummy {
  on_click:t = 'goBack'
  behavior:t='accesskey'
  accessKey:t = 'Esc | J:B'
}

