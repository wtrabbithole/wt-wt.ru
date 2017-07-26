<<#objectives>>
wwObjective {
  id:t='<<id>>'
  status:t='<<status>>'
  size:t='pw, 1@objectiveHeight'
  tdiv {
    pos:t='0, 50%ph-50%h'
    position:t='relative'
    width:t='pw'
    flow:t='vertical'
    tdiv {
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      taskIcon {
        id:t='statusImg'
        background-image:t='<<statusImg>>'
      }
      name {
        id:t='<<getNameId>>'
        text:t='<<getName>>'
        max-width:t='p.p.w'
      }
    }
    desc {
      text:t='<<getDesc>>'
      hideEmptyText:t='yes'
      max-width:t='pw'
    }
    paramsBlock {
      flow:t='vertical';
      width:t='pw';
      <<#getParamsArray>>
        tdiv {
          id:t='<<id>>'
          pos:t='50%pw-50%w, 0'
          position:t='relative'
          tinyFont:t='yes';

          textareaNoTab {
            id:t='pName'
            text:t='<<pName>>'
          }
          textareaNoTab { text:t='#ui/colon' }
          textareaNoTab {
            id:t='pValue'
            text:t='<<pValue>>'
            overlayTextColor:t='active'
          }
        }
      <</getParamsArray>>
    }
    paramsBlock {
      pos:t='50%pw-50%w, 0'
      position:t='relative'

      <<#hasObjectiveZones>>
      objectiveZones {
        css-hier-invalidate:t='yes'
        on_hover:t='onHoverName'
        on_unhover:t='onHoverLostName'

        <<#getUpdatableZonesData>>
        textareaNoTab {
          id:t='<<id>>'
          text:t='<<text>>'
          team:t='<<team>>'
          input-transparent:t='yes'
          tinyFont:t='yes'
        }
        <</getUpdatableZonesData>>
      }
      <</hasObjectiveZones>>

      <<#getUpdatableData>>
        updatableParam {
          id:t='<<id>>'
          status:t='<<status>>'
          width:t='pw'
          margin:t='0.02@scrn_tgt, 0'
          team:t='<<team>>'
          css-hier-invalidate:t='yes'
          tinyFont:t='yes'
            textareaNoTab {
              id:t='pName'
              text:t='<<pName>>'
              <<#addHoverCb>>
                on_hover:t='onHoverName'
                on_unhover:t='onHoverLostName'
              <</addHoverCb>>
              <<#colorize>>
                overlayTextColor:t='<<colorize>>'
              <</colorize>>
            }
            <<#pValue>>
              textareaNoTab { text:t='#ui/colon' }
              textareaNoTab {
                id:t='pValue'
                text:t='<<pValue>>'
                overlayTextColor:t='<<#colorize>><<colorize>><</colorize>><<^colorize>>active<</colorize>>'
              }
            <</pValue>>
        }
      <</getUpdatableData>>
    }
  }
  <<^isLastObjective>>
    objectiveSeparator{ inactive:t='yes' }
  <</isLastObjective>>
}

<</objectives>>
