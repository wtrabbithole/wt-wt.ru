div {
  size:t='sw, sh'
  position:t='root'
  pos:t='0, 0'
  behavior:t='button'
  on_click:t='goBack'
  on_r_click:t='goBack'
  input-transparent:t='yes'
  accessKey:t='Esc | J:B'
}

popup_menu {
  id:t='main_frame'
  width:t='1@sliderWidth + 2@buttonHeight + 4@blockInterval'
  min-width:t='<<columns>>*(<<maxRecipeLen>> * 0.5@itemWidth + 1@itemsInterval) - 1@itemsInterval + 2@framePadding'
  position:t='root'
  pos:t='<<position>>'
  menu_align:t='<<align>>'
  total-input-transparent:t='yes'
  flow:t='vertical'

  Button_close { _on_click:t='goBack'; smallIcon:t='yes'}

  textAreaCentered {
    id:t='header_text'
    width:t='pw'
    overlayTextColor:t='active'
    text:t='<<headerText>>'
  }

  div {
    id:t='recipes_list'
    width:t='pw'
    margin-top:t='1@itemsInterval'
    padding:t='-1@itemsInterval'
    height:t='<<rows>>*(0.5@itemHeight + 1@itemsInterval) - 1@itemsInterval'
    flow:t="h-flow"
    total-input-transparent:t='yes'
    overflow-y:t='auto'

    behaviour:t='posNavigator'
    moveX:t='linear'
    moveY:t='linear'
    navigatorShortcuts:t='yes'
    on_select:t='onRecipeSelect'

    <<#recipesList>>
    recipe {
      size:t='<<maxRecipeLen>> * 0.5@itemWidth, 0.5@itemHeight'
      margin:t='@itemsInterval'
      smallItems:t="yes"
      <<@getIconedMarkup>>
    }
    <</recipesList>>
  }

  navBar {
    class:t='relative'
    style:t='height:<<maxRecipeLen>>@dIco + 1@navBarTopPadding + 2@buttonMargin;'

    navLeft {
      height:t='ph - 1@navBarTopPadding'
      tdiv {
        id:t='selected_recipe_info'
        pos:t='0, ph-h + 0.1@dIco'
        position:t='relative'
      }
    }

    navRight {
      height:t='ph - 1@navBarTopPadding'
      Button_text {
        id:t = 'btn_apply'
        text:t = '<<buttonText>>'
        btnName:t='A'
        _on_click:t = 'onRecipeApply'
        ButtonImg {}
      }
    }
  }

  popup_menu_arrow{}
}
