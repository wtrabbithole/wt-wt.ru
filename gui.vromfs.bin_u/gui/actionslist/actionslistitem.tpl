<<#actions>>
<<#show>>

<<#isLink>>
button {
<</isLink>>

<<^isLink>>
actionListItem {
<</isLink>>

  id:t='<<actionName>>'
  behavior:t='button';

  on_click:t='onAction';

  <<#disabled>>
  enable:t='no'
  <</disabled>>

  <<#icon>>
  icon {
    <<#iconRotation>>
      rotation:t = '<<iconRotation>>'
    <</iconRotation>>
    background-image:t='<<icon>>'; }
  <</icon>>

  <<#haveWarning>>
  warning_icon { id:t='warning_icon' }
  <</haveWarning>>

  text {
    behavior:t='textarea';
    text:t='<<text>>';
    <<#isLink>>
      isLink:t='yes';
      underline{}
    <</isLink>>
  }

  <<#haveDiscount>>
  discount_notification {
    id:t='discount_image';
    type:t='line'
  }
  <</haveDiscount>>
}
<</show>>
<</actions>>
