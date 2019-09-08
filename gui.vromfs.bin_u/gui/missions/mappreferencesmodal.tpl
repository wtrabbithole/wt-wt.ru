root {
  background-color:t = '@modalShadeColor'
  on_click:t='goBack'

  frame {
    width:t='<<maxCountX>>@mapPreferenceIconNestWidth + 1@mapPreferencePreviewFullWidth + <<#hasScroll>>1@scrollBarSize<</hasScroll>>';
    height:t='1@maxWindowHeight'
    max-width:t='1@rw'
    pos:t='0.5pw-0.5w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)'
    position:t='absolute'
    class:t='wnd'
    css-hier-invalidate:t='yes'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<wndTitle>>'
      }

      textarea {
        id:t='counters'
        position:t='relative'
        pos:t='0, 0.5ph-0.5h'
        text:t='<<counterTitle>>'
      }

      Button_close { id:t = 'btn_back' }
    }

    tdiv{
      size:t='pw, ph'
      flow:t='horizontal'
      css-hier-invalidate:t='yes'

      tdiv{
        size:t='fw, ph'
        tdiv {
          id:t='maps_list'
          width:t='pw'
          max-height:t='fh'
          padding-left:t='-1@framePadding'
          flow:t='h-flow'
          overflow-y:t='auto'
          behaviour:t='posNavigator'
          navigatorShortcuts:t='SpaceA'
          scrollbarShortcuts:t='yes'
          position:t='relative'
          on_select:t='onSelect'
          css-hier-invalidate:t='yes'
          total-input-transparent:t='yes'
          hasPremium:t='<<#premium>>yes<</premium>><<^premium>>no<</premium>>'
          hasMaxBanned:t='<<hasMaxBanned>>'
          hasMaxDisliked:t='<<hasMaxDisliked>>'
          <<#maps>>
          mapNest{
            flow:t='vertical'
            textStyle:t='mis-map'
            margin:t='1@mapPreferenceIconMargin, 1@blockInterval'
            css-hier-invalidate:t='yes'

            focus_border {}
            iconMap{
              id:t='icon_<<mapId>>'
              position:t='relative'
              state:t='<<state>>'
              css-hier-invalidate:t='yes'

              mapImg{
                id:t='mapIcon'
                mapId:t='<<mapId>>'
                background-image:t = '<<image>>'
                title:t='<<title>>'
              }

              tdiv{
                position:t='absolute'
                flow:t='horizontal'
                css-hier-invalidate:t='yes'

                mapStateBox{
                  id:t='disliked'
                  type:t='disliked'
                  mapId:t='<<mapId>>'
                  value:t='<<#disliked>>yes<</disliked>><<^disliked>>no<</disliked>>'
                  display:t='hide'
                  on_change_value:t = 'onUpdateIcon'
                  mapStateBoxImg{}
                }

                mapStateBox{
                  id:t='banned'
                  type:t='banned'
                  mapId:t='<<mapId>>'
                  value:t='<<#banned>>yes<</banned>><<^banned>>no<</banned>>'
                  display:t='hide'
                  on_change_value:t = 'onUpdateIcon'
                  mapStateBoxImg{}
                }
              }
            }

            textareaNoTab{
              text:t='<<title>>'
              word-wrap:t='no'
              padding:t='1@blockInterval, 1@blockInterval'
              position:t='relative'
            }
          }
          <</maps>>
        }
      }
      blockSeparator {}

      tdiv{
        height:t='ph'

        tdiv{
          id:t='map_preview'
          width:t='1@mapPreferencePreviewSize + 1@framePadding'
          height:t='ph - 1@buttonHeight - 2@buttonMargin'
          padding-left:t='1@framePadding'
          flow:t='vertical'
          position:t='relative'
          css-hier-invalidate:t='yes'

          textAreaCentered {
            id:t='title'
            class:t='active'
            width:t='1@mapPreferencePreviewSize'
            text:t=''
          }

          img {
            id:t='img_preview'
            size:t='pw, 1@mapPreferencePreviewSize'
            max-width:t='h'
            max-height:t='w'
            pos:t='0.5pw-0.5w, 1@blockInterval'
            position:t='relative'
            background-image:t=''
          }

          tdiv {
            id:t='tactical-map'
            size:t='pw, 1@mapPreferencePreviewSize'
            max-width:t='h'
            max-height:t='w'
            pos:t='0.5pw-0.5w, 1@blockInterval'
            position:t='relative'
            display:t='hide'

            tacticalMap {
              size:t='pw, ph'
            }
          }

          mapStateBox{
            id:t='dislike'
            type:t='disliked'
            margin:t='0, 1@blockInterval'
            position:t='relative'
            mapStateBoxText {text:t='#maps/preferences/dislike'}
            on_change_value:t = 'onUpdateIcon'
            btnName:t='X'
            ButtonImg{}
            mapStateBoxImg{}
          }

          mapStateBox{
            id:t='ban'
            type:t='banned'
            margin:t='0, 1@blockInterval'
            position:t='relative'
            mapStateBoxText {text:t='#maps/preferences/ban'}
            <<^premium>>
            inactiveColor:t='yes'
            tooltip:t= '#mainmenu/onlyWithPremium'
            <</premium>>
            on_change_value:t = 'onUpdateIcon'
            btnName:t='Y'
            ButtonImg{}
            mapStateBoxImg{}
          }

          rowSeparator{}

          textAreaCentered {
            id:t='listTitle'
            class:t='active'
            width:t='1@mapPreferencePreviewSize'
            text:t='<<listTitle>>'
          }

          tdiv {
            id:t='ban_list'
            width:t='pw'
            max-height:t='fh'
            flow:t='vertical'
            overflow-y:t='auto'
            scrollbarShortcuts:t='yes'
            position:t='relative'
            css-hier-invalidate:t='yes'

            include "gui/missions/mapStateBox"
          }
        }

        Button_text {
          id:t='btnReset'
          left:t='pw-w-1@buttonMargin'
          top:t='ph-h-1@buttonMargin'
          position:t='absolute'
          text:t = '#mainmenu/btnReset'
          display:t='hide'
          on_click:t = 'onResetPreferencess'
          btnName:t='RT'
          ButtonImg {}
        }
      }
    }
  }
  gamercard_div {}

  tdiv{
    id:t='chatPopupNest';
    size:t='0.4@sf+10, 0.075*@sf+10';
    position:t='absolute';
    pos:t='0.5pw-0.5w, 0'
    flow:t='vertical'
  }
}