skillParametersTooltip {
  flow:t='vertical'

  <<#skillName>>
  textareaNoTab {
    padding-top:t='12*@sf/@pf'
    padding-left:t='12*@sf/@pf'
    text:t='<<skillName>>'
    max-width:t='pw'
  }
  <</skillName>>

  tdiv {
    pos:t='13*@sf/@pf, @referenceProgressOffset'
    position:t='relative'

    <<#progressBarSelectedValue>>
    crewSpecProgressBar {
      height:t='@referenceProgressHeight'
      position:t='absolute'
      type:t='new'
      min:t='0'
      max:t='1000'
      value:t='<<progressBarSelectedValue>>'
    }

    crewSpecProgressBar {
      height:t='@referenceProgressHeight'
      position:t='absolute'
      type:t='old'
      min:t='0'
      max:t='1000'
      value:t='<<progressBarValue>>'
    }
    <</progressBarSelectedValue>>
  }

  textareaNoTab {
    padding-top:t='12*@sf/@pf'
    padding-left:t='12*@sf/@pf'
    text:t='<<tooltipText>>'
    min-width:t='0.3@scrn_tgt_font'
    max-width:t='0.7@scrn_tgt_font'
  }

  <<#hasSkillRows>>
  table {
    padding:t='12*@sf/@pf, 12*@sf/@pf'
    width:t='pw'

    <<#skillRows>>
    tr {
      height:t='0.038@scrn_tgt'

      td {
        textarea {
          pos:t='0, 0.5(ph-h)'
          position:t='relative'
          text:t='<<skillName>>'
        }
      }
      td {
        tdiv {
          size:t='<<maxSkillCrewLevel>> * (0.185@scrn_tgt \ (<<maxSkillCrewLevel>> * @skillProgressWidthMul)) * @skillProgressWidthMul, 2*@scrn_tgt/100.0'
          pos:t='0, 50%ph - 50%h - 0.002@scrn_tgt'; position:t='relative'

          skillProgressBg {
            height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul + 1@skillProgressBgIncSize'
            width:t='pw + 1@skillProgressBgIncSize + 1'
          }

          skillProgress {
            id:t='availableSkillProgress'
            height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
            width:t='pw'
            pos:t='50%pw-50%w, 50%ph-50%h';
            position:t="absolute"
            type:t='available'
            max:t='<<totalSteps>>'
            value:t='<<availableStep>>'
          }

          skillProgress {
            id:t='skillProgress'
            height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
            width:t='pw'
            pos:t='50%pw-50%w, 50%ph-50%h';
            position:t="absolute"
            type:t='old'
            max:t='<<skillMaxValue>>'
            value:t='<<skillValue>>'
          }
        }
      }
      td {
        textarea {
          pos:t='0, 0.5(ph-h)'
          position:t='relative'
          text:t='<<skillLevel>>'
        }
      }
    }
    <</skillRows>>
  }
  <</hasSkillRows>>

  table {
    padding:t='12*@sf/@pf, 12*@sf/@pf'

    <<#parameterRows>>
    tr {

      // Parameter description
      td {
        padding-top:t='15*@sf/@pf'
        textarea {
          pos:t='0, 0.5(ph-h)'
          position:t='relative'
          text:t='<<descriptionLabel>>'
          max-width:t='0.3@scrn_tgt_font'
        }
      }

      <<#valueItems>>
      td {
        padding-top:t='15*@sf/@pf'
        flow:t='horizontal'

        <<#itemDummy>>
        tdiv {
          size:t='30*@sf/@pf, 1*@sf/@pf'
        }
        <</itemDummy>>

        <<#itemImage>>
        img {
          pos:t='0.5(pw-w), 0.5(ph-h)'
          position:t='relative'
          background-image:t='<<itemImage>>'
          size:t='<<imageSize>>*@sf/@pf, <<imageSize>>*@sf/@pf'
          background-repeat:t='aspect-ratio'
          bgcolor:t='#FFFFFF'
        }
        <</itemImage>>

        <<#itemText>>
        textarea {
          pos:t='0.5(pw-w), 0.5(ph-h)'
          position:t='relative'
          text:t='<<itemText>>'
        }
        <</itemText>>
      }
      <</valueItems>>
    }
    <</parameterRows>>
  }

  tdiv {
    pos:t='12*@sf/@pf, 15*@sf/@pf'
    position:t='relative'
    flow:t='vertical'

    <<#headerItems>>
    <<#itemImage>>
    tdiv {
      img {
        pos:t='0, 0.5(ph-h)'
        position:t='relative'
        background-image:t='<<itemImage>>'
        size:t='<<imageSize>>*@sf/@pf, <<imageSize>>*@sf/@pf'
        background-repeat:t='aspect-ratio'
        bgcolor:t='#FFFFFF'
      }
      textarea{
        pos:t='1@helpInterval, 0.5(ph-h)'
        position:t='relative'
        tinyFont:t="yes"
        text:t='<<imageLegendText>>'
      }
    }
    <</itemImage>>
    <</headerItems>>
  }
}
