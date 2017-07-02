tdiv {
  id:t='armies_object'
  size:t='pw, ph'
  flow:t='vertical'

  HorizontalListBox {
    id:t='armies_by_status_list'
    height:t='0.028@scrn_tgt'

    navigatorShortcuts:t='yes'
    on_select:t='onArmiesByStatusTabChange'
    on_wrap_up:t='onWrapUp'
    on_wrap_down:t='onWrapDown'

    <<#armiesByState>>
      shopFilter {
        shopFilterText {
          pos:t='0, 50%(ph-h)'; position:t='relative'
          text:t='<<tabIconText>> '
        }
        shopFilterText {
          id:t='army_by_state_title_<<id>>'
          display:t='hide'
          tinyFont:t='yes'
          text:t='<<tabText>> '
        }
        shopFilterText {
          id:t='army_by_state_title_count_<<id>>'
          tinyFont:t='yes'
          text:t='<<armiesCountText>>'
        }
      }
    <</armiesByState>>
  }

  ReinforcementsRadioButtonsList {
    id:t='armies_tab_content'
    size:t='pw, fh'
    margin:t='1@framePadding'
    flow:t='h-flow'
    flow-align:t='left'
  }

  statusPanel {
    id:t='paginator_nest_obj'
    size:t='pw, 1@statusPanelHeight'
    background-color:t='@objectiveHeaderBackground'

    tdiv {
      id:t='paginator_place'
      pos:t='50%(pw-w), 50%(ph-h)'; position:t='relative'
    }
  }
}
