root {
  background-color:t='@shadeBackgroundColor'

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h'
    max-height:t='1@maxWindowHeight'
    position:t='absolute'
    class:t='wnd'
    padByLine:t='yes'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<frameHeaderText>>'
      }
      Button_close {}
    }
    tdiv {
      position:t='relative'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'
      <<#branchesView>>
        craftBranchTree {
          width:t='<<branchWidth>>'
          height:t='fh'
          flow:t='vertical'
          <<#branchHeader>>
            craftBranchHeader {
              width:t='pw'
              text:t='<<branchHeader>>'
              text-align:t='center'
              <<#separators>>
                craftTreeSeparator{}
              <</separators>>
            }
          <</branchHeader>>
          <<#branchHeaderItems>>
            craftBranchRow {
              smallItems:t='yes'
              isHeader:t='yes'
              <<#itemsSize>>itemsSize:t='<<itemsSize>>'<</itemsSize>>
              itemsBlock {
                position:t='absolute'
                pos:t='0.5pw - 0.5w, 0.5ph - 0.5h'
                include "gui/items/item"
              }
              <<#separators>>
                craftTreeSeparator{}
              <</separators>>
              craftTreeSeparator{
                located:t='bottom'
              }
            }
          <</branchHeaderItems>>
          craftBranchBody {
            width:t='pw'
            max-height:t='fh'
            flow:t='vertical'
            <<#separators>>
              craftTreeSeparator {}
            <</separators>>
            <<#rows>>
              craftBranchRow {
              <<#itemsSize>>itemsSize:t='<<itemsSize>>'<</itemsSize>>
              <<#itemBlock>>
                itemBlock {
                  <<#hasComponent>>hasComponent:t='yes'<</hasComponent>>
                  <<#isDisabled>>isDisabled:t='yes'<</isDisabled>>
                  include "gui/items/item"
                  <<#shopArrow>>
                    shopArrow {
                      type:t='<<arrowType>>'
                      size:t='<<arrowSize>>'
                      pos:t='<<arrowPos>>'
                    }
                  <</shopArrow>>
                  tdiv {
                    <<#component>><<@component>><</component>>
                  }
                }
              <</itemBlock>>
              }
            <</rows>>
          }
        }
      <</branchesView>>
    }
  }
}
