<<#skinDescription>>
  titleTextArea {
    text-align:t='center'
    text:t='<<name0>>'
  }

  titleTextArea {
    text-align:t='center'
    text:t='<<name>>'
  }

  tdiv{
    size:t = 'pw, fh'
    flow:t='vertical'
    bigMedalPlace{
      bigMedalImg {
        max-height:t='<<ratio>>*h'
        max-width:t='<<ratio>>*w'
        background-image:t='<<image>>'
        status:t='<<status>>'
      }
    }

    tdiv{
      flow:t='vertical'
      size:t='pw, 0'
      max-height:t='ph-@bigMedalPlaceYpos-<<ratio>>*@profileMedalSize-@modStatusCheckboxHeight-3@blockInterval'
      margin:t='0,@blockInterval'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'

      <<#condition>>
        <<#isHeader>>unlockConditionHeader<</isHeader>>
        <<^isHeader>>unlockCondition<</isHeader>>
        {
          unlocked:t='<<unlocked>>'
          textarea{
            text:t='<<text>>'
          }
          <<#hasProgress>>
          challengeDescriptionProgress{
            id:t='progress'
            value:t='<<progress>>'
          }
          <</hasProgress>>
          <<#isForGoldOnly>>
          textarea{
            text:t='<<price>>'
          }
          <</isForGoldOnly>>
        }
      <</condition>>
    }

    <<#isUnlock>>
    tdiv {
      padding-left:t='@unlockConditionHeaderLeftPadding'
      margin:t='0, @blockInterval'

      CheckBox {
        id:t='checkbox-favorites'
        text:t='#mainmenu/UnlockAchievementsToFavorite'
        smallFont:t='yes'
        tooltip:t=''
        on_change_value:t='unlockToFavorites'
        unlockId:t=''
        btnName:t='Y'
        ButtonImg{}
        CheckBoxImg{}
      }
    }
    <</isUnlock>>
  }
<</skinDescription>>