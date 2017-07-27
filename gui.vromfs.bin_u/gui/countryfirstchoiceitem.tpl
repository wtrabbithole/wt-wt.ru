VerticalListBox {
  id:t='country_choice_list_box';
  navigatorShortcuts:t='yes'
  on_select:t='onSelectCountry';

  <<#countries>>
  img {
    background-image:t='<<backgroundImage>>';
    class:t='firstChoiceCountryItem';
    border:t='yes'
    border-color:t='@black'
    margin-bottom:t='3'

    tooltip:t='<<tooltip>>';
    <<#disabled>>
    enable:t='no';
    img {
      background-image:t='#ui/gameuiskin#locked';
      position:t='absolute';
      size:t='@mIco, @mIco';
    }
    <</disabled>>

    <<#text>>
    textareaNoTab {
      pos:t='@mIco, 0.5@mIco-0.5h'
      position:t='relative'
      style:t=' font:@normal;'
      text:t='<<text>>'
    }
    <</text>>

    img {
      background-image:t='#ui/gameuiskin#help_tooltip'
      tooltip:t='<<desription>>'
      size:t='@cIco, @cIco'
      position:t='absolute'
      hide_when_tooltip_empty:t='yes'
      pos:t='pw - w - 0.01@scrn_tgt, 0.01@scrn_tgt'
    }
  }
  <</countries>>
}
