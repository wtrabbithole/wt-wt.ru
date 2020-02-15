tdiv {
  <<#needHeader>>
    textarea {
      text:t='<<?ugm/price>><<?ui/colon>>'
      removeParagraphIndent:t='yes'
    }
  <</needHeader>>

  <<#haveDiscount>>
    textarea {
      text:t='<<listPriceText>>'
      removeParagraphIndent:t='yes'
      overlayTextColor:t='faded'
      tdiv {
        size:t='pw, 1@dp'
        position:t='absolute'
        pos:t='0, 50%ph-50%h'
        background-color:t='@commonTextColor'
      }
    }
  <</haveDiscount>>

  tdiv {
    <<#haveDiscount>>
      margin-left:t='0.01@scrn_tgt'
    <</haveDiscount>>

    textarea {
      text:t='<<priceText>>'
      removeParagraphIndent:t='yes'

      <<#haveDiscount>>
        overlayTextColor:t='good'
      <</haveDiscount>>
    }
  }
}