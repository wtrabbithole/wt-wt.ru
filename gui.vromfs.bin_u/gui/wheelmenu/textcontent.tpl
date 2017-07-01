tdiv {
  top:t='50%ph-50%h'
  position:t='relative'
  flow:t='vertical'
  total-input-transparent:t='yes'
  <<#type>>
    type:t='<<type>>'
  <</type>>
  tdiv {
    left:t='50%pw-50%w'
    position:t='relative'
    css-hier-invalidate:t='yes'
    textareaNoTab {
      text:t='<<shortcutText>>'
      overlayTextColor:t='hotkey'
    }
    textareaNoTab { text:t=' ' }
    textareaNoTab { text:t='#ui/mdash' }
    textareaNoTab { text:t=' ' }
    textareaNoTab {
      text:t='<<name>>'
      chatMode:t='<<#squad>>squad<</squad>><<^squad>>team<</squad>>'
    }
  }
  textareaNoTab {
    text:t='<<additionalText>>'
    tinyFont:t='yes'
    hideEmptyText:t='yes'
  }
}
