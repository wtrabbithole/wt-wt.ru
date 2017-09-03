root {
  background-color:t='@shadeBackgroundColor'

  frame {
    class:t='wndNav'
    largeNavBarHeight:t='yes'
    type:t='dark'

    size:t='1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar'
    pos:t='50%pw-50%w, 1@minYposWindow'
    position:t='absolute'

    frame_header {
      activeText {
        id:t='battle_description_frame_text'
        text:t='#userlog/page/battle'
        caption:t='yes'
      }

      Button_close {}
    }

    tdiv {
      size:t='pw, ph'

      chapterListPlace {
        id:t='chapter_place'
        height:t='ph'
        flow:t = 'vertical'
        increaseWidthForWide:t='yes'

        textareaNoTab {
          id:t='no_active_battles_text'
          width:t='pw'
          margin-top:t='0.01@scrn_tgt'
          text-align:t='center'
          text:t='#worldwar/operation/noActiveBattles'
        }

        listbox {
          id:t='items_list'
          size:t='pw, fh'
          flow:t = 'vertical'
          focus:t='yes'
          _on_select:t='onItemSelect'
          on_wrap_up:t='onWrapUp'
          on_wrap_down:t='onWrapDown'
        }

        tdiv {
          id:t='queue_info'
          size:t='pw, ph'
          flow:t='vertical'

          dummy {
            id:t="ww_queue_update_timer"
            behavior:t='Timer'
            timer_handler_func:t='onTimerUpdate'
            timer_interval_msec:t='1000'
          }

          tdiv {
            flow:t='vertical'
            pos:t='1@framePadding, 0'; position:t='relative'

            tdiv {
              id:t='SIDE_1_queue_side_info'
            }

            tdiv {
              id:t='SIDE_2_queue_side_info'
            }
          }

          tdiv {
            pos:t='1@framePadding, ph-h-1@framePadding'; position:t='absolute'
            flow:t='vertical'

            tdiv {
              textareaNoTab {
                pos:t='0, 50%ph-50%h'; position:t='relative'
                text:t='#worldWar/waiting_session'
              }

              animated_wait_icon {
                pos:t='0, 50%ph-50%h'; position:t='relative'
                margin-left:t='10*@sf/@pf_outdated'
                background-rotation:t='0'
                display:t='show'

                wait_icon_cock {}
              }
            }

            tdiv {
              pos:t='0, 0'; position:t='relative'

              textareaNoTab {
                text:t='#worldWar/waiting_time'
              }

              textAreaCentered {
                id:t='ww_queue_waiting_time'
                text:t=''
              }
            }
          }
        }
      }

      blockSeparator { margin:t='1, 0' }

      tdiv {
        id:t='item_desc'
        size:t='fw, ph'
        flow:t='vertical'
      }
    }

    navBar {
      navLeft{
        Button_text {
          id:t='cluster_select_button'
          width:t='1@bigButtonWidth'
          textareaNoTab {
            id:t='cluster_select_button_text'
            text:t='#options/cluster'
            height:t='ph'
            width:t='pw'
            pare-text:t='yes'
            input-transparent:t='yes'
          }
          on_click:t='onOpenClusterSelect'
          btnName:t='X'
          refuseOpenHoverMenu:t='no'
          ButtonImg {}
        }
      }

      navRight {
        activeText {
          id:t='cant_join_reason_txt'
          pos:t='0, 50%ph-50%h'; position:t='relative'
          padding-right:t='5*@sf/@pf_outdated'
          text:t=''
        }
        Button_text {
          id:t='btn_join_battle'
          class:t='battle'
          navButtonFont:t='yes'
          _on_click:t='onJoinBattle'
          css-hier-invalidate:t='yes'
          isCancel:t='no'
          btnName:t='A'
          inactive:t='no'

          pattern{}
          buttonWink { _transp-timer:t='0' }
          buttonGlance {}
          ButtonImg {}
          textarea {
            class:t='buttonText'
            text:t='#mainmenu/toBattle'
          }
        }
        Button_text {
          id:t='btn_leave_battle'
          class:t='battle'
          navButtonFont:t='yes'
          text:t='#mainmenu/btnCancel'
          _on_click:t='onLeaveBattle'
          css-hier-invalidate:t='yes'
          isCancel:t='yes'
          btnName:t='B'
          display:t='hide'
          enable:t='no'

          pattern{}
          buttonWink { _transp-timer:t='0' }
          buttonGlance {}
          ButtonImg{}
          btnText {
            id:t='btn_leave_event_text'
            text:t='#mainmenu/btnCancel'
          }
        }
      }
    }
  }
}
