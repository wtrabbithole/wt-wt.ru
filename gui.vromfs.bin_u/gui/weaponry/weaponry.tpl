<<#bgBlocks>>
include "gui/weaponry/weaponryBg"
<</bgBlocks>>

<<#weaponryList>>
tdiv {
  id:t='weaponry_list'
  position:t='absolute'

  behavior:t='posNavigator'
  navigatorShortcuts:t='SpaceA'
  moveX:t='closest'
  moveY:t='linear'

  //on_select:t = 'updateDependingButtons';
  //on_click:t='onAircraftClick'
  on_activate:t='onWeaponryActivate'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'
  on_wrap_left:t='onWrapLeft'
  on_wrap_right:t='onWrapRight'

  <<@weaponryList>>
}
<</weaponryList>>

DummyButton {
  btnName:t='LB'
  _on_click:t='onBulletsDecrease'
  _on_click_repeat:t = 'onBulletsDecrease'
}

DummyButton {
  btnName:t='RB'
  _on_click:t='onBulletsIncrease'
  _on_click_repeat:t = 'onBulletsIncrease'
}