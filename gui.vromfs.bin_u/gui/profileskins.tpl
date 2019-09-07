<<#skinDescription>>
  id:t='item_field'
  flow:t='vertical'
  size:t='pw,fh'

  bigMedalPlace{
    bigMedalImg {
      max-height:t='<<height>>'
      max-width:t='<<width>>'
      background-image:t='<<image>>'
      status:t='<<status>>'
    }
  }

  <<#condition>>
    <<#isHeader>>unlockConditionHeader<</isHeader>>
    <<^isHeader>>unlockCondition<</isHeader>>
    {
      unlocked:t='<<unlocked>>'
      textarea{
        id:t='<<id>>'
        text:t='<<text>>'
      }
      <<#hasProgress>>
      challengeDescriptionProgress{
        id:t='progress'
        value:t='<<progress>>'
      }
      <</hasProgress>>
    }
  <</condition>>
  <<#isNotUnlock>>
  textarea{
    width:t=pw
    padding-left:t=@unlockHeaderIconSize
    margin-bottom:t=1@scrn_tgt/100.0
    text:t='<<price>>'
  }
  <</isNotUnlock>>
<</skinDescription>>

