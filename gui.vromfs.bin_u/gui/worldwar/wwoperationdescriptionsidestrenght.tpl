tdiv {
  id:t='strenght_<<sideName>>'
  height:t='ph'
  flow:t='vertical'
  <<#invert>>
    pos:t='pw-w, 0'; position:t='relative'
  <</invert>>

  <<#unitString>>
    <<^invert>>
    tdiv {
      id:t='<<unitName>>'
      pos:t='0, 0'
      position:t='relative'
      <<^isLastElement>>
        height:t='fh'
        max-height:t='1.5@tableIcoSize'
      <</isLastElement>>

      tdiv {
        img {
          size:t='1@tableIcoSize, 1@tableIcoSize'
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          margin-left:t='2@framePadding'
          margin-right:t='2@framePadding'
          background-image:t='<<unitIcon>>'
          shopItemType:t='<<shopItemType>>'
        }

        textareaNoTab {
          margin-right:t='2@framePadding'
          talign:t='left'
          text:t='<<sideUnitCount>>'
        }

        textareaNoTab {
          text-align:t='left'
          text:t='<<unitName>>'
        }
      }
    }
    <</invert>>
    <<#invert>>
    tdiv {
      pos:t='pw-w, 0'
      position:t='relative'
      css-hier-invalidate:t='yes'
      <<^isLastElement>>
        height:t='fh'
        max-height:t='1.5@tableIcoSize'
      <</isLastElement>>

      tdiv {
        textareaNoTab {
          margin-right:t='4@framePadding'
          text-align:t='right'
          text:t='<<unitName>>'
        }

        textareaNoTab {
          margin-right:t='2@framePadding'
          talign:t='right'
          text:t='<<sideUnitCount>>'
        }

        img {
          size:t='1@tableIcoSize, 1@tableIcoSize'
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          margin-right:t='2@framePadding'
          background-image:t='<<unitIcon>>'
          shopItemType:t='<<shopItemType>>'
        }
      }
    }
    <</invert>>
  <</unitString>>
}