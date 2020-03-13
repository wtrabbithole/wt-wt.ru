icon {
  id:t='tracks_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.999 - w/2, ph/2 - (0.42ph) * 0.044 - h/2';
  background-image:t='#ui/gameuiskin#track_state_indicator.svg'

}

icon {
  id:t='turret_drive_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.947 - w/2, ph/2 - (0.42ph) * 0.402 - h/2';
  background-color:t='@white';
  background-image:t='#ui/gameuiskin#turret_gear_state_indicator.svg'
}

icon {
  id:t='gun_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.729 - w/2, ph/2 - (0.42ph) * 0.713 - h/2';
  background-color:t='@white';
  background-image:t='#ui/gameuiskin#gun_state_indicator.svg'
}

icon {
  id:t='engine_state';
  hudTankDebuff:t='yes'
  state:t='ok';
  pos:t='pw/2 - (0.42pw) * 0.396 - w/2, ph/2 - (0.42ph) * 0.926 - h/2';
  background-color:t='@white';
  background-image:t='#ui/gameuiskin#engine_state_indicator.svg'
}

text {
  id:t='stabilizer'
  hudTankDebuff:t='yes'
  state:t='<<stateValue>>'
  position:t='absolute'
  pos:t='pw/2 - w/2, 0.08ph - h/2'
  text:t='#HUD/TXT_STABILIZER'
  css-hier-invalidate:t='yes'
  behaviour:t='bhvHudTankStates'
  display:t='hide'
}

icon {
  id:t='fire_status';
  display:t='hide';
  pos:t='ph/7 * 2.5, ph - h';
  background-color:t='@red';
  background-image:t='#ui/gameuiskin#fire_indicator.svg'
}
