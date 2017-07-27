<<#timersList>>
animSizeObj { //place div
  id:t='<<id>>';
  height:t='0.08@shHud';

  animation:t='hide';
  size-scale:t='selfsize';
  width-base:t='0';
  width-end:t='100'; //updated from script
  width:t='1';
  _size-timer:t='0'; //hidden by default

  massTransp {
    size:t='0.06@shHud, 0.06@shHud';
    pos:t='50%pw-50%w, 50%ph-50%h';
    position:t='absolute';
    _transp-timer:t='0'; //hidden by default

    tdiv {
      id:t='icon';
      size:t='0.85pw, 0.85ph';
      position:t='absolute';
      pos:t='pw/2 - w/2, ph/2 - h/2';
      background-color:t='<<color>>';
      background-image:t='<<icon>>';
      background-repeat:t='aspect-ratio';
    }

    timeBar {
      id:t='timer';
      size:t='1.167*pw, 1.167*ph';
      direction:t='forward';

      position:t='absolute';
      pos:t='pw/2 - w/2, ph/2 - h/2';

      background-color:t='@white';
      background-image:t='#ui/gameuiskin#circular_progress_1';

      tdiv {
        position:t='absolute';
        size:t='pw, ph';
        background-color:t='#33555555';
        background-image:t='#ui/gameuiskin#circular_progress_1';
      }
    }

    <<#needTimeText>>
    activeText {
      id:t='time_text';
      position:t='absolute';
      pos:t='pw/2 - w/2, ph/2 - h/2';
      hudFont:t='normal';

      behaviour:t='Timer';
      text:t='';
    }
    <</needTimeText>>
  }
}
<</timersList>>