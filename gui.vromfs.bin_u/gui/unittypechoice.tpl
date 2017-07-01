div {
  id:t='unit_type_list_box';
  width:t='pw'

  flow:t="h-flow"
  flow-align:t='center'

  behaviour:t='posNavigator'
  navigatorShortcuts:t='yes'
  on_select:t='onSelectUnitType';

  <<#unitTypeItems>>
  img {
    background-image:t='<<backgroundImage>>';
    tooltip:t='<<tooltip>>';
    class:t='firstChoiceUnitItem';

    <<#videoPreview>>
    movie {
      movie-load='<<videoPreview>>'
      movie-autoStart:t='yes'
      movie-loop:t='yes'
    }
    <</videoPreview>>

    textarea {
      text:t='<<text>>';
    }

    tdiv {
      css-hier-invalidate:t='yes';
      <<#countryItems>>
      img {
        size:t='@cIco, @cIco';
        background-image:t='<<countryImg>>';
        margin-top:t='0.01@scrn_tgt_font';
        margin-left:t='0.01@scrn_tgt_font';
      }
      <</countryItems>>
    }

    img {
      background-image:t='#ui/gameuiskin#help_tooltip'
      tooltip:t='<<desription>>'
      size:t='@cIco, @cIco'
      position:t='absolute'
      hide_when_tooltip_empty:t='yes'
      pos:t='pw - w - 0.01@scrn_tgt, 0.01@scrn_tgt'
    }
  }
  <</unitTypeItems>>
}
