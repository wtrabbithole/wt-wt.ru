icon {
  id:t='tracks_state';
  hudTankDebuff:t='yes'
  size:t='ph/7, ph/7';
  state:t='ok';

  position:t='absolute';
  pos:t='pw/2 - (0.42pw) * 0.999 - w/2, ph/2 - (0.42ph) * 0.044 - h/2';

  background-image:t='#ui/gameuiskin#track_state_indicator';

}

icon {
  id:t='turret_drive_state';
  hudTankDebuff:t='yes'
  size:t='p.p.h/7, p.p.h/7';
  state:t='ok';

  pos:t='pw/2 - (0.42pw) * 0.887 - w/2, ph/2 - (0.42ph) * 0.462 - h/2';
  position:t='absolute';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#turret_gear_state_indicator';
}

icon {
  id:t='gun_state';
  hudTankDebuff:t='yes'
  size:t='p.p.h/7, p.p.h/7';
  state:t='ok';

  position:t='absolute';
  pos:t='pw/2 - (0.42pw) * 0.609 - w/2, ph/2 - (0.42ph) * 0.793 - h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#gun_state_indicator';
}

icon {
  id:t='engine_state';
  hudTankDebuff:t='yes'
  size:t='ph/7, ph/7';
  state:t='ok';

  position:t='absolute';
  pos:t='pw/2 - (0.42pw) * 0.216 - w/2, ph/2 - (0.42ph) * 0.976 - h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#engine_state_indicator';
}

icon {
  id:t='fire_status';
  size:t='ph/7, ph/7';
  display:t='hide';

  position:t='absolute';
  pos:t='ph/7 * 2.5, ph - h';

  background-color:t='@red';
  background-image:t='#ui/gameuiskin#fire_indicator';
}
