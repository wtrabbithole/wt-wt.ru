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

  <<#newIconWidget>>
  newIconWidget {
    id:t='tab_new_icon_widget'
    pos:t='0, 0.5ph-0.5h'
    position:t='relative'
    <<@newIconWidget>>
  }
  <</newIconWidget>>

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
    <<#cornerImgSmall>>imgSmall:t='yes'<</cornerImgSmall>>
  }
  <</cornerImg>>

  <<@navImagesText>>
}
<</tabs>>
