icon {
  id:t='engine_state';
  hudTankDebuff:t='yes';
  size:t='p.p.h/7, p.p.h/7';
  state:t='ok';

  pos:t='pw/2 - (0.42pw) * 0.924 - w/2, ph/2 + (0.42ph) * 0.383 - h/2';
  position:t='absolute';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#engine_state_indicator';
}

icon {
  id:t='transmission_state';
  hudTankDebuff:t='yes';
  size:t='ph/7, ph/7';
  state:t='ok';

  position:t='absolute';
  pos:t='pw/2 - (0.42pw) * 0.707 - w/2, ph/2 + (0.42ph) * 0.707 - h/2';

  background-image:t='#ui/gameuiskin#ship_transmission_state_indicator';
}

icon {
  id:t='steering_gear_state';
  hudTankDebuff:t='yes';
  size:t='p.p.h/7, p.p.h/7';
  state:t='ok';

  position:t='absolute';
  pos:t='pw/2 - (0.42pw) * 0.383 - w/2, ph/2 + (0.42ph) * 0.924 - h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#ship_steering_gear_state_indicator';
}


icon {
  id:t='artillery_weapon_state';
  hudTankDebuff:t='yes';
  size:t='ph/7, ph/7';
  state:t='ok';

  position:t='absolute';
  pos:t='pw/2 - (0.42pw) * 0.342 - w/2, ph/2 - (0.42ph) * 0.94 - h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#artillery_weapon_state_indicator';
}

icon {
  id:t='torpedo_state';
  hudTankDebuff:t='yes';
  size:t='ph/7, ph/7';
  state:t='ok';

  position:t='absolute';
  pos:t='pw/2 - (0.42pw) * 0.766 - w/2, ph/2 - (0.42ph) * 0.643 - h/2';

  background-color:t='@white';
  background-image:t='#ui/gameuiskin#ship_torpedo_weapon_state_indicator';
}


tdiv {
  id:t='buoyancy_indicator';
  hudTankDebuff:t='yes';
  size:t='ph/7, ph/7';

  position:t='absolute';
  pos:t='pw/2 + (0.42pw) * 0.5 - w/2, ph/2 - (0.42ph) * 0.866 - h/2';
  flow:t='h-flow';

  textareaNoTab {
    id:t='buoyancy_indicator_text';
    hudFont:t='small';
    overlayTextColor:t='active';
    text-align:t='right';
    text:t='';
    style:t='paragraph-indent:0';
  }

  //custom icon smaller then regular
  icon {
    size:t='pw, ph/4';
    position:t='relative';
    pos:t='0, -0.5h';
    background-color:t='@white';
    background-image:t='#ui/gameuiskin#buoyancy_icon';
  }
}

icon {
  id:t='fire_status';
  size:t='ph/7, ph/7';
  display:t='hide';

  position:t='absolute';
  pos:t='pw/2 + (0.42pw) * 0.766 - w/2, ph/2 - (0.42ph) * 0.643 - h/2';

  background-color:t='@red';
  background-image:t='#ui/gameuiskin#fire_indicator';
}

div {
  position:t='root'
  left:t='sw/2 - w/2'
  bottom:t='@bhHud + 0.15@shHud'

  <<#timersList>>
  animSizeObj { //place div
    id:t='<<id>>';
    height:t='0.08@shHud'

    animation:t='hide'
    size-scale:t='selfsize'
    width-base:t='0'
    width-end:t='100' //updated from script
    width:t='1'
    _size-timer:t='0' //hidden by default

    massTransp {
      id:t='icon'
      size:t='0.06@shHud, 0.06@shHud'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'

      background-color:t='<<color>>';
      background-image:t='<<icon>>';
      background-repeat:t='aspect-ratio'
      _transp-timer:t='0' //hidden by default

      timeBar {
        id:t='timer'
        size:t='1.167*pw, 1.167*ph';
        direction:t='forward'

        position:t='absolute';
        pos:t='pw/2 - w/2, ph/2 - h/2';

        background-color:t='@white';
        background-image:t='#ui/gameuiskin#circular_progress_1';

        tdiv {
          position:t='absolute'
          size:t='pw, ph'
          background-color:t='#33555555';
          background-image:t='#ui/gameuiskin#circular_progress_1';
        }
      }

      <<#needTimeText>>
      activeText {
        id:t='time_text'
        position:t='absolute'
        pos:t='pw/2 - w/2, ph/2 - h/2'
        hudFont:t='normal'

        behaviour:t='Timer'
        text:t=''
      }
      <</needTimeText>>
    }
  }
  <</timersList>>
}

