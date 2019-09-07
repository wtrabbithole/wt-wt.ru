<<#tabs>>
shopFilter {
  <<#id>>id:t='<<id>>'<</id>>

  <<#hidden>>
  display:t='hide'
  enable:t='no'
  <</hidden>>

  <<#visualDisable>>
    inactive:t='yes'
  <</visualDisable>>

  <<#selected>>
    selected:t='yes'
  <</selected>>

  <<#tabImage>>
  shopFilterImg { background-image:t='<<tabImage>>' }
  <</tabImage>>

  <<#unseenIcon>>
  unseenIcon {
    valign:t='center'
    value:t='<<unseenIcon>>'
    unseenText {}
  }
  <</unseenIcon>>

  <<@object>>

  shopFilterText {
    <<#id>>id:t='<<id>>_text'<</id>>
    text:t='<<tabName>>'
  }

  <<#discount>>
  discount {
    id:t='<<#discountId>><<discountId>><</discountId>><<^discountId>><<id>>_discount<</discountId>>'
    type:t='inTab'
    text:t='<<text>>'
    tooltip:t='<<tooltip>>'
  }
  <</discount>>

  <<#cornerImg>>
  cornerImg {
    <<#cornerImgId>>id:t='<<cornerImgId>>'<</cornerImgId>>
    <<^cornerImgId>>id:t='cornerImg'<</cornerImgId>>
    background-image:t='<<cornerImg>>'
    <<^show>>display:t='hide'<</show>>
    <<#orderPopup>>order-popup:t='yes'<</orderPopup>>
    <<#cornerImgSmall>>
      imgSmall:t='yes'
    <</cornerImgSmall>>
    <<^cornerImgSmall>>
      <<#cornerImgTiny>>
        imgTiny:t='yes'
      <</cornerImgTiny>>
    <</cornerImgSmall>>
    <<#hasGlow>>
    cornerImgGlow {}
    <</hasGlow>>
  }
  <</cornerImg>>

  <<@navImagesText>>
}
<</tabs>>
