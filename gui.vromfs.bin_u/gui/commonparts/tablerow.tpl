tr {
  id:t='<<row_id>>'
  <<#even>> even:t='yes' <</even>>
  <<@trParams>>

  <<#cell>>
  td {
    <<#params>>
      id:t='<<id>>'
      <<#active>> active:t='yes' <</active>>
      display:t='<<display>>'
      <<#cellType>> cellType:t='<<cellType>>' <</cellType>>
      <<#width>>width:t='<<width>>' <</width>>
      <<#tdalign>> tdalign:t='<<tdalign>>' <</tdalign>>
      <<#tooltip>> tooltip:t='<<tooltip>>' <</tooltip>>
      <<@rawParam>>

      <<#callback>>
        behaviour:t='button'
        on_click:t='<<callback>>'
      <</callback>>

      <<#needText>>
        <<@textType>> {
          id:t='txt_<<id>>'
          <<#width>>
            width:t='fw'
            pare-text:t='yes'
          <</width>>
          text:t='<<text>>'
          <<@textRawParam>>
        }
      <</needText>>

      <<#image>>
        <<@imageType>> {
          id:t='img_<<id>>'
          background-image:t='<<image>>'
          <<@imageRawParams>>
        }
      <</image>>
      <<^image>>
        <<#fontIcon>>
        <<@fontIconType>> {
          fonticon { text:t='<<fontIcon>>' }
        }
        <</fontIcon>>
      <</image>>

    <</params>>
    <<^params>>
      activeText {
        <<#width>>
          width:t='pw'
          pare-text:t='yes'
        <</width>>
        text:t='<<text>>'
      }
    <</params>>
  }
  <</cell>>
}
