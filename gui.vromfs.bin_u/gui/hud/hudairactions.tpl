tdiv {
  css-hier-invalidate:t='yes';
  padding-left:t='0.005@scrn_tgt_font';

  <<#items>>
    button {
      behaviour:t='touchArea';
      id:t='<<id>>';
      size:t='0.06@scrn_tgt_font, 0.06@scrn_tgt_font';
      margin-left:t='0.005@scrn_tgt_font';
      padding:t='0.003@scrn_tgt_font';
      background-color:t='#77333333';
      img {
        background-image:t='<<image>>';
        size:t='pw, ph';
      }

      shortcut_id:t=<<action>>;
      on_click:t='onShortcutOff';
      on_pushed:t='onShortcutOn';
      touch-area-id:t='<<areaId>>'
    }
  <</items>>

}
