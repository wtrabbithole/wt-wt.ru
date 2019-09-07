icon {
  id:t='crew_gunner';
  state:t='ok';
  hudCrewStatus:t='yes'
  icon_type:t='crew_gunner'
  size:t='ph/7, ph/7';
  tooltip:t=''

  position:t='absolute';
  pos:t='pw/2 + (0.42pw) * 0.972 - w/2, ph/2 + (0.42ph) * 0.25 - h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#crew_gunner_indicator';

  timeBar {
    id:t='transfere_indicatior';
  }
}

icon {
  id:t='crew_driver';
  state:t='ok';
  hudCrewStatus:t='yes';
  icon_type:t='crew_driver'
  size:t='ph/7, ph/7';
  tooltip:t=''

  position:t='absolute';
  pos:t='pw/2 + (0.42pw) * 0.72 - w/2, ph/2 + (0.42ph) * 0.70- h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#crew_driver_indicator';

  timeBar {
    id:t='transfere_indicatior';
  }
}

icon {
  id:t='crew_count';
  hudCrewStatus:t='yes';
  icon_type:t='crew_count'
  size:t='ph/7, ph/7';
  tooltip:t='#hud_tank_crew_members_count'

  position:t='absolute';
  pos:t='0, ph - h'

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#crew';

  textarea {
    id:t='crew_count_text';
    position:t='absolute';
    pos:t='pw, ph/2 - h/2';
    hudFont:t='normal';
    text-align:t='right';
    text:t='';
    style:t='paragraph-indent:0';
  }
}

icon {
  id:t='crew_distance';
  hudCrewStatus:t='yes'
  size:t='ph/7, ph/7';
  state:t='ok';
  tooltip:t=''
  position:t='absolute';
  pos:t='pw/2 + (0.42pw) * 0.23 - w/2, ph/2 + (0.42ph) * 0.99 - h/2';
  background-color:t='@white';
  background-image:t='#ui/gameuiskin#overview_icon';

  tdiv {
    id:t='cooldown'
    re-type:t='sector';
    sector-angle-1:t='0';
    sector-angle-2:t='0';
    size:t='pw, ph';
    position:t='absolute';
    pos:t=0,0;
    background-color:t='@white';
    background-image:t='#ui/gameuiskin#timebar';
  }

  icon {
    hudCrewStatus:t='yes'
    size:t='pw, ph';
    state:t='ok';
    position:t='absolute';
    pos:t= 0,0;
    background-color:t='@white';
    background-image:t='#ui/gameuiskin#timebar';
  }
}
