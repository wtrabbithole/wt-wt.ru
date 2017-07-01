<<#items>>
  shopFilter {
    <<#id>>
      id:t='<<id>>'
    <</id>>

    tooltip:t='<<tooltip>>'

    <<@params>>

    <<#disabled>>
      enable:t='no'
    <</disabled>>
    <<^disabled>>
      <<#selected>>
        selected:t='yes'
      <</selected>>
    <</disabled>>

    <<#image>>
      shopFilterImg {
        background-image:t='<<image>>'
      }
    <</image>>

    shopFilterText {
      text:t='<<text>>'
      hideEmptyText:t='yes'
    }

    <<#needCheckBoxImg>>
      CheckBoxImg {}
    <</needCheckBoxImg>>

    <<#navigationImage>>
      <<@navigationImage>>
    <</navigationImage>>

    <<#discountNotification>>
      discount_notification {
        <<#id>>
          id:t='<<id>>_discount'
        <</id>>
        type:t='<<type>>'
        text:t=''
      }
    <</discountNotification>>
  }
<</items>>
