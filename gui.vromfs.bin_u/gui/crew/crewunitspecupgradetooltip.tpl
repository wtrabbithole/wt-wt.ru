crewUnitSpecUpgradeTooltip {
  flow:t='vertical'
  width:t='0.7*@sf'

  textareaNoTab {
    width:t='pw'
    padding:t='6*@sf/@pf_outdated'
    text:t='<<tooltipText>>'
  }

  <<#tinyTooltipText>>
  textareaNoTab {
    width:t='pw'
    padding:t='6*@sf/@pf_outdated'
    smallFont:t='yes'
    text:t='<<tinyTooltipText>>'
  }
  <</tinyTooltipText>>

  <<#hasExpUpgrade>>
  tdiv {
    height:t='10*@sf/@pf_outdated'
    width:t='pw - 30*@sf/@pf_outdated'
    pos:t='0.5pw - 0.5w, 30*@sf/@pf_outdated'
    position:t='relative'
    margin-bottom:t='16*@sf/@pf_outdated'

    crewSpecProgressBar {
      height:t='ph - 4*@sf/@pf_outdated'
      width:t='pw'
      top:t='0.5ph-0.5h'
      position:t='relative'
      min:t='0'
      max:t='1000'
      value:t='<<progressBarValue>>'
    }

    <<#markers>>
    referenceMarker {
      left:t='<<markerRatio>> * pw - 0.5w'
      textarea {
        position:t='absolute'
        pos:t='0.5pw - 0.5w, -h - 1*@sf/@pf_outdated'
        text:t='<<markerText>>'
      }
    }
    <</markers>>
  }

  textareaNoTab {
    padding:t='6*@sf/@pf_outdated'
    text:t='<<expUpgradeText>>'
    width:t='pw'
    exp_upgrade_text_area:t='yes'
  }
  <</hasExpUpgrade>>
}
