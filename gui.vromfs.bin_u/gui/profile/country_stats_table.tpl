table {
  id:t='country_stats';
  position:t='relative';
  pos:t='0.5pw - 0.5w, 0';
  width:t='pw';
  behavior:t = 'PosNavigator';
  class:t='lbTable';
  selfFocusBorder:t='yes'
  overflow-y:t='auto';
  scrollbarShortcuts:t='yes';
  on_wrap_up:t='onWrapUp';
  on_wrap_down:t='onWrapDown';

  tr {
    height:t='@cIco'
    td {
    }
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#unit_amount_icon';
        background-svg-size:t='@cIco, @cIco';
        tooltip:t='#profile/units_own';
      }
    }
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#item_icon_elite';
        background-svg-size:t='@cIco, @cIco';
        tooltip:t='#profile/elite_units_own';
      }
    }
    <<#hasMedals>>
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#sh_medal.svg';
        background-svg-size:t='@cIco, @cIco';
        tooltip:t='#profile/medal_own';
      }
    }
    <</hasMedals>>
  }
  <<#rows>>
  tr{
    inactive:t='yes'
    td {
      img {
        size:t='@cIco, @cIco';
        left:t='0.5pw - 0.5w';
        top:t='0.5ph - 0.5h';
        position:t='relative';
        background-image:t='<<icon>>';
        background-svg-size:t='@cIco, @cIco';
      }
    }
    <<#nums>>
    td {
      activeText {
        pos:t='0.5pw - 0.5w';
        position:t='relative';
        text:t='<<num>>';
        text-align:t='center';
      }
    }
    <</nums>>
  }
  <</rows>>
}
