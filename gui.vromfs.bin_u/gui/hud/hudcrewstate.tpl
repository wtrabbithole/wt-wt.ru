icon {
  id:t='crew_gunner';
  hudCrewStatus:t='yes'
  icon_type:t='crew_gunner'
  size:t='ph/7, ph/7';
  tooltip:t=''

  position:t='absolute';
  pos:t='pw/2 + (0.42pw) * 0.866 - w/2, ph/2 + (0.42ph) * 0.5 - h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#crew_gunner_indicator';

  timeBar {
    id:t='transfere_indicatior';
  }
}

icon {
  id:t='crew_driver';
  hudCrewStatus:t='yes';
  icon_type:t='crew_driver'
  size:t='ph/7, ph/7';
  tooltip:t=''

  position:t='absolute';
  pos:t='pw/2 + (0.42pw) * 0.5 - w/2, ph/2 + (0.42ph) * 0.866 - h/2';

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
    hudFont:t='small';
    text-align:t='right';
    text:t='';
    style:t='paragraph-indent:0';
  }
}
