img {
  id:t='mainActionButton';
  position:t='absolute';
  pos:t='pw/2 - w/2, -h - 0.005@shHud';
  size:t='0.04@shHud, 0.04@shHud';
  background-image:t='<<gamepadButtonImg>>';
}
<<#activatedButtonImg>>
img {
  id:t='activatedActionButton';
  position:t='absolute';
  pos:t='pw/2 - w/2, -h - 0.005@shHud';
  size:t='0.04@shHud, 0.04@shHud';
  background-image:t='<<activatedButtonImg>>';
  display:t='hide';
}
<</activatedButtonImg>>
img {
  id:t='cancelButton';
  position:t='absolute';
  pos:t='pw/2 - w/2, h + 0.005@shHud';
  size:t='0.03@shHud, 0.03@shHud';
  background-image:t='<<cancelButton>>';
  display:t='hide';
}
