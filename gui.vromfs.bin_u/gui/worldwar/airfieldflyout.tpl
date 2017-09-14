button {
  pos:t='0,0'
  position:t='root'
  size:t='pw,ph'
  background-color:t = '@modalShadeColor'
  on_click:t='goBack'
}

frame {
  id:t='airfield_body'
  pos:t = '40%pw - 50%w, 50%ph - 50%h'
  position:t='absolute'
  class:t='wndNav'

  max-width:t='1@rw'
  max-height:t='1@rh'

  frame_header {
    HorizontalListBox {
      id:t='armies_tabs'
      height:t='ph'
      class:t='header'
      normalFont:t='yes'
      activeAccesskeys:t='RS'
      on_select:t = 'onTabSelect';
      <<@headerTabs>>
    }

    Button_close {}
  }

  tdiv {
    id:t='unit_blocks_place'
    overflow-y:t='auto'
    flow:t='vertical'

    <<#unitString>>
      <<#unitClassText>>
        textareaNoTab {
          text:t='#worldwar/airfield/<<unitClassText>>'
        }
      <</unitClassText>>
      frameBlock {
        id:t='<<unitName>>_<<armyGroupIdx>>'
        margin-top:t='1@framePadding'

        textareaNoTab {
          pos:t='1@flyOutSliderWidth + 2@sliderButtonSquareHeight + 1@buttonWidth - w, 2@framePadding'
          position:t='absolute'
          smallFont:t='yes'
          tooltip:t='#worldwar/airfield/unit_fly_time'
          text:t='<<maxFlyTimeText>>'
        }

        tdiv {
          pos:t='1@slot_interval, ph - h - 1@slot_vert_pad'
          position:t='relative'
          width:t='1@flyOutSliderWidth + 2@sliderButtonSquareHeight + 1@buttonWidth'
          unitName:t='<<unitName>>'
          armyGroupIdx:t='<<armyGroupIdx>>'
          <<#disable>>
            inactive:t='yes'
          <</disable>>

          include "gui/commonParts/progressBar"
        }
        tdiv {
          class:t='rankUpList'
          <<@unitItem>>
        }
        tdiv {
          id:t='secondary_weapon'
          width:t='1@modItemWidth'
          height:t='1@modItemHeight'
        }
      }
    <</unitString>>
  }

  textareaNoTab {
    id:t='armies_limit_text'
    smallFont:t='yes'
    margin-top:t='1@framePadding'
    text:t=''
  }

  textareaNoTab {
    id:t='unit_fly_conditions_title'
    smallFont:t='yes'
    margin-top:t='1@framePadding'
    text:t='#worldwar/airfield/unit_fly_conditions'
  }

  textareaNoTab {
    id:t='unit_fly_conditions_text'
    smallFont:t='yes'
    text:t=''
  }

  navBar{}
}
