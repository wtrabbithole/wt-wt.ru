<<#items>>
awardItemDiv {
  emptyBlock:t='<<emptyBlock>>'
  flow:t='vertical'

  awardItemHeader {
    <<#havePeriodReward>>
      <<^openedPicture>>
        havePeriodReward:t='yes'
      <</openedPicture>>
    <</havePeriodReward>>

    <<#current>>
      today:t='yes'
      arrowCurrent{}
    <</current>>

    size:t='pw, 1@frameHeaderHeight+1';
    tdiv {
      width:t='pw'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='relative'
      flow:t='vertical'
      textarea {
        id:t='award_day_text';
        pos:t='50%pw-50%w, 0';
        position:t='relative'
        removeParagraphIndent:t='yes'
        text:t='<<award_day_text>>';
        text-align:t='center'
      }
      textarea {
        id:t='award_day_text';
        pos:t='50%pw-50%w, -0.005@sf';
        position:t='relative'
        removeParagraphIndent:t='yes'
        text:t='<<week_day_text>>';
        text-align:t='center'
      }
    }
  }

  <<@item>>

  <<#periodicRewardImage>>
  periodicRewardImage {
    background-image:t='@!<<@periodicRewardImage>>'
    <<#openedPicture>>
      opened:t='yes'
    <</openedPicture>>
  }
  <</periodicRewardImage>>
}
<</items>>
