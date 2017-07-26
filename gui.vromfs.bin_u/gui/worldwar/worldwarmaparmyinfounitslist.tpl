tdiv {
  width:t='pw'
  padding:t='1@framePadding, 0'

  <<#columns>>
    tdiv {
      <<#multipleColumns>>
        width:t='50%pw'
        <<^first>>
          padding-left:t='0.01@scrn_tgt'
        <</first>>
      <</multipleColumns>>
      <<^multipleColumns>>
        position:t='relative'
      <</multipleColumns>>

      flow:t='vertical'
      css-hier-invalidate:t='yes'

      include "gui/worldWar/worldWarArmyInfoUnitString"
    }
  <</columns>>
}
<<#multipleColumns>>
  blockSeparator {}
<</multipleColumns>>
