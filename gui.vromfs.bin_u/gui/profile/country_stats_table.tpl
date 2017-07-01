table {
  id:t='country_stats';
  position:t='relative';
  pos:t='0.5pw - 0.5w, 0';
  width:t='pw';

  tr {
    td {
    }
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#unit_amount_icon';
        tooltip:t='#profile/units_own';
      }
    }
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#item_icon_elite';
        tooltip:t='#profile/elite_units_own';
      }
    }
    <<#hasMedals>>
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#sh_medal';
        tooltip:t='#profile/medal_own';
      }
    }
    <</hasMedals>>
  }
  <<#rows>>
  tr{
    td {
      img {
        size:t='@cIco, @cIco';
        background-image:t='<<icon>>';
      }
    }
    <<#nums>>
    td {
      activeText {
        pos:t='0.5pw - 0.5w';
        position:t='relative';
        padding-lest:t='11';
        text:t='<<num>>';
        text-align:t='center';
      }
    }
    <</nums>>
  }
  <</rows>>
}
