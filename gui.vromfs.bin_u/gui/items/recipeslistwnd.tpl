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
  min-width:t='<<itemsInRow>> * 0.5@itemWidth +  <<columns>> * 2@recipeInterval + (<<columns>> - 1) * @itemsSeparatorSize+ 2@dp'
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

  tdiv {
    size:t='pw, @itemsSeparatorSize'
    background-color:t='@frameSeparatorColor'
    margin-top:t='1@blockInterval'
  }

  div {
    id:t='recipes_list'
    width:t='pw'
    padding:t='-1@framePadding + 1@dp, 0'
    padding-bottom:t='-1@blockInterval'
    height:t='<<rows>>*(0.5@itemHeight + 1@recipeInterval) + 1@recipeInterval - 1@blockInterval'
    flow:t="v-flow"
    total-input-transparent:t='yes'
    overflow-y:t='auto'

    behaviour:t='posNavigator'
    moveX:t='linear'
    moveY:t='linear'
    navigatorShortcuts:t='yes'
    on_select:t='onRecipeSelect'

    <<#recipesList>>
    <<#isSeparator>>
    itemsSeparator { height:t='ph - 2@recipeInterval'; margin:t='@recipeInterval, 0'; }
    <</isSeparator>>
    <<^isSeparator>>
    recipe {
      height:t='0.5@itemHeight'
      margin:t='@recipeInterval'
      smallItems:t="yes"
      css-hier-invalidate:t='yes'

      <<@getIconedMarkup>>

      focus_border {}
    }
    <</isSeparator>>
    <</recipesList>>
  }

  navBar {
    class:t='relative'
    //0.1@dico - is a visual space in item type icon.
    style:t='height:<<maxRecipeLen>>@dIco - 0.2@dIco + 1@navBarTopPadding + 1@buttonMargin;'

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
